#include "android_soundfont.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>

namespace mu::app {

void extractBundledSoundfont()
{
    const QString resourcePath = QStringLiteral(":/android/sound/MS Basic.sf3");
    if (!QFile::exists(resourcePath)) {
        return;
    }

    const QString destDir = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation)
                            + QStringLiteral("/sound");
    QDir().mkpath(destDir);

    const QString destPath = destDir + QStringLiteral("/MS Basic.sf3");
    const qint64 resourceSize = QFileInfo(resourcePath).size();
    if (QFileInfo::exists(destPath) && QFileInfo(destPath).size() == resourceSize) {
        return;
    }

    QFile src(resourcePath);
    QFile dst(destPath);
    if (!src.open(QIODevice::ReadOnly) || !dst.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        return;
    }

    constexpr qint64 chunk = 1 << 20;
    QByteArray buf;
    while (!src.atEnd()) {
        buf = src.read(chunk);
        if (buf.isEmpty()) {
            break;
        }
        dst.write(buf);
    }
}

} // namespace mu::app
