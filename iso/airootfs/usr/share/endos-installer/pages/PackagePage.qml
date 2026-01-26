import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io

Rectangle {
    id: packagePage
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
    
    // Package search process
    Process {
        id: packageSearchProc
        property string query: ""
        command: ["bash", "-c", `pacman -Ss "^${query}$" 2>/dev/null | head -20`]
        running: false
        
        stdout: SplitParser {
            onRead: data => {
                const lines = data.trim().split('\n')
                searchResults.text = lines.length > 0 ? data : "No packages found"
            }
        }
    }
    
    Component.onCompleted: {
        // Populate default packages
        optionalPackagesModel.clear()
        
        const packages = [
            {category: "Browsers", name: "firefox", description: "Fast and privacy-focused web browser", selected: true},
            {category: "Browsers", name: "chromium", description: "Open-source web browser from Google", selected: false},
            {category: "Office", name: "libreoffice-fresh", description: "Full-featured office suite", selected: false},
            {category: "Office", name: "onlyoffice-bin", description: "Microsoft Office compatible suite", selected: false},
            {category: "Development", name: "code", description: "Visual Studio Code", selected: false},
            {category: "Development", name: "git", description: "Version control system", selected: true},
            {category: "Development", name: "docker", description: "Container platform", selected: false},
            {category: "Development", name: "nodejs", description: "JavaScript runtime", selected: false},
            {category: "Development", name: "python", description: "Python programming language", selected: true},
            {category: "Multimedia", name: "vlc", description: "Versatile media player", selected: false},
            {category: "Multimedia", name: "gimp", description: "Image editing software", selected: false},
            {category: "Multimedia", name: "obs-studio", description: "Screen recording and streaming", selected: false},
            {category: "Multimedia", name: "audacity", description: "Audio editor", selected: false},
            {category: "Gaming", name: "steam", description: "Gaming platform", selected: false},
            {category: "Gaming", name: "lutris", description: "Game launcher", selected: false},
            {category: "Gaming", name: "wine", description: "Windows compatibility layer", selected: false},
            {category: "Utilities", name: "bleachbit", description: "System cleaner", selected: false},
            {category: "Utilities", name: "gparted", description: "Partition editor", selected: false}
        ]
        
        for (const pkg of packages) {
            optionalPackagesModel.append(pkg)
        }
        
        updatePackageList()
    }
    
    function updatePackageList() {
        const selectedPackages = []
        for (let i = 0; i < optionalPackagesModel.count; i++) {
            const pkg = optionalPackagesModel.get(i)
            if (pkg.selected) {
                selectedPackages.push(pkg.name)
            }
        }
        root.installConfig.optionalPackages = selectedPackages
    }
    
    ListModel {
        id: optionalPackagesModel
    }
    
    ListModel {
        id: customPackagesModel
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 24
        
        // Page title
        Text {
            text: "Package Selection"
            font.pixelSize: 28
            font.weight: Font.Bold
            color: pageTextColor
        }
        
        Text {
            text: "Choose additional software to install"
            font.pixelSize: 14
            color: pageOutlineColor
            Layout.bottomMargin: 8
        }
        
        // Online/Offline status
        Rectangle {
            Layout.fillWidth: true
            Layout.maximumWidth: 700
            implicitHeight: statusRow.implicitHeight + 16
            color: root.installConfig.isOnline ? pageSurfaceContainerHighColor : "#ff555520"
            radius: 8
            border.color: root.installConfig.isOnline ? pagePrimaryColor : "#ff5555"
            border.width: 1
            
            RowLayout {
                id: statusRow
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12
                
                Rectangle {
                    width: 10
                    height: 10
                    radius: 5
                    color: root.installConfig.isOnline ? "#4CAF50" : "#ff5555"
                }
                
                Text {
                    text: root.installConfig.isOnline ? 
                          "Online: You can install additional packages and search the repositories" :
                          "Offline: Only packages included on the installation media can be installed"
                    font.pixelSize: 13
                    color: pageTextColor
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        }
        
        // Tab bar for categories
        TabBar {
            id: tabBar
            Layout.fillWidth: true
            Layout.maximumWidth: 700
            
            background: Rectangle {
                color: pageSurfaceColor
                radius: 8
            }
            
            TabButton {
                text: "Optional Packages"
                
                background: Rectangle {
                    color: parent.checked ? pageSurfaceContainerHighColor : "transparent"
                    radius: 6
                }
                
                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 14
                    color: pageTextColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            TabButton {
                text: "Custom Packages"
                enabled: root.installConfig.isOnline
                
                background: Rectangle {
                    color: parent.checked ? pageSurfaceContainerHighColor : "transparent"
                    radius: 6
                    opacity: parent.enabled ? 1.0 : 0.5
                }
                
                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 14
                    color: pageTextColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
        
        // Stack layout for tab content
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex
            
            // Optional packages tab
            Rectangle {
                color: "transparent"
                
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12
                    
                    Text {
                        text: "Select from curated packages by category"
                        font.pixelSize: 13
                        color: pageOutlineColor
                    }
                    
                    // Category filter
                    ComboBox {
                        id: categoryFilter
                        Layout.fillWidth: true
                        Layout.maximumWidth: 300
                        
                        model: ["All", "Browsers", "Office", "Development", "Multimedia", "Gaming", "Utilities"]
                        currentIndex: 0
                        
                        background: Rectangle {
                            color: pageSurfaceContainerHighColor
                            radius: 6
                            border.color: categoryFilter.activeFocus ? pagePrimaryColor : pageOutlineColor
                            border.width: 1
                        }
                        
                        contentItem: Text {
                            leftPadding: 12
                            rightPadding: categoryFilter.indicator.width + 12
                            text: categoryFilter.displayText
                            font.pixelSize: 13
                            color: pageTextColor
                            verticalAlignment: Text.AlignVCenter
                        }
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
                            anchors.margins: 8
                            clip: true
                            
                            ListView {
                                id: packageList
                                model: optionalPackagesModel
                                spacing: 4
                                
                                delegate: Rectangle {
                                    width: packageList.width
                                    height: 60
                                    color: "transparent"
                                    visible: categoryFilter.currentText === "All" || model.category === categoryFilter.currentText
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 12
                                        
                                        CheckBox {
                                            id: packageCheckbox
                                            checked: model.selected
                                            
                                            onCheckedChanged: {
                                                optionalPackagesModel.setProperty(index, "selected", checked)
                                                updatePackageList()
                                            }
                                            
                                            indicator: Rectangle {
                                                implicitWidth: 20
                                                implicitHeight: 20
                                                radius: 4
                                                border.color: pageOutlineColor
                                                border.width: 2
                                                color: packageCheckbox.checked ? pagePrimaryColor : "transparent"
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "✓"
                                                    color: pageBackgroundColor
                                                    font.pixelSize: 14
                                                    visible: packageCheckbox.checked
                                                }
                                            }
                                        }
                                        
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            
                                            Text {
                                                text: model.name
                                                font.pixelSize: 14
                                                font.weight: Font.Medium
                                                color: pageTextColor
                                            }
                                            
                                            Text {
                                                text: model.description
                                                font.pixelSize: 11
                                                color: pageOutlineColor
                                                Layout.fillWidth: true
                                                wrapMode: Text.WordWrap
                                            }
                                        }
                                        
                                        Rectangle {
                                            implicitWidth: categoryBadge.implicitWidth + 16
                                            implicitHeight: 20
                                            radius: 10
                                            color: pageSurfaceContainerHighColor
                                            
                                            Text {
                                                id: categoryBadge
                                                anchors.centerIn: parent
                                                text: model.category
                                                font.pixelSize: 10
                                                color: pageTextColor
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Package count
                    Text {
                        text: `${root.installConfig.optionalPackages.length} optional packages selected`
                        font.pixelSize: 12
                        color: pageOutlineColor
                    }
                }
            }
            
            // Custom packages tab
            Rectangle {
                color: "transparent"
                
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12
                    
                    Text {
                        text: "Add custom packages from official repositories"
                        font.pixelSize: 13
                        color: pageOutlineColor
                    }
                    
                    // Package input
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        
                        TextField {
                            id: customPackageField
                            Layout.fillWidth: true
                            Layout.maximumWidth: 400
                            placeholderText: "Enter package name..."
                            
                            background: Rectangle {
                                color: pageSurfaceContainerHighColor
                                radius: 6
                                border.color: customPackageField.activeFocus ? pagePrimaryColor : pageOutlineColor
                                border.width: customPackageField.activeFocus ? 2 : 1
                            }
                            
                            color: pageTextColor
                            padding: 12
                            
                            Keys.onReturnPressed: {
                                if (text.trim().length > 0) {
                                    addPackageButton.clicked()
                                }
                            }
                        }
                        
                        Button {
                            id: searchButton
                            text: "Search"
                            enabled: customPackageField.text.trim().length > 0
                            
                            onClicked: {
                                packageSearchProc.query = customPackageField.text.trim()
                                packageSearchProc.exec()
                            }
                            
                            background: Rectangle {
                                color: parent.down ? Qt.darker(pageSurfaceContainerHighColor, 1.2) : 
                                       parent.hovered ? Qt.lighter(pageSurfaceContainerHighColor, 1.1) : pageSurfaceContainerHighColor
                                radius: 6
                                opacity: parent.enabled ? 1.0 : 0.5
                            }
                            
                            contentItem: Text {
                                text: parent.text
                                color: pageTextColor
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        
                        Button {
                            id: addPackageButton
                            text: "Add"
                            enabled: customPackageField.text.trim().length > 0
                            
                            onClicked: {
                                const pkgName = customPackageField.text.trim()
                                if (pkgName.length > 0) {
                                    // Check if package already exists
                                    let exists = false
                                    for (let i = 0; i < customPackagesModel.count; i++) {
                                        if (customPackagesModel.get(i).name === pkgName) {
                                            exists = true
                                            break
                                        }
                                    }
                                    
                                    if (!exists) {
                                        customPackagesModel.append({name: pkgName})
                                        updateCustomPackageList()
                                        customPackageField.text = ""
                                    }
                                }
                            }
                            
                            background: Rectangle {
                                color: parent.down ? Qt.darker(pagePrimaryColor, 1.2) : 
                                       parent.hovered ? Qt.lighter(pagePrimaryColor, 1.1) : pagePrimaryColor
                                radius: 6
                                opacity: parent.enabled ? 1.0 : 0.5
                            }
                            
                            contentItem: Text {
                                text: parent.text
                                color: pageBackgroundColor
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                    
                    // Search results
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 100
                        color: pageSurfaceContainerHighColor
                        radius: 6
                        visible: searchResults.text.length > 0
                        
                        ScrollView {
                            anchors.fill: parent
                            anchors.margins: 8
                            clip: true
                            
                            Text {
                                id: searchResults
                                text: ""
                                font.pixelSize: 11
                                font.family: "monospace"
                                color: pageTextColor
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                    
                    // Custom package list
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: pageSurfaceColor
                        radius: 8
                        border.color: pageOutlineColor
                        border.width: 1
                        
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8
                            
                            Text {
                                text: "Custom packages to install:"
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                color: pageTextColor
                            }
                            
                            ScrollView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                
                                ListView {
                                    id: customPackageList
                                    model: customPackagesModel
                                    spacing: 4
                                    
                                    delegate: Rectangle {
                                        width: customPackageList.width
                                        height: 36
                                        color: mouseArea.containsMouse ? pageSurfaceContainerHighColor : "transparent"
                                        radius: 4
                                        
                                        MouseArea {
                                            id: mouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                        }
                                        
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 12
                                            
                                            Text {
                                                text: "📦"
                                                font.pixelSize: 16
                                            }
                                            
                                            Text {
                                                text: model.name
                                                font.pixelSize: 13
                                                font.family: "monospace"
                                                color: pageTextColor
                                                Layout.fillWidth: true
                                            }
                                            
                                            Button {
                                                text: "Remove"
                                                
                                                onClicked: {
                                                    customPackagesModel.remove(index)
                                                    updateCustomPackageList()
                                                }
                                                
                                                background: Rectangle {
                                                    color: parent.down ? Qt.darker("#ff5555", 1.2) : 
                                                           parent.hovered ? Qt.lighter("#ff5555", 1.1) : "#ff5555"
                                                    radius: 4
                                                }
                                                
                                                contentItem: Text {
                                                    text: parent.text
                                                    font.pixelSize: 11
                                                    color: "white"
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Empty state
                                    Rectangle {
                                        visible: customPackagesModel.count === 0
                                        anchors.centerIn: parent
                                        width: parent.width * 0.8
                                        height: 80
                                        color: "transparent"
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: "No custom packages added\nEnter a package name above and click 'Add'"
                                            font.pixelSize: 13
                                            color: pageOutlineColor
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    Text {
                        text: `${customPackagesModel.count} custom packages added`
                        font.pixelSize: 12
                        color: pageOutlineColor
                    }
                }
            }
        }
    }
    
    function updateCustomPackageList() {
        const customPackages = []
        for (let i = 0; i < customPackagesModel.count; i++) {
            customPackages.push(customPackagesModel.get(i).name)
        }
        root.installConfig.customPackages = customPackages
    }
}
