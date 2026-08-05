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

#include "actionicon.h"

#include <algorithm>
#include <cstdlib>

#include <QByteArray>

#include "mscore.h"
#include "property.h"

using namespace mu;
using namespace muse::draw;
using namespace mu::engraving;

ActionIcon::ActionIcon(EngravingItem* parent)
    : EngravingItem(ElementType::ACTION_ICON, parent)
{
    m_iconFont = Font(configuration()->iconsFontFamily(), Font::Type::Icon);
    m_iconFont.setPointSizeF(UI_ICONS_DEFAULT_FONT_SIZE);
}

ActionIcon* ActionIcon::clone() const
{
    return new ActionIcon(*this);
}

ActionIconType ActionIcon::actionType() const
{
    return m_actionType;
}

void ActionIcon::setActionType(ActionIconType val)
{
    m_actionType = val;
}

const std::string& ActionIcon::actionCode() const
{
    return m_actionCode;
}

bool ActionIcon::isBassline() const
{
    return m_actionType >= ActionIconType::BASSLINE_SALSA_1 && m_actionType <= ActionIconType::BASSLINE_BOLERO_4;
}

static std::string baseActionCode(const std::string& actionCode)
{
    const size_t queryPos = actionCode.find('?');
    return actionCode.substr(0, queryPos);
}

static std::string decodeBasslineText(const std::string& text)
{
    return QByteArray::fromBase64(QByteArray::fromStdString(text), QByteArray::Base64UrlEncoding).toStdString();
}

BasslineSettings ActionIcon::basslineSettings() const
{
    BasslineSettings settings;
    if (isBassline()) {
        const int typeOffset = static_cast<int>(m_actionType) - static_cast<int>(ActionIconType::BASSLINE_SALSA_1);
        settings.pattern = (typeOffset % 4) + 1;
    }

    const size_t queryPos = m_actionCode.find('?');
    if (queryPos == std::string::npos) {
        return settings;
    }

    size_t tokenStart = queryPos + 1;
    while (tokenStart < m_actionCode.size()) {
        const size_t tokenEnd = m_actionCode.find('&', tokenStart);
        const std::string token = m_actionCode.substr(tokenStart, tokenEnd - tokenStart);
        const size_t separator = token.find('=');
        if (separator != std::string::npos) {
            const std::string key = token.substr(0, separator);
            const std::string value = token.substr(separator + 1);
            if (key == "p") {
                settings.pattern = std::clamp(std::atoi(value.c_str()), 1, 5);
            } else if (key == "t") {
                settings.transition = std::clamp(std::atoi(value.c_str()), 0, 5);
            } else if (key == "c") {
                settings.customPattern = decodeBasslineText(value);
            } else if (key == "tc") {
                settings.customTransition = decodeBasslineText(value);
            }
        }
        if (tokenEnd == std::string::npos) {
            break;
        }
        tokenStart = tokenEnd + 1;
    }
    return settings;
}

void ActionIcon::setAction(const std::string& actionCode, char16_t icon)
{
    m_actionCode = actionCode;
    m_icon = icon;
}

void ActionIcon::setBasslineSettings(const BasslineSettings& settings)
{
    const auto encode = [](const std::string& text) {
        return QByteArray::fromStdString(text).toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals).toStdString();
    };
    m_actionCode = baseActionCode(m_actionCode)
                   + "?p=" + std::to_string(settings.pattern)
                   + "&t=" + std::to_string(settings.transition)
                   + "&c=" + encode(settings.customPattern)
                   + "&tc=" + encode(settings.customTransition);
    triggerLayout();
}

engraving::PropertyValue ActionIcon::getProperty(Pid pid) const
{
    switch (pid) {
    case Pid::ACTION:
        return String::fromStdString(actionCode());
    default:
        break;
    }
    return EngravingItem::getProperty(pid);
}

bool ActionIcon::setProperty(Pid pid, const PropertyValue& v)
{
    switch (pid) {
    case Pid::ACTION:
        m_actionCode = v.value<String>().toStdString();
        triggerLayout();
        break;
    default:
        return EngravingItem::setProperty(pid, v);
    }
    return true;
}
