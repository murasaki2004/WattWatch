use std::sync::Mutex;
use std::time::{Duration, Instant};

use crate::cache::MonitorCache;
use crate::monitor::Monitor;

#[cxx::bridge(namespace = "wattwatch")]
mod ffi {
    // ── 功耗采样 ──
    // power: 功率(瓦,正数);charging: true=输入(充电) / false=输出(放电)
    struct PowerSample {
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
        /// 记录一次当前功耗,成功返回 true(sysfs 读取失败时不记录)
        fn push_power_log(self: &mut WattWatchBackend) -> bool;
        /// 读取全部功耗日志(旧 → 新)
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
    /// 上次记录功耗采样的时间(用于每 30 分钟一次的采样调度)
    last_power_log: Option<Instant>,
}

impl WattWatchBackend {
    /// 功耗采样间隔:10 分钟
    const POWER_LOG_INTERVAL: Duration = Duration::from_secs(10 * 60);

    fn make_backend_impl() -> WattWatchBackend {
        WattWatchBackend {
            monitor: Mutex::new(Monitor::new()),
            cache: Mutex::new(MonitorCache::default()),
            last_power_log: None,
        }
    }

    fn refresh(&mut self) {
        let mut m = self.monitor.lock().unwrap();

        // 采样调度:启动后立即记录第一条,之后每 30 分钟记录一次
        let now = Instant::now();
        let due = match self.last_power_log {
            Some(t) => now.duration_since(t) >= Self::POWER_LOG_INTERVAL,
            None => true,
        };
        if due {
            m.push_power_log();
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
        self.monitor.lock().unwrap().push_power_log()
    }

    fn power_log(&self) -> Vec<ffi::PowerSample> {
        let m = self.monitor.lock().unwrap();
        m.get_power_log()
            .into_iter()
            .map(|(p, c)| ffi::PowerSample {
                power: p,
                charging: c,
            })
            .collect()
    }
}
