/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-Studio-CLA-applies
 *
 * MuseScore Studio
 * Music Composition & Notation
 *
 * Copyright (C) 2021 MuseScore Limited and others
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */
#include "applicationactioncontroller.h"

#include <QApplication>
#include <QCloseEvent>
#include <QDragEnterEvent>
#include <QDragMoveEvent>
#include <QDropEvent>
#include <QFileOpenEvent>
#include <QWindow>
#include <QMimeData>

#ifdef Q_OS_ANDROID
#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QJniEnvironment>
#include <QStandardPaths>
#include <QUrl>
#include <QJniObject>
#endif

#include "async/async.h"
#include "audio/common/soundfonttypes.h"

#include "defer.h"
#include "translation.h"
#include "log.h"

using namespace mu::appshell;
using namespace muse;
using namespace muse::actions;

void ApplicationActionController::preInit()
{
    qApp->installEventFilter(this);
}

void ApplicationActionController::init()
{
    dispatcher()->reg(this, "quit", [this](const ActionData& args) {
        bool isAllInstances = args.count() > 0 ? args.arg<bool>(0) : true;
        muse::io::path_t installatorPath = args.count() > 1 ? args.arg<muse::io::path_t>(1) : "";
        quit(isAllInstances, installatorPath);
    });

    dispatcher()->reg(this, "restart", [this]() {
        restart();
    });

    dispatcher()->reg(this, "fullscreen", this, &ApplicationActionController::toggleFullScreen);

    dispatcher()->reg(this, "about-musescore", this, &ApplicationActionController::openAboutDialog);
    dispatcher()->reg(this, "about-qt", this, &ApplicationActionController::openAboutQtDialog);
    dispatcher()->reg(this, "about-musicxml", this, &ApplicationActionController::openAboutMusicXMLDialog);
    dispatcher()->reg(this, "online-handbook", this, &ApplicationActionController::openOnlineHandbookPage);
    dispatcher()->reg(this, "ask-help", this, &ApplicationActionController::openAskForHelpPage);
    dispatcher()->reg(this, "accessibility-statement", this, &ApplicationActionController::openAccessibilityStatementPage);
    dispatcher()->reg(this, "preference-dialog", this, &ApplicationActionController::openPreferencesDialog);

    dispatcher()->reg(this, "revert-factory", this, &ApplicationActionController::revertToFactorySettings);

    dispatcher()->reg(this, "manage-plugins", [this]() {
        interactive()->open("musescore://home?section=plugins");
    });

    // Global actions
    dispatcher()->reg(this, "action://copy", this, &ApplicationActionController::doGlobalCopy);
    dispatcher()->reg(this, "action://cut", this, &ApplicationActionController::doGlobalCut);
    dispatcher()->reg(this, "action://paste", this, &ApplicationActionController::doGlobalPaste);
    dispatcher()->reg(this, "action://undo", this, &ApplicationActionController::doGlobalUndo);
    dispatcher()->reg(this, "action://redo", this, &ApplicationActionController::doGlobalRedo);
    dispatcher()->reg(this, "action://delete", this, &ApplicationActionController::doGlobalDelete);
    dispatcher()->reg(this, "action://cancel", this, &ApplicationActionController::doGlobalCancel);

#ifdef Q_OS_ANDROID
    openAndroidLaunchFileIfAny();
#endif
}

bool ApplicationActionController::eventFilter(QObject* watched, QEvent* event)
{
    if ((event->type() == QEvent::Close && watched == qWindow())
        || event->type() == QEvent::Quit) {
        bool accepted = quit(false);
        event->setAccepted(accepted);

        return true;
    }

    if (watched == qApp) {
        if (event->type() == QEvent::FileOpen) {
            const QFileOpenEvent* openEvent = static_cast<const QFileOpenEvent*>(event);
            const QUrl url = openEvent->url();

            if (projectFilesController()->isUrlSupported(url)) {
                if (startupScenario()->startupCompleted()) {
                    dispatcher()->dispatch("file-open", ActionData::make_arg1<QUrl>(url));
                } else {
                    startupScenario()->setStartupScoreFile(project::ProjectFile { url });
                }

                return true;
            }
        }
    }

    if (watched == qWindow()) {
        if (event->type() == QEvent::DragEnter) {
            if (onDragEnterEvent(static_cast<QDragEnterEvent*>(event))) {
                return true;
            }
        } else if (event->type() == QEvent::DragMove) {
            if (onDragMoveEvent(static_cast<QDragMoveEvent*>(event))) {
                return true;
            }
        } else if (event->type() == QEvent::Drop) {
            if (onDropEvent(static_cast<QDropEvent*>(event))) {
                return true;
            }
        }
    }

    return QObject::eventFilter(watched, event);
}

