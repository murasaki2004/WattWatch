import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import WattWatch 1.0

/// 点击部件后弹出的详细信息面板 — 与紧凑视图同风格
///
/// 左侧(详细信息): 大电池图标 + 百分比 + 状态行(充电中/放电中/已充满/无电池),
///                  以及 monitor 模块返回的完整数据(状态、功率、剩余能量、设计容量、剩余时间)
/// 右侧: 功耗-时间折线图(每 10 分钟采样一次),二者横向排布
ColumnLayout {
    id: root
    spacing: 12

    // 弹出面板默认尺寸(由外壳读取 Layout.* 尺寸提示)
    Layout.preferredWidth: 480
    Layout.preferredHeight: 240
    Layout.minimumWidth: 480
    Layout.minimumHeight: 240

    readonly property bool hasBattery: Gauge.batteryPercent > 0
    readonly property bool charging: Gauge.batteryCharging && root.hasBattery
    readonly property bool lowBattery: root.hasBattery && Gauge.batteryPercent < 20 && !root.charging

    // ── 状态行文本 ──
    readonly property string statusText: {
        if (!root.hasBattery) return "No battery detected";
        if (root.charging && Gauge.batteryPercent >= 100) return "Fully charged";
        if (root.charging)
            return Gauge.batteryRemaining !== ""
                ? "Charging · " + Gauge.batteryRemaining + " to full"
                : "Charging";
        return Gauge.batteryRemaining !== ""
            ? "Discharging · " + Gauge.batteryRemaining + " left"
            : "Discharging";
    }
    readonly property color statusColor: {
        if (!root.hasBattery) return PlasmaCore.Theme.disabledTextColor;
        if (root.charging) return "#4caf50";
        if (root.lowBattery) return "#e53935";
        return PlasmaCore.Theme.textColor;
    }

    // ── 详细信息(左) + 功耗趋势折线图(右) —— 横向排布 ──
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 24
        visible: root.hasBattery

        // ── 左列:详细信息(头部电池图标 + 百分比 + 状态,及完整数据) ──
        ColumnLayout {
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            spacing: 12

            // ── 头部:大电池图标 + 百分比 + 状态 ──
            RowLayout {
                spacing: 18

                BatteryIcon {
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 52
                    percent: Gauge.batteryPercent
                    charging: root.charging
                    valid: root.hasBattery
                }

                ColumnLayout {
                    spacing: 3

                    PlasmaComponents.Label {
                        Layout.alignment: Qt.AlignLeft
                        text: Gauge.batteryPercent + "%"
                        font.pixelSize: 30
                        font.bold: true
                        color: root.lowBattery ? "#e53935" : "#aaaaaa"
                    }

                    PlasmaComponents.Label {
                        Layout.alignment: Qt.AlignLeft
                        text: root.statusText
                        font.pixelSize: 12
                        color: root.statusColor
                    }
                }
            }

            GridLayout {
                columns: 2
                rowSpacing: 6
                columnSpacing: 24

                PlasmaComponents.Label { text: "Status" }
                PlasmaComponents.Label {
                    text: root.charging ? "Charging" : "Discharging"
                    font.bold: true
                    color: root.statusColor
                }

                PlasmaComponents.Label { text: "Power" }
                PlasmaComponents.Label {
                    text: Gauge.batteryPower > 0
                        ? Math.abs(Gauge.batteryPower).toFixed(1) + " W"
                        : "—"
                    font.bold: true
                }

                PlasmaComponents.Label { text: "Energy left" }
                PlasmaComponents.Label {
                    text: Gauge.batteryEnergyNowWh > 0
                        ? Gauge.batteryEnergyNowWh.toFixed(1) + " Wh"
                        : "—"
                    font.bold: true
                }

                PlasmaComponents.Label { text: "Capacity" }
                PlasmaComponents.Label {
                    text: Gauge.batteryCapacityWh > 0
                        ? Gauge.batteryCapacityWh.toFixed(1) + " Wh"
                        : "—"
                    font.bold: true
                }

                PlasmaComponents.Label {
                    text: root.charging ? "Time to full" : "Time left"
                }
                PlasmaComponents.Label {
                    text: Gauge.batteryRemaining === "" ? "—" : Gauge.batteryRemaining
                    font.bold: true
                }
            }
        }

        // ── 竖向分隔线 ──
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            color: PlasmaCore.Theme.textColor
            opacity: 0.15
        }

        // ── 右列:功耗趋势折线图 ──
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignTop
            spacing: 6

            PlasmaComponents.Label {
                text: "Power trend"
                font.bold: true
            }

            PowerChart {
                id: chart
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: 160
                Layout.minimumHeight: 100
                samples: Gauge.powerLog
            }

            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignHCenter
                font.pixelSize: 11
                color: PlasmaCore.Theme.textColor
                opacity: 0.7
                text: {
                    if (!chart.hasData) return "每 10 分钟采样一次";
                    return chart.samples.length + " 条 · " + chart.spanText
                        + " · 平均 " + chart.avgPower.toFixed(1) + " W"
                        + " · 峰值 " + chart.maxPower.toFixed(1) + " W";
                }
            }
        }
    }

    // ── 无电池提示 ──
    PlasmaComponents.Label {
        Layout.alignment: Qt.AlignHCenter
        text: "No battery detected"
        color: PlasmaCore.Theme.disabledTextColor
        visible: !root.hasBattery
    }
}
