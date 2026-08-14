import QtQuick
import org.kde.plasma.core as PlasmaCore

/// 功耗-时间折线图(Canvas 手绘,无额外依赖)
///
/// - samples: 功耗采样数组(旧 → 新),元素形如 { timestamp: unix秒, power: 瓦数, charging: bool }
/// - 横轴: 采样序号(每个采样间隔 10 分钟)
/// - 纵轴: 功耗(W),自动按最大值缩放
/// - 折线分段着色: 充电段绿色,放电段主题色
/// - 数据不足 2 条时显示提示文本
/// - 节点圆点: 若存在连续超过两个节点仅时间戳不同(power 与 charging 均相同),
///   则该段仅首尾节点显示强调圆点,中间节点不再绘制
Canvas {
    id: root

    property var samples: []

    /// 每个采样点的间隔(分钟),用于时间跨度标注
    property int sampleIntervalMinutes: 10

    readonly property bool hasData: root.samples.length >= 2

    // ── 统计 ──
    readonly property real maxPower: {
        let m = 0;
        for (let i = 0; i < root.samples.length; i++) {
            m = Math.max(m, root.samples[i].power);
        }
        return m;
    }
    readonly property real avgPower: {
        let sum = 0;
        for (let i = 0; i < root.samples.length; i++) {
            sum += root.samples[i].power;
        }
        return root.samples.length > 0 ? sum / root.samples.length : 0;
    }
    /// 时间跨度文本(如 "2.5 小时" / "3 天")
    readonly property string spanText: {
        let n = root.samples.length;
        if (n < 2) return "";
        let minutes = (n - 1) * root.sampleIntervalMinutes;
        if (minutes < 60) return minutes + " 分钟";
        let hours = minutes / 60;
        if (hours < 48) {
            return (Math.round(hours * 10) / 10) + " 小时";
        }
        return (Math.round(hours / 24 * 10) / 10) + " 天";
    }

    implicitWidth: 260
    implicitHeight: 110

    antialiasing: true
    renderTarget: Canvas.FramebufferObject

    onSamplesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    // 主题切换时重绘(放电段颜色取自 Plasma 主题)
    Connections {
        target: PlasmaCore.Theme
        function onThemeChanged() { root.requestPaint() }
    }

    onPaint: {
        var ctx = getContext("2d");
        if (!ctx) return;
        ctx.clearRect(0, 0, width, height);

        var n = root.samples.length;
        if (n < 2) {
            // 数据不足:居中提示
            ctx.fillStyle = "#888888";
            ctx.font = "11px sans-serif";
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";
            ctx.fillText(root.samples.length === 0 ? "暂无功耗数据" : "数据不足,等待下一次采样", width / 2, height / 2);
            return;
        }

        // ── 几何与配色 ──
        var padL = 30, padR = 8, padT = 8, padB = 16;
        var plotW = Math.max(width - padL - padR, 20);
        var plotH = Math.max(height - padT - padB, 20);
        var maxP = root.maxPower;
        if (maxP <= 0) maxP = 1;

        var themeOk = PlasmaCore && PlasmaCore.Theme;
        var lineColor = themeOk ? PlasmaCore.Theme.textColor : "#888888";
        var chargeColor = "#4caf50";
        var axisColor = "rgba(128, 128, 128, 0.35)";

        // ── 网格线(4 等分)与纵轴标签 ──
        ctx.strokeStyle = axisColor;
        ctx.lineWidth = 1;
        ctx.fillStyle = "rgba(128, 128, 128, 0.9)";
        ctx.font = "9px sans-serif";
        ctx.textAlign = "right";
        ctx.textBaseline = "middle";
        for (var g = 0; g <= 4; g++) {
            var gy = padT + plotH * (1 - g / 4);
            ctx.beginPath();
            ctx.moveTo(padL, gy);
            ctx.lineTo(padL + plotW, gy);
            ctx.stroke();
            ctx.fillText(Math.round(maxP * g / 4) + "W", padL - 4, gy);
        }

        // ── 折线(仅当两端同为充电时绿色,否则主题色) ──
        ctx.lineWidth = 1.5;
        ctx.lineJoin = "round";
        for (var i = 1; i < n; i++) {
            var x0 = padL + plotW * (i - 1) / (n - 1);
            var y0 = padT + plotH * (1 - root.samples[i - 1].power / maxP);
            var x1 = padL + plotW * i / (n - 1);
            var y1 = padT + plotH * (1 - root.samples[i].power / maxP);
            var bothCharging = root.samples[i - 1].charging && root.samples[i].charging;
            ctx.strokeStyle = bothCharging ? chargeColor : lineColor;
            ctx.beginPath();
            ctx.moveTo(x0, y0);
            ctx.lineTo(x1, y1);
            ctx.stroke();
        }

        // ── 节点圆点(与该节点状态同色:充电绿,放电主题色) ──
        // 显示逻辑:把连续且 power/charging 完全相同的节点归为一段;
        // 段长超过 2(即 >2 个节点仅时间戳不同)时,仅首尾显示强调圆点,中间节点不画。
        var showDot = [];
        var emphasized = [];
        for (var s = 0; s < n; s++) {
            showDot.push(true);
            emphasized.push(false);
        }
        var runStart = 0;
        for (var r = 1; r <= n; r++) {
            var runEnds = (r === n)
                || root.samples[r].power !== root.samples[r - 1].power
                || root.samples[r].charging !== root.samples[r - 1].charging;
            if (runEnds) {
                var runLen = r - runStart;
                if (runLen > 2) {
                    emphasized[runStart] = true;
                    emphasized[r - 1] = true;
                    for (var m = runStart + 1; m < r - 1; m++) {
                        showDot[m] = false;
                    }
                }
                runStart = r;
            }
        }

        var dotR = Math.max(2.0, Math.min(3.0, plotW / n / 2));
        var emphR = dotR + 1.0; // 强调圆点略大
        for (var d = 0; d < n; d++) {
            if (!showDot[d]) continue;
            var dx = padL + plotW * d / (n - 1);
            var dy = padT + plotH * (1 - root.samples[d].power / maxP);
            ctx.fillStyle = root.samples[d].charging ? chargeColor : lineColor;
            ctx.beginPath();
            ctx.arc(dx, dy, emphasized[d] ? emphR : dotR, 0, 2 * Math.PI);
            ctx.fill();
        }

        // ── 横轴时间标注 ──
        ctx.fillStyle = "rgba(128, 128, 128, 0.9)";
        ctx.textBaseline = "alphabetic";
        ctx.textAlign = "left";
        ctx.fillText("-" + root.spanText, padL, height - 2);
        ctx.textAlign = "right";
        ctx.fillText("现在", padL + plotW, height - 2);
    }
}
