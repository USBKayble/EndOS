import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io

Rectangle {
    id: networkPage
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
    
    // Network status check process
    Process {
        id: wifiListProc
        command: ["bash", "-c", "nmcli -t -f SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null || echo 'ERROR:Network manager not available'"]
        running: false
        
        stdout: SplitParser {
            onRead: data => {
                const lines = data.trim().split('\n')
                wifiNetworks.clear()
                
                if (lines[0] && lines[0].startsWith('ERROR:')) {
                    networkStatusText.text = "Network manager not available"
                    return
                }
                
                for (const line of lines) {
                    if (!line) continue
                    const parts = line.split(':')
                    if (parts.length >= 2) {
                        wifiNetworks.append({
                            ssid: parts[0],
                            signal: parseInt(parts[1]) || 0,
                            security: parts[2] || "Open"
                        })
                    }
                }
                
                networkStatusText.text = `Found ${wifiNetworks.count} networks`
            }
        }
    }
    
    Process {
        id: wifiConnectProc
        property string ssid: ""
        property string password: ""
        command: ["bash", "-c", `nmcli dev wifi connect "${ssid}" password "${password}" 2>&1`]
        running: false
        
        stdout: SplitParser {
            onRead: data => {
                if (data.includes("successfully activated")) {
                    connectionStatusText.text = "Connected successfully!"
                    connectionStatusText.color = pagePrimaryColor
                    root.checkNetworkStatus()
                } else if (data.includes("Error")) {
                    connectionStatusText.text = "Connection failed: " + data
                    connectionStatusText.color = "#ff5555"
                } else {
                    connectionStatusText.text = data
                }
            }
        }
    }
    
    ListModel {
        id: wifiNetworks
    }
    
    Component.onCompleted: {
        // Scan for networks on page load
        wifiListProc.running = true
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 24
        
        // Page title
        Text {
            text: "Network Configuration"
            font.pixelSize: 28
            font.weight: Font.Bold
            color: pageTextColor
        }
        
        Text {
            text: "Connect to the internet for package installation and updates"
            font.pixelSize: 14
            color: pageOutlineColor
            Layout.bottomMargin: 8
        }
        
        // Network status card
        Rectangle {
            Layout.fillWidth: true
            Layout.maximumWidth: 600
            implicitHeight: statusLayout.implicitHeight + 32
            color: pageSurfaceContainerHighColor
            radius: 12
            
            ColumnLayout {
                id: statusLayout
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                
                RowLayout {
                    spacing: 12
                    
                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: root.installConfig.isOnline ? "#4CAF50" : "#ff5555"
                    }
                    
                    Text {
                        text: root.installConfig.isOnline ? "Connected to Internet" : "Not Connected"
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        color: pageTextColor
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    Button {
                        text: "Refresh"
                        onClicked: {
                            root.checkNetworkStatus()
                            wifiListProc.running = true
                        }
                        
                        background: Rectangle {
                            color: parent.down ? Qt.darker(pageSurfaceColor, 1.2) : 
                                   parent.hovered ? Qt.lighter(pageSurfaceColor, 1.1) : pageSurfaceColor
                            radius: 6
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: pageTextColor
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
                
                Text {
                    id: networkStatusText
                    text: "Checking network status..."
                    font.pixelSize: 12
                    color: pageOutlineColor
                }
            }
        }
        
        // WiFi connection section
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12
            
            Text {
                text: "Available WiFi Networks"
                font.pixelSize: 18
                font.weight: Font.Medium
                color: pageTextColor
            }
            
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: pageSurfaceColor
                radius: 8
                border.color: pageOutlineColor
                border.width: 1
                
                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 1
                    clip: true
                    
                    ListView {
                        id: wifiList
                        model: wifiNetworks
                        spacing: 4
                        
                        delegate: Rectangle {
                            width: wifiList.width
                            height: 56
                            color: mouseArea.containsMouse ? pageSurfaceContainerHighColor : "transparent"
                            radius: 6
                            
                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    wifiPasswordDialog.ssid = model.ssid
                                    wifiPasswordDialog.security = model.security
                                    if (model.security === "Open" || model.security === "") {
                                        // Connect without password
                                        wifiConnectProc.ssid = model.ssid
                                        wifiConnectProc.password = ""
                                        wifiConnectProc.running = true
                                    } else {
                                        wifiPasswordDialog.open()
                                    }
                                }
                            }
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12
                                
                                Text {
                                    text: "📶"
                                    font.pixelSize: 20
                                }
                                
                                Text {
                                    text: model.ssid
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    color: pageTextColor
                                    Layout.fillWidth: true
                                }
                                
                                Text {
                                    text: model.security
                                    font.pixelSize: 12
                                    color: pageOutlineColor
                                }
                                
                                Text {
                                    text: model.signal + "%"
                                    font.pixelSize: 12
                                    color: pageOutlineColor
                                }
                            }
                        }
                        
                        // Empty state
                        Rectangle {
                            visible: wifiNetworks.count === 0
                            anchors.centerIn: parent
                            width: parent.width * 0.8
                            height: 100
                            color: "transparent"
                            
                            Text {
                                anchors.centerIn: parent
                                text: "No WiFi networks found\nClick Refresh to scan again"
                                font.pixelSize: 14
                                color: pageOutlineColor
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }
            }
            
            Text {
                id: connectionStatusText
                text: ""
                font.pixelSize: 12
                color: pageOutlineColor
                visible: text.length > 0
            }
        }
        
        // Offline option
        Rectangle {
            Layout.fillWidth: true
            Layout.maximumWidth: 600
            implicitHeight: offlineLayout.implicitHeight + 24
            color: pageSurfaceContainerHighColor
            radius: 12
            border.color: skipNetworkCheckbox.checked ? pagePrimaryColor : "transparent"
            border.width: 2
            
            RowLayout {
                id: offlineLayout
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                
                CheckBox {
                    id: skipNetworkCheckbox
                    checked: false
                    
                    indicator: Rectangle {
                        implicitWidth: 20
                        implicitHeight: 20
                        radius: 4
                        border.color: pageOutlineColor
                        border.width: 2
                        color: skipNetworkCheckbox.checked ? pagePrimaryColor : "transparent"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            color: pageBackgroundColor
                            font.pixelSize: 14
                            visible: skipNetworkCheckbox.checked
                        }
                    }
                }
                
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    
                    Text {
                        text: "Continue without network connection"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: pageTextColor
                    }
                    
                    Text {
                        text: "Install using only packages included on the installation media"
                        font.pixelSize: 12
                        color: pageOutlineColor
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
    
    // WiFi password dialog
    Dialog {
        id: wifiPasswordDialog
        property string ssid: ""
        property string security: ""
        
        title: "Connect to " + ssid
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
                text: "Security: " + wifiPasswordDialog.security
                font.pixelSize: 12
                color: pageOutlineColor
            }
            
            TextField {
                id: passwordField
                Layout.fillWidth: true
                placeholderText: "Enter password..."
                echoMode: showPasswordCheckbox.checked ? TextInput.Normal : TextInput.Password
                
                background: Rectangle {
                    color: pageSurfaceContainerHighColor
                    radius: 6
                    border.color: passwordField.activeFocus ? pagePrimaryColor : pageOutlineColor
                    border.width: passwordField.activeFocus ? 2 : 1
                }
                
                color: pageTextColor
                padding: 12
            }
            
            CheckBox {
                id: showPasswordCheckbox
                text: "Show password"
                checked: false
                
                contentItem: Text {
                    text: showPasswordCheckbox.text
                    font.pixelSize: 12
                    color: pageTextColor
                    leftPadding: showPasswordCheckbox.indicator.width + 8
                    verticalAlignment: Text.AlignVCenter
                }
                
                indicator: Rectangle {
                    implicitWidth: 16
                    implicitHeight: 16
                    radius: 3
                    border.color: pageOutlineColor
                    border.width: 2
                    color: showPasswordCheckbox.checked ? pagePrimaryColor : "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "✓"
                        color: pageBackgroundColor
                        font.pixelSize: 10
                        visible: showPasswordCheckbox.checked
                    }
                }
            }
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                
                Item { Layout.fillWidth: true }
                
                Button {
                    text: "Cancel"
                    onClicked: wifiPasswordDialog.close()
                    
                    background: Rectangle {
                        color: parent.down ? Qt.darker(pageSurfaceColor, 1.2) : 
                               parent.hovered ? Qt.lighter(pageSurfaceColor, 1.1) : pageSurfaceColor
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
                    text: "Connect"
                    onClicked: {
                        wifiConnectProc.ssid = wifiPasswordDialog.ssid
                        wifiConnectProc.password = passwordField.text
                        wifiConnectProc.running = true
                        wifiPasswordDialog.close()
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
}
