import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Orchestration only: finds the CLI once, hosts the tab switcher, and hands
// BackupTab.qml / BrowseTab.qml everything they need as plain properties.
// Neither tab reaches into the other or into this file's internals beyond
// that — see the "Tab isolation" note in each tab's own header comment.
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

  // "backup" | "browse"
  property string activeTab: "backup"

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
    findCliProc.running = true
  }

  Process {
    id: findCliProc
    command: ["bash", root.pluginDir + "/find-cli.sh"]
    stdout: StdioCollector { id: findCliStdout; waitForEnd: true }
    onExited: function(exitCode) {
      root.cliPath = (findCliStdout.text || "").trim()
      root.cliChecked = true
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
        if (root.activeTab === "backup" && backupTab.viewMode === "confirm") backupTab.cancelPending()
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
            height: titleText.implicitHeight

            Text {
              id: titleText
              anchors.verticalCenter: parent.verticalCenter
              text: "Proton Drive"
              color: root.barForeground
              font.bold: true
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.subtitle
            }
          }

          Row {
            id: tabRow
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
            visible: root.activeTab === "backup"
            cliPath: root.cliPath
            cliChecked: root.cliChecked
            pluginDir: root.pluginDir
            homeDir: root.homeDir
            cloudGlyph: root.cloudGlyph
            foreground: root.barForeground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          }

          BrowseTab {
            id: browseTab
            anchors.fill: parent
            visible: root.activeTab === "browse"
            cliPath: root.cliPath
            cliChecked: root.cliChecked
            pluginDir: root.pluginDir
            homeDir: root.homeDir
            cloudGlyph: root.cloudGlyph
            foreground: root.barForeground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          }
        }
      }
    }
  }
}
