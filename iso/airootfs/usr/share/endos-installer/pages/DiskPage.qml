import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io

Rectangle {
    id: diskPage
    property var root
    
    // Color properties with fallback defaults
    readonly property color pageTextColor: root ? root.textOnSurfaceColor : "#e6e1e1"
    readonly property color pageBackgroundColor: root ? pageBackgroundColor : "#141313"
    readonly property color pageSurfaceColor: root ? pageSurfaceColor : "#1c1b1c"
    readonly property color pageSurfaceContainerColor: root ? pageSurfaceContainerColor : "#201f20"
    readonly property color pageSurfaceContainerHighColor: root ? pageSurfaceContainerHighColor : "#2b2a2a"
    readonly property color pagePrimaryColor: root ? pagePrimaryColor : "#cbc4cb"
    readonly property color pageOutlineColor: root ? pageOutlineColor : "#948f94"
    
    color: "transparent"
    
    // Disk detection process
    Process {
        id: diskDetectProc
        command: root && root.scriptBasePath 
            ? ["bash", "-c", root.scriptBasePath + "/detect-disks.sh"]
            : ["bash", "-c", "./scripts/detect-disks.sh"]
        running: false
        
        stdout: SplitParser {
            onRead: data => {
                try {
                    const disks = JSON.parse(data)
                    diskModel.clear()
                    
                    for (const disk of disks) {
                        diskModel.append(disk)
                    }
                    
                    if (diskModel.count > 0) {
                        diskCombo.currentIndex = 0
                    }
                } catch (e) {
                    console.error("Failed to parse disk data:", e, data)
                }
            }
        }
    }
    
    // OS detection process
    Process {
        id: osDetectProc
        property string disk: ""
        command: ["bash", "-c", `/usr/share/endos-installer/scripts/detect-os.sh "${disk}"`]
        running: false
        
        stdout: SplitParser {
            onRead: data => {
                try {
                    const osInfo = JSON.parse(data)
                    root.installConfig.existingOS = osInfo
                    root.installConfig.isDualBoot = osInfo.length > 0
                    
                    if (osInfo.length > 0) {
                        dualBootCard.visible = true
                        osListText.text = osInfo.map(os => `• ${os.name} on ${os.partition}`).join('\n')
                    } else {
                        dualBootCard.visible = false
                    }
                } catch (e) {
                    console.error("Failed to parse OS data:", e)
                    root.installConfig.existingOS = []
                    root.installConfig.isDualBoot = false
                    dualBootCard.visible = false
                }
            }
        }
    }
    
    ListModel {
        id: diskModel
    }
    
    Component.onCompleted: {
        diskDetectProc.running = true
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 24
        
        // Page title
        Text {
            text: "Disk Partitioning"
            font.pixelSize: 28
            font.weight: Font.Bold
            color: pageTextColor
        }
        
        Text {
            text: "Choose where to install EndOS"
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
                spacing: 20
                
                // Disk selection
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    
                    Text {
                        text: "Select Installation Disk"
                        font.pixelSize: 18
                        font.weight: Font.Medium
                        color: pageTextColor
                    }
                    
                    ComboBox {
                        id: diskCombo
                        Layout.fillWidth: true
                        Layout.maximumWidth: 600
                        
                        model: diskModel
                        textRole: "displayName"
                        
                        delegate: ItemDelegate {
                            width: diskCombo.width
                            contentItem: ColumnLayout {
                                spacing: 4
                                
                                Text {
                                    text: model.displayName
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    color: pageTextColor
                                }
                                
                                Text {
                                    text: `Size: ${model.size} | Type: ${model.type}`
                                    font.pixelSize: 11
                                    color: pageOutlineColor
                                }
                            }
                            
                            background: Rectangle {
                                color: parent.hovered ? pageSurfaceContainerHighColor : "transparent"
                                radius: 4
                            }
                        }
                        
                        background: Rectangle {
                            color: pageSurfaceContainerHighColor
                            radius: 6
                            border.color: diskCombo.activeFocus ? pagePrimaryColor : pageOutlineColor
                            border.width: diskCombo.activeFocus ? 2 : 1
                        }
                        
                        contentItem: Text {
                            leftPadding: 12
                            rightPadding: diskCombo.indicator.width + 12
                            text: diskCombo.displayText
                            font.pixelSize: 14
                            color: pageTextColor
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onCurrentIndexChanged: {
                            if (currentIndex >= 0) {
                                const disk = diskModel.get(currentIndex)
                                root.installConfig.targetDisk = disk.path
                                
                                // Detect existing OS on this disk
                                osDetectProc.disk = disk.path
                                osDetectProc.running = true
                            }
                        }
                    }
                    
                    // Disk info card
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 600
                        implicitHeight: diskInfoLayout.implicitHeight + 24
                        color: pageSurfaceColor
                        radius: 8
                        border.color: pageOutlineColor
                        border.width: 1
                        visible: diskCombo.currentIndex >= 0
                        
                        ColumnLayout {
                            id: diskInfoLayout
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 8
                            
                            RowLayout {
                                Layout.fillWidth: true
                                
                                Text {
                                    text: "Disk Information"
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    color: pageTextColor
                                }
                                
                                Item { Layout.fillWidth: true }
                                
                                Button {
                                    text: "Refresh"
                                    onClicked: diskDetectProc.running = true
                                    
                                    background: Rectangle {
                                        color: parent.down ? Qt.darker(pageSurfaceContainerHighColor, 1.2) : 
                                               parent.hovered ? Qt.lighter(pageSurfaceContainerHighColor, 1.1) : pageSurfaceContainerHighColor
                                        radius: 4
                                    }
                                    
                                    contentItem: Text {
                                        text: parent.text
                                        font.pixelSize: 11
                                        color: pageTextColor
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                            
                            Grid {
                                columns: 2
                                rowSpacing: 6
                                columnSpacing: 16
                                
                                Text {
                                    text: "Path:"
                                    font.pixelSize: 12
                                    color: pageOutlineColor
                                }
                                Text {
                                    text: diskCombo.currentIndex >= 0 ? diskModel.get(diskCombo.currentIndex).path : "-"
                                    font.pixelSize: 12
                                    color: pageTextColor
                                    font.family: "monospace"
                                }
                                
                                Text {
                                    text: "Size:"
                                    font.pixelSize: 12
                                    color: pageOutlineColor
                                }
                                Text {
                                    text: diskCombo.currentIndex >= 0 ? diskModel.get(diskCombo.currentIndex).size : "-"
                                    font.pixelSize: 12
                                    color: pageTextColor
                                }
                                
                                Text {
                                    text: "Type:"
                                    font.pixelSize: 12
                                    color: pageOutlineColor
                                }
                                Text {
                                    text: diskCombo.currentIndex >= 0 ? diskModel.get(diskCombo.currentIndex).type : "-"
                                    font.pixelSize: 12
                                    color: pageTextColor
                                }
                            }
                        }
                    }
                }
                
                // Dual-boot detection card
                Rectangle {
                    id: dualBootCard
                    Layout.fillWidth: true
                    Layout.maximumWidth: 600
                    implicitHeight: dualBootLayout.implicitHeight + 24
                    color: "#FFB74D20" // Orange tint
                    radius: 12
                    border.color: "#FFB74D"
                    border.width: 2
                    visible: false
                    
                    ColumnLayout {
                        id: dualBootLayout
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
                                text: "Existing Operating System Detected"
                                font.pixelSize: 16
                                font.weight: Font.Bold
                                color: pageTextColor
                            }
                        }
                        
                        Text {
                            text: "We found the following operating systems on this disk:"
                            font.pixelSize: 13
                            color: pageTextColor
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: osListText.implicitHeight + 16
                            color: pageSurfaceContainerColor
                            radius: 6
                            
                            Text {
                                id: osListText
                                anchors.fill: parent
                                anchors.margins: 12
                                text: ""
                                font.pixelSize: 12
                                font.family: "monospace"
                                color: pageTextColor
                            }
                        }
                    }
                }
                
                // Installation mode selection
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    
                    Text {
                        text: "Installation Mode"
                        font.pixelSize: 18
                        font.weight: Font.Medium
                        color: pageTextColor
                    }
                    
                    // Auto mode (erase disk)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 600
                        implicitHeight: autoModeLayout.implicitHeight + 24
                        color: autoModeRadio.checked ? pageSurfaceContainerHighColor : pageSurfaceColor
                        radius: 8
                        border.color: autoModeRadio.checked ? pagePrimaryColor : pageOutlineColor
                        border.width: autoModeRadio.checked ? 2 : 1
                        
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                autoModeRadio.checked = true
                                root.installConfig.installMode = "auto"
                                root.installConfig.isDualBoot = false
                            }
                        }
                        
                        RowLayout {
                            id: autoModeLayout
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12
                            
                            RadioButton {
                                id: autoModeRadio
                                checked: true
                                
                                onCheckedChanged: {
                                    if (checked) {
                                        root.installConfig.installMode = "auto"
                                        root.installConfig.isDualBoot = false
                                    }
                                }
                                
                                indicator: Rectangle {
                                    implicitWidth: 20
                                    implicitHeight: 20
                                    radius: 10
                                    border.color: pageOutlineColor
                                    border.width: 2
                                    color: "transparent"
                                    
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 10
                                        height: 10
                                        radius: 5
                                        color: pagePrimaryColor
                                        visible: autoModeRadio.checked
                                    }
                                }
                            }
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                
                                Text {
                                    text: "Erase Disk and Install EndOS"
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    color: pageTextColor
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                }
                                
                                Text {
                                    text: "⚠️ Warning: This will permanently delete all data on the selected disk"
                                    font.pixelSize: 11
                                    color: "#ff5555"
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                }
                                
                                Text {
                                    text: "Recommended for new installations. Creates optimal partition layout automatically."
                                    font.pixelSize: 11
                                    color: pageOutlineColor
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                    
                    // Dual-boot mode
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 600
                        implicitHeight: dualBootModeLayout.implicitHeight + 24
                        color: dualBootRadio.checked ? pageSurfaceContainerHighColor : pageSurfaceColor
                        radius: 8
                        border.color: dualBootRadio.checked ? pagePrimaryColor : pageOutlineColor
                        border.width: dualBootRadio.checked ? 2 : 1
                        visible: dualBootCard.visible
                        
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                dualBootRadio.checked = true
                                root.installConfig.installMode = "dualboot"
                                root.installConfig.isDualBoot = true
                            }
                        }
                        
                        ColumnLayout {
                            id: dualBootModeLayout
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12
                            
                            RowLayout {
                                spacing: 12
                                
                                RadioButton {
                                    id: dualBootRadio
                                    checked: false
                                    
                                    onCheckedChanged: {
                                        if (checked) {
                                            root.installConfig.installMode = "dualboot"
                                            root.installConfig.isDualBoot = true
                                        }
                                    }
                                    
                                    indicator: Rectangle {
                                        implicitWidth: 20
                                        implicitHeight: 20
                                        radius: 10
                                        border.color: pageOutlineColor
                                        border.width: 2
                                        color: "transparent"
                                        
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 10
                                            height: 10
                                            radius: 5
                                            color: pagePrimaryColor
                                            visible: dualBootRadio.checked
                                        }
                                    }
                                }
                                
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    
                                    Text {
                                        text: "Install Alongside Existing OS (Dual Boot)"
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: pageTextColor
                                    }
                                    
                                    Text {
                                        text: "Shrink existing partition and install EndOS in the freed space"
                                        font.pixelSize: 11
                                        color: pageOutlineColor
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }
                            
                            // Partition resize slider (shown when dual-boot is selected)
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                visible: dualBootRadio.checked
                                
                                Text {
                                    text: "Allocate space for EndOS:"
                                    font.pixelSize: 13
                                    color: pageTextColor
                                }
                                
                                // Visual partition bar
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 40
                                    radius: 6
                                    color: pageSurfaceContainerColor
                                    border.color: pageOutlineColor
                                    border.width: 1
                                    
                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        spacing: 0
                                        
                                        // Existing OS partition
                                        Rectangle {
                                            width: parent.width * ((100 - partitionSlider.value) / 100)
                                            height: parent.height
                                            radius: 4
                                            color: "#FFB74D"
                                            
                                            Text {
                                                anchors.centerIn: parent
                                                text: "Existing OS"
                                                font.pixelSize: 11
                                                color: pageBackgroundColor
                                                visible: parent.width > 80
                                            }
                                        }
                                        
                                        // EndOS partition
                                        Rectangle {
                                            width: parent.width * (partitionSlider.value / 100)
                                            height: parent.height
                                            radius: 4
                                            color: pagePrimaryColor
                                            
                                            Text {
                                                anchors.centerIn: parent
                                                text: "EndOS"
                                                font.pixelSize: 11
                                                color: pageBackgroundColor
                                                visible: parent.width > 60
                                            }
                                        }
                                    }
                                }
                                
                                Slider {
                                    id: partitionSlider
                                    Layout.fillWidth: true
                                    from: 20 // Minimum 20% for EndOS (roughly 20GB on 100GB disk)
                                    to: 80   // Maximum 80% (leave at least 20% for existing OS)
                                    value: 50
                                    stepSize: 5
                                    
                                    background: Rectangle {
                                        x: partitionSlider.leftPadding
                                        y: partitionSlider.topPadding + partitionSlider.availableHeight / 2 - height / 2
                                        implicitWidth: 200
                                        implicitHeight: 4
                                        width: partitionSlider.availableWidth
                                        height: implicitHeight
                                        radius: 2
                                        color: pageOutlineColor
                                        
                                        Rectangle {
                                            width: partitionSlider.visualPosition * parent.width
                                            height: parent.height
                                            color: pagePrimaryColor
                                            radius: 2
                                        }
                                    }
                                    
                                    handle: Rectangle {
                                        x: partitionSlider.leftPadding + partitionSlider.visualPosition * (partitionSlider.availableWidth - width)
                                        y: partitionSlider.topPadding + partitionSlider.availableHeight / 2 - height / 2
                                        implicitWidth: 20
                                        implicitHeight: 20
                                        radius: 10
                                        color: partitionSlider.pressed ? Qt.darker(pagePrimaryColor, 1.2) : pagePrimaryColor
                                        border.color: pageBackgroundColor
                                        border.width: 2
                                    }
                                }
                                
                                Row {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    
                                    Text {
                                        text: `EndOS: ${Math.round(partitionSlider.value)}%`
                                        font.pixelSize: 12
                                        color: pageTextColor
                                    }
                                    
                                    Text {
                                        text: "•"
                                        font.pixelSize: 12
                                        color: pageOutlineColor
                                    }
                                    
                                    Text {
                                        text: `Existing OS: ${Math.round(100 - partitionSlider.value)}%`
                                        font.pixelSize: 12
                                        color: pageTextColor
                                    }
                                }
                                
                                // Warning about minimum space
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: warningText.implicitHeight + 16
                                    color: partitionSlider.value < 30 ? "#ff555520" : "transparent"
                                    radius: 6
                                    border.color: partitionSlider.value < 30 ? "#ff5555" : "transparent"
                                    border.width: partitionSlider.value < 30 ? 1 : 0
                                    visible: partitionSlider.value < 30
                                    
                                    Text {
                                        id: warningText
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        text: "⚠️ Warning: Less than 30% may not provide enough space for a full installation (minimum 20GB recommended)"
                                        font.pixelSize: 11
                                        color: "#ff5555"
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }
                        }
                    }
                    
                    // Manual partitioning mode
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 600
                        implicitHeight: manualModeLayout.implicitHeight + 24
                        color: manualModeRadio.checked ? pageSurfaceContainerHighColor : pageSurfaceColor
                        radius: 8
                        border.color: manualModeRadio.checked ? pagePrimaryColor : pageOutlineColor
                        border.width: manualModeRadio.checked ? 2 : 1
                        
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                manualModeRadio.checked = true
                                root.installConfig.installMode = "manual"
                            }
                        }
                        
                        RowLayout {
                            id: manualModeLayout
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12
                            
                            RadioButton {
                                id: manualModeRadio
                                checked: false
                                
                                onCheckedChanged: {
                                    if (checked) {
                                        root.installConfig.installMode = "manual"
                                    }
                                }
                                
                                indicator: Rectangle {
                                    implicitWidth: 20
                                    implicitHeight: 20
                                    radius: 10
                                    border.color: pageOutlineColor
                                    border.width: 2
                                    color: "transparent"
                                    
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 10
                                        height: 10
                                        radius: 5
                                        color: pagePrimaryColor
                                        visible: manualModeRadio.checked
                                    }
                                }
                            }
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                
                                Text {
                                    text: "Manual Partitioning (Advanced)"
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    color: pageTextColor
                                }
                                
                                Text {
                                    text: "Create custom partition layout using cfdisk or gparted"
                                    font.pixelSize: 11
                                    color: pageOutlineColor
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                }
                                
                                Text {
                                    text: "⚠️ For advanced users only - incorrect partitioning can result in data loss"
                                    font.pixelSize: 11
                                    color: "#ff5555"
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    visible: manualModeRadio.checked
                                }
                            }
                        }
                    }
                }
                
                // Boot partition warning
                Rectangle {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 600
                    implicitHeight: bootWarningLayout.implicitHeight + 24
                    color: "#FFB74D20"
                    radius: 8
                    border.color: "#FFB74D"
                    border.width: 1
                    visible: autoModeRadio.checked || dualBootRadio.checked
                    
                    ColumnLayout {
                        id: bootWarningLayout
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8
                        
                        Text {
                            text: "💡 Boot Partition Size"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: pageTextColor
                        }
                        
                        Text {
                            text: "A boot partition of at least 512MB is recommended for storing multiple kernels and bootloaders. Smaller boot partitions may limit future driver installations."
                            font.pixelSize: 12
                            color: pageTextColor
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            
                            Text {
                                text: "Boot partition size:"
                                font.pixelSize: 12
                                color: pageTextColor
                            }
                            
                            SpinBox {
                                id: bootSizeSpinBox
                                from: 256
                                to: 2048
                                value: 512
                                stepSize: 128
                                
                                onValueChanged: {
                                    root.installConfig.bootPartitionSize = value
                                }
                                
                                textFromValue: function(value) {
                                    return value + " MB"
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
