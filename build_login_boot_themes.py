#!/usr/bin/env python3
"""Build the SDDM (login) and Plymouth (boot splash) themes from design-tokens.json.
Usage: python build_login_boot_themes.py design-tokens.json OUT_DIR
Output: OUT_DIR/sddm/WorkingTitle/{metadata.desktop,theme.conf,Main.qml}
        OUT_DIR/plymouth/WorkingTitle/{WorkingTitle.plymouth,WorkingTitle.script,*.png}
Dark palette only (boot and login are always dark). NOT tested on a real system."""
import json, os, struct, sys, zlib

def hexrgb(h):
    h = h.lstrip('#')
    return [int(h[i:i + 2], 16) for i in (0, 2, 4)]

def png1x1(rgb):
    def chunk(t, d):
        c = struct.pack('>I', len(d)) + t + d
        return c + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    raw = b'\x00' + bytes(rgb)
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 2, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))

MAIN_QML = r'''import QtQuick 2.15
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
'''

PLY_SCRIPT = r'''# Working-title Plymouth theme: dark background, thin accent progress line.
Window.SetBackgroundTopColor(%(bg)s);
Window.SetBackgroundBottomColor(%(bg)s);

W = Window.GetWidth();
H = Window.GetHeight();
bar_w = W * 0.2;
if (bar_w < 240) bar_w = 240;
bar_h = 2;
bar_x = (W - bar_w) / 2;
bar_y = H * 0.55;

track_img = Image("track.png");
fill_img = Image("fill.png");

track = Sprite(track_img.Scale(bar_w, bar_h));
track.SetPosition(bar_x, bar_y, 1);
fill = Sprite(fill_img.Scale(1, bar_h));
fill.SetPosition(bar_x, bar_y, 2);

fun progress_cb(time, progress) {
    w = bar_w * progress;
    if (w < 1) w = 1;
    fill.SetImage(fill_img.Scale(w, bar_h));
}
Plymouth.SetBootProgressFunction(progress_cb);

# Disk-encryption password prompt (LUKS)
prompt_sprite = Sprite();
fun password_cb(prompt, bullets) {
    stars = "";
    for (i = 0; i < bullets; i++) stars = stars + "*";
    img = Image.Text(prompt + "  " + stars, %(text)s, 1, "Sans 14");
    prompt_sprite.SetImage(img);
    prompt_sprite.SetPosition((W - img.GetWidth()) / 2, H * 0.62, 3);
}
Plymouth.SetDisplayPasswordFunction(password_cb);

msg_sprite = Sprite();
fun message_cb(text) {
    img = Image.Text(text, %(dim)s, 1, "Sans 12");
    msg_sprite.SetImage(img);
    msg_sprite.SetPosition((W - img.GetWidth()) / 2, H * 0.7, 3);
}
Plymouth.SetMessageFunction(message_cb);
'''

def f3(h):
    return ', '.join('%.4f' % (x / 255) for x in hexrgb(h))

def main():
    tokens = json.load(open(sys.argv[1], encoding='utf-8'))
    c = tokens['color']['dark']
    out = sys.argv[2]
    acc = hexrgb(c['accent'])
    acc_dim = '#%02x%02x%02x' % tuple(round(x * 0.75) for x in acc)

    sd = os.path.join(out, 'sddm', 'WorkingTitle')
    os.makedirs(sd, exist_ok=True)
    open(os.path.join(sd, 'Main.qml'), 'w', encoding='utf-8', newline='\n').write(MAIN_QML)
    open(os.path.join(sd, 'metadata.desktop'), 'w', encoding='utf-8', newline='\n').write(
        '[SddmGreeterTheme]\nName=WorkingTitle\nDescription=Dark, sharp login screen\n'
        'Author=\nVersion=0.1\nMainScript=Main.qml\nConfigFile=theme.conf\nTheme-Id=WorkingTitle\n'
        'QtVersion=6\n')
    conf = '[General]\ntitle=WorkingTitle\nfont=Inter\n'
    for k, v in (('bg', c['bg']), ('surface', c['surface']), ('border', c['border']),
                 ('text', c['text']), ('textDim', c['text-dim']), ('accent', c['accent']),
                 ('accentDim', acc_dim), ('onAccent', c['on-accent']), ('danger', c['danger'])):
        conf += f'{k}={v}\n'
    open(os.path.join(sd, 'theme.conf'), 'w', encoding='utf-8', newline='\n').write(conf)
    print('wrote', sd)

    pd = os.path.join(out, 'plymouth', 'WorkingTitle')
    os.makedirs(pd, exist_ok=True)
    open(os.path.join(pd, 'track.png'), 'wb').write(png1x1(hexrgb(c['border'])))
    open(os.path.join(pd, 'fill.png'), 'wb').write(png1x1(acc))
    open(os.path.join(pd, 'WorkingTitle.script'), 'w', encoding='utf-8', newline='\n').write(
        PLY_SCRIPT % {'bg': f3(c['bg']), 'text': f3(c['text']), 'dim': f3(c['text-dim'])})
    open(os.path.join(pd, 'WorkingTitle.plymouth'), 'w', encoding='utf-8', newline='\n').write(
        '[Plymouth Theme]\nName=WorkingTitle\nDescription=Dark, minimal boot splash\n'
        'ModuleName=script\n\n[script]\n'
        'ImageDir=/usr/share/plymouth/themes/WorkingTitle\n'
        'ScriptFile=/usr/share/plymouth/themes/WorkingTitle/WorkingTitle.script\n')
    print('wrote', pd)

if __name__ == '__main__':
    main()