#ifdef Q_OS_ANDROID
void ApplicationActionController::openAndroidLaunchFileIfAny()
{
    const QString path = consumeAndroidLaunchFile();
    if (path.isEmpty()) {
        return;
    }

    const QUrl url = QUrl::fromLocalFile(path);
    if (!projectFilesController()->isUrlSupported(url)) {
        LOGW() << "Android launch file is not a supported score: " << url.toString();
        return;
    }

    if (startupScenario()->startupCompleted()) {
        dispatcher()->dispatch("file-open", ActionData::make_arg1<QUrl>(url));
    } else {
        startupScenario()->setStartupScoreFile(project::ProjectFile { url });
    }

    LOGI() << "Android launch file scheduled to open: " << url.toString();
}

QString ApplicationActionController::consumeAndroidLaunchFile()
{
    // On Android, files opened from another app (file manager, OneDrive, etc.)
    // arrive as an ACTION_VIEW/ACTION_EDIT Intent on the Activity rather than as
    // a QFileOpenEvent. Read that Intent here and copy the referenced content://
    // document into our cache so the rest of the app can open it as a local file.
    QJniObject activity(QNativeInterface::QAndroidApplication::context());
    if (!activity.isValid()) {
        return QString();
    }

    QJniObject intent = activity.callObjectMethod("getIntent", "()Landroid/content/Intent;");
    if (!intent.isValid()) {
        return QString();
    }

    QJniObject actionObj = intent.callObjectMethod("getAction", "()Ljava/lang/String;");
    const QString action = actionObj.isValid() ? actionObj.toString() : QString();
    if (action != QLatin1String("android.intent.action.VIEW")
        && action != QLatin1String("android.intent.action.EDIT")) {
        return QString();
    }

    QJniObject uri = intent.callObjectMethod("getData", "()Landroid/net/Uri;");
    if (!uri.isValid()) {
        return QString();
    }

    QJniObject schemeObj = uri.callObjectMethod("getScheme", "()Ljava/lang/String;");
    const QString scheme = schemeObj.isValid() ? schemeObj.toString() : QString();
    const QString uriStr = uri.callObjectMethod("toString", "()Ljava/lang/String;").toString();

    // Avoid re-opening the same file when the Activity is later resumed.
    intent.callObjectMethod("setData", "(Landroid/net/Uri;)Landroid/content/Intent;",
                            static_cast<jobject>(nullptr));

    if (scheme == QLatin1String("file")) {
        return QUrl(uriStr).toLocalFile();
    }

    if (scheme != QLatin1String("content")) {
        return QString();
    }

    // Resolve the human-readable display name (including extension) via the
    // ContentResolver, so type detection by extension keeps working.
    QString displayName;
    QJniObject resolver = activity.callObjectMethod("getContentResolver", "()Landroid/content/ContentResolver;");
    if (resolver.isValid()) {
        QJniObject cursor = resolver.callObjectMethod(
            "query",
            "(Landroid/net/Uri;[Ljava/lang/String;Ljava/lang/String;[Ljava/lang/String;Ljava/lang/String;)Landroid/database/Cursor;",
            uri.object(), nullptr, nullptr, nullptr, nullptr);
        if (cursor.isValid()) {
            if (cursor.callMethod<jboolean>("moveToFirst")) {
                QJniObject column = QJniObject::fromString(QStringLiteral("_display_name"));
                const jint index = cursor.callMethod<jint>("getColumnIndex", "(Ljava/lang/String;)I", column.object());
                if (index >= 0) {
                    QJniObject nameObj = cursor.callObjectMethod("getString", "(I)Ljava/lang/String;", index);
                    if (nameObj.isValid()) {
                        displayName = nameObj.toString();
                    }
                }
            }
            cursor.callMethod<void>("close");
        }
    }

    if (displayName.isEmpty()) {
        // Fall back to the last path segment of the URI, which for some providers
        // (e.g. the OneDrive .external provider) carries the real file name.
        const QString decodedPath = QUrl::fromPercentEncoding(uriStr.toUtf8());
        const int slash = decodedPath.lastIndexOf(QLatin1Char('/'));
        QString candidate = slash >= 0 ? decodedPath.mid(slash + 1) : QString();
        const int query = candidate.indexOf(QLatin1Char('?'));
        if (query >= 0) {
            candidate = candidate.left(query);
        }
        if (candidate.contains(QLatin1Char('.'))) {
            displayName = candidate;
        }
    }

    if (displayName.isEmpty()) {
        displayName = QStringLiteral("opened_score.mscz");
    }

    const QString destDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
                            + QStringLiteral("/opened");
    if (!QDir().mkpath(destDir)) {
        LOGE() << "Failed to create cache directory for opened file: " << destDir;
        return QString();
    }

    const QString destPath = destDir + QLatin1Char('/') + displayName;

    // QFile cannot open SAF content:// URIs (e.g. OneDrive providers); read the
    // document through ContentResolver.openInputStream via JNI instead.
    if (!resolver.isValid()) {
        LOGE() << "No content resolver available for launch uri: " << uriStr;
        return QString();
    }

    QJniEnvironment env;
    QJniObject stream = resolver.callObjectMethod(
        "openInputStream", "(Landroid/net/Uri;)Ljava/io/InputStream;", uri.object());
    if (env.checkAndClearExceptions() || !stream.isValid()) {
        LOGE() << "Failed to open launch content uri: " << uriStr;
        return QString();
    }

    QFile dst(destPath);
    if (!dst.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        LOGE() << "Failed to create cache copy of launch file: " << destPath;
        stream.callMethod<void>("close");
        env.checkAndClearExceptions();
        return QString();
    }

    const jint bufSize = 65536;
    jbyteArray jbuf = env->NewByteArray(bufSize);
    bool ok = true;
    qint64 total = 0;
    for (;;) {
        const jint n = stream.callMethod<jint>("read", "([B)I", jbuf);
        if (env.checkAndClearExceptions()) {
            ok = false;
            break;
        }
        if (n < 0) {
            break;
        }
        if (n > 0) {
            QByteArray chunk(n, Qt::Uninitialized);
            env->GetByteArrayRegion(jbuf, 0, n, reinterpret_cast<jbyte*>(chunk.data()));
            if (dst.write(chunk) != n) {
                ok = false;
                break;
            }
            total += n;
        }
    }
    env->DeleteLocalRef(jbuf);
    stream.callMethod<void>("close");
    env.checkAndClearExceptions();
    dst.close();

    if (!ok || total <= 0) {
        LOGE() << "Failed to read launch content uri into cache: " << uriStr;
        return QString();
    }

    LOGI() << "Copied Android launch file to cache (" << total << " bytes): " << destPath;
    return destPath;
}
#endif // Q_OS_ANDROID

