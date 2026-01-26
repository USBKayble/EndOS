import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: reviewPage
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
        anchors.fill: parent
        anchors.margins: 32
        spacing: 24
        
        // Page title
        Text {
            text: "Review Installation"
            font.pixelSize: 28
            font.weight: Font.Bold
            color: pageTextColor
        }
        
        Text {
            text: "Please review your installation settings before proceeding"
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
                spacing: 16
                
                // Language & Regional Settings
                ReviewSection {
                    title: "Language & Regional Settings"
                    items: [
                        {label: "Language", value: root.installConfig.language},
                        {label: "Timezone", value: root.installConfig.timezone},
                        {label: "Keyboard Layout", value: root.installConfig.keyboardLayout}
                    ]
                }
                
                // Network
                ReviewSection {
                    title: "Network"
                    items: [
                        {label: "Status", value: root.installConfig.isOnline ? "Connected" : "Offline"},
                        {label: "Mode", value: root.installConfig.isOnline ? "Online Installation" : "Offline Installation"}
                    ]
                }
                
                // Disk Configuration
                ReviewSection {
                    title: "Disk Configuration"
                    warning: root.installConfig.installMode === "auto" ? "⚠️ All data on the selected disk will be erased" : ""
                    items: [
                        {label: "Target Disk", value: root.installConfig.targetDisk},
                        {label: "Installation Mode", value: 
                            root.installConfig.installMode === "auto" ? "Erase Disk (Clean Install)" :
                            root.installConfig.installMode === "dualboot" ? "Dual Boot (Alongside Existing OS)" :
                            "Manual Partitioning"
                        },
                        {label: "Dual Boot", value: root.installConfig.isDualBoot ? "Yes" : "No"},
                        {label: "Boot Partition Size", value: root.installConfig.bootPartitionSize + " MB"}
                    ]
                }
                
                // User Account
                ReviewSection {
                    title: "User Account"
                    items: [
                        {label: "Full Name", value: root.installConfig.fullName},
                        {label: "Username", value: root.installConfig.username},
                        {label: "Password", value: "●".repeat(10)},
                        {label: "Root Account", value: root.installConfig.enableRootAccount ? "Enabled" : "Disabled"},
                        {label: "Login Screen", value: "Auto-login to desktop (lock on boot can be configured in settings)"}
                    ]
                }
                
                // System Configuration
                ReviewSection {
                    title: "System Configuration"
                    items: [
                        {label: "Hostname", value: root.installConfig.hostname},
                        {label: "Network Time (NTP)", value: root.installConfig.enableNTP ? "Enabled" : "Disabled"},
                        {label: "Multilib Repository", value: root.installConfig.enableMultilib ? "Enabled" : "Disabled"},
                        {label: "AUR Helper", value: root.installConfig.aurHelper}
                    ]
                }
                
                // Packages
                ReviewSection {
                    title: "Software Packages"
                    items: [
                        {label: "Base System", value: "Linux kernel, Hyprland, Essential utilities"},
                        {label: "Optional Packages", value: root.installConfig.optionalPackages.length + " selected"},
                        {label: "Custom Packages", value: root.installConfig.customPackages.length + " added"}
                    ]
                }
                
                // Hardware
                ReviewSection {
                    title: "Hardware Detection"
                    items: [
                        {label: "CPU", value: root.installConfig.detectedCPU || "Detecting..."},
                        {label: "GPU", value: root.installConfig.detectedGPU || "Detecting..."},
                        {label: "NVIDIA Drivers", value: root.installConfig.needsNvidiaDriver ? "Will be installed" : "Not needed"},
                        {label: "AMD Drivers", value: root.installConfig.needsAMDDriver ? "Will be installed" : "Not needed"}
                    ]
                }
                
                // Estimated installation info
                Rectangle {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 700
                    implicitHeight: estimateLayout.implicitHeight + 24
                    color: pageSurfaceContainerHighColor
                    radius: 12
                    
                    ColumnLayout {
                        id: estimateLayout
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12
                        
                        Text {
                            text: "Installation Estimate"
                            font.pixelSize: 16
                            font.weight: Font.Medium
                            color: pageTextColor
                        }
                        
                        Grid {
                            columns: 2
                            rowSpacing: 8
                            columnSpacing: 24
                            
                            Text {
                                text: "Estimated Time:"
                                font.pixelSize: 13
                                color: pageOutlineColor
                            }
                            Text {
                                text: root.installConfig.isOnline ? "15-30 minutes" : "10-15 minutes"
                                font.pixelSize: 13
                                color: pageTextColor
                            }
                            
                            Text {
                                text: "Disk Space Required:"
                                font.pixelSize: 13
                                color: pageOutlineColor
                            }
                            Text {
                                text: "~8-15 GB"
                                font.pixelSize: 13
                                color: pageTextColor
                            }
                            
                            Text {
                                text: "Total Packages:"
                                font.pixelSize: 13
                                color: pageOutlineColor
                            }
                            Text {
                                text: `~${200 + root.installConfig.optionalPackages.length + root.installConfig.customPackages.length} packages`
                                font.pixelSize: 13
                                color: pageTextColor
                            }
                        }
                    }
                }
                
                // Final confirmation
                Rectangle {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 700
                    implicitHeight: confirmLayout.implicitHeight + 24
                    color: "#ff555520"
                    radius: 12
                    border.color: "#ff5555"
                    border.width: 2
                    
                    ColumnLayout {
                        id: confirmLayout
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12
                        
                        RowLayout {
                            spacing: 12
                            
                            Text {
                                text: "⚠️"
                                font.pixelSize: 24
                            }
                            
                            Text {
                                text: "Important: Please Read"
                                font.pixelSize: 16
                                font.weight: Font.Bold
                                color: pageTextColor
                            }
                        }
                        
                        Text {
                            text: root.installConfig.installMode === "auto" ?
                                  "You are about to permanently erase all data on " + root.installConfig.targetDisk + ". This action cannot be undone." :
                                  root.installConfig.isDualBoot ?
                                  "You are about to modify partitions on " + root.installConfig.targetDisk + ". Make sure you have backups of important data." :
                                  "You are about to install EndOS. Make sure your partition layout is correct."
                            font.pixelSize: 13
                            color: pageTextColor
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                        
                        CheckBox {
                            id: confirmCheckbox
                            text: "I understand and want to proceed with the installation"
                            checked: false
                            
                            contentItem: Text {
                                text: confirmCheckbox.text
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                color: pageTextColor
                                leftPadding: confirmCheckbox.indicator.width + 8
                                verticalAlignment: Text.AlignVCenter
                                wrapMode: Text.WordWrap
                            }
                            
                            indicator: Rectangle {
                                implicitWidth: 20
                                implicitHeight: 20
                                radius: 4
                                border.color: "#ff5555"
                                border.width: 2
                                color: confirmCheckbox.checked ? pagePrimaryColor : "transparent"
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: pageBackgroundColor
                                    font.pixelSize: 14
                                    visible: confirmCheckbox.checked
                                }
                            }
                        }
                    }
                }
                
                Item { height: 20 }
            }
        }
    }
    
    // Custom component for review sections
    component ReviewSection: Rectangle {
        property string title: ""
        property var items: []
        property string warning: ""
        
        Layout.fillWidth: true
        Layout.maximumWidth: 700
        implicitHeight: sectionLayout.implicitHeight + 24
        color: pageSurfaceColor
        radius: 8
        border.color: pageOutlineColor
        border.width: 1
        
        ColumnLayout {
            id: sectionLayout
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            
            Text {
                text: title
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
                
                Repeater {
                    model: items
                    
                    delegate: Item {
                        width: parent.width / 2
                        height: Math.max(labelText.implicitHeight, valueText.implicitHeight)
                        
                        Text {
                            id: labelText
                            text: modelData.label + ":"
                            font.pixelSize: 13
                            color: pageOutlineColor
                            visible: index % 2 === 0
                        }
                        
                        Text {
                            id: valueText
                            text: modelData.value
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: pageTextColor
                            wrapMode: Text.WordWrap
                            visible: index % 2 === 1
                        }
                    }
                }
            }
            
            Text {
                text: warning
                font.pixelSize: 12
                color: "#ff5555"
                visible: warning.length > 0
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
        }
    }
}
