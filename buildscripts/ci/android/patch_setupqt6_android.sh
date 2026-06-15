#!/usr/bin/env bash
set -euo pipefail

setup_qt6="muse/buildscripts/cmake/SetupQt6.cmake"
if [ ! -f "$setup_qt6" ]; then
  echo "error: $setup_qt6 not found" >&2
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
import re

path = Path('muse/buildscripts/cmake/SetupQt6.cmake')
text = path.read_text()
matched = False

def replace_once(current_text, pattern, replacement, *, flags=0):
    updated_text, replacements = re.subn(pattern, replacement, current_text, count=1, flags=flags)
    return updated_text, replacements

text, replacements = replace_once(
    text,
    r'(find_package\(\s*Qt6\b[\s\S]*?\bCOMPONENTS\b[\s\S]*?)\bDBus\b',
    r'\1',
)
matched = matched or replacements > 0

text, replacements = replace_once(
    text,
    r'^\s*list\(APPEND\s+qt_components\s+DBus\)\s*$\n?',
    '',
    flags=re.M,
)
matched = matched or replacements > 0

text, replacements = replace_once(
    text,
    r'^\s*list\(APPEND\s+QT_LIBRARIES\s+Qt::DBus\)\s*$\n?',
    '',
    flags=re.M,
)
matched = matched or replacements > 0

assert matched, 'expected DBus component declaration not found in SetupQt6.cmake'

path.write_text(text)

