#pragma once
#include "cxxbridge/bridge.rs.hpp"
#include <QObject>
#include <QString>
#include <QVariantList>
#include <qqmlintegration.h>

class GaugeProxy : public QObject {
    Q_OBJECT
    Q_PROPERTY(uint  batteryPercent READ batteryPercent NOTIFY dataChanged FINAL)
    Q_PROPERTY(bool  batteryCharging READ batteryIsCharging NOTIFY dataChanged FINAL)
    Q_PROPERTY(float batteryPower READ batteryPowerW NOTIFY dataChanged FINAL)
    Q_PROPERTY(QString batteryRemaining READ batteryRemaining NOTIFY dataChanged FINAL)
    Q_PROPERTY(float batteryCapacityWh READ batteryCapacityWh NOTIFY dataChanged FINAL)
    Q_PROPERTY(float batteryEnergyNowWh READ batteryEnergyNowWh NOTIFY dataChanged FINAL)
    Q_PROPERTY(QVariantList powerLog READ powerLog NOTIFY dataChanged FINAL)

public:
    explicit GaugeProxy(QObject *parent = nullptr);
    ~GaugeProxy() = default;

    uint  batteryPercent() const;
    bool  batteryIsCharging() const;
    float batteryPowerW() const;
    QString batteryRemaining() const;
    float batteryCapacityWh() const;
    float batteryEnergyNowWh() const;
    QVariantList powerLog() const;

    /// 手动记录一次当前功耗采样(读取失败时静默)
    Q_INVOKABLE void pushPowerLog();

    Q_INVOKABLE void refresh();

Q_SIGNALS:
    void dataChanged();

private:
    rust::Box<wattwatch::WattWatchBackend> _backend;
};
