import QtQuick 2.15
import QtQuick.Controls 2.15

// Working-title SDDM theme. Colors come from theme.conf (generated from design-tokens.json).
Rectangle {
    id: root
    width: 1280; height: 720
    color: config.bg
    property bool he: Qt.locale().name.indexOf("he") === 0
    LayoutMirroring.enabled: he
    LayoutMirroring.childrenInherit: true
    function t(en, hebrew) { return he ? hebrew : en }

    Connections {
        target: sddm
        function onLoginFailed() {
            message.text = root.t("Login failed", "הכניסה נכשלה")
            password.text = ""
            password.forceActiveFocus()
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 12
        width: 320

        Text {
            text: config.title
            color: config.text
            font.family: config.font; font.pixelSize: 28
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Rectangle { width: parent.width; height: 2; color: config.accent }

        ComboBox {
            id: user
            width: parent.width
            model: userModel
            textRole: "name"
            currentIndex: userModel.lastIndex
            font.family: config.font
        }
        TextField {
            id: password
            width: parent.width
            echoMode: TextInput.Password
            placeholderText: root.t("Password", "סיסמה")
            color: config.text
            font.family: config.font; font.pixelSize: 14
            focus: true
            background: Rectangle {
                color: config.surface
                border.width: 2
                border.color: password.activeFocus ? config.accent : config.border
                radius: 2
            }
            Keys.onReturnPressed: sddm.login(user.currentText, password.text, session.currentIndex)
            Keys.onEnterPressed: sddm.login(user.currentText, password.text, session.currentIndex)
        }
        ComboBox {
            id: session
            width: parent.width
            model: sessionModel
            textRole: "name"
            currentIndex: sessionModel.lastIndex
            font.family: config.font
        }
        Button {
            width: parent.width
            text: root.t("Log in", "כניסה")
            font.family: config.font
            contentItem: Text {
                text: parent.text; font: parent.font
                color: config.onAccent
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle { color: parent.down ? config.accentDim : config.accent; radius: 2 }
            onClicked: sddm.login(user.currentText, password.text, session.currentIndex)
        }
        Text {
            id: message
            width: parent.width
            color: config.danger
            font.family: config.font; font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Row {
        anchors { bottom: parent.bottom; right: parent.right; margins: 24 }
        spacing: 16
        Button {
            text: root.t("Restart", "הפעלה מחדש"); flat: true
            onClicked: sddm.reboot()
            contentItem: Text { text: parent.text; color: config.textDim; font.family: config.font }
            background: Item {}
        }
        Button {
            text: root.t("Shut down", "כיבוי"); flat: true
            onClicked: sddm.powerOff()
            contentItem: Text { text: parent.text; color: config.textDim; font.family: config.font }
            background: Item {}
        }
    }
}