for relative_path, replacements in {
    'muse/framework/audio/driver/CMakeLists.txt': [
        (
            'elseif(OS_IS_LIN OR OS_IS_FBSD)\n',
            'elseif((OS_IS_LIN OR OS_IS_FBSD) AND NOT ANDROID)\n',
        ),
        (
            '    find_package(ALSA REQUIRED)\n    target_link_libraries(muse_audio_driver PRIVATE ALSA::ALSA pthread)\n',
            '    if (NOT ANDROID)\n        find_package(ALSA REQUIRED)\n        target_link_libraries(muse_audio_driver PRIVATE ALSA::ALSA pthread)\n    endif()\n',
        ),
    ],
    'muse/framework/midi/CMakeLists.txt': [
        (
            'elseif (OS_IS_LIN OR OS_IS_FBSD)\n',
            'elseif ((OS_IS_LIN OR OS_IS_FBSD) AND NOT ANDROID)\n',
        ),
        (
            '    find_package(ALSA REQUIRED)\n    target_include_directories(muse_midi PRIVATE ${ALSA_INCLUDE_DIRS})\n    target_link_libraries(muse_midi PRIVATE ${ALSA_LIBRARIES} pthread)\n',
            '    if (NOT ANDROID)\n        find_package(ALSA REQUIRED)\n        target_include_directories(muse_midi PRIVATE ${ALSA_INCLUDE_DIRS})\n        target_link_libraries(muse_midi PRIVATE ${ALSA_LIBRARIES} pthread)\n    endif()\n',
        ),
    ],
    'muse/framework/ui/CMakeLists.txt': [
        (
            '    if (OS_IS_LIN)\n        target_link_libraries(muse_ui PRIVATE Qt::DBus)\n    endif()\n',
            '    if (OS_IS_LIN AND NOT ANDROID)\n        target_link_libraries(muse_ui PRIVATE Qt::DBus)\n    endif()\n',
        ),
        (
            'elseif(OS_IS_LIN)\n    target_sources(muse_ui PRIVATE\n        internal/platform/linux/linuxplatformtheme.cpp\n        internal/platform/linux/linuxplatformtheme.h\n    )\n',
            'elseif(OS_IS_LIN AND NOT ANDROID)\n    target_sources(muse_ui PRIVATE\n        internal/platform/linux/linuxplatformtheme.cpp\n        internal/platform/linux/linuxplatformtheme.h\n    )\n',
        ),
    ],
    'muse/framework/ui/uimodule.cpp': [
        (
            '#elif defined(Q_OS_LINUX)\n#include "internal/platform/linux/linuxplatformtheme.h"\n#include "internal/windowscontroller.h"\n',
            '#elif defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)\n#include "internal/platform/linux/linuxplatformtheme.h"\n#include "internal/windowscontroller.h"\n',
        ),
        (
            '    #elif defined(Q_OS_LINUX)\n    m_platformTheme = std::make_shared<LinuxPlatformTheme>();\n',
            '    #elif defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)\n    m_platformTheme = std::make_shared<LinuxPlatformTheme>();\n',
        ),
    ],
    'muse/framework/ui/uimodule.h': [
        (
            '#elif defined(Q_OS_LINUX)\nclass LinuxPlatformTheme;\n',
            '#elif defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)\nclass LinuxPlatformTheme;\n',
        ),
        (
            '    #elif defined(Q_OS_LINUX)\n    std::shared_ptr<LinuxPlatformTheme> m_platformTheme;\n',
            '    #elif defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)\n    std::shared_ptr<LinuxPlatformTheme> m_platformTheme;\n',
        ),
    ],
    'muse/framework/midi/midimodule.cpp': [
        (
            '#if defined(Q_OS_LINUX) || defined(Q_OS_FREEBSD)\n#include "internal/platform/lin/alsamidioutport.h"\n#include "internal/platform/lin/alsamidiinport.h"\n',
            '#if (defined(Q_OS_LINUX) || defined(Q_OS_FREEBSD)) && !defined(Q_OS_ANDROID)\n#include "internal/platform/lin/alsamidioutport.h"\n#include "internal/platform/lin/alsamidiinport.h"\n',
        ),
        (
            '    #if defined(Q_OS_LINUX) || defined(Q_OS_FREEBSD)\n    m_midiOutPort = std::make_shared<AlsaMidiOutPort>();\n    m_midiInPort = std::make_shared<AlsaMidiInPort>();\n',
            '    #if (defined(Q_OS_LINUX) || defined(Q_OS_FREEBSD)) && !defined(Q_OS_ANDROID)\n    m_midiOutPort = std::make_shared<AlsaMidiOutPort>();\n    m_midiInPort = std::make_shared<AlsaMidiInPort>();\n',
        ),
    ],
    'muse/framework/midi/midimodule.h': [
        (
            '#if defined(Q_OS_LINUX)\nclass AlsaMidiOutPort;\nclass AlsaMidiInPort;\n',
            '#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)\nclass AlsaMidiOutPort;\nclass AlsaMidiInPort;\n',
        ),
        (
            '    #if defined(Q_OS_LINUX) || defined(Q_OS_FREEBSD)\n    std::shared_ptr<AlsaMidiOutPort> m_midiOutPort;\n    std::shared_ptr<AlsaMidiInPort> m_midiInPort;\n',
            '    #if (defined(Q_OS_LINUX) || defined(Q_OS_FREEBSD)) && !defined(Q_OS_ANDROID)\n    std::shared_ptr<AlsaMidiOutPort> m_midiOutPort;\n    std::shared_ptr<AlsaMidiInPort> m_midiInPort;\n',
        ),
    ],
    'muse/framework/audio/main/internal/audiodrivercontroller.cpp': [
        (
            '#if defined(Q_OS_LINUX) || defined(Q_OS_FREEBSD)\n#include <QtEnvironmentVariables>\n#include "audio/driver/platform/lin/alsaaudiodriver.h"\n',
            '#if (defined(Q_OS_LINUX) || defined(Q_OS_FREEBSD)) && !defined(Q_OS_ANDROID)\n#include <QtEnvironmentVariables>\n#include "audio/driver/platform/lin/alsaaudiodriver.h"\n',
        ),
        (
            '#if defined(Q_OS_LINUX) || defined(Q_OS_FREEBSD)\n    if (qEnvironmentVariableIsSet("MUSESCORE_FORCE_ALSA")) {\n',
            '#if (defined(Q_OS_LINUX) || defined(Q_OS_FREEBSD)) && !defined(Q_OS_ANDROID)\n    if (qEnvironmentVariableIsSet("MUSESCORE_FORCE_ALSA")) {\n',
        ),
        (
            '#if defined(Q_OS_LINUX) || defined(Q_OS_FREEBSD)\n    names.push_back("ALSA");\n',
            '#if (defined(Q_OS_LINUX) || defined(Q_OS_FREEBSD)) && !defined(Q_OS_ANDROID)\n    names.push_back("ALSA");\n',
        ),
    ],
    'muse/framework/midi/internal/dummymidioutport.cpp': [
        (
            'void DummyMidiOutPort::init()\n{\n}\n',
            'void DummyMidiOutPort::init()\n{\n}\n\nvoid DummyMidiOutPort::deinit()\n{\n}\n\nasync::Notification DummyMidiOutPort::deviceChanged() const\n{\n    return async::Notification();\n}\n',
        ),
    ],
    'muse/framework/midi/internal/dummymidiinport.cpp': [
        (
            'void DummyMidiInPort::init()\n{\n}\n',
            'void DummyMidiInPort::init()\n{\n}\n\nvoid DummyMidiInPort::deinit()\n{\n}\n\nasync::Notification DummyMidiInPort::availableDevicesChanged() const\n{\n    return async::Notification();\n}\n\nasync::Notification DummyMidiInPort::deviceChanged() const\n{\n    return async::Notification();\n}\n',
        ),
    ],
    'muse/framework/midi/internal/dummymidioutport.h': [
        (
            'public:\n\n    void init();\n\n    MidiDeviceList availableDevices() const override;\n    async::Notification availableDevicesChanged() const override;\n',
            'public:\n\n    void init();\n    void deinit();\n\n    MidiDeviceList availableDevices() const override;\n    async::Notification availableDevicesChanged() const override;\n',
        ),
        (
            '    MidiDeviceID deviceID() const override;\n\n    bool supportsMIDI20Output() const override;\n',
            '    MidiDeviceID deviceID() const override;\n    async::Notification deviceChanged() const override;\n\n    bool supportsMIDI20Output() const override;\n',
        ),
    ],
    'muse/framework/midi/internal/dummymidiinport.h': [
        (
            'public:\n\n    void init();\n\n    std::vector<MidiDevice> availableDevices() const override;\n\n    Ret connect(const MidiDeviceID& deviceID) override;\n',
            'public:\n\n    void init();\n    void deinit();\n\n    std::vector<MidiDevice> availableDevices() const override;\n    async::Notification availableDevicesChanged() const override;\n\n    Ret connect(const MidiDeviceID& deviceID) override;\n',
        ),
        (
            '    bool isConnected() const override;\n    MidiDeviceID deviceID() const override;\n\n    async::Channel<tick_t, Event> eventReceived() const override;\n',
            '    bool isConnected() const override;\n    MidiDeviceID deviceID() const override;\n    async::Notification deviceChanged() const override;\n\n    async::Channel<tick_t, Event> eventReceived() const override;\n',
        ),
    ],
    'muse/framework/audio/main/audiomodule.cpp': [
        (
            '#ifndef Q_OS_WASM\n    m_startAudioController->startAudioProcessing(mode);\n#endif\n',
            '#if !defined(Q_OS_WASM)\n    m_startAudioController->startAudioProcessing(mode);\n#endif\n',
        ),
    ],
    # On Android, the default appDataPath fallback (/usr/local/share/...) does
    # not exist, so the synth never finds the bundled soundfont. Add the app's
    # writable AppLocalDataLocation/sound dir to the scanned set; the main app
    # extracts MS Basic.sf3 into that location on first launch.
    'muse/framework/audio/main/internal/audioconfiguration.cpp': [
        (
            '#include "audioconfiguration.h"\n\n//TODO: remove with global clearing of Q_OS_*** defines\n#include <QtGlobal>\n',
            '#include "audioconfiguration.h"\n\n//TODO: remove with global clearing of Q_OS_*** defines\n#include <QtGlobal>\n\n#ifdef Q_OS_ANDROID\n#include <QStandardPaths>\n#include "log.h"\n#endif\n',
        ),
        (
            'io::paths_t AudioConfiguration::soundFontDirectories() const\n{\n    io::paths_t paths = userSoundFontDirectories();\n    paths.push_back(globalConfiguration()->appDataPath());\n\n    return paths;\n}\n',
            'io::paths_t AudioConfiguration::soundFontDirectories() const\n{\n    io::paths_t paths = userSoundFontDirectories();\n    paths.push_back(globalConfiguration()->appDataPath());\n\n#ifdef Q_OS_ANDROID\n    const QString androidSoundDir = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation) + QStringLiteral("/sound");\n    paths.push_back(io::path_t(androidSoundDir));\n    LOGI() << "Android soundfont dirs: appData=" << globalConfiguration()->appDataPath().toStdString() << " writable=" << androidSoundDir.toStdString();\n#endif\n\n    return paths;\n}\n',
        ),
    ],
    # Route ConsoleLogDest output to Android logcat so muse LOG* macros become
    # visible without needing run-as access to the app's internal data dir.
    'muse/framework/global/thirdparty/kors_logger/src/logdefdest.cpp': [
        (
            '#include "logdefdest.h"\n\n#include <iostream>\n\n#ifdef _WIN32\n#include <Windows.h>\n#endif\n\nusing namespace kors::logger;\n',
            '#include "logdefdest.h"\n\n#include <iostream>\n\n#ifdef _WIN32\n#include <Windows.h>\n#endif\n\n#ifdef __ANDROID__\n#include <android/log.h>\n#endif\n\nusing namespace kors::logger;\n',
        ),
        (
            'void ConsoleLogDest::write(const LogMsg& logMsg)\n{\n    std::string log = m_layout.output(logMsg);\n\n#ifdef _WIN32\n',
            'void ConsoleLogDest::write(const LogMsg& logMsg)\n{\n    std::string log = m_layout.output(logMsg);\n\n#ifdef __ANDROID__\n    int prio = ANDROID_LOG_INFO;\n    if (logMsg.type == Logger::ERRR) { prio = ANDROID_LOG_ERROR; }\n    else if (logMsg.type == Logger::WARN) { prio = ANDROID_LOG_WARN; }\n    else if (logMsg.type == Logger::DEBG) { prio = ANDROID_LOG_DEBUG; }\n    __android_log_print(prio, "MuseScore", "%s", log.c_str());\n    return;\n#endif\n\n#ifdef _WIN32\n',
        ),
    ],
    # Link liblog on Android so __android_log_print resolves at link time.
    'muse/framework/global/CMakeLists.txt': [
        (
            'target_link_libraries(muse_global PRIVATE ${CMAKE_DL_LIBS})\n',
            'target_link_libraries(muse_global PRIVATE ${CMAKE_DL_LIBS})\n\nif (ANDROID)\n    target_link_libraries(muse_global PRIVATE log)\nendif()\n',
        ),
    ],
    # Pick the android-specific Main.qml when loading the main window. Without
    # this, Q_OS_LINUX falls through to "linux" and the QML lookup fails.
    'muse/framework/ui/internal/guiapplication.cpp': [
        (
            '#if defined(Q_OS_MAC)\n    QString platform = "mac";\n#elif defined(Q_OS_WIN)\n    QString platform = "win";\n#else\n    QString platform = "linux";\n#endif\n',
            '#if defined(Q_OS_MAC)\n    QString platform = "mac";\n#elif defined(Q_OS_WIN)\n    QString platform = "win";\n#elif defined(Q_OS_ANDROID)\n    QString platform = "android";\n#else\n    QString platform = "linux";\n#endif\n',
        ),
    ],
}.items():
    target = Path(relative_path)
    if not target.exists():
        raise SystemExit(f'error: {relative_path} not found')

    contents = target.read_text()
    for old, new in replacements:
        if old not in contents:
            raise SystemExit(f'expected patch target not found in {relative_path}')
        contents = contents.replace(old, new, 1)
    target.write_text(contents)

