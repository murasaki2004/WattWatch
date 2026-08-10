use crate::cache::MonitorCache;
use circular_buffer::FixedCircularBuffer;

pub struct Monitor {
    // f32表示power、bool为true时表示输入；false时表示输出
    power_log: FixedCircularBuffer<(f32, bool), 1440>
}

impl Monitor {
    pub fn new() -> Self {
        let power_log_init = FixedCircularBuffer::<(f32, bool), 1440>::new();
        Self {
            power_log: power_log_init
        }
    }

    /// 获取设备剩余电量百分比。
    ///
    /// 通过 sysfs 读取 `/sys/class/power_supply/BAT0/capacity` 获取电池剩余容量百分比。
    /// 若文件不存在或内容无法解析为无符号整数，则返回 `None`。
    ///
    /// 返回值范围为 `0..=100`（`Some` 时）。
    fn get_battery_percentage() -> Option<u8> {
        let capacity_str = std::fs::read_to_string("/sys/class/power_supply/BAT0/capacity").ok()?;
        let capacity: u8 = capacity_str.trim().parse().ok()?;
        Some(capacity)
    }

    /// 获取设备电池实时输入/输出功率（单位：w）
    ///
    /// 通过 sysfs 读取 `/sys/class/power_supply/BAT0/power_now` 获取功率。
    /// 若文件不存在或内容无法解析，则返回 `None`。
    /// 需要结合电池充电状态判断属于输入or输出
    fn get_battery_power(&mut self) -> Option<f32> {
        let power_str = std::fs::read_to_string("/sys/class/power_supply/BAT0/power_now").ok()?;
        let power_uw: f32 = power_str.trim().parse().ok()?;
        Some(power_uw / 1_000_000.0)
    }

    /// 获取设备电池容量。
    ///
    /// 通过linux的sysfs读取BAT0的energy_full_design
    /// 单位wh
    fn get_battery_capacity(&mut self) -> Option<f32> {
        let capacity_str =
            std::fs::read_to_string("/sys/class/power_supply/BAT0/energy_full_design").ok()?;
        // sysfs 中 energy_full_design 单位为微瓦时（μWh），除以 1_000_000 转换为 Wh。
        let capacity_uw: f32 = capacity_str.trim().parse().ok()?;
        Some(capacity_uw / 1_000_000.0)
    }

    /// 获取设备电池当前剩余能量。
    ///
    /// 通过 sysfs 读取 `/sys/class/power_supply/BAT0/energy_now` 获取当前剩余能量。
    /// 若文件不存在或内容无法解析，则返回 `None`。
    ///
    /// 单位 Wh（源数据为 μWh，除以 1_000_000 转换）。
    fn get_battery_energy_now(&mut self) -> Option<f32> {
        let energy_str = std::fs::read_to_string("/sys/class/power_supply/BAT0/energy_now").ok()?;
        let energy_uw: f32 = energy_str.trim().parse().ok()?;
        Some(energy_uw / 1_000_000.0)
    }

    /// 获取设备电池充电状态。
    ///
    /// 通过 sysfs 读取 `/sys/class/power_supply/BAT0/status` 获取充放电状态。
    ///   `"Charging"` 或 `"Full"` 视为充电中（`Some(true)`），
    ///   `"Discharging"` 或 `"Not charging"` 视为离电（`Some(false)`），
    ///   其他状态（如 `"Unknown"`）或读取失败返回 `None`。
    fn get_battery_status() -> Option<bool> {
        let status = std::fs::read_to_string("/sys/class/power_supply/BAT0/status").ok()?;
        match status.trim() {
            "Charging" | "Full" => Some(true),
            "Discharging" | "Not charging" => Some(false),
            _ => None,
        }
    }

    /// 计算电池剩余续航时间。
    ///
    /// 根据放电功率 `power_w`（取绝对值后的瓦数）和电池设计容量
    /// 估算剩余小时:分钟数。容量或功率不可用 / 为零时返回空串。
    ///
    /// # Arguments
    ///
    /// * `power_w` — 放电功率（瓦，正数）
    fn calculate_battery_remaining(&mut self, power_w: f32) -> String {
        if power_w <= 0.0 {
            return String::new();
        }

        let capacity = match self.get_battery_capacity() {
            Some(c) if c > 0.0 => c,
            _ => return String::new(),
        };

        let battery_life = capacity / power_w; // 小时
        let hours = battery_life as u8;
        let minutes = (battery_life.fract() * 60.0).round() as u8;
        format!("{}:{:02}", hours, minutes)
    }

