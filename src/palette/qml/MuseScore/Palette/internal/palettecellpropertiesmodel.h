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

#pragma once

#include <QObject>
#include <qqmlintegration.h>

#include "modularity/ioc.h"

#include "ipaletteconfiguration.h"

namespace mu::palette {
class PaletteCellPropertiesModel : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString name READ name WRITE setName NOTIFY propertiesChanged)
    Q_PROPERTY(double xOffset READ xOffset WRITE setXOffset NOTIFY propertiesChanged)
    Q_PROPERTY(double yOffset READ yOffset WRITE setYOffset NOTIFY propertiesChanged)
    Q_PROPERTY(double scaleFactor READ scaleFactor WRITE setScaleFactor NOTIFY propertiesChanged)
    Q_PROPERTY(bool drawStaff READ drawStaff WRITE setDrawStaff NOTIFY propertiesChanged)
    Q_PROPERTY(bool isBassline READ isBassline NOTIFY propertiesChanged)
    Q_PROPERTY(int basslinePattern READ basslinePattern WRITE setBasslinePattern NOTIFY propertiesChanged)
    Q_PROPERTY(int transitionPattern READ transitionPattern WRITE setTransitionPattern NOTIFY propertiesChanged)
    Q_PROPERTY(QString customBassline READ customBassline WRITE setCustomBassline NOTIFY propertiesChanged)
    Q_PROPERTY(QString customTransition READ customTransition WRITE setCustomTransition NOTIFY propertiesChanged)

    QML_ELEMENT

    muse::GlobalInject<IPaletteConfiguration> configuration;

public:
    QString name() const;
    double xOffset() const;
    double yOffset() const;
    double scaleFactor() const;
    bool drawStaff() const;
    bool isBassline() const;
    int basslinePattern() const;
    int transitionPattern() const;
    QString customBassline() const;
    QString customTransition() const;

    Q_INVOKABLE void load(const QVariant& properties);
    Q_INVOKABLE void reject();

public slots:
    void setName(const QString& name);
    void setXOffset(double xOffset);
    void setYOffset(double yOffset);
    void setScaleFactor(double scale);
    void setDrawStaff(bool drawStaff);
    void setBasslinePattern(int pattern);
    void setTransitionPattern(int pattern);
    void setCustomBassline(const QString& pattern);
    void setCustomTransition(const QString& pattern);

signals:
    void propertiesChanged();

private:
    void setConfig(const IPaletteConfiguration::PaletteCellConfig& config);

    QString m_cellId;
    IPaletteConfiguration::PaletteCellConfig m_currentConfig;
    IPaletteConfiguration::PaletteCellConfig m_originConfig;
};
}
