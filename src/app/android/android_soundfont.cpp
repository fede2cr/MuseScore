#include "android_soundfont.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>

#include "log.h"

namespace mu::app {

void extractBundledSoundfont()
{
    const QString resourcePath = QStringLiteral(":/android/sound/MS Basic.sf3");
    if (!QFile::exists(resourcePath)) {
        LOGE() << "Android soundfont resource missing at " << resourcePath;
        return;
    }

    const QString destDir = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation)
                            + QStringLiteral("/sound");
    if (!QDir().mkpath(destDir)) {
        LOGE() << "Failed to create soundfont dir " << destDir;
        return;
    }

    const QString destPath = destDir + QStringLiteral("/MS Basic.sf3");
    const qint64 resourceSize = QFileInfo(resourcePath).size();
    if (QFileInfo::exists(destPath) && QFileInfo(destPath).size() == resourceSize) {
        LOGI() << "Android soundfont already present at " << destPath << " (" << resourceSize << " bytes)";
        return;
    }

    QFile src(resourcePath);
    QFile dst(destPath);
    if (!src.open(QIODevice::ReadOnly)) {
        LOGE() << "Failed to open resource " << resourcePath;
        return;
    }
    if (!dst.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        LOGE() << "Failed to open dest " << destPath << " for writing";
        return;
    }

    constexpr qint64 chunk = 1 << 20;
    qint64 total = 0;
    QByteArray buf;
    while (!src.atEnd()) {
        buf = src.read(chunk);
        if (buf.isEmpty()) {
            break;
        }
        const qint64 w = dst.write(buf);
        if (w != buf.size()) {
            LOGE() << "Short write to " << destPath << " wrote=" << w << " expected=" << buf.size();
            return;
        }
        total += w;
    }
    LOGI() << "Extracted Android soundfont to " << destPath << " (" << total << " bytes)";
}

} // namespace mu::app
