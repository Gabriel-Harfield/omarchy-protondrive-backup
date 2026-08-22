import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// Deliberately minimal: CLI provisioning and version-pinning are fully
// automatic now (see ensure-cli.sh, run from Panel.qml) — there is no path
// field and no install/detect button here on purpose, so nothing in this
// UI can point the plugin at an untested CLI build. Login is the one thing
// that still needs a human: it opens a real browser window, so it can't
// happen silently on its own. This view is kept as its own isolated
// component (not just deleted) so a later update has somewhere to grow —
// see the user's 2026-08-22 note that Settings stays for future additions.
Item {
  id: root

  required property string cliPath
  required property string cliVersion
  required property color foreground
  required property string fontFamily

  property bool loggingIn: false
  property string loginError: ""

  function loginNow() {
    if (root.cliPath === "" || root.loggingIn) return
    root.loggingIn = true
    root.loginError = ""
    loginProc.command = [root.cliPath, "auth", "login"]
    loginProc.running = false
    loginProc.running = true
  }

  Process {
    id: loginProc
    stdout: StdioCollector { id: loginStdout; waitForEnd: true }
    stderr: StdioCollector { id: loginStderr; waitForEnd: true }
    onExited: function(exitCode) {
      root.loggingIn = false
      root.loginError = exitCode === 0
        ? ""
        : ((loginStderr.text || "").trim() || (loginStdout.text || "").trim() || "Login failed")
    }
  }

  // --- UI --------------------------------------------------------------

  Flickable {
    id: bodyFlick
    anchors.fill: parent
    clip: true
    contentWidth: width
    contentHeight: settingsColumn.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height

    Column {
      id: settingsColumn
      width: bodyFlick.width
      spacing: Style.space(14)

      PanelSectionHeader { text: "PROTON DRIVE CLI"; foreground: root.foreground }

      Text {
        width: parent.width
        text: root.cliPath !== ""
          ? "Version " + root.cliVersion + " — pinned and managed automatically by this plugin."
          : "Setting up…"
        color: Qt.darker(root.foreground, 1.3)
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
      }

      Button {
        text: root.loggingIn ? "Opening browser…" : "Log in"
        bordered: true
        enabled: root.cliPath !== "" && !root.loggingIn
        width: parent.width
        foreground: root.foreground
        accent: Color.accent
        fontFamily: root.fontFamily
        onClicked: root.loginNow()
      }

      Text {
        visible: root.loginError !== ""
        width: parent.width
        text: "Login failed: " + root.loginError
        color: Color.urgent
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
      }
    }
  }
}
