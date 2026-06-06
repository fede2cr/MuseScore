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
            '#include "audioconfiguration.h"\n\n//TODO: remove with global clearing of Q_OS_*** defines\n#include <QtGlobal>\n\n#ifdef Q_OS_ANDROID\n#include <QStandardPaths>\n#endif\n',
        ),
        (
            'io::paths_t AudioConfiguration::soundFontDirectories() const\n{\n    io::paths_t paths = userSoundFontDirectories();\n    paths.push_back(globalConfiguration()->appDataPath());\n\n    return paths;\n}\n',
            'io::paths_t AudioConfiguration::soundFontDirectories() const\n{\n    io::paths_t paths = userSoundFontDirectories();\n    paths.push_back(globalConfiguration()->appDataPath());\n\n#ifdef Q_OS_ANDROID\n    paths.push_back(io::path_t(QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation) + QStringLiteral("/sound")));\n#endif\n\n    return paths;\n}\n',
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

