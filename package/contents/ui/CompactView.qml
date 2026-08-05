import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import WattWatch 1.0

/// 面板紧凑视图 — 电池图标 + 功耗/剩余时间(适配 40px 面板)
///
/// 布局: [电池图标]  xxW/xx:xx
///  - 电池图标区分状态: 充电=电池+闪电 / 放电=电池+向下箭头 / 低电<20%=红 / 无电池=灰
///  - 文本: 放电时 = 功耗/剩余续航; 充电时 = 功率/充满所需时间
///  - 时间不可估算(功率为 0 或数据缺失)时仅显示功率
///
/// 点击切换展开/收起详细面板(官方部件同款写法,不依赖外壳自动行为)
Item {
    id: root

    required property PlasmoidItem plasmoidItem

    readonly property bool hasBattery: Gauge.batteryPercent > 0
    readonly property bool charging: Gauge.batteryCharging && root.hasBattery

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    // ── 点击切换详细面板 ──
    MouseArea {
        anchors.fill: parent
        z: 1
        onClicked: root.plasmoidItem.expanded = !root.plasmoidItem.expanded
    }

    // ── 内容:电池图标 + 文本 ──
    RowLayout {
        id: layout
        anchors.fill: parent
        spacing: 5

        // ── 文本:xxW/xx:xx ──
        readonly property string powerText: {
            if (!root.hasBattery) return "—";
            return Gauge.batteryPower > 0
                ? Math.round(Gauge.batteryPower) + "W"
                : "—W";
        }
        readonly property string infoText: {
            if (!root.hasBattery) return "—";
            if (Gauge.batteryRemaining === "") return layout.powerText;
            return layout.powerText + "/" + Gauge.batteryRemaining;
        }

        // ── 电池图标(自绘) ──
        BatteryIcon {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            Layout.alignment: Qt.AlignVCenter
            percent: Gauge.batteryPercent
            charging: root.charging
            valid: root.hasBattery
        }

        // ── 功耗/时间文本(加粗黑色,宽度随内容自适应) ──
        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignVCenter
            font.bold: true
            font.pixelSize: 12
            color: "#000000"
            text: layout.infoText
            // 兜底:面板空间被压缩到小于内容时不溢出,改为省略号
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }
}
