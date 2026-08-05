import QtQuick
import org.kde.plasma.core as PlasmaCore

/// 电池图标 — Canvas 自绘,适配窄面板
///
/// 一对同风格的电池图标,用内部符号区分状态:
///  - 充电: 电池外壳 + 大号闪电(绿色壳 + 黄色闪电)
///  - 放电: 电池外壳 + 向下放电箭头(主题色壳 + 同色箭头)
///  - 低电量(<20% 且未充电): 壳与箭头变红
///  - 无电池: 灰色空心电池 + 斜线
Canvas {
    id: root

    property real percent: 0
    property bool charging: false
    property bool valid: true

    readonly property color chargeColor: "#4caf50"
    readonly property color lowColor: "#e53935"
    readonly property color boltColor: "#ffd54f"

    implicitWidth: 20
    implicitHeight: 20

    antialiasing: true
    renderTarget: Canvas.FramebufferObject

    onPercentChanged: requestPaint()
    onChargingChanged: requestPaint()
    onValidChanged: requestPaint()

    // 主题切换时重绘(放电壳/箭头取自 Plasma 主题)
    Connections {
        target: PlasmaCore.Theme
        function onThemeChanged() { root.requestPaint() }
    }

    onPaint: {
        var ctx = getContext("2d");
        if (!ctx) return;
        ctx.clearRect(0, 0, width, height);

        // 主题色(防御读取:极端环境下主题不可用时回退灰色)
        var themeOk = PlasmaCore && PlasmaCore.Theme;
        var themeColor = themeOk ? PlasmaCore.Theme.textColor : "#8a8a8a";
        var disabledColor = themeOk ? PlasmaCore.Theme.disabledTextColor : "#666666";

        // 参考 20×20 的电池几何(按实际尺寸等比缩放)
        var s = Math.min(width, height);
        var bx = s * 0.02, by = s * 0.22;       // 外壳
        var bw = s * 0.76, bh = s * 0.56;
        var r  = s * 0.06;                       // 圆角
        var capW = s * 0.12, capH = s * 0.20;    // 正极凸起
        var capX = bx + bw, capY = by + (bh - capH) / 2;
        var lw = Math.max(s * 0.045, 1.0);       // 线宽

        // ── 状态色 ──
        var frameColor = root.charging ? root.chargeColor
                       : root.percent < 20 ? root.lowColor
                       : themeColor;
        if (!root.valid) frameColor = disabledColor;

        // ── 正极 ──
        ctx.fillStyle = frameColor;
        roundedRect(ctx, capX, capY, capW, capH, s * 0.02);
        ctx.fill();

        // ── 外壳 ──
        ctx.strokeStyle = frameColor;
        ctx.lineWidth = lw;
        roundedRect(ctx, bx, by, bw, bh, r);
        ctx.stroke();

        if (root.valid && root.charging) {
            // ── 样式 A(充电): 大号闪电,绿色边框 + 黄色闪电 ──
            ctx.fillStyle = root.boltColor;
            ctx.beginPath();
            ctx.moveTo(bx + bw * 0.58, by + bh * 0.06);
            ctx.lineTo(bx + bw * 0.26, by + bh * 0.55);
            ctx.lineTo(bx + bw * 0.45, by + bh * 0.55);
            ctx.lineTo(bx + bw * 0.42, by + bh * 0.94);
            ctx.lineTo(bx + bw * 0.74, by + bh * 0.45);
            ctx.lineTo(bx + bw * 0.55, by + bh * 0.45);
            ctx.closePath();
            ctx.fill();
        } else if (root.valid) {
            // ── 样式 B(放电): 电池外壳 + 向下放电箭头(与闪电同风格) ──
            var arrowColor = root.percent < 20 ? root.lowColor : themeColor;
            var cx = bx + bw * 0.5;
            ctx.strokeStyle = arrowColor;
            ctx.fillStyle = arrowColor;
            ctx.lineWidth = Math.max(lw * 1.2, 1.5);
            ctx.lineCap = "round";
            // 箭杆(竖线)
            ctx.beginPath();
            ctx.moveTo(cx, by + bh * 0.14);
            ctx.lineTo(cx, by + bh * 0.46);
            ctx.stroke();
            // 箭头(实心三角,尖端向下)
            ctx.beginPath();
            ctx.moveTo(cx, by + bh * 0.76);
            ctx.lineTo(cx - bw * 0.20, by + bh * 0.44);
            ctx.lineTo(cx + bw * 0.20, by + bh * 0.44);
            ctx.closePath();
            ctx.fill();
        } else {
            // ── 无电池: 斜线 ──
            ctx.strokeStyle = disabledColor;
            ctx.lineWidth = lw;
            ctx.beginPath();
            ctx.moveTo(bx + bw * 0.20, by + bh * 0.80);
            ctx.lineTo(bx + bw * 0.80, by + bh * 0.20);
            ctx.stroke();
        }
    }

    /// 圆角矩形路径(需要配合 ctx.fill() / ctx.stroke())
    function roundedRect(ctx, x, y, w, h, r) {
        ctx.beginPath();
        ctx.moveTo(x + r, y);
        ctx.lineTo(x + w - r, y);
        ctx.arcTo(x + w, y, x + w, y + r, r);
        ctx.lineTo(x + w, y + h - r);
        ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
        ctx.lineTo(x + r, y + h);
        ctx.arcTo(x, y + h, x, y + h - r, r);
        ctx.lineTo(x, y + r);
        ctx.arcTo(x, y, x + r, y, r);
        ctx.closePath();
    }
}