QWindow* ApplicationActionController::qWindow() const
{
    return mainWindow() ? mainWindow()->qWindow() : nullptr;
}

ApplicationActionController::DragTarget ApplicationActionController::dragTarget(const QUrl& url) const
{
    if (projectFilesController()->isUrlSupported(url)) {
        return DragTarget::ProjectFile;
    } else if (url.isLocalFile()) {
        muse::io::path_t filePath = url.toLocalFile();
        if (muse::audio::synth::isSoundFont(filePath)) {
            return DragTarget::SoundFont;
        } else if (extensionInstaller()->isFileSupported(filePath)) {
            return DragTarget::Extension;
        }
    }
    return DragTarget::Unknown;
}

bool ApplicationActionController::onDragEnterEvent(QDragEnterEvent* event)
{
    return onDragMoveEvent(event);
}

bool ApplicationActionController::onDragMoveEvent(QDragMoveEvent* event)
{
    const QMimeData* mime = event->mimeData();
    QList<QUrl> urls = mime->urls();
    if (urls.count() > 0) {
        const QUrl& url = urls.front();
        DragTarget target = dragTarget(url);
        if (target != DragTarget::Unknown) {
            event->setDropAction(Qt::LinkAction);
            event->acceptProposedAction();
            return true;
        }
    }

    return false;
}

