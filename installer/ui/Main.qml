import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "components"

ApplicationWindow {
    id: root
    width: 1000
    height: 700
    visible: true
    title: "EndOS Installer" + (Backend.isDryRun ? " (DRY RUN)" : "")
    
    color: ThemeBridge.color("background")

    // Replace standard Header
    header: ToolBar {
        visible: Backend.isDryRun
        background: Rectangle { color: "#FF9800" }
        RowLayout {
            anchors.fill: parent
            Label {
                text: "⚠️ DRY RUN MODE - No changes will be made to your system ⚠️"
                color: "black"
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        // Sidebar
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 260
            color: ThemeBridge.color("surface")
            radius: 16

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                Text {
                    text: "EndOS Setup"
                    font.pixelSize: 24
                    font.weight: 600
                    font.family: "Google Sans Flex"
                    font.variableAxes: ({"wght": 600, "wdth": 100})
                    color: ThemeBridge.color("on_surface")
                    Layout.bottomMargin: 20
                }

                Repeater {
                    model: ["Welcome", "Region", "Disk", "User", "Summary", "Install"]
                    delegate: Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        
                        Rectangle {
                            anchors.fill: parent
                            color: index === stackLayout.currentIndex ? ThemeBridge.color("primary") : "transparent"
                            radius: 8
                            opacity: index === stackLayout.currentIndex ? 0.2 : 0
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            spacing: 10
                            
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: index <= stackLayout.currentIndex ? ThemeBridge.color("primary") : ThemeBridge.color("outline")
                            }
                            
                            Text {
                                text: modelData
                                color: ThemeBridge.color("on_surface")
                                font.pixelSize: 16
                                font.family: "Google Sans Flex"
                                font.weight: 450
                                font.variableAxes: ({"wght": 450, "wdth": 100})
                                opacity: index === stackLayout.currentIndex ? 1.0 : 0.7
                            }
                        }
                    }
                }
                
                Item { Layout.fillHeight: true }
            }
        }

        // Content
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: ThemeBridge.color("surface")
            radius: 16
            
            StackLayout {
                id: stackLayout
                anchors.fill: parent
                anchors.margins: 30
                currentIndex: 0
                ColumnLayout {
                    spacing: 20
                    Text { 
                        text: "Welcome to EndOS"; 
                        color: ThemeBridge.color("on_surface")
                        font.pixelSize: 32
                        font.family: "Google Sans Flex"
                        font.weight: 550
                        font.variableAxes: ({"wght": 550, "wdth": 100})
                    }
                    Text { 
                        text: "This wizard will guide you through the installation process."; 
                        font.pixelSize: 16; 
                        color: ThemeBridge.color("on_surface")
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.family: "Google Sans Flex"
                        font.weight: 450
                        font.variableAxes: ({"wght": 450, "wdth": 100})
                    }
                    Item { Layout.fillHeight: true }
                    StyledButton {
                        text: "Get Started"
                        isPrimary: true
                        onClicked: stackLayout.currentIndex = 1
                    }
                }

                // 1: Region
                ColumnLayout {
                    spacing: 12
                    Text { 
                        text: "Select Region"; 
                        font.pixelSize: 20; color: ThemeBridge.color("on_surface")
                        font.family: "Google Sans Flex"
                        font.weight: 550
                        font.variableAxes: ({"wght": 550, "wdth": 100})
                    }
                    StyledComboBox {
                        id: timezoneSelector
                        model: regionModel
                        Layout.fillWidth: true
                    }
                    
                    Component.onCompleted: {
                        var tzs = Installer.getTimezones()
                        for (var i=0; i<tzs.length; i++) regionModel.append({text: tzs[i]})
                        timezoneSelector.currentIndex = 0
                    }

                    Item { Layout.fillHeight: true }
                    RowLayout {
                        Item { Layout.fillWidth: true }
                        StyledButton {
                            text: "Next"
                            isPrimary: true
                            onClicked: stackLayout.currentIndex = 2
                        }
                    }
                }
                
                // 2: Disk Selection
                ColumnLayout {
                    spacing: 12
                    Text { 
                        text: "Select Target Disk"; font.pixelSize: 20; color: ThemeBridge.color("on_surface")
                        font.family: "Google Sans Flex"; font.weight: 550; font.variableAxes: ({"wght": 550, "wdth": 100})
                    }
                    
                    StyledComboBox {
                        id: diskSelector
                        model: diskModel
                        textRole: "text"
                        Layout.fillWidth: true
                    }
                    
                    Component.onCompleted: refreshDisks()

                    StyledButton {
                        text: "Refresh Disks"
                        onClicked: refreshDisks()
                    }

                    Item { Layout.fillHeight: true }
                    
                    RowLayout {
                        StyledButton { text: "Back"; onClicked: stackLayout.currentIndex = 1 }
                        Item { Layout.fillWidth: true }
                        StyledButton {
                            text: "Next"
                            isPrimary: true
                            enabled: diskSelector.currentIndex >= 0
                            onClicked: stackLayout.currentIndex = 3
                        }
                    }

                    function refreshDisks() {
                        diskModel.clear()
                        var disks = Installer.scanDisks()
                        for (var i=0; i<disks.length; i++) {
                            var d = disks[i]
                            var label = d.device + " (" + d.size + ") - " + d.model
                            diskModel.append({text: label, device: d.device})
                        }
                        if (diskModel.count > 0) diskSelector.currentIndex = 0
                    }
                }
                
                // 3: User Creation
                ColumnLayout {
                    spacing: 12
                    Text { 
                        text: "Create User"; font.pixelSize: 20; color: ThemeBridge.color("on_surface")
                        font.family: "Google Sans Flex"; font.weight: 550; font.variableAxes: ({"wght": 550, "wdth": 100})
                    }
                    
                    Text { 
                        text: "Username"; color: ThemeBridge.color("on_surface")
                        font.family: "Google Sans Flex"; font.weight: 450; font.variableAxes: ({"wght": 450, "wdth": 100})
                    }
                    StyledTextField {
                        id: usernameField
                        placeholderText: "username"
                        Layout.fillWidth: true
                    }
                    
                    Text { 
                        text: "Password"; color: ThemeBridge.color("on_surface")
                        font.family: "Google Sans Flex"; font.weight: 450; font.variableAxes: ({"wght": 450, "wdth": 100})
                    }
                    StyledTextField {
                        id: passwordField
                        echoMode: TextInput.Password
                        placeholderText: "••••••••"
                        Layout.fillWidth: true
                    }

                    Item { Layout.fillHeight: true }
                    
                    RowLayout {
                        StyledButton { text: "Back"; onClicked: stackLayout.currentIndex = 2 }
                        Item { Layout.fillWidth: true }
                        StyledButton {
                            text: "Next"
                            isPrimary: true
                            enabled: usernameField.text.length > 0
                            onClicked: stackLayout.currentIndex = 4
                        }
                    }
                }

                // 4: Summary
                ColumnLayout {
                     spacing: 12
                     Text { 
                        text: "Ready to Install"; font.pixelSize: 20; color: ThemeBridge.color("on_surface")
                        font.family: "Google Sans Flex"; font.weight: 550; font.variableAxes: ({"wght": 550, "wdth": 100})
                     }
                     Text { 
                        text: "Target: " + (diskSelector.currentText || "None")
                        color: ThemeBridge.color("on_surface")
                        font.family: "Google Sans Flex"; font.weight: 450; font.variableAxes: ({"wght": 450, "wdth": 100})
                     }
                     Text {
                         text: "Region: " + timezoneSelector.currentText
                         color: ThemeBridge.color("on_surface")
                         font.family: "Google Sans Flex"; font.weight: 450; font.variableAxes: ({"wght": 450, "wdth": 100})
                     }
                     Text { 
                        text: "User: " + usernameField.text
                        color: ThemeBridge.color("on_surface")
                        font.family: "Google Sans Flex"; font.weight: 450; font.variableAxes: ({"wght": 450, "wdth": 100})
                     }
                     Text {
                         text: "Warning: Data on the selected disk will be erased."
                         color: "#FF5252"
                         font.family: "Google Sans Flex"; font.weight: 450; font.variableAxes: ({"wght": 450, "wdth": 100})
                     }
                     Item { Layout.fillHeight: true }
                     RowLayout {
                        StyledButton { text: "Back"; onClicked: stackLayout.currentIndex = 3 }
                        Item { Layout.fillWidth: true }
                        StyledButton {
                            text: "Install"
                            isPrimary: true
                            onClicked: {
                                stackLayout.currentIndex = 5
                                beginInstall()
                            }
                        }
                     }
                }

                // 5: Install Progress
                ColumnLayout {
                    spacing: 20
                    Text { 
                        text: installStatus
                        font.pixelSize: 24
                        color: ThemeBridge.color("on_surface")
                        font.family: "Google Sans Flex"; font.weight: 550; font.variableAxes: ({"wght": 550, "wdth": 100})
                        Layout.alignment: Qt.AlignHCenter
                    }
                    
                    ProgressBar {
                        Layout.fillWidth: true
                        from: 0; to: 100
                        value: installPercent
                    }
                    
                    Text {
                        text: installMessage
                        color: ThemeBridge.color("on_surface")
                        font.family: "Google Sans Flex"; font.weight: 450; font.variableAxes: ({"wght": 450, "wdth": 100})
                        Layout.alignment: Qt.AlignHCenter
                    }
                    
                    StyledButton {
                        text: "Close"
                        visible: installFinished
                        Layout.alignment: Qt.AlignHCenter
                        onClicked: Qt.quit()
                    }
                }

            }
        }
    }

    property string installStatus: "Installing..."
    property string installMessage: "Initializing..."
    property real installPercent: 0
    property bool installFinished: false

    Connections {
        target: Installer
        function onProgressChanged(percent, msg) {
            installPercent = percent
            installMessage = msg
        }
        function onFinished(success, msg) {
            installFinished = true
            installPercent = 100
            installStatus = success ? "Installation Complete!" : "Installation Failed"
            installMessage = msg
        }
    }

    function beginInstall() {
        var selectedDisk = ""
        if (diskModel.count > 0 && diskSelector.currentIndex >= 0) {
             selectedDisk = diskModel.get(diskSelector.currentIndex).device
        }
        
        var config = {
            targetDisk: selectedDisk,
            timezone: timezoneSelector.currentText,
            username: usernameField.text || "endos",
            password: passwordField.text || "password"
        }
        Installer.startInstall(config)
    }

    ListModel { id: diskModel }
    ListModel { id: regionModel }
}