# The QML FileDialog wrapper uses Qt.labs.platform.FileDialog which fails to
# instantiate on Android ("Window.window does only support types deriving from
# Item"). Route file/dir selection through QFileDialog on Android (same as
# Windows/macOS) by excluding Android from every Q_OS_LINUX file-dialog gate
# in this file. Q_OS_LINUX is also defined on Android, so without this every
# selectOpening*/selectSaving*/selectDirectory call goes through the broken
# QML dialog and silently returns an empty path.
#
# Additionally, QFileDialog on Android returns Storage Access Framework
# content:// URIs (e.g. content://com.android.providers.downloads.documents/...)
# which MuseScore cannot open as plain files and which have no extension for
# filetype detection. Copy the SAF stream to a cache file under the app's
# cache dir using the resolved display name so the extension is preserved,
# and return that local path.
interactive_cpp = Path('muse/framework/interactive/internal/interactive.cpp')
if not interactive_cpp.exists():
    raise SystemExit(f'error: {interactive_cpp} not found')

text = interactive_cpp.read_text()

ifdef_new = '#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)'
ifndef_new = '#if !defined(Q_OS_LINUX) || defined(Q_OS_ANDROID)'
text, n_ifdef = re.subn(r'^#ifdef\s+Q_OS_LINUX\s*$', ifdef_new, text, flags=re.M)
text, n_ifndef = re.subn(r'^#ifndef\s+Q_OS_LINUX\s*$', ifndef_new, text, flags=re.M)
if n_ifdef < 1 or n_ifndef < 1:
    raise SystemExit(f'expected Q_OS_LINUX gates not found in {interactive_cpp}')

# Add Qt includes used by the SAF helper. QFileDialog likely brings most of
# these in transitively but be explicit so the build is robust.
includes_anchor = '#include <QFileDialog>\n'
includes_extra = (
    '#include <QFileDialog>\n'
    '#include <QDir>\n'
    '#include <QFile>\n'
    '#include <QFileInfo>\n'
    '#include <QStandardPaths>\n'
    '#include <QUrl>\n'
    '#ifdef Q_OS_ANDROID\n'
    '#include <QCoreApplication>\n'
    '#include <QJniEnvironment>\n'
    '#include <QJniObject>\n'
    '#endif\n'
)
if includes_anchor not in text:
    raise SystemExit(f'include anchor not found in {interactive_cpp}')
text = text.replace(includes_anchor, includes_extra, 1)

