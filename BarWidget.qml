import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.gabrielharfield.protondrive-backup"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false

  readonly property bool busy: panelLoader.item ? panelLoader.item.busy === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  // Nerd Font glyph (JetBrainsMono Nerd Font, aliased via Style.fontFamily
  // "monospace" — see qs.Commons Style.qml): md-cloud_check, same glyph and
  // same surrogate-pair escape form already proven to render correctly in
  // this environment by the sync plugin's BarWidget.qml, so it follows the
  // bar's foreground color like every other bar icon instead of risking an
  // unverified codepoint rendering as tofu.
  readonly property string icon: "\uDB80\uDD60"

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.busy ? "…" : root.icon
    tooltipText: "Proton Drive Backup"
    fixedWidth: root.bar && root.bar.vertical ? -1 : Style.space(27)
    fixedHeight: root.bar && root.bar.vertical ? Style.space(26) : -1
    onPressed: function(b) {
      if (b === Qt.LeftButton) root.toggle()
    }
  }
}
