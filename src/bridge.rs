use std::path::PathBuf;
use std::sync::Mutex;
use std::time::{Duration, Instant};

use crate::cache::MonitorCache;
use crate::monitor::Monitor;
use crate::storage;

#[cxx::bridge(namespace = "wattwatch")]
mod ffi {
    // ── 功耗采样 ──
    // timestamp: unix 秒;power: 功率(瓦,正数);charging: true=输入(充电) / false=输出(放电)
    struct PowerSample {
        timestamp: i64,
        power: f32,
        charging: bool,
    }

    extern "Rust" {
        // ── 类型 ──
        type WattWatchBackend;

        // ── 工厂 ──
        fn make_backend() -> Box<WattWatchBackend>;

        // ── 数据刷新 ──
        fn refresh(&mut self);

        // ── 属性读取（只读）──
        fn battery_percent(self: &WattWatchBackend) -> u8;
        fn battery_is_charging(self: &WattWatchBackend) -> bool;
        fn battery_power_w(self: &WattWatchBackend) -> f32;
        fn battery_remaining(self: &WattWatchBackend) -> String;
        fn battery_capacity_wh(self: &WattWatchBackend) -> f32;
        fn battery_energy_now_wh(self: &WattWatchBackend) -> f32;

        // ── 功耗日志 ──
        /// 记录一次当前功耗,成功返回 true(sysfs 读取失败时不记录),并持久化到磁盘
        fn push_power_log(self: &mut WattWatchBackend) -> bool;
        /// 读取全部功耗日志(旧 → 新,含时间戳)
        fn power_log(self: &WattWatchBackend) -> Vec<PowerSample>;
    }
}

// ── 实现 ──

fn make_backend() -> Box<WattWatchBackend> {
    Box::new(WattWatchBackend::make_backend_impl())
}

pub struct WattWatchBackend {
    monitor: Mutex<Monitor>,
    cache: Mutex<MonitorCache>,
    /// 上次记录功耗采样的时间(用于每 10 分钟一次的采样调度)
    last_power_log: Option<Instant>,
    /// 功耗日志持久化路径
    powerlog_path: PathBuf,
}

impl WattWatchBackend {
    /// 功耗采样间隔:10 分钟
    const POWER_LOG_INTERVAL: Duration = Duration::from_secs(10 * 60);

    fn make_backend_impl() -> WattWatchBackend {
        let mut backend = WattWatchBackend {
            monitor: Mutex::new(Monitor::new()),
            cache: Mutex::new(MonitorCache::default()),
            last_power_log: None,
            powerlog_path: storage::default_powerlog_path(),
        };
        backend.restore_powerlog_history();
        backend
    }

    /// 启动时从磁盘恢复历史采样(旧 → 新,超容量自动截断最旧)。
    fn restore_powerlog_history(&mut self) {
        let history = storage::load_powerlog(&self.powerlog_path);
        if history.is_empty() {
            return;
        }
        let mut m = self.monitor.lock().unwrap();
        for sample in history {
            m.restore_sample(sample);
        }
    }

    /// 将当前缓冲持久化到磁盘(失败静默:仅本次未落盘,内存数据不受影响)。
    fn persist_powerlog(&self, samples: &[crate::monitor::PowerSample]) {
        if let Err(e) = storage::save_powerlog(&self.powerlog_path, samples) {
            eprintln!("WattWatch: failed to persist power log: {e}");
        }
    }

    fn refresh(&mut self) {
        let mut m = self.monitor.lock().unwrap();

        // 采样调度:启动后立即记录第一条,之后每 10 分钟记录一次
        let now = Instant::now();
        let due = match self.last_power_log {
            Some(t) => now.duration_since(t) >= Self::POWER_LOG_INTERVAL,
            None => true,
        };
        if due {
            if m.push_power_log() {
                let samples = m.get_power_log();
                self.persist_powerlog(&samples);
            }
            self.last_power_log = Some(now);
        }

        let fresh = m.refresh_all();
        *self.cache.lock().unwrap() = fresh;
    }

    fn battery_percent(&self) -> u8 {
        self.cache.lock().unwrap().battery_percent
    }

    fn battery_is_charging(&self) -> bool {
        self.cache.lock().unwrap().battery_is_charging
    }

    fn battery_power_w(&self) -> f32 {
        self.cache.lock().unwrap().battery_power_w
    }

    fn battery_remaining(&self) -> String {
        self.cache.lock().unwrap().battery_remaining.clone()
    }

    fn battery_capacity_wh(&self) -> f32 {
        self.cache.lock().unwrap().battery_capacity_wh
    }

    fn battery_energy_now_wh(&self) -> f32 {
        self.cache.lock().unwrap().battery_energy_now_wh
    }

    fn push_power_log(&mut self) -> bool {
        self.last_power_log = Some(Instant::now()); // 手动采样同样重置自动采样计时
        let mut m = self.monitor.lock().unwrap();
        let ok = m.push_power_log();
        if ok {
            let samples = m.get_power_log();
            self.persist_powerlog(&samples);
        }
        ok
    }

    fn power_log(&self) -> Vec<ffi::PowerSample> {
        let m = self.monitor.lock().unwrap();
        m.get_power_log()
            .into_iter()
            .map(|(ts, p, c)| ffi::PowerSample {
                timestamp: ts,
                power: p,
                charging: c,
            })
            .collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// 集成:采样 → 持久化 → 新实例从磁盘恢复 的完整闭环。
    /// 依赖真实 sysfs;无电池环境下自动跳过(采样失败时)。
    #[test]
    fn persistence_roundtrip_via_backend() {
        let path = std::env::temp_dir()
            .join(format!("wattwatch_test_{}_backend.csv", std::process::id()));
        let _ = std::fs::remove_file(&path);

        // 第一个实例:手动采样(成功时触发持久化)
        let mut b1 = WattWatchBackend {
            monitor: Mutex::new(Monitor::new()),
            cache: Mutex::new(MonitorCache::default()),
            last_power_log: None,
            powerlog_path: path.clone(),
        };
        let pushed = b1.push_power_log();
        let n1 = b1.power_log().len();
        assert!(n1 <= 1);
        if !pushed {
            // 无电池/读取失败:采样未发生,无法验证恢复,直接结束
            let _ = std::fs::remove_file(&path);
            return;
        }

        // 第二个实例:从磁盘恢复(路径相同)
        let mut b2 = WattWatchBackend {
            monitor: Mutex::new(Monitor::new()),
            cache: Mutex::new(MonitorCache::default()),
            last_power_log: None,
            powerlog_path: path.clone(),
        };
        b2.restore_powerlog_history();
        let restored = b2.power_log();
        assert_eq!(restored.len(), 1, "新实例应恢复持久化的 1 条采样");
        assert_eq!(restored[0].power, n1_power(&b1));
        assert!(restored[0].timestamp > 1_500_000_000, "时间戳应为 unix 秒");

        let _ = std::fs::remove_file(&path);
    }

    fn n1_power(b: &WattWatchBackend) -> f32 {
        b.power_log()[0].power
    }
}
