import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root
    
    width: 400
    height: 300
    
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    property bool disableSave: true
    property Item textAreaInstance: null
    readonly property var fontWeights: [400, 500, 600, 700]

    function saveNote() {
        var targetArea = root.textAreaInstance;
        if (targetArea && Plasmoid.configuration.noteText !== targetArea.text) {
            Plasmoid.configuration.noteText = targetArea.text;
            var b64Text = Qt.btoa(unescape(encodeURIComponent(targetArea.text)));
            executableDataSource.connectSource("echo '" + b64Text + "' | base64 -d > \"$HOME/.config/plasma-custom-textnote-text.txt\"; echo 'done'");
        }
    }

    Plasma5Support.DataSource {
        id: executableDataSource
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName)

            if (sourceName.indexOf("plasma-custom-textnote-text.txt") !== -1) {
                if (sourceName.indexOf("cat ") !== -1) {
                    var stdout = data["stdout"] || "";
                    var b64Text = stdout.replace(/\s+/g, '');
                    if (b64Text.length > 0) {
                        try {
                            var decodedText = decodeURIComponent(escape(Qt.atob(b64Text)));
                            var targetArea = root.textAreaInstance;
                            if (targetArea && targetArea.text !== decodedText) {
                                root.disableSave = true;
                                targetArea.text = decodedText;
                            }
                            if (Plasmoid.configuration.noteText !== decodedText) {
                                Plasmoid.configuration.noteText = decodedText;
                            }
                        } catch(e) {
                            console.log("Error decoding text note: " + e);
                        }
                    }
                    root.disableSave = false;
                }
            }
        }
    }

    Timer {
        id: startupEnableTimer
        interval: 1000
        running: true
        repeat: false
        onTriggered: {
            root.disableSave = false;
        }
    }
    
    compactRepresentation: Item {
        Kirigami.Icon {
            anchors.fill: parent
            source: "text-x-generic"
            active: compactMouse.containsMouse
        }
        
        MouseArea {
            id: compactMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.expanded = !root.expanded
        }
    }
    
    fullRepresentation: Item {
        Layout.minimumWidth: 209
        Layout.minimumHeight: 150
        Layout.preferredWidth: 209
        Layout.preferredHeight: 300
        
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: Plasmoid.configuration.bgOpacity
            radius: 12
        }
        
        QQC2.ScrollView {
            id: scrollView
            anchors.fill: parent
            anchors.margins: 10
            
            QQC2.TextArea {
                id: textArea
                width: scrollView.availableWidth
                height: Math.max(implicitHeight, scrollView.availableHeight)
                text: Plasmoid.configuration.noteText
                color: Plasmoid.configuration.textColor
                font.pixelSize: Plasmoid.configuration.textSize
                font.family: Plasmoid.configuration.fontFamily
                font.weight: root.fontWeights[Plasmoid.configuration.fontWeight] || 400
                wrapMode: QQC2.TextArea.Wrap
                selectByMouse: true
                background: Rectangle {
                    color: "transparent"
                }

                TapHandler {
                    id: tapHandler
                    onTapped: (point) => {
                        var pos = point.position;
                        var lineH = (textArea.lineCount > 0 && textArea.contentHeight > 0)
                            ? (textArea.contentHeight / textArea.lineCount)
                            : (textArea.font.pixelSize * 1.3);
                        if (pos.y > textArea.topPadding + textArea.contentHeight || textArea.text.length === 0) {
                            var clickedRow = Math.max(0, Math.floor((pos.y - textArea.topPadding) / lineH));
                            var currentLastRow = Math.max(0, textArea.lineCount - 1);
                            var linesToAdd = clickedRow - (textArea.text.length === 0 ? 0 : currentLastRow);
                            if (linesToAdd > 0) {
                                textArea.text = textArea.text + "\n".repeat(linesToAdd);
                            }
                            textArea.cursorPosition = textArea.text.length;
                            textArea.forceActiveFocus();
                        }
                    }
                }

                onTextChanged: {
                    if (!root.disableSave) {
                        saveTimer.restart()
                    }
                }
                Component.onCompleted: {
                    root.textAreaInstance = textArea;
                }
                Component.onDestruction: {
                    root.saveNote();
                    root.textAreaInstance = null;
                }
            }
        }
        
        Timer {
            id: saveTimer
            interval: 500
            onTriggered: {
                root.saveNote()
            }
        }
    }

    Component.onCompleted: {
        executableDataSource.connectSource("cat \"$HOME/.config/plasma-custom-textnote-text.txt\" | base64")
    }

    Component.onDestruction: {
        root.saveNote()
    }
}
