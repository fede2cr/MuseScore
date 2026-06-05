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
            '#if !defined(Q_OS_WASM) && !defined(Q_OS_ANDROID)\n    m_startAudioController->startAudioProcessing(mode);\n#endif\n',
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
    'static muse::io::path_t copyAndroidContentUriToCache(const QString& uri)\n'
    '{\n'
    '    if (!uri.startsWith(QLatin1String("content://"))) {\n'
    '        return muse::io::path_t(uri);\n'
    '    }\n'
    '    QString displayName = QFileInfo(uri).fileName();\n'
    '    if (displayName.isEmpty()) {\n'
    '        displayName = QStringLiteral("opened_file");\n'
    '    }\n'
    '    QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation)\n'
    '                       + QStringLiteral("/opened");\n'
    '    QDir().mkpath(cacheDir);\n'
    '    QString cachePath = cacheDir + QLatin1Char(\'/\') + displayName;\n'
    '    QFile src(uri);\n'
    '    QFile dst(cachePath);\n'
    '    if (!src.open(QIODevice::ReadOnly) || !dst.open(QIODevice::WriteOnly | QIODevice::Truncate)) {\n'
    '        return muse::io::path_t();\n'
    '    }\n'
    '    dst.write(src.readAll());\n'
    '    return muse::io::path_t(cachePath);\n'
    '}\n'
    '#endif\n'
)
if helper_anchor not in text:
    raise SystemExit(f'helper anchor not found in {interactive_cpp}')
text = text.replace(helper_anchor, helper_block, 1)

# Route the async selectOpeningFile result through the SAF helper on Android.
async_anchor = '            QString file = files.first();\n            (void)resolve(file);\n'
async_new = (
    '            QString file = files.first();\n'
    '#ifdef Q_OS_ANDROID\n'
    '            (void)resolve(copyAndroidContentUriToCache(file));\n'
    '#else\n'
    '            (void)resolve(file);\n'
    '#endif\n'
)
if async_anchor not in text:
    raise SystemExit(f'async open anchor not found in {interactive_cpp}')
text = text.replace(async_anchor, async_new, 1)

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
    '    return copyAndroidContentUriToCache(result);\n'
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

interactive_cpp.write_text(text)
PY