# Insert the SAF helper right after filterToString().
helper_anchor = '    return result.join(";;");\n}\n\n#endif\n'
helper_block = (
    '    return result.join(";;");\n'
    '}\n'
    '\n'
    '#endif\n'
    '\n'
    '#ifdef Q_OS_ANDROID\n'
    '// Registered in muse::io (FileSystem) so the content:// copy-back happens\n'
    '// when the cache file stream is closed after writing.\n'
    'namespace muse::io {\n'
    'void registerAndroidSafSave(const std::string& cachePath, const std::string& contentUri);\n'
    '}\n'
    '\n'
    '// Query the ContentResolver for the human-readable _display_name (with\n'
    '// extension) of a content:// document. SAF URIs (e.g. OneDrive) carry no\n'
    '// usable filename in the URI path itself, so this is the only reliable way\n'
    '// to recover the extension MuseScore needs for file-type detection.\n'
    'static QString queryAndroidDisplayName(const QJniObject& activity, const QJniObject& jUri)\n'
    '{\n'
    '    QString name;\n'
    '    QJniEnvironment env;\n'
    '    QJniObject resolver = activity.callObjectMethod("getContentResolver", "()Landroid/content/ContentResolver;");\n'
    '    if (!resolver.isValid()) {\n'
    '        return name;\n'
    '    }\n'
    '    QJniObject cursor = resolver.callObjectMethod(\n'
    '        "query",\n'
    '        "(Landroid/net/Uri;[Ljava/lang/String;Ljava/lang/String;[Ljava/lang/String;Ljava/lang/String;)Landroid/database/Cursor;",\n'
    '        jUri.object(), nullptr, nullptr, nullptr, nullptr);\n'
    '    if (env.checkAndClearExceptions() || !cursor.isValid()) {\n'
    '        return name;\n'
    '    }\n'
    '    if (cursor.callMethod<jboolean>("moveToFirst")) {\n'
    '        QJniObject col = QJniObject::fromString(QStringLiteral("_display_name"));\n'
    '        const jint idx = cursor.callMethod<jint>("getColumnIndex", "(Ljava/lang/String;)I", col.object());\n'
    '        if (idx >= 0) {\n'
    '            QJniObject n = cursor.callObjectMethod("getString", "(I)Ljava/lang/String;", idx);\n'
    '            if (n.isValid()) {\n'
    '                name = n.toString();\n'
    '            }\n'
    '        }\n'
    '    }\n'
    '    cursor.callMethod<void>("close");\n'
    '    env.checkAndClearExceptions();\n'
    '    return name;\n'
    '}\n'
    '\n'
    '// Map a few content MIME types to an extension, used only as a fallback when\n'
    '// the display name carries no extension.\n'
    'static QString extensionFromMimeType(const QString& mime)\n'
    '{\n'
    '    if (mime == QLatin1String("audio/midi") || mime == QLatin1String("audio/x-midi")) {\n'
    '        return QStringLiteral("mid");\n'
    '    }\n'
    '    if (mime == QLatin1String("application/vnd.recordare.musicxml+xml")) {\n'
    '        return QStringLiteral("musicxml");\n'
    '    }\n'
    '    if (mime == QLatin1String("application/vnd.recordare.musicxml")) {\n'
    '        return QStringLiteral("mxl");\n'
    '    }\n'
    '    if (mime == QLatin1String("application/xml") || mime == QLatin1String("text/xml")) {\n'
    '        return QStringLiteral("xml");\n'
    '    }\n'
    '    return QString();\n'
    '}\n'
    '\n'
    '// Read a content:// document into destPath using ContentResolver.openInputStream.\n'
    '// QFile cannot open SAF provider URIs (notably the OneDrive\n'
    '// storageaccessprovider), so we must go through the resolver via JNI.\n'
    'static bool readAndroidContentToFile(const QJniObject& activity, const QJniObject& jUri, const QString& destPath)\n'
    '{\n'
    '    QJniEnvironment env;\n'
    '    QJniObject resolver = activity.callObjectMethod("getContentResolver", "()Landroid/content/ContentResolver;");\n'
    '    if (!resolver.isValid()) {\n'
    '        return false;\n'
    '    }\n'
    '    QJniObject stream = resolver.callObjectMethod(\n'
    '        "openInputStream", "(Landroid/net/Uri;)Ljava/io/InputStream;", jUri.object());\n'
    '    if (env.checkAndClearExceptions() || !stream.isValid()) {\n'
    '        LOGE() << "ContentResolver.openInputStream failed";\n'
    '        return false;\n'
    '    }\n'
    '    QFile dst(destPath);\n'
    '    if (!dst.open(QIODevice::WriteOnly | QIODevice::Truncate)) {\n'
    '        LOGE() << "Failed to create cache copy: " << destPath.toStdString();\n'
    '        stream.callMethod<void>("close");\n'
    '        env.checkAndClearExceptions();\n'
    '        return false;\n'
    '    }\n'
    '    const jint bufSize = 65536;\n'
    '    jbyteArray jbuf = env->NewByteArray(bufSize);\n'
    '    bool ok = true;\n'
    '    qint64 total = 0;\n'
    '    for (;;) {\n'
    '        const jint n = stream.callMethod<jint>("read", "([B)I", jbuf);\n'
    '        if (env.checkAndClearExceptions()) {\n'
    '            ok = false;\n'
    '            break;\n'
    '        }\n'
    '        if (n < 0) {\n'
    '            break;\n'
    '        }\n'
    '        if (n > 0) {\n'
    '            QByteArray chunk(n, Qt::Uninitialized);\n'
    '            env->GetByteArrayRegion(jbuf, 0, n, reinterpret_cast<jbyte*>(chunk.data()));\n'
    '            if (dst.write(chunk) != n) {\n'
    '                ok = false;\n'
    '                break;\n'
    '            }\n'
    '            total += n;\n'
    '        }\n'
    '    }\n'
    '    env->DeleteLocalRef(jbuf);\n'
    '    stream.callMethod<void>("close");\n'
    '    env.checkAndClearExceptions();\n'
    '    dst.close();\n'
    '    LOGI() << "Read " << total << " bytes from content uri";\n'
    '    return ok && total > 0;\n'
    '}\n'
    '\n'
    'static muse::io::path_t copyAndroidContentUriToCache(const QString& uri)\n'
    '{\n'
    '    LOGI() << "Android pick result uri: " << uri.toStdString();\n'
    '    if (uri.isEmpty()) {\n'
    '        return muse::io::path_t();\n'
    '    }\n'
    '    if (!uri.startsWith(QLatin1String("content://"))) {\n'
    '        return muse::io::path_t(uri);\n'
    '    }\n'
    '    QJniObject jUri = QJniObject::callStaticObjectMethod(\n'
    '        "android/net/Uri", "parse", "(Ljava/lang/String;)Landroid/net/Uri;",\n'
    '        QJniObject::fromString(uri).object<jstring>());\n'
    '    QJniObject activity(QNativeInterface::QAndroidApplication::context());\n'
    '    if (!jUri.isValid() || !activity.isValid()) {\n'
    '        LOGE() << "Invalid content Uri or activity context";\n'
    '        return muse::io::path_t();\n'
    '    }\n'
    '    QString displayName = queryAndroidDisplayName(activity, jUri);\n'
    '    if (displayName.isEmpty() || !displayName.contains(QLatin1Char(\'.\'))) {\n'
    '        QString mime;\n'
    '        QJniObject resolver = activity.callObjectMethod("getContentResolver", "()Landroid/content/ContentResolver;");\n'
    '        if (resolver.isValid()) {\n'
    '            QJniObject t = resolver.callObjectMethod("getType", "(Landroid/net/Uri;)Ljava/lang/String;", jUri.object());\n'
    '            if (t.isValid()) {\n'
    '                mime = t.toString();\n'
    '            }\n'
    '        }\n'
    '        const QString ext = extensionFromMimeType(mime);\n'
    '        QString base = displayName.isEmpty() ? QStringLiteral("opened_file") : displayName;\n'
    '        if (!ext.isEmpty()) {\n'
    '            base += QLatin1Char(\'.\') + ext;\n'
    '        }\n'
    '        displayName = base;\n'
    '    }\n'
    '    if (displayName.isEmpty()) {\n'
    '        displayName = QStringLiteral("opened_file.mscz");\n'
    '    }\n'
    '    LOGI() << "Android pick display name: " << displayName.toStdString();\n'
    '    QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation)\n'
    '                       + QStringLiteral("/opened");\n'
    '    if (!QDir().mkpath(cacheDir)) {\n'
    '        LOGE() << "Failed to create cache dir: " << cacheDir.toStdString();\n'
    '        return muse::io::path_t();\n'
    '    }\n'
    '    const QString cachePath = cacheDir + QLatin1Char(\'/\') + displayName;\n'
    '    if (!readAndroidContentToFile(activity, jUri, cachePath)) {\n'
    '        LOGE() << "Failed to read content uri into cache: " << uri.toStdString();\n'
    '        return muse::io::path_t();\n'
    '    }\n'
    '    LOGI() << "Copied picked file to cache: " << cachePath.toStdString();\n'
    '    return muse::io::path_t(cachePath);\n'
    '}\n'
    '\n'
    '// Save side: QFileDialog::getSaveFileName returns a SAF content:// URI for a\n'
    '// freshly created (empty) document. MuseScore cannot stream into a content://\n'
    '// URI through QFile, so route the export to a local cache file (keeping the\n'
    '// proper extension for writer selection) and register the cache->content URI\n'
    '// mapping. The bytes are copied back to the chosen document via\n'
    '// ContentResolver.openOutputStream once the cache file stream is closed.\n'
    'static muse::io::path_t prepareAndroidSaveUri(const QString& uri, const muse::io::path_t& defaultPath)\n'
    '{\n'
    '    LOGI() << "Android save pick result uri: " << uri.toStdString();\n'
    '    if (uri.isEmpty()) {\n'
    '        return muse::io::path_t();\n'
    '    }\n'
    '    if (!uri.startsWith(QLatin1String("content://"))) {\n'
    '        const QString local = QUrl::fromUserInput(uri).toLocalFile();\n'
    '        return muse::io::path_t(local.isEmpty() ? uri : local);\n'
    '    }\n'
    '    QJniObject jUri = QJniObject::callStaticObjectMethod(\n'
    '        "android/net/Uri", "parse", "(Ljava/lang/String;)Landroid/net/Uri;",\n'
    '        QJniObject::fromString(uri).object<jstring>());\n'
    '    QJniObject activity(QNativeInterface::QAndroidApplication::context());\n'
    '    if (!jUri.isValid() || !activity.isValid()) {\n'
    '        LOGE() << "Android save: invalid content Uri or activity context";\n'
    '        return muse::io::path_t();\n'
    '    }\n'
    '    const QString defaultName = QFileInfo(defaultPath.toQString()).fileName();\n'
    '    const QString defaultSuffix = QFileInfo(defaultPath.toQString()).suffix();\n'
    '    QString displayName = queryAndroidDisplayName(activity, jUri);\n'
    '    if (displayName.isEmpty()) {\n'
    '        displayName = defaultName.isEmpty() ? QStringLiteral("score") : defaultName;\n'
    '    }\n'
    '    if (!displayName.contains(QLatin1Char(\'.\')) && !defaultSuffix.isEmpty()) {\n'
    '        displayName += QLatin1Char(\'.\') + defaultSuffix;\n'
    '    }\n'
    '    const QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation)\n'
    '                             + QStringLiteral("/saved");\n'
    '    if (!QDir().mkpath(cacheDir)) {\n'
    '        LOGE() << "Android save: failed to create cache dir: " << cacheDir.toStdString();\n'
    '        return muse::io::path_t();\n'
    '    }\n'
    '    const QString cachePath = cacheDir + QLatin1Char(\'/\') + displayName;\n'
    '    QFile::remove(cachePath);\n'
    '    muse::io::registerAndroidSafSave(cachePath.toStdString(), uri.toStdString());\n'
    '    LOGI() << "Android save routed to cache: " << cachePath.toStdString()\n'
    '           << " -> " << uri.toStdString();\n'
    '    return muse::io::path_t(cachePath);\n'
    '}\n'
    '#endif\n'
)
if helper_anchor not in text:
    raise SystemExit(f'helper anchor not found in {interactive_cpp}')
