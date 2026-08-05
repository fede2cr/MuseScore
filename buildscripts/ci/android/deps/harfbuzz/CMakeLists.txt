# SPDX-License-Identifier: GPL-3.0-only
# MuseScore-Studio-CLA-applies
#
# MuseScore Studio
# Music Composition & Notation
#
# Copyright (C) 2026 MuseScore Limited
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

# Build wrapper for the harfbuzz sources seeded by seed_muse_deps.sh.
# muse/framework/draw/cmake/SetupHarfBuzz.cmake add_subdirectory()s this file.

muse_create_thirdparty_module(harfbuzz)

target_sources(harfbuzz PRIVATE
    harfbuzz/src/harfbuzz.cc
)

target_include_directories(harfbuzz PRIVATE ${FREETYPE_INCLUDE_DIRS})

target_compile_definitions(harfbuzz PRIVATE HAVE_FREETYPE)

target_no_warning(harfbuzz -Wno-truncate)
target_no_warning(harfbuzz -Wno-uninitialized)
