import QtQuick
import QtQuick.Controls.Basic

ComboBox {
    id: control
    
    property color accentColor: ThemeBridge.color("primary")
    property color textColor: ThemeBridge.color("on_surface")
    property color backgroundColor: ThemeBridge.color("surface_container")
    property color popupColor: ThemeBridge.color("surface_container_high")
    
    delegate: ItemDelegate {
        id: delegate
        width: control.width
        contentItem: Text {
            text: modelData
            color: control.textColor
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            
            font.pixelSize: 15
            font.hintingPreference: Font.PreferFullHinting
            font.family: "Google Sans Flex"
            font.variableAxes: ({
                "wght": 450,
                "wdth": 100,
            })
        }
        highlighted: control.highlightedIndex === index
        
        background: Rectangle {
            color: delegate.highlighted ? Qt.rgba(control.accentColor.r, control.accentColor.g, control.accentColor.b, 0.2) : "transparent"
        }
    }

    contentItem: Text {
        leftPadding: 10
        rightPadding: control.indicator.width + control.spacing
        text: control.displayText
        color: control.textColor
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        
        font.pixelSize: 15
        font.hintingPreference: Font.PreferFullHinting
        font.family: "Google Sans Flex"
        font.variableAxes: ({
            "wght": 450,
            "wdth": 100,
        })
    }

    indicator: Canvas {
        x: control.width - width - control.rightPadding
        y: control.topPadding + (control.availableHeight - height) / 2
        width: 12
        height: 8
        contextType: "2d"
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.moveTo(0, 0)
            ctx.lineTo(width, 0)
            ctx.lineTo(width / 2, height)
            ctx.closePath()
            ctx.fillStyle = control.textColor
            ctx.fill()
        }
    }

    background: Rectangle {
        implicitWidth: 120
        implicitHeight: 40
        color: control.backgroundColor
        border.color: control.activeFocus ? control.accentColor : "transparent"
        border.width: 2
        radius: 8
    }

    popup: Popup {
        y: control.height - 1
        width: control.width
        implicitHeight: contentItem.implicitHeight
        padding: 1

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex

            ScrollIndicator.vertical: ScrollIndicator { }
        }

        background: Rectangle {
            color: control.popupColor
            border.color: control.accentColor
            radius: 8
        }
    }
}
