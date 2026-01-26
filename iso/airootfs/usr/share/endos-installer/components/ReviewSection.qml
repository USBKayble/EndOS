import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: reviewSection
    
    property string title: ""
    property var items: []
    property string warning: ""
    
    // Color properties with fallbacks
    property color sectionBackgroundColor: "#1d1c1c"
    property color sectionBorderColor: "#938f8f"
    property color sectionTitleColor: "#cbc4cb"
    property color sectionLabelColor: "#938f8f"
    property color sectionValueColor: "#e6e1e1"
    property color sectionWarningColor: "#ffb4ab"
    
    Layout.fillWidth: true
    implicitHeight: sectionLayout.implicitHeight + 32
    color: sectionBackgroundColor
    radius: 12
    border.color: sectionBorderColor
    border.width: 1
    
    ColumnLayout {
        id: sectionLayout
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        
        // Section title
        Text {
            text: reviewSection.title
            font.pixelSize: 16
            font.weight: Font.DemiBold
            color: sectionTitleColor
        }
        
        // Warning if present
        Text {
            visible: reviewSection.warning !== ""
            text: reviewSection.warning
            font.pixelSize: 12
            color: sectionWarningColor
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
        
        // Section items
        Repeater {
            model: reviewSection.items
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                
                Text {
                    text: modelData.label + ":"
                    font.pixelSize: 13
                    color: sectionLabelColor
                    Layout.preferredWidth: 180
                }
                
                Text {
                    text: modelData.value || "Not set"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: sectionValueColor
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
