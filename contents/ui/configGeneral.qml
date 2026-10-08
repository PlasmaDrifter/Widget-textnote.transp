import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: generalPage
    
    property string cfg_notePages: plasmoid.configuration.notePages
    property int cfg_currentPage: plasmoid.configuration.currentPage
    property string cfg_noteText: plasmoid.configuration.noteText
    property color cfg_textColor: plasmoid.configuration.textColor
    property alias cfg_textSize: textSizeSpinBox.value
    property alias cfg_bgOpacity: opacitySlider.value
    property string cfg_fontFamily: plasmoid.configuration.fontFamily
    property alias cfg_fontWeight: fontWeightCombo.currentIndex

    property var pagesList: []
    property int activePageIndex: 0
    property bool internalChange: false

    function initPages() {
        internalChange = true;
        var raw = generalPage.cfg_notePages;
        if (raw && raw.length > 0) {
            try {
                var parsed = JSON.parse(raw);
                if (Array.isArray(parsed) && parsed.length > 0) {
                    pagesList = parsed;
                } else {
                    pagesList = [generalPage.cfg_noteText || ""];
                }
            } catch(e) {
                pagesList = [generalPage.cfg_noteText || ""];
            }
        } else {
            pagesList = [generalPage.cfg_noteText || ""];
        }
        activePageIndex = Math.min(Math.max(0, generalPage.cfg_currentPage || 0), pagesList.length - 1);
        refreshComboModel();
        noteTextArea.text = pagesList[activePageIndex] || "";
        internalChange = false;
    }

    function refreshComboModel() {
        var arr = [];
        for (var i = 0; i < pagesList.length; i++) {
            arr.push(i18n("Page %1", i + 1));
        }
        pageCombo.model = arr;
        pageCombo.currentIndex = activePageIndex;
    }

    function saveCurrentPage(txt) {
        if (internalChange) return;
        var p = pagesList.slice();
        p[activePageIndex] = txt;
        pagesList = p;
        generalPage.cfg_notePages = JSON.stringify(p);
        if (activePageIndex === 0) {
            generalPage.cfg_noteText = txt;
        }
    }

    function addNewPage() {
        var p = pagesList.slice();
        p[activePageIndex] = noteTextArea.text;
        p.push("");
        pagesList = p;
        activePageIndex = pagesList.length - 1;
        refreshComboModel();
        internalChange = true;
        noteTextArea.text = "";
        internalChange = false;
        generalPage.cfg_notePages = JSON.stringify(p);
        generalPage.cfg_currentPage = activePageIndex;
    }

    function deleteCurrentPage() {
        if (pagesList.length <= 1) return;
        var p = pagesList.slice();
        p.splice(activePageIndex, 1);
        pagesList = p;
        activePageIndex = Math.min(activePageIndex, pagesList.length - 1);
        refreshComboModel();
        internalChange = true;
        noteTextArea.text = pagesList[activePageIndex] || "";
        internalChange = false;
        generalPage.cfg_notePages = JSON.stringify(p);
        generalPage.cfg_currentPage = activePageIndex;
        if (pagesList.length > 0) {
            generalPage.cfg_noteText = pagesList[0] || "";
        }
    }

    function selectPage(idx) {
        if (idx < 0 || idx >= pagesList.length || idx === activePageIndex) return;
        var p = pagesList.slice();
        p[activePageIndex] = noteTextArea.text;
        pagesList = p;
        generalPage.cfg_notePages = JSON.stringify(p);
        activePageIndex = idx;
        generalPage.cfg_currentPage = idx;
        internalChange = true;
        noteTextArea.text = pagesList[idx] || "";
        internalChange = false;
    }
    
    Kirigami.FormLayout {
        
        RowLayout {
            Kirigami.FormData.label: "Text Color:"
            
            Rectangle {
                id: colorPreview
                width: 50
                height: 30
                border.color: "gray"
                border.width: 1
                radius: 3
                color: generalPage.cfg_textColor
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: colorDialog.open()
                }
            }
            
            QQC2.Label {
                text: generalPage.cfg_textColor
            }
        }
        
        ColorDialog {
            id: colorDialog
            title: "Choose Text Color"
            selectedColor: generalPage.cfg_textColor
            onAccepted: {
                generalPage.cfg_textColor = selectedColor
            }
        }
        
        QQC2.SpinBox {
            id: textSizeSpinBox
            Kirigami.FormData.label: "Text Size:"
            from: 8
            to: 48
            stepSize: 1
        }

        QQC2.ComboBox {
            id: fontFamilyCombo
            Kirigami.FormData.label: "Font Family:"
            model: Qt.fontFamilies().sort()
            Layout.fillWidth: true
            
            Component.onCompleted: {
                var idx = model.indexOf(generalPage.cfg_fontFamily)
                if (idx !== -1) {
                    currentIndex = idx
                }
            }
            
            onActivated: {
                generalPage.cfg_fontFamily = currentText
            }
        }

        Connections {
            target: generalPage
            function onCfg_fontFamilyChanged() {
                var idx = fontFamilyCombo.model.indexOf(generalPage.cfg_fontFamily)
                if (idx !== -1) {
                    fontFamilyCombo.currentIndex = idx
                }
            }
        }

        QQC2.ComboBox {
            id: fontWeightCombo
            Kirigami.FormData.label: "Font weight:"
            model: [
                i18n("Normal"),
                i18n("Medium"),
                i18n("Demi-Bold"),
                i18n("Bold")
            ]
        }
        
        RowLayout {
            Kirigami.FormData.label: "Background Opacity:"
            
            QQC2.Slider {
                id: opacitySlider
                from: 0.0
                to: 1.0
                stepSize: 0.05
                Layout.fillWidth: true
            }
            
            QQC2.Label {
                text: Math.round(opacitySlider.value * 100) + "%"
            }
        }
        
        Item {
            Kirigami.FormData.isSection: true
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Page Management:")

            QQC2.ComboBox {
                id: pageCombo
                Layout.fillWidth: true
                onActivated: {
                    generalPage.selectPage(currentIndex);
                }
            }

            QQC2.Button {
                text: i18n("Add Page")
                icon.name: "list-add"
                onClicked: {
                    generalPage.addNewPage();
                }
            }

            QQC2.Button {
                text: i18n("Delete Page")
                icon.name: "list-remove"
                enabled: generalPage.pagesList.length > 1
                onClicked: {
                    generalPage.deleteCurrentPage();
                }
            }
        }
        
        QQC2.Label {
            Kirigami.FormData.label: i18n("Page Content:")
            text: i18n("Edit note content for the selected page:")
            font.italic: true
        }
        
        QQC2.ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: 150
            QQC2.ScrollBar.vertical.policy: QQC2.ScrollBar.AlwaysOn
            QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
            
            QQC2.TextArea {
                id: noteTextArea
                wrapMode: QQC2.TextArea.Wrap
                onTextChanged: {
                    generalPage.saveCurrentPage(text);
                }
            }
        }
    }

    Component.onCompleted: {
        generalPage.initPages();
    }
}
