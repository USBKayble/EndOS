import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: completionPage
    property var root
    
    // Color properties with fallback defaults
    readonly property color pageTextColor: root ? pageTextColor : "#e6e1e1"
    readonly property color pageBackgroundColor: root ? pageBackgroundColor : "#141313"
    readonly property color pageSurfaceColor: root ? pageSurfaceColor : "#1c1b1c"
    readonly property color pageSurfaceContainerColor: root ? pageSurfaceContainerColor : "#201f20"
    readonly property color pageSurfaceContainerHighColor: root ? pageSurfaceContainerHighColor : "#2b2a2a"
    readonly property color pagePrimaryColor: root ? pagePrimaryColor : "#cbc4cb"
    readonly property color pageOutlineColor: root ? pageOutlineColor : "#948f94"
    color: "transparent"
    
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 32
        width: parent.width * 0.7
        
        // Success icon
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 120
            height: 120
            radius: 60
            color: "#4CAF5020"
            border.color: "#4CAF50"
            border.width: 4
            
            Text {
                anchors.centerIn: parent
                text: "✓"
                font.pixelSize: 64
                font.weight: Font.Bold
                color: "#4CAF50"
            }
        }
        
        // Success message
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Installation Complete!"
            font.pixelSize: 32
            font.weight: Font.Bold
            color: pageTextColor
        }
        
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: parent.width
            text: "EndOS has been successfully installed on your system"
            font.pixelSize: 16
            color: pageOutlineColor
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
        
        Item { height: 10 }
        
        // Installation summary
        Rectangle {
            Layout.fillWidth: true
            Layout.maximumWidth: 600
            Layout.alignment: Qt.AlignHCenter
            implicitHeight: summaryLayout.implicitHeight + 24
            color: pageSurfaceContainerHighColor
            radius: 12
            
            ColumnLayout {
                id: summaryLayout
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                
                Text {
                    text: "Installation Summary"
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    color: pageTextColor
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: pageOutlineColor
                    opacity: 0.3
                }
                
                Grid {
                    columns: 2
                    rowSpacing: 8
                    columnSpacing: 24
                    
                    Text {
                        text: "Hostname:"
                        font.pixelSize: 13
                        color: pageOutlineColor
                    }
                    Text {
                        text: root.installConfig.hostname
                        font.pixelSize: 13
                        color: pageTextColor
                    }
                    
                    Text {
                        text: "Username:"
                        font.pixelSize: 13
                        color: pageOutlineColor
                    }
                    Text {
                        text: root.installConfig.username
                        font.pixelSize: 13
                        color: pageTextColor
                    }
                    
                    Text {
                        text: "Packages Installed:"
                        font.pixelSize: 13
                        color: pageOutlineColor
                    }
                    Text {
                        text: `~${200 + root.installConfig.optionalPackages.length + root.installConfig.customPackages.length}`
                        font.pixelSize: 13
                        color: pageTextColor
                    }
                }
            }
        }
        
        // Next steps info
        Rectangle {
            Layout.fillWidth: true
            Layout.maximumWidth: 600
            Layout.alignment: Qt.AlignHCenter
            implicitHeight: nextStepsLayout.implicitHeight + 24
            color: pageSurfaceColor
            radius: 12
            border.color: pageOutlineColor
            border.width: 1
            
            ColumnLayout {
                id: nextStepsLayout
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                
                Text {
                    text: "💡 Quick Tips"
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    color: pageTextColor
                }
                
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    
                    TipRow {
                        text: "Press Super+/ to view all keyboard shortcuts"
                    }
                    
                    TipRow {
                        text: "Press Super+I to open system settings"
                    }
                    
                    TipRow {
                        text: "Press Ctrl+Super+T to change wallpaper"
                    }
                    
                    TipRow {
                        text: "Configure lock on boot in ~/.config/illogical-impulse/config.json"
                    }
                    
                    TipRow {
                        text: "Visit the EndOS documentation for more information"
                    }
                }
            }
        }
        
        Item { height: 10 }
        
        // Action buttons
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 16
            
            // Stay in live environment button
            Button {
                id: stayButton
                text: "Stay in Live Environment"
                font.pixelSize: 14
                implicitWidth: 220
                implicitHeight: 50
                
                contentItem: Text {
                    text: stayButton.text
                    font: stayButton.font
                    color: pageTextColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                background: Rectangle {
                    color: stayButton.down ? Qt.darker(pageSurfaceContainerHighColor, 1.2) : 
                           stayButton.hovered ? Qt.lighter(pageSurfaceContainerHighColor, 1.1) : pageSurfaceContainerHighColor
                    radius: 25
                    border.color: pageOutlineColor
                    border.width: 2
                }
                
                onClicked: {
                    Qt.quit()
                }
            }
            
            // Reboot button
            Button {
                id: rebootButton
                text: "Reboot Now"
                font.pixelSize: 14
                font.weight: Font.Medium
                implicitWidth: 220
                implicitHeight: 50
                
                contentItem: Text {
                    text: rebootButton.text
                    font: rebootButton.font
                    color: pageBackgroundColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                background: Rectangle {
                    color: rebootButton.down ? Qt.darker(pagePrimaryColor, 1.2) : 
                           rebootButton.hovered ? Qt.lighter(pagePrimaryColor, 1.1) : pagePrimaryColor
                    radius: 25
                }
                
                onClicked: {
                    rebootDialog.open()
                }
            }
        }
        
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: parent.width
            text: "Remember to remove the installation media before rebooting"
            font.pixelSize: 12
            color: pageOutlineColor
            opacity: 0.7
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }
    
    // Reboot confirmation dialog
    Dialog {
        id: rebootDialog
        title: "Reboot System?"
        modal: true
        anchors.centerIn: parent
        width: 400
        
        background: Rectangle {
            color: pageSurfaceContainerColor
            radius: 12
            border.color: pageOutlineColor
            border.width: 1
        }
        
        ColumnLayout {
            width: parent.width
            spacing: 16
            
            Text {
                text: "Are you sure you want to reboot now?\n\nMake sure to remove the installation media."
                font.pixelSize: 13
                color: pageTextColor
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                
                Item { Layout.fillWidth: true }
                
                Button {
                    text: "Cancel"
                    onClicked: rebootDialog.close()
                    
                    background: Rectangle {
                        color: parent.down ? Qt.darker(pageSurfaceContainerHighColor, 1.2) : 
                               parent.hovered ? Qt.lighter(pageSurfaceContainerHighColor, 1.1) : pageSurfaceContainerHighColor
                        radius: 6
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: pageTextColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                
                Button {
                    text: "Reboot"
                    onClicked: {
                        rebootDialog.close()
                        Quickshell.execDetached(["systemctl", "reboot"])
                    }
                    
                    background: Rectangle {
                        color: parent.down ? Qt.darker(pagePrimaryColor, 1.2) : 
                               parent.hovered ? Qt.lighter(pagePrimaryColor, 1.1) : pagePrimaryColor
                        radius: 6
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: pageBackgroundColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }
    
    // Custom tip component
    component TipRow: RowLayout {
        property string text: ""
        Layout.fillWidth: true
        spacing: 8
        
        Text {
            text: "•"
            font.pixelSize: 16
            color: pagePrimaryColor
        }
        
        Text {
            text: parent.text
            font.pixelSize: 12
            color: pageTextColor
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
    }
}