bool ApplicationActionController::onDropEvent(QDropEvent* event)
{
    const QMimeData* mime = event->mimeData();
    QList<QUrl> urls = mime->urls();
    if (urls.count() > 0) {
        const QUrl& url = urls.front();

        bool shouldBeHandled = true;
        DragTarget target = dragTarget(url);
        switch (target) {
        case DragTarget::ProjectFile: {
            async::Async::call(this, [this, url]() {
                    Ret ret = projectFilesController()->openProject(url);
                    if (!ret) {
                        LOGE() << ret.toString();
                    }
                });
        } break;
        case DragTarget::SoundFont: {
            muse::io::path_t filePath = url.toLocalFile();
            async::Async::call(this, [this, filePath]() {
                    soundFontInstallScenario()->installSoundFont(Uri::fromLocalFile(filePath));
                });
        } break;
        case DragTarget::Extension: {
            muse::io::path_t filePath = url.toLocalFile();
            async::Async::call(this, [this, filePath]() {
                    extensionInstaller()->installExtension(filePath);
                });
        } break;
        case DragTarget::Unknown:
            shouldBeHandled = false;
            break;
        }

        if (shouldBeHandled) {
            event->accept();
        } else {
            event->ignore();
        }

        return shouldBeHandled;
    }

    return false;
}

bool ApplicationActionController::quit(bool isAllInstances, const muse::io::path_t& installerPath)
{
    if (m_quiting) {
        return false;
    }

    m_quiting = true;
    DEFER {
        m_quiting = false;
    };

    if (!projectFilesController()->closeOpenedProject(false)) {
        return false;
    }

    if (multiwindowsProvider()->isFirstWindow() && !installerPath.empty()) {
#if defined(Q_OS_LINUX)
        platformInteractive()->revealInFileBrowser(installerPath);
#else
        platformInteractive()->openUrl(QUrl::fromLocalFile(installerPath.toQString()));
#endif
    }

    if (!multiwindowsProvider()->isFirstWindow()) {
        multiwindowsProvider()->notifyAboutWindowWasQuited();
    }

    if (isAllInstances) {
        multiwindowsProvider()->quitForAll();
    } else {
        multiwindowsProvider()->quitWindow(iocContext());
    }

    return true;
}

void ApplicationActionController::restart()
{
    if (projectFilesController()->closeOpenedProject(false)) {
        if (multiwindowsProvider()->windowCount() == 1) {
            application()->restart();
        } else {
            multiwindowsProvider()->quitAllAndRestartLast();

            QCoreApplication::exit();
        }
    }
}

void ApplicationActionController::toggleFullScreen()
{
    mainWindow()->toggleFullScreen();
}

void ApplicationActionController::openAboutDialog()
{
    interactive()->open("musescore://about/musescore");
}

void ApplicationActionController::openAboutQtDialog()
{
    QApplication::aboutQt();
}

void ApplicationActionController::openAboutMusicXMLDialog()
{
    interactive()->open("musescore://about/musicxml");
}

void ApplicationActionController::openOnlineHandbookPage()
{
    std::string handbookUrl = configuration()->handbookUrl();
    platformInteractive()->openUrl(handbookUrl);
}

void ApplicationActionController::openAskForHelpPage()
{
    std::string askForHelpUrl = configuration()->askForHelpUrl();
    platformInteractive()->openUrl(askForHelpUrl);
}

void ApplicationActionController::openAccessibilityStatementPage()
{
    std::string accessibilityStatementUrl = configuration()->accessibilityStatementUrl();
    platformInteractive()->openUrl(accessibilityStatementUrl);
}

void ApplicationActionController::openPreferencesDialog()
{
    const context::IPlaybackStatePtr state = globalContext()->playbackState();
    if (state->playbackStatus() == audio::PlaybackStatus::Running) {
        dispatcher()->dispatch("stop");

        async::Channel<audio::PlaybackStatus> statusChanged = state->playbackStatusChanged();
        statusChanged.onReceive(this, [statusChanged, this](audio::PlaybackStatus) {
            auto statusChangedMut = statusChanged;
            statusChangedMut.disconnect(this);
            doOpenPreferencesDialog();
        });

        return;
    }

    doOpenPreferencesDialog();
}

