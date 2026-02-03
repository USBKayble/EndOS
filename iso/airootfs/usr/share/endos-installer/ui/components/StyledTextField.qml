import QtQuick
import QtQuick.Layouts
// Use raw QtQuick primitives to ensure rendering works

FocusScope {
    id: control
    implicitWidth: 200
    implicitHeight: 40
    
    // Properties matching TextField interface
    property alias text: input.text
    property alias readOnly: input.readOnly
    property alias echoMode: input.echoMode
    property alias inputMask: input.inputMask
    property alias validator: input.validator
    property alias font: input.font
    property string placeholderText: ""
    
    // Theme properties
    property color accentColor: ThemeBridge.color("primary")
    property color textColor: ThemeBridge.color("on_surface")
    property color backgroundColor: ThemeBridge.color("surface_container")
    property color placeholderColor: ThemeBridge.color("on_surface_variant") // or dimmed
    
    // Background
    Rectangle {
        anchors.fill: parent
        color: control.backgroundColor
        radius: 8
        border.color: input.activeFocus ? control.accentColor : "transparent"
        border.width: 2
    }
    
    // Placeholder
    Text {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: Text.AlignVCenter
        text: control.placeholderText
        font: control.font
        color: control.placeholderColor
        visible: !input.text && !input.activeFocus
        elide: Text.ElideRight
    }
    
    // Input
    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        
        // Restored theme color
        color: control.textColor
        renderType: Text.QtRendering
        
        selectionColor: control.accentColor
        selectedTextColor: ThemeBridge.color("on_primary")
        
        font.pixelSize: 15 // Updated to match reference
        font.hintingPreference: Font.PreferFullHinting
        font.family: "Google Sans Flex"
        font.variableAxes: ({
            "wght": 450,
            "wdth": 100,
        })
        selectByMouse: true
        clip: true
    }
    

}
