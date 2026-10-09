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

    property bool disableSave: false
    property Item textAreaInstance: null
    readonly property var fontWeights: [400, 500, 600, 700]

    property var pages: [""]
    property int currentPageIndex: 0
    readonly property string pageBreakDelimiter: "\n\n--- PAGE BREAK ---\n\n"

    function initPages() {
        var raw = Plasmoid.configuration.notePages;
        var loaded = null;
        if (raw) {
            try {
                var parsed = JSON.parse(raw);
                if (Array.isArray(parsed) && parsed.length > 0) {
                    loaded = parsed.map(function(p) {
                        return (typeof p === "string" && p.trim() === "--- PAGE BREAK ---") ? "" : p;
                    });
                }
            } catch (e) {}
        }
        root.pages = loaded || [Plasmoid.configuration.noteText || ""];

        var savedCurrent = Plasmoid.configuration.currentPage !== undefined ? Plasmoid.configuration.currentPage : 0;
        root.currentPageIndex = Math.min(Math.max(0, savedCurrent), root.pages.length - 1);

        if (root.textAreaInstance) {
            root.disableSave = true;
            root.textAreaInstance.text = root.pages[root.currentPageIndex] || "";
            root.disableSave = false;
        }
    }

    function syncCurrentText() {
        if (root.textAreaInstance) {
            var currentText = root.textAreaInstance.text;
            if (root.pages[root.currentPageIndex] !== currentText) {
                var updated = root.pages.slice();
                updated[root.currentPageIndex] = currentText;
                root.pages = updated;
            }
        }
    }

    function saveNote() {
        if (root.disableSave) return;
        syncCurrentText();

        Plasmoid.configuration.notePages = JSON.stringify(root.pages);
        Plasmoid.configuration.currentPage = root.currentPageIndex;
        if (root.pages.length > 0) {
            Plasmoid.configuration.noteText = root.pages[0] || "";
        }

        var combinedText = root.pages.join(root.pageBreakDelimiter);
        var b64Text = Qt.btoa(unescape(encodeURIComponent(combinedText)));
        executableDataSource.connectSource("echo '" + b64Text + "' | base64 -d > \"$HOME/.config/plasma-custom-textnote-text.txt\"; echo 'done'");
    }

    function switchPage(newIndex) {
        if (newIndex < 0 || newIndex >= root.pages.length || newIndex === root.currentPageIndex) return;
        syncCurrentText();

        root.currentPageIndex = newIndex;
        Plasmoid.configuration.currentPage = newIndex;

        if (root.textAreaInstance) {
            root.disableSave = true;
            root.textAreaInstance.text = root.pages[newIndex] || "";
            root.textAreaInstance.cursorPosition = 0;
            root.disableSave = false;
        }

        saveNote();
    }

    function addPage() {
        syncCurrentText();

        var newPagesList = root.pages.slice();
        newPagesList.push("");
        root.pages = newPagesList;

        var newIndex = root.pages.length - 1;
        root.currentPageIndex = newIndex;
        Plasmoid.configuration.currentPage = newIndex;

        if (root.textAreaInstance) {
            root.disableSave = true;
            root.textAreaInstance.text = "";
            root.textAreaInstance.cursorPosition = 0;
            root.disableSave = false;
            root.textAreaInstance.forceActiveFocus();
        }

        saveNote();
    }

    function deletePage(indexToDelete) {
        if (root.pages.length <= 1) return;
        if (indexToDelete === undefined || indexToDelete < 0) indexToDelete = root.currentPageIndex;

        var newPagesList = root.pages.slice();
        newPagesList.splice(indexToDelete, 1);
        root.pages = newPagesList;

        var nextIndex = Math.min(root.currentPageIndex, root.pages.length - 1);
        root.currentPageIndex = nextIndex;
        Plasmoid.configuration.currentPage = nextIndex;

        if (root.textAreaInstance) {
            root.disableSave = true;
            root.textAreaInstance.text = root.pages[nextIndex] || "";
            root.textAreaInstance.cursorPosition = 0;
            root.disableSave = false;
        }

        saveNote();
    }

    Connections {
        target: Plasmoid.configuration
        function onNotePagesChanged() {
            root.initPages();
        }
        function onCurrentPageChanged() {
            var newIdx = Math.min(Math.max(0, Plasmoid.configuration.currentPage || 0), root.pages.length - 1);
            if (newIdx !== root.currentPageIndex) {
                root.switchPage(newIdx);
            }
        }
    }

    Plasma5Support.DataSource {
        id: executableDataSource
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName)

            if (sourceName.indexOf("plasma-custom-textnote-text.txt") !== -1 && sourceName.indexOf("cat ") !== -1) {
                var stdout = data["stdout"] || "";
                var b64Text = stdout.replace(/\s+/g, '');
                if (b64Text.length > 0) {
                    try {
                        var decodedText = decodeURIComponent(escape(Qt.atob(b64Text)));
                        var loadedPages = [];
                        if (decodedText.indexOf("--- PAGE BREAK ---") !== -1) {
                            var rawParts = decodedText.split("--- PAGE BREAK ---");
                            for (var i = 0; i < rawParts.length; i++) {
                                var p = rawParts[i].replace(/^[\r\n]+/, '').replace(/[\r\n]+$/, '');
                                if (p.trim() === "--- PAGE BREAK ---") {
                                    p = "";
                                }
                                loadedPages.push(p);
                            }
                        } else {
                            loadedPages = [decodedText];
                        }
                        if (loadedPages.length > 0) {
                            root.disableSave = true;
                            root.pages = loadedPages;
                            root.currentPageIndex = Math.min(root.currentPageIndex, loadedPages.length - 1);
                            if (root.textAreaInstance) {
                                root.textAreaInstance.text = loadedPages[root.currentPageIndex] || "";
                            }
                            Plasmoid.configuration.notePages = JSON.stringify(loadedPages);
                            Plasmoid.configuration.currentPage = root.currentPageIndex;
                            Plasmoid.configuration.noteText = loadedPages[0] || "";
                            root.disableSave = false;
                        }
                    } catch(e) {
                        console.log("Error decoding text note: " + e);
                    }
                }
            }
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
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: bottomNavBar.top
            anchors.topMargin: 10
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.bottomMargin: 4
            
            QQC2.TextArea {
                id: textArea
                width: scrollView.availableWidth
                height: Math.max(implicitHeight, scrollView.availableHeight)
                text: root.pages[root.currentPageIndex] || ""
                color: Plasmoid.configuration.textColor
                font.pixelSize: Plasmoid.configuration.textSize
                font.family: Plasmoid.configuration.fontFamily
                font.weight: root.fontWeights[Plasmoid.configuration.fontWeight] || 400
                wrapMode: QQC2.TextArea.Wrap
                selectByMouse: true
                background: Rectangle {
                    color: "transparent"
                }

                Keys.onPressed: (event) => {
                    if (event.modifiers & Qt.AltModifier) {
                        if (event.key === Qt.Key_Left || event.key === Qt.Key_PageUp) {
                            root.switchPage(root.currentPageIndex - 1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_PageDown) {
                            root.switchPage(root.currentPageIndex + 1);
                            event.accepted = true;
                        }
                    }
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
                    root.initPages();
                }
                Component.onDestruction: {
                    root.saveNote();
                    root.textAreaInstance = null;
                }
            }
        }

        RowLayout {
            id: bottomNavBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.bottomMargin: 6
            height: 24
            spacing: 4
            opacity: root.pages.length > 1 ? (navHoverArea.hovered ? 0.95 : 0.5) : (navHoverArea.hovered ? 0.95 : 0.0)
            
            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }

            HoverHandler {
                id: navHoverArea
            }

            // Container for page rectangles that automatically shrink as more pages are added
            RowLayout {
                visible: root.pages.length > 1
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Math.max(2, Math.min(4, Math.floor(40 / Math.max(1, root.pages.length))))

                Repeater {
                    model: root.pages.length

                    Rectangle {
                        id: pageRect
                        required property int index

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.maximumWidth: 38
                        Layout.minimumWidth: 12

                        radius: Math.min(6, Math.max(3, Math.floor(pageRect.width / 4)))
                        color: root.currentPageIndex === index
                            ? Qt.alpha(Plasmoid.configuration.textColor, 0.35)
                            : (pageMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.1))
                        border.color: root.currentPageIndex === index
                            ? Plasmoid.configuration.textColor
                            : (pageMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(1, 1, 1, 0.2))
                        border.width: root.currentPageIndex === index ? 1.5 : 1

                        Text {
                            anchors.centerIn: parent
                            text: (pageRect.index + 1)
                            color: Plasmoid.configuration.textColor
                            font.pixelSize: Math.max(8, Math.min(11, Math.floor(pageRect.width * 0.45)))
                            font.bold: root.currentPageIndex === pageRect.index
                        }

                        MouseArea {
                            id: pageMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.switchPage(pageRect.index)
                            }
                        }

                        QQC2.ToolTip.visible: pageMouseArea.containsMouse
                        QQC2.ToolTip.text: i18n("Page %1", pageRect.index + 1)
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                visible: root.pages.length <= 1
            }

            // Add Page Button at far right
            Rectangle {
                Layout.alignment: Qt.AlignRight
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                radius: 5
                color: addMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.1)
                border.color: addMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.5) : Qt.rgba(1, 1, 1, 0.25)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "+"
                    color: Plasmoid.configuration.textColor
                    font.pixelSize: 13
                    font.bold: true
                }

                MouseArea {
                    id: addMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.addPage()
                }

                QQC2.ToolTip.visible: addMouseArea.containsMouse
                QQC2.ToolTip.text: i18n("Add Page")
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
        root.initPages();
        executableDataSource.connectSource("cat \"$HOME/.config/plasma-custom-textnote-text.txt\" | base64");
    }

    Component.onDestruction: {
        root.saveNote();
    }
}
