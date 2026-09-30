#include "ConfigGenerator.h"
#include "Paths.h"

#include <QFile>
#include <QTextStream>

GeneratedConfigs ConfigGenerator::generate(const QString & /*hostIP*/)
{
    Paths::createWorkDir();

    QFile nginxFile(Paths::nginxConf());
    if (nginxFile.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        QTextStream out(&nginxFile);
        out << nginxConfig();
        nginxFile.close();
    }

    GeneratedConfigs configs;
    configs.nginxConfig = Paths::nginxConf();
    return configs;
}

QString ConfigGenerator::nginxConfig() const
{
    // Keep paths with forward slashes; quote them for Windows spaces.
    const QString err = Paths::nginxErrLog();
    const QString pid = Paths::nginxPid();

    return QStringLiteral(
        "worker_processes 1;\n"
        "error_log \"%1\" warn;\n"
        "pid       \"%2\";\n"
        "\n"
        "events {\n"
        "    worker_connections 512;\n"
        "}\n"
        "\n"
        "rtmp {\n"
        "    server {\n"
        "        listen 1935;\n"
        "        chunk_size 4096;\n"
        "\n"
        "        application app {\n"
        "            live on;\n"
        "            record off;\n"
        "            sync 10ms;\n"
        "            on_publish http://127.0.0.1:9988/on_publish;\n"
        "            # push rtmp://live.twitch.tv/app/YOUR_TWITCH_KEY;\n"
        "        }\n"
        "\n"
        "        application live2 {\n"
        "            live on;\n"
        "            record off;\n"
        "            on_publish http://127.0.0.1:9988/on_publish;\n"
        "        }\n"
        "    }\n"
        "}\n"
        "\n"
        "http {\n"
        "    access_log off;\n"
        "    server {\n"
        "        listen 8080;\n"
        "        location /stat { rtmp_stat all; }\n"
        "    }\n"
        "}\n"
    ).arg(err, pid);
}
