#include "Paths.h"

#include <QDir>
#include <QStandardPaths>

namespace Paths {

QString workDir()
{
    return QDir::homePath() + QStringLiteral("/.ps5streamer");
}

QString nginxConf()
{
    return workDir() + QStringLiteral("/nginx.conf");
}

QString nginxPid()
{
    return workDir() + QStringLiteral("/nginx.pid");
}

QString nginxErrLog()
{
    return workDir() + QStringLiteral("/nginx-error.log");
}

QString dnsmasqConf()
{
    return workDir() + QStringLiteral("/dnsmasq.conf");
}

void createWorkDir()
{
    QDir().mkpath(workDir());
}

} // namespace Paths
