import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: welcomePage
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
        anchors.centerIn: parent
        spacing: 32
        width: parent.width * 0.6
        
        // Logo/Icon area
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 120
            height: 120
            radius: 60
            color: pagePrimaryColor
            opacity: 0.2
            
            Text {
                anchors.centerIn: parent
                text: "E"
                font.pixelSize: 64
                font.weight: Font.Bold
                color: pagePrimaryColor
            }
        }
        
        // Welcome title
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Welcome to EndOS"
            font.pixelSize: 42
            font.weight: Font.Bold
            color: pageTextColor
        }
        
        // Subtitle
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: parent.width
            text: "A modern, Arch-based distribution with a beautiful Hyprland desktop environment"
            font.pixelSize: 16
            color: pageOutlineColor
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
        
        Item { height: 20 }
        
        // Action buttons
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 16
            
            // Install button
            Button {
                id: installButton
                text: "Install EndOS"
                font.pixelSize: 16
                font.weight: Font.Medium
                Layout.preferredWidth: 200
                Layout.preferredHeight: 50
                
                contentItem: Text {
                    text: installButton.text
                    font: installButton.font
                    color: pageBackgroundColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                background: Rectangle {
                    color: installButton.down ? Qt.darker(pagePrimaryColor, 1.2) : 
                           installButton.hovered ? Qt.lighter(pagePrimaryColor, 1.1) : pagePrimaryColor
                    radius: 25
                    
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }
                
                onClicked: {
                    root.nextPage()
                }
            }
            
            // Try button
            Button {
                id: tryButton
                text: "Try EndOS"
                font.pixelSize: 16
                font.weight: Font.Medium
                Layout.preferredWidth: 200
                Layout.preferredHeight: 50
                
                contentItem: Text {
                    text: tryButton.text
                    font: tryButton.font
                    color: pageTextColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                background: Rectangle {
                    color: "transparent"
                    border.color: pageOutlineColor
                    border.width: 2
                    radius: 25
                    
                    Rectangle {
                        anchors.fill: parent
                        color: pageTextColor
                        opacity: tryButton.down ? 0.2 : tryButton.hovered ? 0.1 : 0
                        radius: parent.radius
                        
                        Behavior on opacity {
                            NumberAnimation { duration: 150 }
                        }
                    }
                }
                
                onClicked: {
                    // Mark installer as dismissed so it doesn't auto-launch again
                    var dismissProc = Qt.createQmlObject('import Quickshell.Io; Process { command: ["touch", "/home/" + Qt.getenv("USER") + "/.config/installer-dismissed"] }', tryButton);
                    dismissProc.running = true;
                    
                    // Close installer and let user explore
                    Qt.quit()
                }
            }
        }
        
        Item { height: 20 }
        
        // Footer text
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: parent.width
            text: "You can launch the installer anytime by searching 'install' or running the 'endos-installer' command"
            font.pixelSize: 12
            color: pageOutlineColor
            opacity: 0.7
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }
    
    // Animated background effect (optional)
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        z: -1
        
        Repeater {
            model: 3
            Rectangle {
                width: 400
                height: 400
                radius: 200
                color: pagePrimaryColor
                opacity: 0.03
                x: Math.random() * parent.width - 200
                y: Math.random() * parent.height - 200
                
                SequentialAnimation on opacity {
                    running: true
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 0.05
                        duration: 3000 + (index * 500)
                        easing.type: Easing.InOutQuad
                    }
                    NumberAnimation {
                        to: 0.03
                        duration: 3000 + (index * 500)
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
    }
}