text = text.replace(helper_anchor, helper_block, 1)

# On Android the widget QFileDialog (created with `new QFileDialog` + open())
# shows Qt's non-native file browser, which cannot reach shared storage and
# resolves to an empty path -- so File > Open silently does nothing (logged as
# "Try open project: url = ''"). Route the async selectOpeningFile through the
# native static QFileDialog::getOpenFileName (which Qt maps to the Android
# Storage Access Framework picker, ACTION_OPEN_DOCUMENT) by delegating to
# selectOpeningFileSync, which also copies the picked content:// URI into the
# app cache so the rest of the app can open it as a real file.
async_open_anchor = (
    '    return async::make_promise<io::path_t>([title, dir, filter](auto resolve, auto reject) {\n'
    '        QFileDialog* dlg = new QFileDialog(nullptr, QString::fromStdString(title), dir.toQString(), filterToString(filter));\n'
    '\n'
    '        dlg->setFileMode(QFileDialog::ExistingFile);\n'
)
async_open_new = (
    '#ifdef Q_OS_ANDROID\n'
    '    // Use AsyncByPromise (not AsyncByBody): the body below calls the blocking\n'
    '    // native SAF picker and then resolves. AsyncByBody would run the body\n'
    '    // synchronously inside the Promise constructor, i.e. before the caller has\n'
    '    // attached onResolve(), so the resolved path would be dropped and the file\n'
    '    // never opened. AsyncByPromise defers the body to the event loop so the\n'
    '    // continuation is connected before resolve() fires.\n'
    '    return async::make_promise<io::path_t>([this, title, dir, filter](auto resolve, auto reject) {\n'
    '        const io::path_t selected = selectOpeningFileSync(title, dir, filter, 0);\n'
    '        LOGI() << "Android async open resolved to: " << selected.toStdString();\n'
    '        if (selected.empty()) {\n'
    '            Ret ret = muse::make_ret(Ret::Code::Cancel);\n'
    '            (void)reject(ret.code(), ret.text());\n'
    '        } else {\n'
    '            (void)resolve(selected);\n'
    '        }\n'
    '        return async::Promise<io::path_t>::Result::unchecked();\n'
    '    }, async::PromiseType::AsyncByPromise);\n'
    '#else\n'
    '    return async::make_promise<io::path_t>([title, dir, filter](auto resolve, auto reject) {\n'
    '        QFileDialog* dlg = new QFileDialog(nullptr, QString::fromStdString(title), dir.toQString(), filterToString(filter));\n'
    '\n'
    '        dlg->setFileMode(QFileDialog::ExistingFile);\n'
)
if async_open_anchor not in text:
    raise SystemExit(f'async open dialog anchor not found in {interactive_cpp}')
text = text.replace(async_open_anchor, async_open_new, 1)

# Close the Android #ifdef/#else opened above, right before the QML #else.
async_close_anchor = (
    '        dlg->open();\n'
    '\n'
    '        return async::Promise<io::path_t>::Result::unchecked();\n'
    '    }, async::PromiseType::AsyncByBody);\n'
    '\n'
    '#else\n'
)
async_close_new = (
    '        dlg->open();\n'
    '\n'
    '        return async::Promise<io::path_t>::Result::unchecked();\n'
    '    }, async::PromiseType::AsyncByBody);\n'
    '#endif // Q_OS_ANDROID\n'
    '\n'
    '#else\n'
)
if async_close_anchor not in text:
    raise SystemExit(f'async open close anchor not found in {interactive_cpp}')
text = text.replace(async_close_anchor, async_close_new, 1)

# Route selectOpeningFileSync result through the SAF helper. Use the
# QFileDialog::getOpenFileName line plus its trailing return as a unique
# anchor (the bare "return result;" appears many times in this file).
sync_anchor = (
    '    QString result = QFileDialog::getOpenFileName(nullptr, QString::fromStdString(title), dir.toQString(), filterToString(\n'
    '                                                      filter), nullptr, qoptions);\n'
    '    return result;\n'
)
sync_new = (
    '    QString result = QFileDialog::getOpenFileName(nullptr, QString::fromStdString(title), dir.toQString(), filterToString(\n'
    '                                                      filter), nullptr, qoptions);\n'
    '#ifdef Q_OS_ANDROID\n'
    '    if (result.isEmpty()) {\n'
    '        return io::path_t();\n'
    '    }\n'
    '    const io::path_t cached = copyAndroidContentUriToCache(result);\n'
    '    if (cached.empty()) {\n'
    '        // The picker returned a document but its bytes could not be read.\n'
    '        // openInputStream typically fails here with FileNotFoundException\n'
    '        // "No content provider" -- either the cloud provider is not\n'
    '        // accessible to this app, or the file is an online-only placeholder.\n'
    '        // Tell the user instead of silently returning to the Home page.\n'
    '        const bool cloud = result.contains(QLatin1String("storageaccessprovider"))\n'
    '                           || result.contains(QLatin1String("RefreshOption"));\n'
    '        const std::string msg = cloud\n'
    '            ? std::string("MuseScore could not read this file from the cloud provider. "\n'
    '                          "If it is stored online only, open it once in your cloud app (e.g. OneDrive) "\n'
    '                          "or mark it \\"Available offline\\", then try again. "\n'
    '                          "Otherwise, try copying it to local storage and opening it from there.")\n'
    '            : std::string("MuseScore could not read the selected file. It may be unavailable or in an unsupported location.");\n'
    '        errorSync(muse::trc("project", "Could not open file"), Text(msg));\n'
    '    }\n'
    '    return cached;\n'
    '#else\n'
    '    return result;\n'
    '#endif\n'
)
if sync_anchor not in text:
    raise SystemExit(f'sync open anchor not found in {interactive_cpp}')
text = text.replace(sync_anchor, sync_new, 1)

# Route selectOpeningFilesSync results through the SAF helper.
multi_anchor = (
    '    for (const QString& path : result) {\n'
    '        paths.emplace_back(path);\n'
    '    }\n'
)
multi_new = (
    '    for (const QString& path : result) {\n'
    '#ifdef Q_OS_ANDROID\n'
    '        paths.emplace_back(copyAndroidContentUriToCache(path));\n'
    '#else\n'
    '        paths.emplace_back(path);\n'
    '#endif\n'
    '    }\n'
)
if multi_anchor not in text:
    raise SystemExit(f'multi open anchor not found in {interactive_cpp}')
