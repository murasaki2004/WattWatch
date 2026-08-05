#pragma once
#include "cxxbridge/bridge.rs.hpp"
#include <QObject>
#include <QString>
#include <qqmlintegration.h>

class GaugeProxy : public QObject {
    Q_OBJECT
    Q_PROPERTY(uint  batteryPercent READ batteryPercent NOTIFY dataChanged FINAL)
    Q_PROPERTY(bool  batteryCharging READ batteryIsCharging NOTIFY dataChanged FINAL)
    Q_PROPERTY(float batteryPower READ batteryPowerW NOTIFY dataChanged FINAL)
    Q_PROPERTY(QString batteryRemaining READ batteryRemaining NOTIFY dataChanged FINAL)
    Q_PROPERTY(float batteryCapacityWh READ batteryCapacityWh NOTIFY dataChanged FINAL)
    Q_PROPERTY(float batteryEnergyNowWh READ batteryEnergyNowWh NOTIFY dataChanged FINAL)

public:
    explicit GaugeProxy(QObject *parent = nullptr);
    ~GaugeProxy() = default;

    uint  batteryPercent() const;
    bool  batteryIsCharging() const;
    float batteryPowerW() const;
    QString batteryRemaining() const;
    float batteryCapacityWh() const;
    float batteryEnergyNowWh() const;

    Q_INVOKABLE void refresh();

Q_SIGNALS:
    void dataChanged();

private:
    rust::Box<wattwatch::WattWatchBackend> _backend;
};
