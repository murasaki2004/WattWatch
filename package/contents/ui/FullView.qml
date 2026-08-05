import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import WattWatch 1.0

/// 点击部件后弹出的详细信息面板 — 与紧凑视图同风格
///
/// 头部: 大号电池图标 + 大百分比 + 状态行(充电中/放电中/已充满/无电池)
/// 下方: monitor 模块返回的完整数据(状态、功率、剩余能量、设计容量、剩余时间)
ColumnLayout {
    id: root
    spacing: 12

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

    // ── 头部:大电池图标 + 百分比 + 状态 ──
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
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
                text: root.hasBattery ? Gauge.batteryPercent + "%" : "—"
                font.pixelSize: 30
                font.bold: true
                color: root.lowBattery ? "#e53935" : PlasmaCore.Theme.textColor
            }

            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignLeft
                text: root.statusText
                font.pixelSize: 12
                color: root.statusColor
            }
        }
    }

    // ── 分隔线 ──
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: PlasmaCore.Theme.textColor
        opacity: 0.15
    }

    // ── 详细信息(无电池时隐藏)──
    GridLayout {
        columns: 2
        rowSpacing: 6
        columnSpacing: 24
        visible: root.hasBattery

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

    // ── 无电池提示 ──
    PlasmaComponents.Label {
        Layout.alignment: Qt.AlignHCenter
        text: "No battery detected"
        color: PlasmaCore.Theme.disabledTextColor
        visible: !root.hasBattery
    }
}
