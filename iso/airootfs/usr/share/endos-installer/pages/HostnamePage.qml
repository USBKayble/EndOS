import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: hostnamePage
    property var root    // Color properties with fallback defaults
    readonly property color pageTextColor: root ? root.textOnSurfaceColor : "#e6e1e1"
    readonly property color pageBackgroundColor: root ? pageBackgroundColor : "#141313"
    readonly property color pageSurfaceColor: root ? pageSurfaceColor : "#1c1b1c"
    readonly property color pageSurfaceContainerColor: root ? pageSurfaceContainerColor : "#201f20"
    readonly property color pageSurfaceContainerHighColor: root ? pageSurfaceContainerHighColor : "#2b2a2a"
    readonly property color pagePrimaryColor: root ? pagePrimaryColor : "#cbc4cb"
    readonly property color pageOutlineColor: root ? pageOutlineColor : "#948f94"
    color: "transparent"
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 24
        
        // Page title
        Text {
            text: "System Configuration"
            font.pixelSize: 28
            font.weight: Font.Bold
            color: pageTextColor
        }
        
        Text {
            text: "Configure hostname and system settings"
            font.pixelSize: 14
            color: pageOutlineColor
            Layout.bottomMargin: 8
        }
        
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            
            ColumnLayout {
                width: parent.width
                spacing: 24
                
                // Hostname
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 500
                    spacing: 8
                    
                    Text {
                        text: "Hostname"
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        color: pageTextColor
                    }
                    
                    Text {
                        text: "The name of your computer on the network"
                        font.pixelSize: 11
                        color: pageOutlineColor
                    }
                    
                    TextField {
                        id: hostnameField
                        Layout.fillWidth: true
                        text: "endos"
                        placeholderText: "endos"
                        
                        validator: RegularExpressionValidator {
                            regularExpression: /^[a-z0-9-]+$/
                        }
                        
                        onTextChanged: {
                            if (root && root.installConfig) root.installConfig.hostname = text
                            validateHostname()
                        }
                        
                        function validateHostname() {
                            if (text.length === 0) {
                                hostnameValidation.text = ""
                                return false
                            } else if (text.length < 2) {
                                hostnameValidation.text = "⚠️ Hostname must be at least 2 characters"
                                hostnameValidation.color = "#ff5555"
                                return false
                            } else if (!/^[a-z0-9-]+$/.test(text)) {
                                hostnameValidation.text = "⚠️ Hostname can only contain lowercase letters, numbers, and hyphens"
                                hostnameValidation.color = "#ff5555"
                                return false
                            } else if (text.startsWith('-') || text.endsWith('-')) {
                                hostnameValidation.text = "⚠️ Hostname cannot start or end with a hyphen"
                                hostnameValidation.color = "#ff5555"
                                return false
                            } else {
                                hostnameValidation.text = "✓ Hostname is valid"
                                hostnameValidation.color = "#4CAF50"
                                return true
                            }
                        }
                        
                        Component.onCompleted: {
                            if (root && root.installConfig) root.installConfig.hostname = text
                        }
                        
                        background: Rectangle {
                            color: pageSurfaceContainerHighColor
                            radius: 6
                            border.color: hostnameField.activeFocus ? pagePrimaryColor : 
                                         !hostnameField.validateHostname() && hostnameField.text.length > 0 ? "#ff5555" : pageOutlineColor
                            border.width: hostnameField.activeFocus ? 2 : 1
                        }
                        
                        color: pageTextColor
                        padding: 12
                    }
                    
                    Text {
                        id: hostnameValidation
                        text: "✓ Hostname is valid"
                        font.pixelSize: 11
                        color: "#4CAF50"
                        visible: text.length > 0
                    }
                }
                
                // System settings card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 500
                    implicitHeight: systemSettingsLayout.implicitHeight + 24
                    color: pageSurfaceColor
                    radius: 8
                    border.color: pageOutlineColor
                    border.width: 1
                    
                    ColumnLayout {
                        id: systemSettingsLayout
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 16
                        
                        Text {
                            text: "System Settings"
                            font.pixelSize: 16
                            font.weight: Font.Medium
                            color: pageTextColor
                        }
                        
                        // NTP
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            
                            CheckBox {
                                id: ntpCheckbox
                                text: "Enable Network Time Protocol (NTP)"
                                checked: true
                                
                                onCheckedChanged: {
                                    if (root && root.installConfig) root.installConfig.enableNTP = checked
                                }
                                
                                contentItem: Text {
                                    text: ntpCheckbox.text
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    color: pageTextColor
                                    leftPadding: ntpCheckbox.indicator.width + 8
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                indicator: Rectangle {
                                    implicitWidth: 18
                                    implicitHeight: 18
                                    radius: 4
                                    border.color: pageOutlineColor
                                    border.width: 2
                                    color: ntpCheckbox.checked ? pagePrimaryColor : "transparent"
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "✓"
                                        color: pageBackgroundColor
                                        font.pixelSize: 12
                                        visible: ntpCheckbox.checked
                                    }
                                }
                            }
                            
                            Text {
                                text: "Automatically synchronize system time with internet time servers"
                                font.pixelSize: 11
                                color: pageOutlineColor
                                leftPadding: 26
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                            }
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: pageOutlineColor
                            opacity: 0.3
                        }
                        
                        // Multilib
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            
                            CheckBox {
                                id: multilibCheckbox
                                text: "Enable Multilib repository"
                                checked: true
                                
                                onCheckedChanged: {
                                    if (root && root.installConfig) root.installConfig.enableMultilib = checked
                                }
                                
                                contentItem: Text {
                                    text: multilibCheckbox.text
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    color: pageTextColor
                                    leftPadding: multilibCheckbox.indicator.width + 8
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                indicator: Rectangle {
                                    implicitWidth: 18
                                    implicitHeight: 18
                                    radius: 4
                                    border.color: pageOutlineColor
                                    border.width: 2
                                    color: multilibCheckbox.checked ? pagePrimaryColor : "transparent"
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "✓"
                                        color: pageBackgroundColor
                                        font.pixelSize: 12
                                        visible: multilibCheckbox.checked
                                    }
                                }
                            }
                            
                            Text {
                                text: "Required for running 32-bit applications, Wine, Steam, and some games"
                                font.pixelSize: 11
                                color: pageOutlineColor
                                leftPadding: 26
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
                
                // AUR helper selection
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 500
                    spacing: 12
                    
                    Text {
                        text: "AUR Helper"
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        color: pageTextColor
                    }
                    
                    Text {
                        text: "Helper tool for installing packages from the Arch User Repository"
                        font.pixelSize: 11
                        color: pageOutlineColor
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        
                        // Yay
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: yayLayout.implicitHeight + 16
                            color: yayRadio.checked ? pageSurfaceContainerHighColor : pageSurfaceColor
                            radius: 6
                            border.color: yayRadio.checked ? pagePrimaryColor : pageOutlineColor
                            border.width: yayRadio.checked ? 2 : 1
                            
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    yayRadio.checked = true
                                    if (root && root.installConfig) root.installConfig.aurHelper = "yay"
                                }
                            }
                            
                            RowLayout {
                                id: yayLayout
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12
                                
                                RadioButton {
                                    id: yayRadio
                                    checked: true
                                    
                                    onCheckedChanged: {
                                        if (checked) if (root && root.installConfig) root.installConfig.aurHelper = "yay"
                                    }
                                    
                                    indicator: Rectangle {
                                        implicitWidth: 18
                                        implicitHeight: 18
                                        radius: 9
                                        border.color: pageOutlineColor
                                        border.width: 2
                                        color: "transparent"
                                        
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 8
                                            height: 8
                                            radius: 4
                                            color: pagePrimaryColor
                                            visible: yayRadio.checked
                                        }
                                    }
                                }
                                
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    
                                    Text {
                                        text: "yay (Recommended)"
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        color: pageTextColor
                                    }
                                    
                                    Text {
                                        text: "Popular, user-friendly, written in Go"
                                        font.pixelSize: 11
                                        color: pageOutlineColor
                                    }
                                }
                            }
                        }
                        
                        // Paru
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: paruLayout.implicitHeight + 16
                            color: paruRadio.checked ? pageSurfaceContainerHighColor : pageSurfaceColor
                            radius: 6
                            border.color: paruRadio.checked ? pagePrimaryColor : pageOutlineColor
                            border.width: paruRadio.checked ? 2 : 1
                            
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    paruRadio.checked = true
                                    if (root && root.installConfig) root.installConfig.aurHelper = "paru"
                                }
                            }
                            
                            RowLayout {
                                id: paruLayout
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12
                                
                                RadioButton {
                                    id: paruRadio
                                    checked: false
                                    
                                    onCheckedChanged: {
                                        if (checked) if (root && root.installConfig) root.installConfig.aurHelper = "paru"
                                    }
                                    
                                    indicator: Rectangle {
                                        implicitWidth: 18
                                        implicitHeight: 18
                                        radius: 9
                                        border.color: pageOutlineColor
                                        border.width: 2
                                        color: "transparent"
                                        
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 8
                                            height: 8
                                            radius: 4
                                            color: pagePrimaryColor
                                            visible: paruRadio.checked
                                        }
                                    }
                                }
                                
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    
                                    Text {
                                        text: "paru"
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        color: pageTextColor
                                    }
                                    
                                    Text {
                                        text: "Feature-rich, yay replacement, written in Rust"
                                        font.pixelSize: 11
                                        color: pageOutlineColor
                                    }
                                }
                            }
                        }
                        
                        // None
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: noneLayout.implicitHeight + 16
                            color: noneRadio.checked ? pageSurfaceContainerHighColor : pageSurfaceColor
                            radius: 6
                            border.color: noneRadio.checked ? pagePrimaryColor : pageOutlineColor
                            border.width: noneRadio.checked ? 2 : 1
                            
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    noneRadio.checked = true
                                    if (root && root.installConfig) root.installConfig.aurHelper = "none"
                                }
                            }
                            
                            RowLayout {
                                id: noneLayout
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12
                                
                                RadioButton {
                                    id: noneRadio
                                    checked: false
                                    
                                    onCheckedChanged: {
                                        if (checked) if (root && root.installConfig) root.installConfig.aurHelper = "none"
                                    }
                                    
                                    indicator: Rectangle {
                                        implicitWidth: 18
                                        implicitHeight: 18
                                        radius: 9
                                        border.color: pageOutlineColor
                                        border.width: 2
                                        color: "transparent"
                                        
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 8
                                            height: 8
                                            radius: 4
                                            color: pagePrimaryColor
                                            visible: noneRadio.checked
                                        }
                                    }
                                }
                                
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    
                                    Text {
                                        text: "None"
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        color: pageTextColor
                                    }
                                    
                                    Text {
                                        text: "Manual AUR package management only"
                                        font.pixelSize: 11
                                        color: pageOutlineColor
                                    }
                                }
                            }
                        }
                    }
                }
                
                Item { Layout.fillHeight: true }
            }
        }
    }
}
