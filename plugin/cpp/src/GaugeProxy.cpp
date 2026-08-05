#include "GaugeProxy.hpp"

GaugeProxy::GaugeProxy(QObject *parent)
    : QObject{parent}, _backend{wattwatch::make_backend()} {}

void GaugeProxy::refresh() {
    _backend->refresh();
    Q_EMIT dataChanged();
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

#include "moc_GaugeProxy.cpp"
