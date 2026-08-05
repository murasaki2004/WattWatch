import QtQuick

/// 环形仪表 — Canvas 绘制圆环 + 中心文字
/// - value: 当前值 (0-100)
/// - innerLabel: 环内主文字 (如 "45%")
/// - innerSubLabel: 环内副文字 (如 "65°C" 或 "GPU")
/// - ringColor: 可选覆盖颜色，不设则根据 value 自动从绿渐变到红
Canvas {
    id: root

    // ── 公开属性 ──
    property real value: 0
    property real maxValue: 100
    property string innerLabel: ""
    property string innerSubLabel: ""
    property color ringColor: "transparent"   // transparent = 自动计算
    property real ringWidth: 4
    property color bgColor: "#2a2a2a"
    property bool invertColors: false          // 电池模式：高值=绿，低值=红

    property bool valid: true

    // 尺寸随父布局缩放，默认最小尺寸
    implicitWidth: 60
    implicitHeight: 60

    antialiasing: true
    renderTarget: Canvas.FramebufferObject

    // ── 自动根据值计算颜色 (绿→黄→红) ──
    function computedColor(pct) {
        pct = Math.min(pct, 100);
        if (pct < 50) {
            var t = pct / 50.0;
            return Qt.rgba(t * 1.0, 0.85 + t * 0.15, 0.15, 1.0);
        } else if (pct < 80) {
            var t2 = (pct - 50) / 30.0;
            return Qt.rgba(1.0, 1.0 - t2 * 0.85, 0.15, 1.0);
        } else {
            return Qt.rgba(1.0, 0.15, 0.15, 1.0);
        }
    }

    // ── 数据变化时触发重绘 ──
    onValueChanged: requestPaint()
    onRingColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onValidChanged: requestPaint()
    onInnerLabelChanged: requestPaint()
    onInnerSubLabelChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        var w = width;
        var h = height;
        var centerX = w / 2;
        var centerY = h / 2;
        var rw = Math.max(ringWidth, 1.5);
        var radius = Math.min(w, h) / 2 - rw - 2;
        if (radius < 4) radius = 4;

        ctx.clearRect(0, 0, w, h);

        // ── 背景圆环 ──
        ctx.beginPath();
        ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI);
        ctx.strokeStyle = bgColor;
        ctx.lineWidth = rw;
        ctx.lineCap = "round";
        ctx.stroke();

        // ── 前景弧 (仅有效数据) ──
        if (valid && value > 0) {
            var ratio = Math.min(value / maxValue, 1.0);
            var startAngle = -Math.PI / 2;
            var endAngle = startAngle + ratio * 2 * Math.PI;
            var color = ringColor.a > 0 ? ringColor : computedColor(invertColors ? 100 - value : value);

            ctx.beginPath();
            ctx.arc(centerX, centerY, radius, startAngle, endAngle);
            ctx.strokeStyle = color;
            ctx.lineWidth = rw;
            ctx.lineCap = "round";
            ctx.stroke();
        }

        if (!valid && value <= 0) {
            // N/A: 画一个浅灰色细环表示无数据
            ctx.beginPath();
            ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI);
            ctx.strokeStyle = "#444444";
            ctx.lineWidth = 1;
            ctx.lineCap = "round";
            ctx.stroke();
        }

        // ── 中心文字 ──
        var fontSize = Math.max(radius * 0.45, 8);
        var subFontSize = Math.max(radius * 0.3, 6);

        if (innerLabel) {
            ctx.fillStyle = "#eeeeee";
            ctx.font = "bold " + Math.round(fontSize) + "px sans-serif";
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";
            var labelY = innerSubLabel ? centerY - fontSize * 0.35 : centerY;
            ctx.fillText(innerLabel, centerX, labelY);
        }

        if (innerSubLabel) {
            ctx.fillStyle = "#999999";
            ctx.font = Math.round(subFontSize) + "px sans-serif";
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";
            var subY = innerLabel ? centerY + fontSize * 0.55 : centerY;
            ctx.fillText(innerSubLabel, centerX, subY);
        }
    }
}
