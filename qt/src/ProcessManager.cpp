#include "ProcessManager.h"
#include "Paths.h"

#include <QCoreApplication>
#include <QFile>
#include <QFileInfo>
#include <QThread>
#include <QTimer>

ProcessManager::ProcessManager(QObject *parent)
    : QObject(parent)
{
}

ProcessManager::~ProcessManager()
{
    stopAll();
}

QString ProcessManager::resolveNginxBin()
{
    const QString appDir = QCoreApplication::applicationDirPath();
    const QStringList candidates = {
#ifdef Q_OS_WIN
        appDir + QStringLiteral("/nginx.exe"),
        appDir + QStringLiteral("/Binaries/nginx.exe"),
        QStringLiteral("C:/nginx/nginx.exe"),
#else
        appDir + QStringLiteral("/nginx"),
        appDir + QStringLiteral("/Binaries/nginx"),
        QStringLiteral("/usr/sbin/nginx"),
        QStringLiteral("/usr/bin/nginx"),
        QStringLiteral("/usr/local/sbin/nginx"),
        QStringLiteral("/usr/local/bin/nginx"),
#endif
    };

    for (const QString &path : candidates) {
        if (QFileInfo::exists(path))
            return path;
    }

    // Fall back to PATH lookup
#ifdef Q_OS_WIN
    return QStringLiteral("nginx.exe");
#else
    return QStringLiteral("nginx");
#endif
}

void ProcessManager::startNginx(const QString &configPath)
{
    const QString bin = resolveNginxBin();
    if (!QFileInfo::exists(bin) && !bin.contains(QLatin1Char('/')) && !bin.contains(QLatin1Char('\\'))) {
        // May still be on PATH — try starting; fail later if not found
    } else if (!QFileInfo::exists(bin)) {
        emit nginxFailed(
#ifdef Q_OS_WIN
            QStringLiteral("nginx not found. Place nginx.exe (with RTMP module) next to the app or in C:\\nginx.")
#else
            QStringLiteral("nginx not found. Install nginx with the RTMP module (e.g. libnginx-mod-rtmp).")
#endif
        );
        return;
    }

    killStrayNginx();

    if (m_nginx) {
        m_nginx->kill();
        m_nginx->deleteLater();
        m_nginx = nullptr;
    }

    m_nginx = new QProcess(this);
    m_nginx->setProcessChannelMode(QProcess::MergedChannels);

    connect(m_nginx, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this](int exitCode, QProcess::ExitStatus) {
                if (exitCode != 0)
                    emit nginxCrashed();
            });

    m_nginx->start(bin, {QStringLiteral("-c"), configPath, QStringLiteral("-g"), QStringLiteral("daemon off;")});

    if (!m_nginx->waitForStarted(3000)) {
        const QString err = m_nginx->errorString();
        m_nginx->deleteLater();
        m_nginx = nullptr;
        emit nginxFailed(err);
        return;
    }

    // Give nginx a moment to bind or fail
    QTimer::singleShot(800, this, [this]() {
        if (!m_nginx)
            return;
        if (m_nginx->state() != QProcess::Running) {
            const QString msg = QString::fromUtf8(m_nginx->readAll()).trimmed();
            emit nginxFailed(msg.isEmpty() ? QStringLiteral("nginx exited immediately") : msg);
            m_nginx->deleteLater();
            m_nginx = nullptr;
            return;
        }
        emit nginxStarted();
    });
}

void ProcessManager::stopNginx()
{
    if (!m_nginx)
        return;

    m_nginx->disconnect();
    m_nginx->terminate();
    if (!m_nginx->waitForFinished(3000))
        m_nginx->kill();
    m_nginx->deleteLater();
    m_nginx = nullptr;

    QFile::remove(Paths::nginxPid());
}

void ProcessManager::stopAll()
{
    stopNginx();
}

void ProcessManager::killStrayNginx()
{
#ifdef Q_OS_WIN
    QProcess::execute(QStringLiteral("taskkill"), {QStringLiteral("/F"), QStringLiteral("/IM"), QStringLiteral("nginx.exe")});
#else
    QProcess::execute(QStringLiteral("pkill"), {QStringLiteral("-f"), resolveNginxBin()});
#endif
    QThread::msleep(300);
}
