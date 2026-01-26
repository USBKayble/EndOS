import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: languagePage
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
            text: "Language & Regional Settings"
            font.pixelSize: 28
            font.weight: Font.Bold
            color: pageTextColor
        }
        
        Text {
            text: "Configure your language, timezone, and keyboard layout"
            font.pixelSize: 14
            color: pageOutlineColor
            Layout.bottomMargin: 16
        }
        
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            
            ColumnLayout {
                width: parent.width
                spacing: 24
                
                // Language selection
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    
                    Text {
                        text: "Language"
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        color: pageTextColor
                    }
                    
                    ComboBox {
                        id: languageCombo
                        Layout.fillWidth: true
                        Layout.maximumWidth: 400
                        
                        model: [
                            "English (US)",
                            "English (UK)",
                            "Spanish",
                            "French",
                            "German",
                            "Chinese (Simplified)",
                            "Japanese",
                            "Korean",
                            "Portuguese (Brazil)",
                            "Russian"
                        ]
                        
                        currentIndex: 0
                        
                        onCurrentTextChanged: {
                            const localeMap = {
                                "English (US)": "en_US",
                                "English (UK)": "en_GB",
                                "Spanish": "es_ES",
                                "French": "fr_FR",
                                "German": "de_DE",
                                "Chinese (Simplified)": "zh_CN",
                                "Japanese": "ja_JP",
                                "Korean": "ko_KR",
                                "Portuguese (Brazil)": "pt_BR",
                                "Russian": "ru_RU"
                            }
                            if (root && root.installConfig) {
                                root.installConfig.language = localeMap[currentText] || "en_US"
                            }
                        }
                    }
                }
                
                // Timezone selection
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    
                    Text {
                        text: "Timezone"
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        color: pageTextColor
                    }
                    
                    Text {
                        text: "Select your timezone for accurate date and time"
                        font.pixelSize: 12
                        color: pageOutlineColor
                    }
                    
                    ComboBox {
                        id: timezoneCombo
                        Layout.fillWidth: true
                        Layout.maximumWidth: 400
                        
                        model: [
                            "America/New_York (EST/EDT)",
                            "America/Chicago (CST/CDT)",
                            "America/Denver (MST/MDT)",
                            "America/Los_Angeles (PST/PDT)",
                            "Europe/London (GMT/BST)",
                            "Europe/Paris (CET/CEST)",
                            "Asia/Tokyo (JST)",
                            "Asia/Shanghai (CST)",
                            "Australia/Sydney (AEST/AEDT)",
                            "UTC"
                        ]
                        
                        currentIndex: 0
                        
                        onCurrentTextChanged: {
                            if (root && root.installConfig) {
                                const timezone = currentText.split(" ")[0]
                                root.installConfig.timezone = timezone
                            }
                        }
                    }
                }
                
                // Keyboard layout selection
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    
                    Text {
                        text: "Keyboard Layout"
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        color: pageTextColor
                    }
                    
                    Text {
                        text: "Test your keyboard layout in the field below"
                        font.pixelSize: 12
                        color: pageOutlineColor
                    }
                    
                    ComboBox {
                        id: keyboardCombo
                        Layout.fillWidth: true
                        Layout.maximumWidth: 400
                        
                        model: [
                            "US",
                            "UK",
                            "German",
                            "French",
                            "Spanish",
                            "Russian",
                            "Japanese",
                            "Korean",
                            "DVORAK",
                            "Colemak"
                        ]
                        
                        currentIndex: 0
                        
                        onCurrentTextChanged: {
                            const layoutMap = {
                                "US": "us",
                                "UK": "uk",
                                "German": "de",
                                "French": "fr",
                                "Spanish": "es",
                                "Russian": "ru",
                                "Japanese": "jp",
                                "Korean": "kr",
                                "DVORAK": "dvorak",
                                "Colemak": "colemak"
                            }
                            if (root && root.installConfig) {
                                root.installConfig.keyboardLayout = layoutMap[currentText] || "us"
                            }
                        }
                    }
                    
                    TextField {
                        id: keyboardTestField
                        Layout.fillWidth: true
                        Layout.maximumWidth: 400
                        placeholderText: "Type here to test your keyboard layout..."
                        
                        background: Rectangle {
                            color: pageSurfaceContainerHighColor
                            radius: 6
                            border.color: keyboardTestField.activeFocus ? pagePrimaryColor : pageOutlineColor
                            border.width: keyboardTestField.activeFocus ? 2 : 1
                        }
                        
                        color: pageTextColor
                        padding: 12
                    }
                }
                
                Item { Layout.fillHeight: true }
            }
        }
    }
}