text = text.replace(multi_anchor, multi_new, 1)

# Route the selectSavingFileSync result through the SAF save helper. After the
# Q_OS_LINUX gate rewrite above, Android takes the QFileDialog::getSaveFileName
# branch, which returns a SAF content:// URI. Convert that to a writable cache
# path (and register the copy-back) instead of handing a content:// URI to the
# exporter, which cannot stream into it.
save_anchor = (
    '    QString result = QFileDialog::getSaveFileName(nullptr, QString::fromStdString(title), dir.toQString(), filterToString(\n'
    '                                                      filter), nullptr, options);\n'
    '    return result;\n'
)
save_new = (
    '    QString result = QFileDialog::getSaveFileName(nullptr, QString::fromStdString(title), dir.toQString(), filterToString(\n'
    '                                                      filter), nullptr, options);\n'
    '#ifdef Q_OS_ANDROID\n'
    '    return prepareAndroidSaveUri(result, dir);\n'
    '#else\n'
    '    return result;\n'
    '#endif\n'
)
if save_anchor not in text:
    raise SystemExit(f'save anchor not found in {interactive_cpp}')
text = text.replace(save_anchor, save_new, 1)

interactive_cpp.write_text(text)

# --- Android SAF save copy-back (FileSystem) -------------------------------
#
# selectSavingFileSync (above) routes Android saves/exports to a local cache
# file and registers a cache->content:// URI mapping via
# muse::io::registerAndroidSafSave(). Here we implement that registry plus the
# actual copy-back: when the cache file's write stream is closed, stream its
# bytes to the chosen SAF document through ContentResolver.openOutputStream.
# This makes export (PDF, MIDI, MusicXML, ...) and "Save as" work for any SAF
# location (Downloads, OneDrive, Drive, ...).
filesystem_cpp = Path('muse/framework/global/io/internal/filesystem.cpp')
if not filesystem_cpp.exists():
    raise SystemExit(f'error: {filesystem_cpp} not found')

fs_text = filesystem_cpp.read_text()

fs_includes_anchor = (
    '#include "../ioretcodes.h"\n'
    '#include "log.h"\n'
    '\n'
    'using namespace muse;\n'
    'using namespace muse::io;\n'
)
fs_includes_new = (
    '#include "../ioretcodes.h"\n'
    '#include "log.h"\n'
    '\n'
    '#ifdef Q_OS_ANDROID\n'
    '#include <map>\n'
    '#include <mutex>\n'
    '#include <string>\n'
    '#include <QFile>\n'
    '#include <QCoreApplication>\n'
    '#include <QJniEnvironment>\n'
    '#include <QJniObject>\n'
    '#endif\n'
    '\n'
    'using namespace muse;\n'
    'using namespace muse::io;\n'
    '\n'
    '#ifdef Q_OS_ANDROID\n'
    'namespace muse::io {\n'
    'static std::map<std::string, std::string> s_pendingSafSaves;\n'
    'static std::mutex s_pendingSafSavesMutex;\n'
    '\n'
    '// Called from interactive.cpp (prepareAndroidSaveUri) after the SAF picker\n'
    '// returns a content:// document URI for a chosen save/export target.\n'
    'void registerAndroidSafSave(const std::string& cachePath, const std::string& contentUri)\n'
    '{\n'
    '    std::lock_guard<std::mutex> lock(s_pendingSafSavesMutex);\n'
    '    s_pendingSafSaves[cachePath] = contentUri;\n'
    '}\n'
    '\n'
    '// Stream the bytes of a freshly written cache file into the SAF document\n'
    '// using ContentResolver.openOutputStream. QFile cannot write content:// URIs.\n'
    'static bool writeCacheFileToContentUri(const QString& cachePath, const QString& contentUri)\n'
    '{\n'
    '    QFile src(cachePath);\n'
    '    if (!src.open(QIODevice::ReadOnly)) {\n'
    '        LOGE() << "SAF save: cannot open cache file: " << cachePath.toStdString();\n'
    '        return false;\n'
    '    }\n'
    '    QJniObject jUri = QJniObject::callStaticObjectMethod(\n'
    '        "android/net/Uri", "parse", "(Ljava/lang/String;)Landroid/net/Uri;",\n'
    '        QJniObject::fromString(contentUri).object<jstring>());\n'
    '    QJniObject activity(QNativeInterface::QAndroidApplication::context());\n'
    '    if (!jUri.isValid() || !activity.isValid()) {\n'
    '        LOGE() << "SAF save: invalid content Uri or activity context";\n'
    '        return false;\n'
    '    }\n'
    '    QJniEnvironment env;\n'
    '    QJniObject resolver = activity.callObjectMethod("getContentResolver", "()Landroid/content/ContentResolver;");\n'
    '    if (!resolver.isValid()) {\n'
    '        LOGE() << "SAF save: no content resolver";\n'
    '        return false;\n'
    '    }\n'
    '    QJniObject stream = resolver.callObjectMethod(\n'
    '        "openOutputStream", "(Landroid/net/Uri;Ljava/lang/String;)Ljava/io/OutputStream;",\n'
    '        jUri.object(), QJniObject::fromString(QStringLiteral("wt")).object<jstring>());\n'
    '    if (env.checkAndClearExceptions() || !stream.isValid()) {\n'
    '        stream = resolver.callObjectMethod(\n'
    '            "openOutputStream", "(Landroid/net/Uri;)Ljava/io/OutputStream;", jUri.object());\n'
    '        if (env.checkAndClearExceptions() || !stream.isValid()) {\n'
    '            LOGE() << "SAF save: openOutputStream failed for " << contentUri.toStdString();\n'
    '            return false;\n'
    '        }\n'
    '    }\n'
    '    const jint bufSize = 65536;\n'
    '    jbyteArray jbuf = env->NewByteArray(bufSize);\n'
    '    bool ok = true;\n'
    '    qint64 total = 0;\n'
    '    while (!src.atEnd()) {\n'
    '        const QByteArray chunk = src.read(bufSize);\n'
    '        if (chunk.isEmpty()) {\n'
    '            break;\n'
    '        }\n'
    '        env->SetByteArrayRegion(jbuf, 0, chunk.size(), reinterpret_cast<const jbyte*>(chunk.constData()));\n'
    '        if (env.checkAndClearExceptions()) {\n'
    '            ok = false;\n'
    '            break;\n'
    '        }\n'
    '        stream.callMethod<void>("write", "([BII)V", jbuf, jint(0), jint(chunk.size()));\n'
    '        if (env.checkAndClearExceptions()) {\n'
    '            ok = false;\n'
    '            break;\n'
    '        }\n'
    '        total += chunk.size();\n'
    '    }\n'
    '    stream.callMethod<void>("flush");\n'
    '    env.checkAndClearExceptions();\n'
    '    stream.callMethod<void>("close");\n'
    '    env.checkAndClearExceptions();\n'
    '    env->DeleteLocalRef(jbuf);\n'
    '    src.close();\n'
    '    LOGI() << "SAF save: wrote " << total << " bytes to " << contentUri.toStdString();\n'
    '    return ok && total > 0;\n'
    '}\n'
    '\n'
    '// If the just-closed cache path was registered as a SAF save target, copy\n'
    '// it back to the content:// document now.\n'
    'static void flushAndroidSafSaveIfPending(const QString& cachePath)\n'
    '{\n'
    '    const std::string key = cachePath.toStdString();\n'
    '    std::string contentUri;\n'
    '    {\n'
    '        std::lock_guard<std::mutex> lock(s_pendingSafSavesMutex);\n'
    '        auto it = s_pendingSafSaves.find(key);\n'
    '        if (it == s_pendingSafSaves.end()) {\n'
    '            return;\n'
    '        }\n'
    '        contentUri = it->second;\n'
    '    }\n'
    '    const bool ok = writeCacheFileToContentUri(cachePath, QString::fromStdString(contentUri));\n'
    '    if (!ok) {\n'
    '        LOGE() << "SAF save: failed to flush cache to content uri: " << contentUri;\n'
    '    }\n'
    '    std::lock_guard<std::mutex> lock(s_pendingSafSavesMutex);\n'
    '    s_pendingSafSaves.erase(key);\n'
    '}\n'
    '}\n'
    '#endif\n'
)
if fs_includes_anchor not in fs_text:
    raise SystemExit(f'filesystem includes anchor not found in {filesystem_cpp}')
