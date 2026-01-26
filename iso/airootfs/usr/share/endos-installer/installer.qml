//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io

ApplicationWindow {
    id: root
    
    // Window properties
    title: root.dryRun ? "EndOS Installer (DRY RUN - No Changes Will Be Made)" : "EndOS Installer"
    visible: true
    minimumWidth: 900
    minimumHeight: 650
    width: 1000
    height: 700
    
    // Check for dry-run mode
    // TODO: Read from environment variable when Quickshell supports it
    // For now, manually set to true for testing, false for production
    property bool dryRun: true  // Set to true for testing
    
    // Script base path - use current directory for development, /usr/share for production
    readonly property string scriptBasePath: "./scripts"  // Change to "/usr/share/endos-installer/scripts" for production
    
    // Installation state
    property var installConfig: ({
        // Language & Locale
        language: "en_US",
        timezone: "America/New_York",
        keyboardLayout: "us",
        
        // Network
        networkConfigured: false,
        isOnline: false,
        
        // Disk
        installMode: "auto", // "auto" or "manual"
        targetDisk: "",
        isDualBoot: false,
        existingOS: [],
        partitions: [],
        bootPartitionSize: 512, // MB
        swapSize: 0, // MB, 0 = no swap
        
        // User
        fullName: "",
        username: "",
        password: "",
        enableRootAccount: false,
        autoLogin: false,
        
        // Hostname
        hostname: "endos",
        enableNTP: true,
        enableMultilib: true,
        aurHelper: "yay",
        
        // Packages
        defaultPackages: [],
        optionalPackages: [],
        customPackages: [],
        
        // Hardware
        detectedGPU: "",
        detectedCPU: "",
        needsNvidiaDriver: false,
        needsAMDDriver: false,
        
        // Installation
        isInstalling: false,
        installProgress: 0,
        currentTask: "",
        installLogs: []
    })
    
    // Current page index (0 = welcome)
    property int currentPage: 0
    
    // Page list
    readonly property var pages: [
        "WelcomePage",
        "LanguagePage",
        "NetworkPage",
        "DiskPage",
        "UserPage",
        "HostnamePage",
        "PackagePage",
        "ReviewPage",
        "ProgressPage",
        "CompletionPage"
    ]
    
    // Theme colors - Material 3 colors matching dots-hyprland Appearance.qml
    // In production, these will load dynamically from Common.Appearance.m3colors
    // For development, hardcoded values matching the illogical-impulse theme
    readonly property color backgroundColor: "#141313"  // m3background
    readonly property color surfaceColor: "#1c1b1c"  // m3surfaceContainerLow
    readonly property color surfaceContainerColor: "#201f20"  // m3surfaceContainer
    readonly property color surfaceContainerHighColor: "#2b2a2a"  // m3surfaceContainerHigh
    readonly property color primaryColor: "#cbc4cb"  // m3primary
    readonly property color textOnSurfaceColor: "#e6e1e1"  // m3onSurface
    readonly property color textOnBackgroundColor: "#e6e1e1"  // m3onBackground
    readonly property color outlineColor: "#948f94"  // m3outline
    readonly property int windowRounding: 12
    
    // Background
    color: backgroundColor
    
    // Initialization timer - run once after window loads
    Timer {
        id: initTimer
        interval: 100
        running: true
        repeat: false
        onTriggered: {
            // Check network connectivity
            checkNetworkStatus()
            
            // Detect hardware
            detectHardware()
            
            // Load default packages
            loadDefaultPackages()
        }
    }
    
    // Functions
    function nextPage() {
        if (currentPage < pages.length - 1) {
            currentPage++
        }
    }
    
    function previousPage() {
        if (currentPage > 0) {
            currentPage--
        }
    }
    
    function goToPage(pageIndex) {
        if (pageIndex >= 0 && pageIndex < pages.length) {
            currentPage = pageIndex
        }
    }
    
    function checkNetworkStatus() {
        networkCheckProc.running = true
    }
    
    function detectHardware() {
        hardwareDetectProc.running = true
    }
    
    function loadDefaultPackages() {
        // Load default package list from file or hardcoded
        installConfig.defaultPackages = [
            "base",
            "linux",
            "linux-firmware",
            "hyprland",
            "quickshell",
            "firefox",
            "kitty",
            "dolphin"
        ]
    }
    
    function startInstallation() {
        // Write config to file using helper script
        configWriterProc.running = true
    }
    
    // Config writer process
    Process {
        id: configWriterProc
        command: [root.scriptBasePath + "/write-config.sh", JSON.stringify(root.installConfig)]
        running: false
        
        onExited: (exitCode) => {
            if (exitCode === 0) {
                // Config written successfully, start installation
                installConfig.isInstalling = true
                currentPage = 8 // Progress page
                installationProc.running = true
            } else {
                console.error("Failed to write config file")
            }
        }
    }
    
    // Processes
    Process {
        id: networkCheckProc
        command: ["bash", "-c", "ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1 && echo 'online' || echo 'offline'"]
        stdout: SplitParser {
            onRead: data => {
                const status = data.trim()
                root.installConfig.isOnline = (status === "online")
                root.installConfig.networkConfigured = root.installConfig.isOnline
                console.log("Network status:", status)
            }
        }
    }
    
    Process {
        id: hardwareDetectProc
        command: root.dryRun 
            ? [root.scriptBasePath + "/detect-hardware.sh", "--dry-run"]
            : [root.scriptBasePath + "/detect-hardware.sh"]
        running: false
        
        property string buffer: ""
        
        stdout: SplitParser {
            onRead: data => {
                // Accumulate output until we have complete JSON
                hardwareDetectProc.buffer += data
                
                // Try to parse when we see closing brace
                if (data.includes("}")) {
                    try {
                        const hardware = JSON.parse(hardwareDetectProc.buffer.trim())
                        root.installConfig.detectedGPU = hardware.gpu || ""
                        root.installConfig.detectedCPU = hardware.cpu || ""
                        root.installConfig.needsNvidiaDriver = hardware.needsNvidiaDriver || false
                        root.installConfig.needsAMDDriver = hardware.needsAMDDriver || false
                        console.log("Hardware detected:", JSON.stringify(hardware))
                        hardwareDetectProc.buffer = "" // Clear buffer after successful parse
                    } catch (e) {
                        console.error("Failed to parse hardware detection:", e, "Buffer:", hardwareDetectProc.buffer)
                    }
                }
            }
        }
    }
    
    Process {
        id: installationProc
        command: root.dryRun 
            ? [root.scriptBasePath + "/install.sh", "--dry-run", "/tmp/endos-install-config.json"]
            : [root.scriptBasePath + "/install.sh", "/tmp/endos-install-config.json"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim()
                root.installConfig.installLogs.push(line)
                
                // Parse progress updates (format: PROGRESS:50:Installing packages...)
                if (line.startsWith("PROGRESS:")) {
                    const parts = line.split(":")
                    if (parts.length >= 3) {
                        root.installConfig.installProgress = parseInt(parts[1])
                        root.installConfig.currentTask = parts.slice(2).join(":")
                    }
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.currentPage = 9 // Completion page
            } else {
                console.error("Installation failed with exit code:", exitCode)
                // Show error dialog
            }
        }
    }
    
    // Main content
    Rectangle {
        id: mainContainer
        anchors.fill: parent
        anchors.margins: 8
        color: surfaceContainerColor
        radius: windowRounding
        
        // Dry-run warning banner
        Rectangle {
            id: dryRunBanner
            visible: root.dryRun
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 40
            color: "#FF9800"
            z: 100
            
            Text {
                anchors.centerIn: parent
                text: "⚠ DRY RUN MODE - No changes will be made to your system ⚠"
                font.pixelSize: 14
                font.weight: Font.Bold
                color: "#000000"
            }
        }
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            anchors.topMargin: root.dryRun ? 56 : 16
            spacing: 16
            
            // Sidebar with step indicator
            Rectangle {
                id: sidebar
                Layout.fillHeight: true
                Layout.preferredWidth: 250
                color: surfaceColor
                radius: 8
                visible: currentPage > 0 && currentPage < 8 // Hide on welcome and progress pages
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    
                    Text {
                        text: "Installation Steps"
                        color: textOnSurfaceColor
                        font.pixelSize: 18
                        font.weight: Font.Medium
                        Layout.alignment: Qt.AlignHCenter
                    }
                    
                    Repeater {
                        model: [
                            {name: "Language", icon: "language", page: 1},
                            {name: "Network", icon: "wifi", page: 2},
                            {name: "Disk", icon: "hard_drive", page: 3},
                            {name: "User", icon: "person", page: 4},
                            {name: "Hostname", icon: "computer", page: 5},
                            {name: "Packages", icon: "package", page: 6},
                            {name: "Review", icon: "checklist", page: 7}
                        ]
                        
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 48
                            color: (currentPage === modelData.page) ? primaryColor : "transparent"
                            radius: 6
                            opacity: (currentPage >= modelData.page) ? 1.0 : 0.5
                            
                            Row {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12
                                
                                Rectangle {
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: (currentPage === modelData.page) ? backgroundColor : outlineColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                
                                Text {
                                    text: modelData.name
                                    color: (currentPage === modelData.page) ? backgroundColor : textOnSurfaceColor
                                    font.pixelSize: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                    
                    Item { Layout.fillHeight: true }
                }
            }
            
            // Main content area with page loader
            Rectangle {
                id: contentArea
                Layout.fillHeight: true
                Layout.fillWidth: true
                color: "transparent"
                
                Loader {
                    id: pageLoader
                    anchors.fill: parent
                    source: Qt.resolvedUrl("pages/" + pages[currentPage] + ".qml")
                    
                    onLoaded: {
                        // Pass root reference to loaded page
                        if (item) {
                            item.root = root
                        }
                    }
                }
            }
        }
    }
    
    // Global navigation buttons (shown on most pages, hidden on welcome/progress)
    Rectangle {
        id: navigationBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 8
        height: 60
        color: surfaceContainerHighColor
        radius: windowRounding
        visible: currentPage > 0 && currentPage < 8 // Hide on welcome and progress pages
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12
            
            Button {
                text: "Back"
                enabled: currentPage > 1
                onClicked: previousPage()
                Layout.preferredWidth: 120
                Layout.preferredHeight: 40
            }
            
            Item { Layout.fillWidth: true }
            
            Text {
                text: "Step " + currentPage + " of " + (pages.length - 3)
                color: textOnSurfaceColor
                font.pixelSize: 14
            }
            
            Item { Layout.fillWidth: true }
            
            Button {
                text: (currentPage === 7) ? "Install" : "Next"
                enabled: true // Will be controlled by individual pages
                onClicked: {
                    if (currentPage === 7) {
                        startInstallation()
                    } else {
                        nextPage()
                    }
                }
                Layout.preferredWidth: 120
                Layout.preferredHeight: 40
                highlighted: (currentPage === 7)
            }
        }
    }
}
