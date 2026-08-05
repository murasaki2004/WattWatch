/// 一次 `refresh_all()` 后的监控数据快照。
///
/// 各字段的 N/A 哨兵值：
/// - `battery_percent`：`0`
/// - `battery_remaining`：空字符串
/// - `battery_power_w` / `battery_capacity_wh` / `battery_energy_now_wh`：`0.0`
#[derive(Debug, Clone)]
pub struct MonitorCache {
    pub battery_percent: u8,
    pub battery_is_charging: bool,
    pub battery_power_w: f32,
    pub battery_remaining: String,
    /// 电池设计容量（Wh），来自 `energy_full_design`
    pub battery_capacity_wh: f32,
    /// 电池当前剩余能量（Wh），来自 `energy_now`
    pub battery_energy_now_wh: f32,
}

impl Default for MonitorCache {
    fn default() -> Self {
        Self {
            battery_percent: 0,
            battery_is_charging: false,
            battery_power_w: 0.0,
            battery_remaining: String::new(),
            battery_capacity_wh: 0.0,
            battery_energy_now_wh: 0.0,
        }
    }
}
