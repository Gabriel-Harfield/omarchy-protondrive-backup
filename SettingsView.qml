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
  required property string pluginDir
  required property color foreground
  required property string fontFamily

  property bool loggingIn: false
  property string loginError: ""

  function loginNow() {
    if (root.cliPath === "" || root.loggingIn) return
    root.loggingIn = true
    root.loginError = ""
    loginProc.command = ["bash", root.pluginDir + "/auth-login.sh", root.cliPath]
    loginProc.running = false
    loginProc.running = true
  }

  // Goes through auth-login.sh rather than calling the CLI directly: that
  // script bounds both the captured output (a byte ceiling, same pattern as
  // every other script here) and the process's wall-clock lifetime (a
  // `timeout`), which a bare Process + StdioCollector pair can't do on its
  // own — see the script's own header for why. Only stdout is read: the
  // script always emits well-formed JSON on both success and failure paths.
  Process {
    id: loginProc
    stdout: StdioCollector { id: loginStdout; waitForEnd: true }
    onExited: function(exitCode) {
      root.loggingIn = false
      var raw = (loginStdout.text || "").trim()
      var parsed = null
      try { parsed = JSON.parse(raw) } catch (e) { parsed = null }
      root.loginError = (parsed && parsed.ok === true)
        ? ""
        : ((parsed && parsed.message) || raw || "Login failed")
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
        textFormat: Text.PlainText
        color: Color.urgent
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
      }
    }
  }
}
