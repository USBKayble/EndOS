import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: progressPage
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
        width: parent.width * 0.8
        
        // Main progress indicator
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 16
            
            // Circular progress indicator
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 120
                height: 120
                radius: 60
                color: "transparent"
                border.color: pageOutlineColor
                border.width: 8
                
                Rectangle {
                    id: progressArc
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.color: pagePrimaryColor
                    border.width: 8
                    
                    // This is a simplified progress indicator
                    // A proper implementation would use Canvas for an arc
                    opacity: root.installConfig.installProgress / 100
                }
                
                Text {
                    anchors.centerIn: parent
                    text: Math.round(root.installConfig.installProgress) + "%"
                    font.pixelSize: 32
                    font.weight: Font.Bold
                    color: pageTextColor
                }
            }
            
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Installing EndOS..."
                font.pixelSize: 24
                font.weight: Font.Medium
                color: pageTextColor
            }
        }
        
        // Current task
        Rectangle {
            Layout.fillWidth: true
            Layout.maximumWidth: 600
            Layout.alignment: Qt.AlignHCenter
            implicitHeight: taskLayout.implicitHeight + 24
            color: pageSurfaceContainerHighColor
            radius: 12
            
            ColumnLayout {
                id: taskLayout
                anchors.fill: parent
                anchors.margins: 16
                spacing: 8
                
                Text {
                    text: "Current Task:"
                    font.pixelSize: 13
                    color: pageOutlineColor
                }
                
                Text {
                    text: root.installConfig.currentTask || "Preparing installation..."
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    color: pageTextColor
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        }
        
        // Progress steps indicator
        ColumnLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: 600
            Layout.alignment: Qt.AlignHCenter
            spacing: 8
            
            Repeater {
                model: [
                    {step: "Partitioning disk", progress: 10},
                    {step: "Formatting partitions", progress: 20},
                    {step: "Installing base system", progress: 50},
                    {step: "Installing packages", progress: 70},
                    {step: "Configuring system", progress: 85},
                    {step: "Installing bootloader", progress: 95},
                    {step: "Finalizing installation", progress: 100}
                ]
                
                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    
                    Rectangle {
                        width: 16
                        height: 16
                        radius: 8
                        color: root.installConfig.installProgress >= modelData.progress ? pagePrimaryColor : pageSurfaceContainerHighColor
                        border.color: pageOutlineColor
                        border.width: 1
                        
                        Text {
                            anchors.centerIn: parent
                            text: root.installConfig.installProgress >= modelData.progress ? "✓" : ""
                            color: pageBackgroundColor
                            font.pixelSize: 10
                        }
                    }
                    
                    Text {
                        text: modelData.step
                        font.pixelSize: 13
                        color: root.installConfig.installProgress >= modelData.progress ? pageTextColor : pageOutlineColor
                        Layout.fillWidth: true
                    }
                    
                    Text {
                        text: root.installConfig.installProgress >= modelData.progress ? "Done" : 
                              root.installConfig.installProgress >= (modelData.progress - 10) ? "In progress..." : "Pending"
                        font.pixelSize: 11
                        color: pageOutlineColor
                    }
                }
            }
        }
        
        // Log viewer toggle
        ColumnLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: 600
            Layout.alignment: Qt.AlignHCenter
            spacing: 8
            
            Button {
                id: toggleLogsButton
                text: showLogs ? "Hide Installation Logs" : "Show Installation Logs"
                Layout.alignment: Qt.AlignHCenter
                
                property bool showLogs: false
                
                onClicked: {
                    showLogs = !showLogs
                }
                
                background: Rectangle {
                    color: parent.down ? Qt.darker(pageSurfaceContainerHighColor, 1.2) : 
                           parent.hovered ? Qt.lighter(pageSurfaceContainerHighColor, 1.1) : pageSurfaceContainerHighColor
                    radius: 6
                }
                
                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 12
                    color: pageTextColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 200
                color: pageSurfaceColor
                radius: 8
                border.color: pageOutlineColor
                border.width: 1
                visible: toggleLogsButton.showLogs
                
                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 8
                    clip: true
                    
                    TextArea {
                        id: logViewer
                        readOnly: true
                        text: root.installConfig.installLogs.join('\n')
                        font.pixelSize: 10
                        font.family: "monospace"
                        color: pageTextColor
                        wrapMode: TextEdit.Wrap
                        background: Rectangle {
                            color: "transparent"
                        }
                        
                        // Auto-scroll to bottom
                        onTextChanged: {
                            cursorPosition = text.length
                        }
                    }
                }
            }
        }
        
        // Warning text
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: 500
            text: "⚠️ Do not power off or restart your computer during installation"
            font.pixelSize: 12
            color: "#ff5555"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }
}