    /// 计算电池充满电所需时间。
    ///
    /// 根据充电功率 `power_w`（瓦）、电池设计容量和当前剩余能量
    /// 估算从当前电量充至满电所需的小时:分钟数。
    /// 功率不可用 / 为零、容量或当前剩余能量不可用 / 已充满时返回空串。
    ///
    /// # Arguments
    ///
    /// * `power_w` — 充电功率（瓦，正数）
    fn calculate_battery_charging_remaining(&mut self, power_w: f32) -> String {
        if power_w <= 0.0 {
            return String::new();
        }

        let capacity = match self.get_battery_capacity() {
            Some(c) if c > 0.0 => c,
            _ => return String::new(),
        };

        let energy_now = match self.get_battery_energy_now() {
            Some(e) if e > 0.0 => e,
            _ => return String::new(),
        };

        // 还需充入的能量 = 设计容量 - 当前剩余能量
        let remaining_energy = capacity - energy_now;
        if remaining_energy <= 0.0 {
            return String::new();
        }

        let charge_life = remaining_energy / power_w; // 小时
        let hours = charge_life as u8;
        let minutes = (charge_life.fract() * 60.0).round() as u8;
        format!("{}:{:02}", hours, minutes)
    }


    /// 将当前功率与状态计入日志。
    ///
    /// 成功记录返回 `true`;sysfs 读取失败时不记录并返回 `false`。
    pub fn push_power_log(&mut self) -> bool {
        let (Some(power), Some(status)) =
            (self.get_battery_power(), Monitor::get_battery_status())
        else {
            return false;
        };
        self.power_log.push_back((power, status));
        true
    }

    /// 读取功耗日志快照(旧 → 新)。
    ///
    /// 返回 `power_log` 中记录的功率与充放电状态,
    /// `f32` 为功率(瓦,正数),`bool` 为 `true` 时表示输入(充电),`false` 表示输出(放电)。
    pub fn get_power_log(&self) -> Vec<(f32, bool)> {
        self.power_log.to_vec()
    }

    /// 采集所有传感器数据并填充 `MonitorCache`。
    ///
    /// 内部依次调用各 `get_*` 方法，将结果写入缓存结构体。
    /// `battery_power_w` 为 sysfs 原始功率（正数），充 / 放电由 `battery_is_charging` 区分；
    /// `battery_remaining` 在放电时为剩余续航，充电时为充满所需时间。
    pub fn refresh_all(&mut self) -> MonitorCache {
        let battery_percent = Monitor::get_battery_percentage().unwrap_or(0);
        let battery_is_charging = Monitor::get_battery_status().unwrap_or(false);

        let battery_power_w = self.get_battery_power().unwrap_or(0.0);

        let battery_remaining = if battery_is_charging {
            self.calculate_battery_charging_remaining(battery_power_w)
        } else {
            self.calculate_battery_remaining(battery_power_w)
        };

        MonitorCache {
            battery_percent,
            battery_is_charging,
            battery_power_w,
            battery_remaining,
            battery_capacity_wh: self.get_battery_capacity().unwrap_or(0.0),
            battery_energy_now_wh: self.get_battery_energy_now().unwrap_or(0.0),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// 环形缓冲:容量上限 1440,满时挤出最旧,读取顺序保持插入序(旧 → 新)。
    #[test]
    fn power_log_bounded_and_ordered() {
        let mut m = Monitor::new();
        for i in 0..1500u32 {
            m.power_log.push_back((i as f32, i % 2 == 0));
        }
        let log = m.get_power_log();
        assert_eq!(log.len(), 1440);
        assert_eq!(log[0].0, 60.0); // 最旧的 60 条被挤出
        assert_eq!(log[1439].0, 1499.0);
        for w in log.windows(2) {
            assert!(w[0].0 < w[1].0, "顺序必须保持插入序");
        }
    }

    /// 真实 sysfs 下 push 一次应记录一条(机器无电池时静默失败,不 panic)。
    #[test]
    fn push_power_log_with_sysfs() {
        let mut m = Monitor::new();
        let _ = m.push_power_log();
        let log = m.get_power_log();
        assert!(log.len() <= 1);
        if let Some((p, _c)) = log.first() {
            assert!(*p >= 0.0);
        }
    }
}
