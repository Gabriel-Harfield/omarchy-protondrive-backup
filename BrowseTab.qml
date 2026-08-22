import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Format.js" as Format

// Read/write breadcrumb navigation of the user's own Proton Drive, starting
// at /my-files (the CLI's own default root — "shared-with-me" and other
// top-level sections use a different, node-UID-based addressing scheme the
// simple segment/breadcrumb model here doesn't attempt to handle). Fully
// self-contained, like BackupTab.qml: its own state, its own Processes.
// Deliberately no delete here — this tab only downloads and uploads, so
// browsing around Proton Drive can never destroy something by accident.
Item {
  id: root

  required property string cliPath
  required property bool cliChecked
  required property string cliError
  required property string pluginDir
  required property string homeDir
  required property string cloudGlyph
  required property color foreground
  required property string fontFamily

  readonly property string downloadDir: homeDir + "/Downloads/ProtonDrive"

  property var currentSegments: ["my-files"]
  readonly property string currentPath: "/" + root.currentSegments.map(root.escapeSegment).join("/")

  property var entries: []
  property bool loadingEntries: false
  property bool busy: false
  property string busyLabel: ""
  property string lastError: ""

  property bool _loadedOnce: false
  onCliPathChanged: root.maybeAutoLoad()
  Component.onCompleted: root.maybeAutoLoad()

  function maybeAutoLoad() {
    if (root.cliPath === "" || root._loadedOnce) return
    root._loadedOnce = true
    root.loadEntries()
  }

  // The CLI's own path syntax: a literal "/" inside a node name must be
  // backslash-escaped so it isn't read as a path separator.
  function escapeSegment(name) {
    return String(name).split("/").join("\\/")
  }

  function navigateToIndex(i) {
    root.currentSegments = root.currentSegments.slice(0, i + 1)
    root.loadEntries()
  }

  function navigateInto(name) {
    root.currentSegments = root.currentSegments.concat([name])
    root.loadEntries()
  }

  function navigateUp() {
    if (root.currentSegments.length <= 1) return
    root.currentSegments = root.currentSegments.slice(0, -1)
    root.loadEntries()
  }

  function loadEntries() {
    if (root.cliPath === "" || root.loadingEntries) return
    root.loadingEntries = true
    root.lastError = ""
    listProc.command = ["bash", root.pluginDir + "/list-path.sh", root.cliPath, root.currentPath]
    listProc.running = false
    listProc.running = true
  }

  Process {
    id: listProc
    stdout: StdioCollector { id: listStdout; waitForEnd: true }
    onExited: function(exitCode) {
      root.loadingEntries = false
      var raw = (listStdout.text || "").trim()
      var parsed = null
      try { parsed = JSON.parse(raw) } catch (e) { parsed = null }
      if (parsed && parsed.ok === true) {
        root.entries = Array.isArray(parsed.entries) ? parsed.entries : []
      } else {
        root.entries = []
        root.lastError = (parsed && parsed.message) ? parsed.message : "Couldn't list this folder."
      }
    }
  }

  function downloadEntry(name) {
    if (root.busy) return
    root.busy = true
    root.busyLabel = "Downloading…"
    var remotePath = root.currentPath + "/" + root.escapeSegment(name)
    downloadProc.command = ["bash", root.pluginDir + "/download-path.sh", root.cliPath, remotePath, root.downloadDir]
    downloadProc.running = false
    downloadProc.running = true
  }

  Process {
    id: downloadProc
    stdout: StdioCollector { id: downloadStdout; waitForEnd: true }
    onExited: function(exitCode) {
      root.busy = false
      root.busyLabel = ""
      var raw = (downloadStdout.text || "").trim()
      var parsed = null
      try { parsed = JSON.parse(raw) } catch (e) { parsed = null }
      if (parsed && parsed.ok === true) {
        notifyProc.command = ["omarchy-notification-send", "-g", root.cloudGlyph,
          "Downloaded from Proton Drive", parsed.localPath]
        notifyProc.running = false
        notifyProc.running = true
      } else {
        root.lastError = "Download failed."
        notifyProc.command = ["omarchy-notification-send", "-g", root.cloudGlyph, "-u", "critical",
          "Download failed", root.currentPath]
        notifyProc.running = false
        notifyProc.running = true
      }
    }
  }

  function uploadHere() {
    if (root.cliPath === "" || root.busy) return
    pickProc.command = ["omarchy-file-select", "--title", "Choose a file or folder to upload to " + root.currentPath]
    pickProc.running = false
    pickProc.running = true
  }

  Process {
    id: pickProc
    stdout: StdioCollector { id: pickStdout; waitForEnd: true }
    onExited: function(exitCode) {
      var raw = (pickStdout.text || "").trim()
      if (exitCode !== 0 || raw === "") return
      root.busy = true
      root.busyLabel = "Uploading…"
      uploadProc.command = ["bash", root.pluginDir + "/upload-to.sh", root.cliPath,
        raw.split("\n")[0], root.currentPath]
      uploadProc.running = false
      uploadProc.running = true
    }
  }

  Process {
    id: uploadProc
    stdout: StdioCollector { id: uploadStdout; waitForEnd: true }
    onExited: function(exitCode) {
      root.busy = false
      root.busyLabel = ""
      var raw = (uploadStdout.text || "").trim()
      var parsed = null
      try { parsed = JSON.parse(raw) } catch (e) { parsed = null }
      if (parsed && parsed.ok === true) {
        notifyProc.command = ["omarchy-notification-send", "-g", root.cloudGlyph,
          "Uploaded to Proton Drive", root.currentPath]
        notifyProc.running = false
        notifyProc.running = true
        root.loadEntries()
      } else {
        root.lastError = "Upload failed: " + (parsed ? parsed.message : raw)
        notifyProc.command = ["omarchy-notification-send", "-g", root.cloudGlyph, "-u", "critical",
          "Upload failed", root.lastError]
        notifyProc.running = false
        notifyProc.running = true
      }
    }
  }

  Process {
    id: notifyProc
  }

  // --- UI --------------------------------------------------------------

  Flickable {
    id: bodyFlick
    anchors.fill: parent
    clip: true
    contentWidth: width
    contentHeight: mainColumn.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height

    Column {
      id: mainColumn
      width: bodyFlick.width
      spacing: Style.space(10)

      Text {
        visible: !root.cliChecked
        width: parent.width
        text: "Setting up Proton Drive CLI…"
        color: Qt.darker(root.foreground, 1.5)
        font.pixelSize: Style.font.bodySmall
      }

      Text {
        visible: root.cliChecked && root.cliPath === ""
        width: parent.width
        text: "Could not set up the Proton Drive CLI: " + root.cliError
        textFormat: Text.PlainText
        color: Color.urgent
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
      }

      Text {
        visible: root.lastError !== ""
        width: parent.width
        text: root.lastError
        textFormat: Text.PlainText
        color: Color.urgent
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
      }

      Flow {
        width: parent.width
        spacing: Style.spacing.xxs

        Repeater {
          model: root.currentSegments

          Row {
            required property int index
            required property string modelData
            spacing: Style.spacing.xxs

            Text {
              text: modelData
              textFormat: Text.PlainText
              color: index === root.currentSegments.length - 1 ? root.foreground : Qt.darker(root.foreground, 1.3)
              font.bold: index === root.currentSegments.length - 1
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall

              MouseArea {
                anchors.fill: parent
                enabled: index !== root.currentSegments.length - 1
                cursorShape: Qt.PointingHandCursor
                onClicked: root.navigateToIndex(index)
              }
            }

            Text {
              visible: index !== root.currentSegments.length - 1
              text: "/"
              color: Qt.darker(root.foreground, 1.5)
              font.pixelSize: Style.font.bodySmall
            }
          }
        }
      }

      Row {
        width: parent.width
        spacing: Style.spacing.sm

        Button {
          text: "↑ Up"
          bordered: true
          enabled: root.currentSegments.length > 1 && !root.busy
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.navigateUp()
        }

        Button {
          text: "Upload here"
          bordered: true
          enabled: !root.busy && root.cliPath !== ""
          foreground: root.foreground
          accent: Color.accent
          fontFamily: root.fontFamily
          onClicked: root.uploadHere()
        }

        Button {
          text: root.loadingEntries ? "…" : "↻"
          bordered: true
          enabled: !root.loadingEntries && root.cliPath !== ""
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.loadEntries()
        }
      }

      Text {
        visible: root.busy
        width: parent.width
        text: root.busyLabel
        textFormat: Text.PlainText
        color: Qt.darker(root.foreground, 1.5)
        font.pixelSize: Style.font.bodySmall
      }

      PanelSeparator { foreground: root.foreground }

      Text {
        visible: !root.loadingEntries && root.entries.length === 0 && root.lastError === ""
        width: parent.width
        text: "This folder is empty."
        color: Qt.darker(root.foreground, 1.5)
        font.pixelSize: Style.font.bodySmall
      }

      Repeater {
        model: root.entries

        Column {
          id: entryRow
          width: mainColumn.width
          required property var modelData

          Row {
            width: parent.width
            spacing: Style.spacing.sm

            Column {
              width: parent.width - dlBtn.width - parent.spacing
              spacing: Style.spacing.xxs

              MouseArea {
                width: parent.width
                height: nameText.implicitHeight
                enabled: entryRow.modelData.type === "folder"
                cursorShape: entryRow.modelData.type === "folder" ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.navigateInto(entryRow.modelData.name)

                Text {
                  id: nameText
                  width: parent.width
                  text: (entryRow.modelData.type === "folder" ? "📁 " : "📄 ") + entryRow.modelData.name
                  textFormat: Text.PlainText
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideMiddle
                }
              }

              Text {
                width: parent.width
                text: Format.formatDateTime(entryRow.modelData.modified)
                  + (entryRow.modelData.type === "folder" ? "" : "  ·  " + Format.formatBytes(entryRow.modelData.size))
                color: Qt.darker(root.foreground, 1.5)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            PanelActionButton {
              id: dlBtn
              iconText: "⤓"
              tooltipText: "Download"
              foreground: root.foreground
              enabled: !root.busy
              onClicked: root.downloadEntry(entryRow.modelData.name)
            }
          }

          PanelSeparator { foreground: root.foreground; strength: 0.06 }
        }
      }
    }
  }
}
