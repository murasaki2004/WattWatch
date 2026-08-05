use std::sync::Mutex;

use crate::cache::MonitorCache;
use crate::monitor::Monitor;

#[cxx::bridge(namespace = "wattwatch")]
mod ffi {
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
    }
}

// ── 实现 ──

pub struct WattWatchBackend {
    monitor: Mutex<Monitor>,
    cache: Mutex<MonitorCache>,
}

fn make_backend() -> Box<WattWatchBackend> {
    Box::new(WattWatchBackend {
        monitor: Mutex::new(Monitor::new()),
        cache: Mutex::new(MonitorCache::default()),
    })
}

impl WattWatchBackend {
    fn refresh(&mut self) {
        let mut m = self.monitor.lock().unwrap();
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
}
