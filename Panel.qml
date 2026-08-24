import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Orchestration only: ensures the plugin's own pinned Proton Drive CLI copy
// is in place once (ensure-cli.sh — never the system/AUR copy, never
// "latest"), hosts the tab switcher and the gear-icon Settings view, and
// hands BackupTab.qml / BrowseTab.qml / SettingsView.qml everything they
// need as plain properties. None of the three reaches into another — see
// the isolation note in each one's own header comment. cliPath is owned
// exclusively here now: SettingsView only displays it (read-only) and can
// no longer change it, so nothing in the UI can point the plugin at an
// untested CLI build.
Panel {
  id: root
  moduleName: "io.github.gabrielharfield.protondrive-backup"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  readonly property string homeDir: Quickshell.env("HOME")
  readonly property string pluginDir: homeDir + "/.config/omarchy/plugins/io.github.gabrielharfield.protondrive-backup"
  readonly property string cloudGlyph: "\uDB80\uDD60"

  property string cliPath: ""
  property bool cliChecked: false
  property string cliVersion: ""
  property string cliError: ""

  // "backup" | "browse"
  property string activeTab: "backup"
  // "tabs" | "settings"
  property string panelView: "tabs"

  // open()/close() are the only overrides needed: base Panel.qml's toggle(),
  // closeForPopoutSwitch(), and the `opened`/`popoutSwitchClosing`
  // properties already dispatch through these and panelController, so
  // redeclaring any of them here would just shadow (or, for the two
  // properties, illegally duplicate) what the base type already provides.
  function open() { root.controller.show() }
  function close() { root.controller.hide() }
  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  Component.onCompleted: {
    ensureCliProc.running = true
  }

  // Runs on every panel instantiation, not just "first ever use" — cheap
  // when the pinned binary is already in place (a version-string check,
  // not a re-hash; see ensure-cli.sh), and it's what makes a corrupted or
  // externally-replaced binary self-heal back to the pinned build instead
  // of the plugin silently running on top of something untested.
  Process {
    id: ensureCliProc
    command: ["bash", root.pluginDir + "/ensure-cli.sh"]
    stdout: StdioCollector { id: ensureCliStdout; waitForEnd: true }
    onExited: function(exitCode) {
      var raw = (ensureCliStdout.text || "").trim()
      var parsed = null
      try { parsed = JSON.parse(raw) } catch (e) { parsed = null }
      root.cliChecked = true
      if (parsed && parsed.ok === true) {
        root.cliPath = parsed.path
        root.cliVersion = parsed.version
        root.cliError = ""
      } else {
        root.cliPath = ""
        root.cliError = (parsed && parsed.message) || raw || "Could not set up the Proton Drive CLI."
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(Style.space(500))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: false
      onCloseRequested: {
        if (root.panelView === "settings") root.panelView = "tabs"
        else if (root.activeTab === "backup" && backupTab.viewMode === "confirm") backupTab.cancelPending()
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Item {
        anchors.fill: parent

        Column {
          id: topBlock
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          spacing: Style.space(8)

          Row {
            id: headerRow
            width: parent.width
            height: Math.max(titleText.implicitHeight, gearBtn.implicitHeight)

            Text {
              id: titleText
              anchors.verticalCenter: parent.verticalCenter
              text: "Proton Drive"
              color: root.barForeground
              font.bold: true
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.subtitle
            }

            Item {
              width: headerRow.width - titleText.width - gearBtn.width
              height: 1
            }

            PanelActionButton {
              id: gearBtn
              anchors.verticalCenter: parent.verticalCenter
              iconText: root.panelView === "settings" ? "\u2715" : "\uDB81\uDC93"
              tooltipText: root.panelView === "settings" ? "Back" : "Settings"
              foreground: root.barForeground
              onClicked: root.panelView = (root.panelView === "settings") ? "tabs" : "settings"
            }
          }

          Row {
            id: tabRow
            visible: root.panelView === "tabs"
            width: parent.width
            spacing: Style.spacing.sm

            Button {
              text: "Backup"
              bordered: true
              selected: root.activeTab === "backup"
              foreground: root.barForeground
              accent: Color.accent
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onClicked: root.activeTab = "backup"
            }

            Button {
              text: "Browse"
              bordered: true
              selected: root.activeTab === "browse"
              foreground: root.barForeground
              accent: Color.accent
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onClicked: root.activeTab = "browse"
            }
          }

          PanelSeparator { foreground: root.barForeground }
        }

        Item {
          anchors.top: topBlock.bottom
          anchors.topMargin: Style.space(8)
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom

          BackupTab {
            id: backupTab
            anchors.fill: parent
            visible: root.panelView === "tabs" && root.activeTab === "backup"
            cliPath: root.cliPath
            cliChecked: root.cliChecked
            cliError: root.cliError
            pluginDir: root.pluginDir
            homeDir: root.homeDir
            cloudGlyph: root.cloudGlyph
            foreground: root.barForeground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          }

          BrowseTab {
            id: browseTab
            anchors.fill: parent
            visible: root.panelView === "tabs" && root.activeTab === "browse"
            cliPath: root.cliPath
            cliChecked: root.cliChecked
            cliError: root.cliError
            pluginDir: root.pluginDir
            homeDir: root.homeDir
            cloudGlyph: root.cloudGlyph
            foreground: root.barForeground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          }

          SettingsView {
            id: settingsView
            anchors.fill: parent
            visible: root.panelView === "settings"
            cliPath: root.cliPath
            cliVersion: root.cliVersion
            pluginDir: root.pluginDir
            foreground: root.barForeground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          }
        }
      }
    }
  }
}
