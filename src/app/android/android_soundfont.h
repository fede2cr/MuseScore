#pragma once

namespace mu::app {

#ifdef Q_OS_ANDROID
// Extract the bundled MS Basic soundfont from Qt resources to the app's
// writable data directory on first launch so the soundfont controller can
// scan it. No-op if the extracted copy already exists with the same size.
void extractBundledSoundfont();
#endif

} // namespace mu::app
