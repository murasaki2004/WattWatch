#include "Plugin.hpp"
#include "GaugeProxy.hpp"
#include <QQmlEngine>

#ifndef PLUGIN_URI
#error Missing external define. Pass PLUGIN_URI to plugin build step
#endif

namespace {
QObject *gaugeProxySingletonBuilder(QQmlEngine *, QJSEngine *) {
    return new GaugeProxy();
}
}

void Plugin::registerTypes(char const *uri) {
    Q_ASSERT(QLatin1String(uri) == QLatin1String(PLUGIN_URI));
    qmlRegisterSingletonType<GaugeProxy>(uri, 1, 0, "Gauge",
                                         gaugeProxySingletonBuilder);
}

#include "moc_Plugin.cpp"
