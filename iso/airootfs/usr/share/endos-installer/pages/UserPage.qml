import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: userPage
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
            text: "User Account Setup"
            font.pixelSize: 28
            font.weight: Font.Bold
            color: pageTextColor
        }
        
        Text {
            text: "Create your user account for EndOS"
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
                
                // Full name
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 500
                    spacing: 8
                    
                    Text {
                        text: "Full Name"
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        color: pageTextColor
                    }
                    
                    TextField {
                        id: fullNameField
                        Layout.fillWidth: true
                        placeholderText: "John Doe"
                        
                        onTextChanged: {
                            root.installConfig.fullName = text
                            
                            // Auto-generate username from full name if username field is empty or auto-generated
                            if (usernameField.text === "" || usernameField.text === previousAutoUsername) {
                                const generated = text.toLowerCase().replace(/\s+/g, '').replace(/[^a-z0-9]/g, '')
                                usernameField.text = generated
                                previousAutoUsername = generated
                            }
                        }
                        
                        property string previousAutoUsername: ""
                        
                        background: Rectangle {
                            color: pageSurfaceContainerHighColor
                            radius: 6
                            border.color: fullNameField.activeFocus ? pagePrimaryColor : pageOutlineColor
                            border.width: fullNameField.activeFocus ? 2 : 1
                        }
                        
                        color: pageTextColor
                        padding: 12
                    }
                }
                
                // Username
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 500
                    spacing: 8
                    
                    Text {
                        text: "Username"
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        color: pageTextColor
                    }
                    
                    Text {
                        text: "Lowercase letters, numbers, and underscores only"
                        font.pixelSize: 11
                        color: pageOutlineColor
                    }
                    
                    TextField {
                        id: usernameField
                        Layout.fillWidth: true
                        placeholderText: "johndoe"
                        
                        validator: RegularExpressionValidator {
                            regularExpression: /^[a-z][a-z0-9_-]*$/
                        }
                        
                        onTextChanged: {
                            root.installConfig.username = text
                            validateUsername()
                        }
                        
                        function validateUsername() {
                            if (text.length === 0) {
                                usernameValidation.text = ""
                                usernameValidation.color = pageOutlineColor
                                return false
                            } else if (text.length < 3) {
                                usernameValidation.text = "⚠️ Username must be at least 3 characters"
                                usernameValidation.color = "#ff5555"
                                return false
                            } else if (!/^[a-z]/.test(text)) {
                                usernameValidation.text = "⚠️ Username must start with a lowercase letter"
                                usernameValidation.color = "#ff5555"
                                return false
                            } else if (!/^[a-z][a-z0-9_-]*$/.test(text)) {
                                usernameValidation.text = "⚠️ Username can only contain lowercase letters, numbers, underscore, and dash"
                                usernameValidation.color = "#ff5555"
                                return false
                            } else {
                                usernameValidation.text = "✓ Username is valid"
                                usernameValidation.color = "#4CAF50"
                                return true
                            }
                        }
                        
                        background: Rectangle {
                            color: pageSurfaceContainerHighColor
                            radius: 6
                            border.color: usernameField.activeFocus ? pagePrimaryColor : 
                                         usernameField.text.length > 0 && !usernameField.validateUsername() ? "#ff5555" : pageOutlineColor
                            border.width: usernameField.activeFocus ? 2 : 1
                        }
                        
                        color: pageTextColor
                        padding: 12
                    }
                    
                    Text {
                        id: usernameValidation
                        text: ""
                        font.pixelSize: 11
                        visible: text.length > 0
                    }
                }
                
                // Password
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 500
                    spacing: 8
                    
                    Text {
                        text: "Password"
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        color: pageTextColor
                    }
                    
                    TextField {
                        id: passwordField
                        Layout.fillWidth: true
                        placeholderText: "Enter a strong password"
                        echoMode: showPasswordCheckbox.checked ? TextInput.Normal : TextInput.Password
                        
                        onTextChanged: {
                            root.installConfig.password = text
                            validatePassword()
                        }
                        
                        function validatePassword() {
                            const length = text.length
                            const hasUpper = /[A-Z]/.test(text)
                            const hasLower = /[a-z]/.test(text)
                            const hasNumber = /[0-9]/.test(text)
                            const hasSpecial = /[^A-Za-z0-9]/.test(text)
                            
                            let strength = 0
                            if (length >= 8) strength++
                            if (length >= 12) strength++
                            if (hasUpper && hasLower) strength++
                            if (hasNumber) strength++
                            if (hasSpecial) strength++
                            
                            if (length === 0) {
                                passwordStrength.text = ""
                                passwordStrength.color = pageOutlineColor
                                return 0
                            } else if (strength < 2) {
                                passwordStrength.text = "⚠️ Weak password"
                                passwordStrength.color = "#ff5555"
                                return 1
                            } else if (strength < 4) {
                                passwordStrength.text = "⚠️ Moderate password"
                                passwordStrength.color = "#FFB74D"
                                return 2
                            } else {
                                passwordStrength.text = "✓ Strong password"
                                passwordStrength.color = "#4CAF50"
                                return 3
                            }
                        }
                        
                        background: Rectangle {
                            color: pageSurfaceContainerHighColor
                            radius: 6
                            border.color: passwordField.activeFocus ? pagePrimaryColor : pageOutlineColor
                            border.width: passwordField.activeFocus ? 2 : 1
                        }
                        
                        color: pageTextColor
                        padding: 12
                    }
                    
                    Text {
                        id: passwordStrength
                        text: ""
                        font.pixelSize: 11
                        visible: text.length > 0
                    }
                    
                    Text {
                        text: "Recommended: At least 12 characters with uppercase, lowercase, numbers, and symbols"
                        font.pixelSize: 11
                        color: pageOutlineColor
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }
                }
                
                // Confirm password
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 500
                    spacing: 8
                    
                    Text {
                        text: "Confirm Password"
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        color: pageTextColor
                    }
                    
                    TextField {
                        id: confirmPasswordField
                        Layout.fillWidth: true
                        placeholderText: "Re-enter your password"
                        echoMode: showPasswordCheckbox.checked ? TextInput.Normal : TextInput.Password
                        
                        onTextChanged: {
                            validatePasswordMatch()
                        }
                        
                        function validatePasswordMatch() {
                            if (text.length === 0) {
                                passwordMatch.text = ""
                                passwordMatch.color = pageOutlineColor
                                return false
                            } else if (text !== passwordField.text) {
                                passwordMatch.text = "⚠️ Passwords do not match"
                                passwordMatch.color = "#ff5555"
                                return false
                            } else {
                                passwordMatch.text = "✓ Passwords match"
                                passwordMatch.color = "#4CAF50"
                                return true
                            }
                        }
                        
                        background: Rectangle {
                            color: pageSurfaceContainerHighColor
                            radius: 6
                            border.color: confirmPasswordField.activeFocus ? pagePrimaryColor : 
                                         confirmPasswordField.text.length > 0 && !confirmPasswordField.validatePasswordMatch() ? "#ff5555" : pageOutlineColor
                            border.width: confirmPasswordField.activeFocus ? 2 : 1
                        }
                        
                        color: pageTextColor
                        padding: 12
                    }
                    
                    Text {
                        id: passwordMatch
                        text: ""
                        font.pixelSize: 11
                        visible: text.length > 0
                    }
                }
                
                // Show password toggle
                CheckBox {
                    id: showPasswordCheckbox
                    text: "Show password"
                    checked: false
                    
                    contentItem: Text {
                        text: showPasswordCheckbox.text
                        font.pixelSize: 13
                        color: pageTextColor
                        leftPadding: showPasswordCheckbox.indicator.width + 8
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    indicator: Rectangle {
                        implicitWidth: 18
                        implicitHeight: 18
                        radius: 4
                        border.color: pageOutlineColor
                        border.width: 2
                        color: showPasswordCheckbox.checked ? pagePrimaryColor : "transparent"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            color: pageBackgroundColor
                            font.pixelSize: 12
                            visible: showPasswordCheckbox.checked
                        }
                    }
                }
                
                // Additional options
                Rectangle {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 500
                    implicitHeight: optionsLayout.implicitHeight + 24
                    color: pageSurfaceColor
                    radius: 8
                    border.color: pageOutlineColor
                    border.width: 1
                    
                    ColumnLayout {
                        id: optionsLayout
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12
                        
                        Text {
                            text: "Additional Options"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: pageTextColor
                        }
                        
                        CheckBox {
                            id: enableRootCheckbox
                            text: "Enable root account"
                            checked: false
                            
                            onCheckedChanged: {
                                root.installConfig.enableRootAccount = checked
                            }
                            
                            contentItem: Text {
                                text: enableRootCheckbox.text
                                font.pixelSize: 13
                                color: pageTextColor
                                leftPadding: enableRootCheckbox.indicator.width + 8
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            indicator: Rectangle {
                                implicitWidth: 18
                                implicitHeight: 18
                                radius: 4
                                border.color: pageOutlineColor
                                border.width: 2
                                color: enableRootCheckbox.checked ? pagePrimaryColor : "transparent"
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: pageBackgroundColor
                                    font.pixelSize: 12
                                    visible: enableRootCheckbox.checked
                                }
                            }
                        }
                        
                        Text {
                            text: "Not recommended for security reasons. Use sudo instead."
                            font.pixelSize: 11
                            color: pageOutlineColor
                            leftPadding: 26
                        }
                        
                        CheckBox {
                            id: autoLoginCheckbox
                            text: "Enable automatic login"
                            checked: false
                            
                            onCheckedChanged: {
                                root.installConfig.autoLogin = checked
                            }
                            
                            contentItem: Text {
                                text: autoLoginCheckbox.text
                                font.pixelSize: 13
                                color: pageTextColor
                                leftPadding: autoLoginCheckbox.indicator.width + 8
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            indicator: Rectangle {
                                implicitWidth: 18
                                implicitHeight: 18
                                radius: 4
                                border.color: pageOutlineColor
                                border.width: 2
                                color: autoLoginCheckbox.checked ? pagePrimaryColor : "transparent"
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: pageBackgroundColor
                                    font.pixelSize: 12
                                    visible: autoLoginCheckbox.checked
                                }
                            }
                        }
                        
                        Text {
                            text: "⚠️ Only enable on single-user systems. Security risk on shared computers."
                            font.pixelSize: 11
                            color: "#ff5555"
                            leftPadding: 26
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            visible: autoLoginCheckbox.checked
                        }
                    }
                }
                
                Item { Layout.fillHeight: true }
            }
        }
    }
}