fs_text = fs_text.replace(fs_includes_anchor, fs_includes_new, 1)

fs_close_anchor = (
    'Ret FileSystem::closeStream(StreamId fileId)\n'
    '{\n'
    '    std::lock_guard<std::mutex> lock(m_openStreamsMutex);\n'
    '\n'
    '    auto it = m_openStreams.find(fileId);\n'
    '    if (it == m_openStreams.end()) {\n'
    '        return make_ret(Err::FSWriteError);\n'
    '    }\n'
    '\n'
    '    std::unique_ptr<QFile> file = std::move(it->second);\n'
    '    m_openStreams.erase(it);\n'
    '\n'
    '    IF_ASSERT_FAILED(file) {\n'
    '        return make_ret(Err::FSWriteError);\n'
    '    }\n'
    '\n'
    '    file->close();\n'
    '    return make_ret(Err::NoError);\n'
    '}\n'
)
fs_close_new = (
    'Ret FileSystem::closeStream(StreamId fileId)\n'
    '{\n'
    '    QString closedPath;\n'
    '    {\n'
    '        std::lock_guard<std::mutex> lock(m_openStreamsMutex);\n'
    '\n'
    '        auto it = m_openStreams.find(fileId);\n'
    '        if (it == m_openStreams.end()) {\n'
    '            return make_ret(Err::FSWriteError);\n'
    '        }\n'
    '\n'
    '        std::unique_ptr<QFile> file = std::move(it->second);\n'
    '        m_openStreams.erase(it);\n'
    '\n'
    '        IF_ASSERT_FAILED(file) {\n'
    '            return make_ret(Err::FSWriteError);\n'
    '        }\n'
    '\n'
    '        closedPath = file->fileName();\n'
    '        file->close();\n'
    '    }\n'
    '\n'
    '#ifdef Q_OS_ANDROID\n'
    '    flushAndroidSafSaveIfPending(closedPath);\n'
    '#else\n'
    '    Q_UNUSED(closedPath);\n'
    '#endif\n'
    '    return make_ret(Err::NoError);\n'
    '}\n'
)
if fs_close_anchor not in fs_text:
    raise SystemExit(f'filesystem closeStream anchor not found in {filesystem_cpp}')
fs_text = fs_text.replace(fs_close_anchor, fs_close_new, 1)

filesystem_cpp.write_text(fs_text)

# --- Android audio playback support ---------------------------------------
#
# Upstream muse has no Android audio driver, only ALSA / WASAPI / CoreAudio /
# WebAudio. With ALSA excluded, AudioDriverController::createDriver returns
# nothing on Android, so playback is dead and we had to skip startAudioProcessing
# entirely.
#
# Add a QAudioSink-based driver (QtMultimedia) so the synthesizer can push
# float32 audio out to the device speakers. Qt for Android maps QAudioSink to
# AAudio/OpenSL ES under the hood, no extra permissions are required for
# audio output.

# 1. Make sure SetupQt6.cmake pulls in Qt6::Multimedia on Android.
setup_qt6_path = Path('muse/buildscripts/cmake/SetupQt6.cmake')
setup_qt6_text = setup_qt6_path.read_text()
multimedia_anchor = 'find_package(Qt6 6.8 REQUIRED COMPONENTS ${qt_components})'
multimedia_block = (
    'if (ANDROID)\n'
    '    list(APPEND qt_components Multimedia)\n'
    '    list(APPEND QT_LIBRARIES Qt::Multimedia)\n'
    'endif()\n'
    '\n'
    'find_package(Qt6 6.8 REQUIRED COMPONENTS ${qt_components})'
)
if multimedia_anchor not in setup_qt6_text:
    raise SystemExit('Multimedia anchor not found in SetupQt6.cmake')
setup_qt6_text = setup_qt6_text.replace(multimedia_anchor, multimedia_block, 1)
setup_qt6_path.write_text(setup_qt6_text)

# 2. Drop the Qt-based driver source files into muse.
android_audio_dir = Path('muse/framework/audio/driver/platform/android')
android_audio_dir.mkdir(parents=True, exist_ok=True)

qt_driver_h = '''/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-CLA-applies
 */
#pragma once

#include <memory>

#include "audio/iaudiodriver.h"
#include "global/async/asyncable.h"

class QAudioSink;
class QIODevice;

namespace muse::audio {
class QtAudioDriver : public IAudioDriver, public muse::async::Asyncable
{
public:
    QtAudioDriver();
    ~QtAudioDriver() override;

    void init() override;
    std::string name() const override;
    AudioDeviceID defaultDevice() const override;

    bool open(const Spec& spec, Spec* activeSpec) override;
    void close() override;
    bool isOpened() const override;

    const Spec& activeSpec() const override;
    async::Channel<Spec> activeSpecChanged() const override;

    std::vector<samples_t> availableOutputDeviceBufferSizes() const override;
    std::vector<sample_rate_t> availableOutputDeviceSampleRates() const override;
    AudioDeviceList availableOutputDevices() const override;
    async::Notification availableOutputDevicesChanged() const override;

private:
    class CallbackDevice;
    std::unique_ptr<QAudioSink> m_sink;
    std::unique_ptr<CallbackDevice> m_device;
    Spec m_activeSpec;
    bool m_isOpened = false;
    async::Channel<Spec> m_activeSpecChanged;
    async::Notification m_availableOutputDevicesChanged;
};
}
'''

