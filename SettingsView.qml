import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// CLI setup: install the proton-drive binary and/or log in. Reused, adapted
// logic from io.github.gabrielharfield.protondrive-sync's own Settings view,
// which the user confirmed works well there. Self-contained like BackupTab
// and BrowseTab — its only coupling to Panel.qml is the cliPath hand-off
// below (see the comment on the `cliPath` property).
Item {
  id: root

  required property string pluginDir
  required property color foreground
  required property string fontFamily

  // Seeded once from Panel.qml's own cliPath at instantiation, then owned
  // locally from here on. Panel.qml listens to this property's own
  // auto-generated cliPathChanged signal (`onCliPathChanged:` on the
  // SettingsView instance) to mirror edits/detects/installs back into its
  // own cliPath, which is what actually flows down into BackupTab/BrowseTab.
  // No custom signal needed for that — QML already provides one per property.
  required property string initialCliPath
  property string cliPath: initialCliPath

  property bool installingCli: false
  property string installError: ""
  property string installMessage: ""

  property bool loggingIn: false
  property string loginError: ""

  function detectCli() {
    detectProc.command = ["bash", root.pluginDir + "/find-cli.sh"]
    detectProc.running = false
    detectProc.running = true
  }

  Process {
    id: detectProc
    stdout: StdioCollector { id: detectStdout; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        var p = (detectStdout.text || "").trim()
        if (p !== "") root.cliPath = p
      }
    }
  }

  function installCli() {
    if (root.installingCli) return
    root.installingCli = true
    root.installError = ""
    root.installMessage = ""
    installProc.command = ["bash", root.pluginDir + "/install-cli.sh"]
    installProc.running = false
    installProc.running = true
  }

  Process {
    id: installProc
    stdout: StdioCollector { id: installStdout; waitForEnd: true }
    stderr: StdioCollector { id: installStderr; waitForEnd: true }
    onExited: function(exitCode) {
      root.installingCli = false
      var raw = (installStdout.text || "").trim()
      var parsed = null
      try { parsed = JSON.parse(raw) } catch (e) { parsed = null }
      if (parsed && parsed.ok) {
        root.installError = ""
        root.installMessage = "Installed proton-drive " + parsed.version + " to " + parsed.path
        root.cliPath = parsed.path
      } else {
        root.installMessage = ""
        root.installError = (parsed && parsed.message)
          || (installStderr.text || "").trim()
          || raw
          || ("install script exited with code " + exitCode)
      }
    }
  }

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

      Button {
        text: root.installingCli ? "Installing…" : "Install Proton-CLI"
        bordered: true
        enabled: !root.installingCli
        width: parent.width
        foreground: root.foreground
        accent: Color.accent
        fontFamily: root.fontFamily
        onClicked: root.installCli()
      }

      Text {
        visible: root.installMessage !== ""
        width: parent.width
        text: root.installMessage
        color: Qt.darker(root.foreground, 1.3)
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
      }

      Text {
        visible: root.installError !== ""
        width: parent.width
        text: "Install failed: " + root.installError
        color: Color.urgent
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
      }

      TextField {
        id: cliField
        width: parent.width
        text: root.cliPath
        foreground: root.foreground
        placeholderText: "/path/to/proton-drive"
        onTextChanged: root.cliPath = text
      }

      Row {
        width: parent.width
        spacing: Style.spacing.sm

        Button {
          text: "Auto-detect"
          bordered: true
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.detectCli()
        }

        Button {
          text: root.loggingIn ? "Opening browser…" : "Log in"
          bordered: true
          enabled: root.cliPath !== "" && !root.loggingIn
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.loginNow()
        }
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
