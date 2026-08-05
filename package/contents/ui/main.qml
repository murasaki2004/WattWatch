import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import WattWatch 1.0

PlasmoidItem {
    id: root

    // 每秒刷新
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: Gauge.refresh()
    }

    // ── 面板状态栏紧凑视图 ──
    preferredRepresentation: compactRepresentation
    compactRepresentation: CompactView { plasmoidItem: root }

    // ── 弹出详细面板 ──
    fullRepresentation: FullView {}

    // ── 紧凑视图实例引用 ──
    // 注意:compactRepresentation 是 QQmlComponent,内联 id 在外层不可见,
    // 实例由外壳延迟创建,必须通过 compactRepresentationItemChanged 信号获取。
    property Item compactItem: null
    onCompactRepresentationItemChanged: root.compactItem = root.compactRepresentationItem

    // ── 部件宽度跟随紧凑视图内容(否则面板按 0/默认宽度分配,内容被截断/重叠) ──
    clip: true
    implicitWidth: root.compactItem ? root.compactItem.implicitWidth : 40
    implicitHeight: root.compactItem ? root.compactItem.implicitHeight : 20
    Layout.preferredWidth: root.compactItem ? root.compactItem.implicitWidth : 40
    Layout.preferredHeight: root.compactItem ? root.compactItem.implicitHeight : 20

    // ── 部件图标(添加部件/未展开时显示)──
    Plasmoid.icon: "battery"

    // 鼠标悬停提示(Plasma 6: 直接属性,不再使用 Plasmoid 附着对象)
    toolTipMainText: "WattWatch"
    toolTipSubText: {
        if (Gauge.batteryPercent <= 0) {
            return "No battery detected";
        }
        let parts = [];
        parts.push(Gauge.batteryPercent + "%");
        parts.push((Gauge.batteryCharging ? "+" : "−")
            + Math.abs(Gauge.batteryPower).toFixed(1) + " W");
        if (Gauge.batteryRemaining !== "") {
            parts.push(Gauge.batteryRemaining
                + (Gauge.batteryCharging ? " to full" : " left"));
        }
        return parts.join(" | ");
    }
}