qt_driver_cpp = r'''/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-CLA-applies
 */
#include "qtaudiodriver.h"

#include <algorithm>
#include <cstring>
#include <limits>
#include <vector>

#include <QAudioFormat>
#include <QAudioSink>
#include <QIODevice>
#include <QMediaDevices>

#include "log.h"

using namespace muse::audio;

class QtAudioDriver::CallbackDevice : public QIODevice
{
public:
    CallbackDevice(Callback cb, std::size_t frameBytes)
        : m_cb(std::move(cb)), m_buf(frameBytes), m_bufPos(frameBytes) {}

protected:
    qint64 readData(char* data, qint64 maxlen) override
    {
        if (!m_cb || maxlen <= 0) {
            if (maxlen > 0) {
                std::memset(data, 0, static_cast<std::size_t>(maxlen));
            }
            return maxlen;
        }
        qint64 written = 0;
        while (written < maxlen) {
            if (m_bufPos >= m_buf.size()) {
                m_cb(m_buf.data(), static_cast<int>(m_buf.size()));
                m_bufPos = 0;
            }
            const qint64 toCopy = std::min<qint64>(
                maxlen - written, static_cast<qint64>(m_buf.size() - m_bufPos));
            std::memcpy(data + written, m_buf.data() + m_bufPos,
                        static_cast<std::size_t>(toCopy));
            m_bufPos += static_cast<std::size_t>(toCopy);
            written += toCopy;
        }
        return written;
    }
    qint64 writeData(const char*, qint64) override { return 0; }
    qint64 bytesAvailable() const override
    {
        return std::numeric_limits<qint64>::max() / 2;
    }

private:
    Callback m_cb;
    std::vector<std::uint8_t> m_buf;
    std::size_t m_bufPos;
};

QtAudioDriver::QtAudioDriver() = default;
QtAudioDriver::~QtAudioDriver() { close(); }

void QtAudioDriver::init() {}

std::string QtAudioDriver::name() const { return "QtAudio"; }

AudioDeviceID QtAudioDriver::defaultDevice() const { return "default"; }

bool QtAudioDriver::open(const Spec& spec, Spec* activeSpec)
{
    if (m_isOpened) {
        close();
    }
    if (!spec.isValid()) {
        LOGE() << "QtAudioDriver: invalid spec";
        return false;
    }

    QAudioFormat format;
    format.setSampleRate(static_cast<int>(spec.output.sampleRate));
    format.setChannelCount(static_cast<int>(spec.output.audioChannelCount));
    format.setSampleFormat(QAudioFormat::Float);

    const QAudioDevice device = QMediaDevices::defaultAudioOutput();
    if (!device.isFormatSupported(format)) {
        LOGW() << "QtAudioDriver: float format not natively supported, Qt will resample";
    }

    const std::size_t frameBytes
        = static_cast<std::size_t>(spec.output.samplesPerChannel)
          * static_cast<std::size_t>(spec.output.audioChannelCount)
          * sizeof(float);

    m_device = std::make_unique<CallbackDevice>(spec.callback, frameBytes);
    m_device->open(QIODevice::ReadOnly);

    m_sink = std::make_unique<QAudioSink>(device, format);
    // Give Qt ~4 audio frames of buffering. Too small => underruns / stutter.
    m_sink->setBufferSize(static_cast<int>(frameBytes) * 4);
    m_sink->start(m_device.get());

    m_activeSpec = spec;
    m_isOpened = true;
    if (activeSpec) {
        *activeSpec = spec;
    }
    LOGI() << "QtAudioDriver: opened sampleRate=" << spec.output.sampleRate
           << " channels=" << static_cast<int>(spec.output.audioChannelCount)
           << " samplesPerChannel=" << spec.output.samplesPerChannel;
    return true;
}

void QtAudioDriver::close()
{
    if (m_sink) {
        m_sink->stop();
        m_sink.reset();
    }
    if (m_device) {
        m_device->close();
        m_device.reset();
    }
    m_isOpened = false;
}

bool QtAudioDriver::isOpened() const { return m_isOpened; }

const IAudioDriver::Spec& QtAudioDriver::activeSpec() const { return m_activeSpec; }

muse::async::Channel<IAudioDriver::Spec> QtAudioDriver::activeSpecChanged() const
{
    return m_activeSpecChanged;
}

std::vector<muse::audio::samples_t> QtAudioDriver::availableOutputDeviceBufferSizes() const
{
    return { 256, 512, 1024, 2048, 4096 };
}

std::vector<muse::audio::sample_rate_t> QtAudioDriver::availableOutputDeviceSampleRates() const
{
    return { 44100, 48000 };
}

muse::audio::AudioDeviceList QtAudioDriver::availableOutputDevices() const
{
    AudioDevice d;
    d.id = "default";
    d.name = "Default";
    return { d };
}

muse::async::Notification QtAudioDriver::availableOutputDevicesChanged() const
{
    return m_availableOutputDevicesChanged;
}
'''

(android_audio_dir / 'qtaudiodriver.h').write_text(qt_driver_h)
(android_audio_dir / 'qtaudiodriver.cpp').write_text(qt_driver_cpp)

# 3. Patch the audio driver CMakeLists to compile the Android driver and
# link Qt6::Multimedia.
driver_cmake = Path('muse/framework/audio/driver/CMakeLists.txt')
driver_cmake_text = driver_cmake.read_text()
driver_cmake_anchor = 'target_link_libraries(muse_audio_driver PRIVATE muse_audio_common)'
driver_cmake_block = (
    'if (ANDROID)\n'
    '    target_sources(muse_audio_driver PRIVATE\n'
    '        platform/android/qtaudiodriver.cpp\n'
    '        platform/android/qtaudiodriver.h\n'
    '    )\n'
    '    target_link_libraries(muse_audio_driver PRIVATE Qt6::Multimedia)\n'
    'endif()\n'
    '\n'
    'target_link_libraries(muse_audio_driver PRIVATE muse_audio_common)'
)
if driver_cmake_anchor not in driver_cmake_text:
    raise SystemExit('audio driver CMakeLists anchor not found')
driver_cmake_text = driver_cmake_text.replace(driver_cmake_anchor, driver_cmake_block, 1)
driver_cmake.write_text(driver_cmake_text)

# 4. Wire the new driver into AudioDriverController. Without an Android branch
# both createDriver() and availableAudioDrivers() fall through to nothing on
# Android (since ALSA is gated out above), which leaves the engine with no
# output device.
controller_path = Path('muse/framework/audio/main/internal/audiodrivercontroller.cpp')
controller_text = controller_path.read_text()

controller_include_anchor = '#include "audiodrivercontroller.h"\n'
controller_include_new = (
    '#include "audiodrivercontroller.h"\n'
    '\n'
    '#ifdef Q_OS_ANDROID\n'
    '#include "audio/driver/platform/android/qtaudiodriver.h"\n'
    '#endif\n'
)
if controller_include_anchor not in controller_text:
    raise SystemExit('audiodrivercontroller include anchor not found')
controller_text = controller_text.replace(controller_include_anchor, controller_include_new, 1)

controller_create_anchor = ('IAudioDriverPtr AudioDriverController::createDriver'
                            '(const std::string& name) const\n{\n')
controller_create_new = (
    controller_create_anchor
    + '#ifdef Q_OS_ANDROID\n'
    + '    UNUSED(name);\n'
    + '    return std::shared_ptr<IAudioDriver>(new QtAudioDriver());\n'
    + '#endif\n'
)
if controller_create_anchor not in controller_text:
    raise SystemExit('audiodrivercontroller createDriver anchor not found')
controller_text = controller_text.replace(controller_create_anchor, controller_create_new, 1)

controller_avail_anchor = ('std::vector<std::string> AudioDriverController::'
                           'availableAudioDrivers() const\n{\n'
                           '    std::vector<std::string> names;\n')
controller_avail_new = (
    controller_avail_anchor
    + '#ifdef Q_OS_ANDROID\n'
    + '    names.push_back("QtAudio");\n'
    + '    return names;\n'
    + '#endif\n'
)
if controller_avail_anchor not in controller_text:
    raise SystemExit('audiodrivercontroller availableAudioDrivers anchor not found')
controller_text = controller_text.replace(controller_avail_anchor, controller_avail_new, 1)

controller_path.write_text(controller_text)
PY