void ApplicationActionController::doOpenPreferencesDialog()
{
    if (multiwindowsProvider()->isPreferencesAlreadyOpened()) {
        multiwindowsProvider()->activateWindowWithOpenedPreferences();
        return;
    }

    interactive()->open("muse://preferences");
}

void ApplicationActionController::revertToFactorySettings()
{
    std::string title = muse::trc("appshell", "Are you sure you want to revert to factory settings?");
    std::string question = muse::trc("appshell", "This action will reset all your app preferences and delete all custom palettes and custom shortcuts. "
                                                 "The list of recent scores will also be cleared.\n\n"
                                                 "This action will not delete any of your scores.");

    IInteractive::ButtonData cancelBtn = interactive()->buttonData(IInteractive::Button::Cancel);
    cancelBtn.accent = true;

    int revertBtn = int(IInteractive::Button::Apply);
    auto promise = interactive()->warning(title, question,
                                          { cancelBtn,
                                            IInteractive::ButtonData(revertBtn, muse::trc("appshell", "Revert")) },
                                          cancelBtn.btn, { muse::IInteractive::Option::WithIcon },
                                          muse::trc("appshell", "Revert to factory settings"));

    promise.onResolve(this, [this](const IInteractive::Result& res) {
        if (res.isButton(IInteractive::Button::Cancel)) {
            return;
        }

        static constexpr bool KEEP_DEFAULT_SETTINGS = false;
        static constexpr bool NOTIFY_ABOUT_CHANGES = false;
        static constexpr bool NOTIFY_OTHER_INSTANCES = false;
        configuration()->revertToFactorySettings(KEEP_DEFAULT_SETTINGS, NOTIFY_ABOUT_CHANGES, NOTIFY_OTHER_INSTANCES);

        std::string title = muse::trc("appshell", "Would you like to restart MuseScore Studio now?");
        std::string question = muse::trc("appshell", "MuseScore Studio needs to be restarted for these changes to take effect.");

        int restartBtn = int(IInteractive::Button::Apply);
        auto promise = interactive()->question(title, question,
                                               { interactive()->buttonData(IInteractive::Button::Cancel),
                                                 IInteractive::ButtonData(restartBtn, muse::trc("appshell", "Restart"), true) },
                                               restartBtn);

        promise.onResolve(this, [this](const IInteractive::Result& res) {
            if (!res.isButton(IInteractive::Button::Cancel)) {
                restart();
            }
        });
    });
}

bool ApplicationActionController::hasProjectAndIsFocused() const
{
    bool hasProject = globalContext()->currentProject() != nullptr;
    bool isFocused = uiContextResolver()->currentUiContext() == context::UiCtxProjectFocused;
    return hasProject && isFocused;
}

void ApplicationActionController::doGlobalCopy()
{
    if (hasProjectAndIsFocused()) {
        dispatcher()->dispatch("action://notation/copy");
    } else {
        // resolve other actions
    }
}

void ApplicationActionController::doGlobalCut()
{
    if (hasProjectAndIsFocused()) {
        dispatcher()->dispatch("action://notation/cut");
    } else {
        // resolve other actions
    }
}

void ApplicationActionController::doGlobalPaste()
{
    if (hasProjectAndIsFocused()) {
        dispatcher()->dispatch("action://notation/paste");
    } else {
        // resolve other actions
    }
}

void ApplicationActionController::doGlobalUndo()
{
    if (hasProjectAndIsFocused()) {
        dispatcher()->dispatch("action://notation/undo");
    } else {
        // resolve other actions
    }
}

void ApplicationActionController::doGlobalRedo()
{
    if (hasProjectAndIsFocused()) {
        dispatcher()->dispatch("action://notation/redo");
    } else {
        // resolve other actions
    }
}

void ApplicationActionController::doGlobalDelete()
{
    if (hasProjectAndIsFocused()) {
        dispatcher()->dispatch("action://notation/delete");
    } else {
        // resolve other actions
    }
}

void ApplicationActionController::doGlobalCancel()
{
    if (hasProjectAndIsFocused()) {
        dispatcher()->dispatch("action://notation/cancel");
    } else {
        dispatcher()->dispatch("nav-escape");
    }
}
