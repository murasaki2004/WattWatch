#include "GaugeProxy.hpp"
#include <QVariantMap>

GaugeProxy::GaugeProxy(QObject *parent)
    : QObject{parent}, _backend{wattwatch::make_backend()} {}

void GaugeProxy::refresh() {
    _backend->refresh(); // 每秒刷新显示数据;功耗日志由后端按 30 分钟间隔自动采样
    Q_EMIT dataChanged();
}

void GaugeProxy::pushPowerLog() {
    _backend->push_power_log();
}

uint  GaugeProxy::batteryPercent() const    { return _backend->battery_percent(); }
bool  GaugeProxy::batteryIsCharging() const { return _backend->battery_is_charging(); }
float GaugeProxy::batteryPowerW() const     { return _backend->battery_power_w(); }
float GaugeProxy::batteryCapacityWh() const { return _backend->battery_capacity_wh(); }
float GaugeProxy::batteryEnergyNowWh() const { return _backend->battery_energy_now_wh(); }

QString GaugeProxy::batteryRemaining() const {
    auto s = _backend->battery_remaining();
    return QString::fromUtf8(s.data(), static_cast<int>(s.size()));
}

QVariantList GaugeProxy::powerLog() const {
    QVariantList list;
    auto samples = _backend->power_log();
    for (const auto &s : samples) {
        QVariantMap m;
        m[QStringLiteral("timestamp")] = static_cast<qlonglong>(s.timestamp);
        m[QStringLiteral("power")] = s.power;
        m[QStringLiteral("charging")] = s.charging;
        list.append(m);
    }
    return list;
}

#include "moc_GaugeProxy.cpp"
