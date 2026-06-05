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
            '    find_package(ALSA REQUIRED)\n    target_link_libraries(muse_audio_driver PRIVATE ALSA::ALSA pthread)\n',
            '    if (NOT ANDROID)\n        find_package(ALSA REQUIRED)\n        target_link_libraries(muse_audio_driver PRIVATE ALSA::ALSA pthread)\n    endif()\n',
        ),
    ],
    'muse/framework/midi/CMakeLists.txt': [
        (
            '    find_package(ALSA REQUIRED)\n    target_include_directories(muse_midi PRIVATE ${ALSA_INCLUDE_DIRS})\n    target_link_libraries(muse_midi PRIVATE ${ALSA_LIBRARIES} pthread)\n',
            '    if (NOT ANDROID)\n        find_package(ALSA REQUIRED)\n        target_include_directories(muse_midi PRIVATE ${ALSA_INCLUDE_DIRS})\n        target_link_libraries(muse_midi PRIVATE ${ALSA_LIBRARIES} pthread)\n    endif()\n',
        ),
    ],
    'muse/framework/ui/CMakeLists.txt': [
        (
            '    if (OS_IS_LIN)\n        target_link_libraries(muse_ui PRIVATE Qt::DBus)\n    endif()\n',
            '    if (NOT ANDROID && OS_IS_LIN)\n        target_link_libraries(muse_ui PRIVATE Qt::DBus)\n    endif()\n',
        ),
    ],
}.items():
    target = Path(relative_path)
    if not target.exists():
        raise SystemExit(f'error: {relative_path} not found')

    contents = target.read_text()
    for old, new in replacements:
        if old not in contents:
            raise SystemExit(f'expected ALSA block not found in {relative_path}')
        contents = contents.replace(old, new, 1)
    target.write_text(contents)
PY
