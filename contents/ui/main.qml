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

    property var pages: [""]
    property int currentPageIndex: 0
    readonly property string pageBreakDelimiter: "\n\n--- PAGE BREAK ---\n\n"

    function initPages() {
        var rawPages = Plasmoid.configuration.notePages;
        if (rawPages && rawPages.length > 0) {
            try {
                var parsed = JSON.parse(rawPages);
                if (Array.isArray(parsed) && parsed.length > 0) {
                    root.pages = parsed;
                } else {
                    root.pages = [Plasmoid.configuration.noteText || ""];
                }
            } catch(e) {
                root.pages = [Plasmoid.configuration.noteText || ""];
            }
        } else {
            root.pages = [Plasmoid.configuration.noteText || ""];
        }

        var savedCurrent = Plasmoid.configuration.currentPage !== undefined ? Plasmoid.configuration.currentPage : 0;
        root.currentPageIndex = Math.min(Math.max(0, savedCurrent), root.pages.length - 1);

        if (root.textAreaInstance) {
            root.disableSave = true;
            root.textAreaInstance.text = root.pages[root.currentPageIndex] || "";
            root.disableSave = false;
        }
    }

    function saveNote() {
        if (root.disableSave) return;
        var targetArea = root.textAreaInstance;
        if (targetArea) {
            var currentText = targetArea.text;
            if (root.pages[root.currentPageIndex] !== currentText) {
                var updatedPages = root.pages.slice();
                updatedPages[root.currentPageIndex] = currentText;
                root.pages = updatedPages;
            }
        }

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

        if (root.textAreaInstance) {
            var currentText = root.textAreaInstance.text;
            var updatedPages = root.pages.slice();
            updatedPages[root.currentPageIndex] = currentText;
            root.pages = updatedPages;
        }

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
        if (root.textAreaInstance) {
            var currentText = root.textAreaInstance.text;
            var updatedPages = root.pages.slice();
            updatedPages[root.currentPageIndex] = currentText;
            root.pages = updatedPages;
        }

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

            if (sourceName.indexOf("plasma-custom-textnote-text.txt") !== -1) {
                if (sourceName.indexOf("cat ") !== -1) {
                    var stdout = data["stdout"] || "";
                    var b64Text = stdout.replace(/\s+/g, '');
                    if (b64Text.length > 0) {
                        try {
                            var decodedText = decodeURIComponent(escape(Qt.atob(b64Text)));
                            var loadedPages = [];
                            if (decodedText.indexOf("--- PAGE BREAK ---") !== -1) {
                                loadedPages = decodedText.split(/[\r\n]+--- PAGE BREAK ---[\r\n]+/);
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
            height: 26
            spacing: 2
            opacity: navHoverArea.hovered ? 0.95 : 0.4
            
            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }

            HoverHandler {
                id: navHoverArea
            }

            QQC2.ToolButton {
                id: prevButton
                implicitWidth: 26
                implicitHeight: 26
                icon.name: "go-previous"
                text: "<"
                display: icon.name ? QQC2.AbstractButton.IconOnly : QQC2.AbstractButton.TextOnly
                enabled: root.currentPageIndex > 0
                onClicked: root.switchPage(root.currentPageIndex - 1)
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: i18n("Previous Page")
            }

            QQC2.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: i18n("Page %1 / %2", root.currentPageIndex + 1, Math.max(1, root.pages.length))
                color: Plasmoid.configuration.textColor
                font.pixelSize: Math.max(10, Plasmoid.configuration.textSize - 4)
                elide: Text.ElideRight
            }

            QQC2.ToolButton {
                id: nextButton
                implicitWidth: 26
                implicitHeight: 26
                icon.name: "go-next"
                text: ">"
                display: icon.name ? QQC2.AbstractButton.IconOnly : QQC2.AbstractButton.TextOnly
                enabled: root.currentPageIndex < root.pages.length - 1
                onClicked: root.switchPage(root.currentPageIndex + 1)
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: i18n("Next Page")
            }

            QQC2.ToolButton {
                id: addButton
                implicitWidth: 26
                implicitHeight: 26
                icon.name: "list-add"
                text: "+"
                display: icon.name ? QQC2.AbstractButton.IconOnly : QQC2.AbstractButton.TextOnly
                onClicked: root.addPage()
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: i18n("Add Page")
            }

            QQC2.ToolButton {
                id: deleteButton
                implicitWidth: 26
                implicitHeight: 26
                icon.name: "list-remove"
                text: "-"
                display: icon.name ? QQC2.AbstractButton.IconOnly : QQC2.AbstractButton.TextOnly
                enabled: root.pages.length > 1
                visible: root.pages.length > 1
                onClicked: root.deletePage(root.currentPageIndex)
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: i18n("Delete Current Page")
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
