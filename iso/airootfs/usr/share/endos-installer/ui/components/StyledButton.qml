import QtQuick
import QtQuick.Controls.Basic

Button {
    id: control
    
    property color accentColor: ThemeBridge.color("primary")
    property color onAccentColor: ThemeBridge.color("on_primary")
    property color surfaceColor: ThemeBridge.color("surface_container_high")
    property color textColor: ThemeBridge.color("on_surface")
    
    property bool isPrimary: false
    
    contentItem: Text {
        text: control.text
        
        // Font configuration
        font.family: "Google Sans Flex"
        font.pixelSize: 15
        font.hintingPreference: Font.PreferFullHinting
        font.weight: 450 // Regular
        font.variableAxes: ({
            "wght": 450,
            "wdth": 100,
        })
        
        opacity: enabled ? 1.0 : 0.3
        color: control.isPrimary ? control.onAccentColor : control.textColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        renderType: Text.QtRendering
        elide: Text.ElideRight
    }
    
    palette.buttonText: control.isPrimary ? control.onAccentColor : control.textColor

    background: Rectangle {
        implicitWidth: 100
        implicitHeight: 40
        opacity: enabled ? 1 : 0.3
        color: control.isPrimary ? control.accentColor : (control.down ? Qt.darker(control.surfaceColor, 1.1) : control.surfaceColor)
        radius: 8
        
        Behavior on color { ColorAnimation { duration: 100 } }
    }
}
