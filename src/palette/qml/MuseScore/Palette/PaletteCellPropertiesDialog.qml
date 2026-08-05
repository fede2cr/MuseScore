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
import QtQuick

import Muse.Ui
import Muse.UiComponents
import MuseScore.Palette

import "internal"

StyledDialogView {
    id: root

    title: qsTrc("palette", "Palette cell properties")

    contentWidth: propertiesModel.isBassline ? 360 : 280
    contentHeight: contentColumn.implicitHeight
    margins: 12

    property var properties

    PaletteCellPropertiesModel {
        id: propertiesModel
    }

    Component.onCompleted: {
        propertiesModel.load(root.properties)
    }

    NavigationPanel {
        id: navPanel
        name: "PaletteCellPropertiesDialog"
        section: root.navigationSection
        enabled: contentColumn.enabled && contentColumn.visible
        order: 1
        direction: NavigationPanel.Horizontal
    }

    onNavigationActivateRequested: {
        nameField.navigation.requestActive()
    }

    Column {
        id: contentColumn
        anchors.fill: parent
        spacing: 12

        StyledTextLabel {
            text: qsTrc("palette", "Name")
            font: ui.theme.bodyBoldFont
        }

        TextInputField {
            id: nameField
            currentText: propertiesModel.name

            onTextChanged: function(newTextValue) {
                propertiesModel.name = newTextValue
            }

            navigation.panel: navPanel
            navigation.order: 1
        }

        SeparatorLine { anchors.margins: -root.margins }

        StyledTextLabel {
            text: qsTrc("palette", "Content offset")
            font: ui.theme.bodyBoldFont
        }

        Grid {
            id: grid
            width: parent.width

            columns: 2
            spacing: 12

            PalettePropertyItem {
                title: qsTrc("palette", "X")
                value: propertiesModel.xOffset
                incrementStep: 1
                minValue: -10
                maxValue: 10
                //: Abbreviation of "spatium"
                measureUnit: qsTrc("global", "sp")

                onValueEdited: function (newValue) {
                    propertiesModel.xOffset = newValue
                }

                navigation.panel: navPanel
                navigation.order: 2
            }

            PalettePropertyItem {
                title: qsTrc("palette", "Y")
                value: propertiesModel.yOffset
                incrementStep: 1
                minValue: -10
                maxValue: 10
                measureUnit: qsTrc("global", "sp")

                onValueEdited: function (newValue) {
                    propertiesModel.yOffset = newValue
                }

                navigation.panel: navPanel
                navigation.order: 3
            }

            PalettePropertyItem {
                title: qsTrc("palette", "Content scale")
                value: propertiesModel.scaleFactor
                incrementStep: 0.1
                minValue: 0.1
                maxValue: 10

                onValueEdited: function (newValue) {
                    propertiesModel.scaleFactor = newValue
                }

                navigation.panel: navPanel
                navigation.order: 4
            }
        }

        CheckBox {
            width: parent.width
            text: qsTrc("palette", "Draw staff")

            checked: propertiesModel.drawStaff

            onClicked: {
                propertiesModel.drawStaff = !checked
            }

            navigation.panel: navPanel
            navigation.order: 5
        }

        SeparatorLine {
            visible: propertiesModel.isBassline
            anchors.margins: -root.margins
        }

        StyledTextLabel {
            visible: propertiesModel.isBassline
            text: qsTrc("palette", "Bassline pattern")
            font: ui.theme.bodyBoldFont
        }

        StyledDropdown {
            visible: propertiesModel.isBassline
            width: parent.width
            model: [
                { text: qsTrc("palette", "Pattern 1"), value: 1 },
                { text: qsTrc("palette", "Pattern 2"), value: 2 },
                { text: qsTrc("palette", "Pattern 3"), value: 3 },
                { text: qsTrc("palette", "Pattern 4"), value: 4 },
                { text: qsTrc("palette", "Custom"), value: 5 }
            ]
            textRole: "text"
            valueRole: "value"
            currentIndex: propertiesModel.basslinePattern - 1
            onActivated: function(index, value) {
                propertiesModel.basslinePattern = value
            }
            navigation.panel: navPanel
            navigation.order: 6
        }

        TextInputArea {
            visible: propertiesModel.isBassline && propertiesModel.basslinePattern === 5
            width: parent.width
            initialHeight: 64
            currentText: propertiesModel.customBassline
            hint: qsTrc("palette", "2:C0,1:R,1:C7,2:C0,2:C7")
            onTextChanged: function(newTextValue) {
                propertiesModel.customBassline = newTextValue
            }
            navigation.panel: navPanel
            navigation.order: 7
        }

        StyledTextLabel {
            visible: propertiesModel.isBassline
            text: qsTrc("palette", "Transition pattern")
            font: ui.theme.bodyBoldFont
        }

        StyledDropdown {
            visible: propertiesModel.isBassline
            width: parent.width
            model: [
                { text: qsTrc("palette", "None"), value: 0 },
                { text: qsTrc("palette", "Transition 1"), value: 1 },
                { text: qsTrc("palette", "Transition 2"), value: 2 },
                { text: qsTrc("palette", "Transition 3"), value: 3 },
                { text: qsTrc("palette", "Transition 4"), value: 4 },
                { text: qsTrc("palette", "Custom"), value: 5 }
            ]
            textRole: "text"
            valueRole: "value"
            currentIndex: propertiesModel.transitionPattern
            onActivated: function(index, value) {
                propertiesModel.transitionPattern = value
            }
            navigation.panel: navPanel
            navigation.order: 8
        }

        TextInputArea {
            visible: propertiesModel.isBassline && propertiesModel.transitionPattern === 5
            width: parent.width
            initialHeight: 64
            currentText: propertiesModel.customTransition
            hint: qsTrc("palette", "1:C0,1:C7,1:N7,1:N0")
            onTextChanged: function(newTextValue) {
                propertiesModel.customTransition = newTextValue
            }
            navigation.panel: navPanel
            navigation.order: 9
        }

        ButtonBox {
            width: parent.width

            buttons: [ ButtonBoxModel.Cancel, ButtonBoxModel.Ok ]

            navigationPanel.section: root.navigationSection
            navigationPanel.order: 2

            onStandardButtonClicked: function(buttonId) {
                if (buttonId === ButtonBoxModel.Cancel) {
                    propertiesModel.reject()
                    root.hide()
                } else if (buttonId === ButtonBoxModel.Ok) {
                    root.hide()
                }
            }
        }
    }
}
