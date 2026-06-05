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

updated, count = re.subn(
    r'(find_package\(\s*Qt6\b[\s\S]*?\bCOMPONENTS\b[\s\S]*?)\bDBus\b',
    r'\1',
    text,
    count=1,
)

if count == 0:
    updated, count = re.subn(
        r'^\s*list\(APPEND\s+qt_components\s+DBus\)\s*$\n?',
        '',
        text,
        flags=re.M,
    )

assert count != 0, 'expected DBus component declaration not found in SetupQt6.cmake'

path.write_text(updated)
PY
