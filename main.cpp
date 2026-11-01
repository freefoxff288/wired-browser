// Wired Browser: точка входа для сборки в .exe (на Linux его можно запускать и без сборки: qml src/browser.qml).
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QtWebEngineQuick/qtwebenginequickglobal.h>

int main(int argc, char *argv[])
{
    QCoreApplication::setOrganizationName("Wired");
    QCoreApplication::setApplicationName("WiredBrowser");
    QtWebEngineQuick::initialize();   // до создания приложения — требование QtWebEngine
    QGuiApplication app(argc, argv);
    app.setWindowIcon(QIcon(":/icon.png"));
    QQmlApplicationEngine engine;
    engine.load(QUrl("qrc:/browser.qml"));
    if (engine.rootObjects().isEmpty())
        return 1;
    return app.exec();
}
