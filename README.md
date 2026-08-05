# WattWatch

[![License: MPL-2.0](https://img.shields.io/badge/License-MPL--2.0-blue.svg)](LICENSE)
[![KDE Plasma](https://img.shields.io/badge/Plasma-6-blue)](https://kde.org/plasma-desktop)
[![Rust](https://img.shields.io/badge/Rust-2024-orange.svg)](https://www.rust-lang.org/)

KDE Plasma 6 电源监控小部件（Plasmoid）。实时显示电池电量、充放电功率与剩余续航时间，数据直接来自 Linux sysfs。后端使用 Rust 编写，通过 cxx 桥接与 C++ QML 插件通信。

## 功能特性

- **电量百分比**：来自 `/sys/class/power_supply/BAT0/capacity`
- **实时功率**：充放电功率（W），来自 `power_now`
- **剩余时间**：放电时估算剩余续航，充电时估算充满所需时间
- **容量信息**：设计容量（`energy_full_design`）与当前剩余能量（`energy_now`），单位 Wh
- **电池图标**：按状态区分 —— 充电（电池+闪电）、放电（向下箭头）、低电量 <20%（红色）、无电池（灰色）
- **双视图**：
  - 紧凑视图：适配面板的电池图标 + 功率/时间文本（如 `23W/1:32`）
  - 完整视图：点击部件展开，显示百分比、状态行与完整监控数据
- **每秒自动刷新**

## 架构

Rust 后端 → cxx 桥接 → C++ QML 插件 → QML Plasmoid：

```
┌──────────────┐   ┌───────────────┐   ┌──────────────────┐   ┌──────────────┐
│ Rust staticlib│──▶│ cxx bridge    │──▶│ C++ QML Plugin   │──▶│ QML Plasmoid │
│ wattwatch_   │   │ (bridge.rs)   │   │ (URI: WattWatch) │   │ (package/)   │
│ backend      │   │               │   │                  │   │              │
└──────────────┘   └───────────────┘   └──────────────────┘   └──────────────┘
     ▲ 读取 sysfs
```

- **Rust 层**（`src/`）：
  - `monitor.rs` — 通过 sysfs 读取电池各项数据
  - `cache.rs` — `refresh_all()` 后的数据快照
  - `bridge.rs` — `#[cxx::bridge]` 定义 Rust ↔ C++ 的 FFI 接口
  - `lib.rs` — 模块入口，编译为 staticlib（`wattwatch_backend`）
- **C++ 层**（`plugin/cpp/`）：
  - `Plugin.cpp` — QML 插件注册
  - `GaugeProxy.cpp` — 将 Rust 后端属性代理为 QML 可读属性（`Gauge.*`）
- **QML 层**（`package/contents/ui/`）：
  - `main.qml` — Plasmoid 入口，每秒刷新，装配两种视图
  - `CompactView.qml` / `FullView.qml` — 紧凑视图与详细视图
  - `BatteryIcon.qml` — 自绘电池图标（按充放电/低电量状态变色）
  - `RingGauge.qml` — 环形仪表组件（目前存在但尚未接入视图）

## 依赖

- CMake ≥ 3.24
- Rust 工具链（cargo）+ `cxxbridge`
- [Corrosion](https://github.com/corrosion-rs/corrosion)（CMake 集成 Rust）
- KF6 ≥ 6.1.0（KCMUtils、Config）
- Qt6 ≥ 6.6.0（Qml、Gui、Quick、Core）
- Plasma 开发包、ECM（Extra CMake Modules）

## 构建与安装

项目根目录提供 Makefile 封装：

```sh
# 构建（默认 Release）
make build

# 安装到系统（需要 sudo）
make install

# 在独立窗口中预览
make run

# 清理构建产物
make clean
```

也可以直接使用 CMake：

```sh
cmake -S . -B build_release -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build_release
sudo cmake --install build_release
```

卸载：

```sh
make uninstall
```

## 使用

安装完成后，在 Plasma 面板上「添加部件」搜索 **WattWatch** 即可。部件默认显示电池图标与功率/时间文本，点击展开完整视图。

## 目录结构

```
WattWatch/
├── Cargo.toml              # Rust crate（wattwatch_backend，staticlib）
├── CMakeLists.txt          # 构建/安装脚本
├── LICENSE                 # MPL-2.0 许可证
├── Makefile                # build / install / run / clean 等常用目标
├── src/                    # Rust 后端（sysfs 监控 + cxx 桥接）
│   ├── lib.rs
│   ├── monitor.rs
│   ├── cache.rs
│   └── bridge.rs
├── plugin/
│   └── cpp/                # C++ QML 插件（URI: WattWatch）
│       ├── include/        #   Plugin.hpp / GaugeProxy.hpp
│       ├── src/            #   Plugin.cpp / GaugeProxy.cpp
│       └── qmldir
└── package/                # Plasmoid 包（org.murasaki.wattwatch）
    ├── metadata.json
    └── contents/ui/        # QML 界面（main / CompactView / FullView / RingGauge / BatteryIcon）
```

## 数据来源

所有监控数据均通过 Linux sysfs 读取，路径硬编码为 `BAT0`：

| 字段 | sysfs 路径 | 单位 |
| --- | --- | --- |
| 电量 | `/sys/class/power_supply/BAT0/capacity` | % |
| 功率 | `/sys/class/power_supply/BAT0/power_now` | W（μW ÷ 1e6） |
| 设计容量 | `/sys/class/power_supply/BAT0/energy_full_design` | Wh（μWh ÷ 1e6） |
| 剩余能量 | `/sys/class/power_supply/BAT0/energy_now` | Wh（μWh ÷ 1e6） |
| 充放电状态 | `/sys/class/power_supply/BAT0/status` | Charging / Full / Discharging |

> 注：当前仅支持电池节点 `BAT0`；若文件缺失或解析失败，界面显示兜底值（无电池状态）。

## 许可证

本项目采用 [Mozilla Public License 2.0](https://mozilla.org/MPL/2.0/)（MPL-2.0），详见 [LICENSE](LICENSE)。

C++ 插件层（`plugin/cpp/`）与构建脚本（`CMakeLists.txt`、`Makefile`）参考了 [isosphere/bcdt-rust_plasmoid_example](https://github.com/isosphere/bcdt-rust_plasmoid_example)（MPL-2.0，作者 Simon Brummer），特此致谢。

## 致谢

- [isosphere/bcdt-rust_plasmoid_example](https://github.com/isosphere/bcdt-rust_plasmoid_example) — Rust 后端 Plasmoid 参考实现
- [cxx](https://github.com/dtolnay/cxx) — Rust ↔ C++ 桥接
- [Corrosion](https://github.com/corrosion-rs/corrosion) — CMake 与 Cargo 集成
