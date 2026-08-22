import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Format.js" as Format

// Déjà Dup-style dated backups of a single file or folder at a time, into
// the plugin's own dedicated /my-files/Backups folder. Self-contained:
// owns its own list, its own pending-upload/confirm flow, and its own
// Processes — Panel.qml only ever reads/writes the properties below and
// never reaches into BrowseTab.qml or vice versa.
Item {
  id: root

  required property string cliPath
  required property bool cliChecked
  required property string pluginDir
  required property string homeDir
  required property string cloudGlyph
  required property color foreground
  required property string fontFamily

  readonly property string downloadDir: homeDir + "/Downloads/ProtonDriveBackups"

  // "list" | "confirm"
  property string viewMode: "list"

  property bool loadingList: false
  property var backups: []  // [{name, type: "file"|"folder", size, modified}], newest first

  property bool busy: false
  property string busyLabel: ""
  property string lastError: ""

  // An item has been picked and is waiting for the user to confirm (and
  // optionally trash old backups of the same item) before it's uploaded.
  property string pendingLocalPath: ""
  property bool pendingIsFolder: false
  property string pendingBase: ""
  property string pendingExt: ""
  property string pendingRemoteName: ""
  property var relatedBackups: []
  property var selectedForTrash: ({})

  property bool _loadedOnce: false
  onCliPathChanged: root.maybeAutoLoad()
  Component.onCompleted: root.maybeAutoLoad()

  function maybeAutoLoad() {
    if (root.cliPath === "" || root._loadedOnce) return
    root._loadedOnce = true
    root.refreshList()
  }

  // --- name helpers ----------------------------------------------------

  function baseNameOf(path) {
    var parts = String(path || "").split("/")
    return parts[parts.length - 1]
  }

  // Splits "report.pdf" into {base:"report", ext:".pdf"}. A leading dot
  // (dotfile) never counts as the extension separator, and a name with no
  // dot at all gets ext:"".
  function splitExt(name) {
    var s = String(name || "")
    var dot = s.lastIndexOf(".")
    if (dot <= 0) return { base: s, ext: "" }
    return { base: s.substring(0, dot), ext: s.substring(dot) }
  }

  // A remote backup belongs to the same "family" as the local item being
  // backed up if it's the same kind (file/folder) and its name is that
  // item's base name plus a timestamp plus its extension — i.e. it was
  // produced by backing up a same-named local item at some point. No
  // content comparison, purely name-based.
  function isRelated(entry, base, ext, isFolder) {
    if (entry.type !== (isFolder ? "folder" : "file")) return false
    var prefix = base + "_"
    if (entry.name.substring(0, prefix.length) !== prefix) return false
    if (ext === "") return entry.name.substring(entry.name.length - 1) !== "."
      && entry.name.indexOf(".", prefix.length) === -1
    return entry.name.substring(entry.name.length - ext.length) === ext
  }

  // --- list ----------------------------------------------------------------

  function refreshList() {
    if (root.cliPath === "" || root.loadingList) return
    root.loadingList = true
    listProc.command = ["bash", root.pluginDir + "/list-backups.sh", root.cliPath]
    listProc.running = false
    listProc.running = true
  }

  Process {
    id: listProc
    stdout: StdioCollector { id: listStdout; waitForEnd: true }
    onExited: function(exitCode) {
      root.loadingList = false
      var raw = (listStdout.text || "").trim()
      var parsed = []
      try { parsed = JSON.parse(raw) } catch (e) { parsed = [] }
      root.backups = Array.isArray(parsed) ? parsed : []
    }
  }

  // --- picking a file or folder --------------------------------------------

  function pickItem() {
    if (root.cliPath === "" || root.busy) return
    pickProc.command = ["omarchy-file-select", "--title", "Choose a file or folder to back up to Proton Drive"]
    pickProc.running = false
    pickProc.running = true
  }

  Process {
    id: pickProc
    stdout: StdioCollector { id: pickStdout; waitForEnd: true }
    onExited: function(exitCode) {
      var raw = (pickStdout.text || "").trim()
      if (exitCode !== 0 || raw === "") return
      root.pendingLocalPath = raw.split("\n")[0]
      statProc.command = ["bash", root.pluginDir + "/stat-kind.sh", root.pendingLocalPath]
      statProc.running = false
      statProc.running = true
    }
  }

  // The picker itself doesn't reliably distinguish file vs folder unless
  // asked with --directory, so kind is detected here after the fact
  // instead of by which button was pressed (see stat-kind.sh).
  Process {
    id: statProc
    stdout: StdioCollector { id: statStdout; waitForEnd: true }
    onExited: function(exitCode) {
      var isFolder = (statStdout.text || "").trim() === "folder"
      var name = root.baseNameOf(root.pendingLocalPath)
      var split = isFolder ? { base: name, ext: "" } : root.splitExt(name)
      root.pendingIsFolder = isFolder
      root.pendingBase = split.base
      root.pendingExt = split.ext
      root.pendingRemoteName = split.base + Format.timestampSuffix() + split.ext
      root.relatedBackups = root.backups.filter(function(b) {
        return root.isRelated(b, split.base, split.ext, isFolder)
      })
      root.selectedForTrash = ({})
      root.viewMode = "confirm"
    }
  }

  function toggleTrashSelection(name) {
    var m = {}
    for (var k in root.selectedForTrash) m[k] = root.selectedForTrash[k]
    m[name] = !m[name]
    root.selectedForTrash = m
  }

  function cancelPending() {
    root.pendingLocalPath = ""
    root.relatedBackups = []
    root.selectedForTrash = ({})
    root.viewMode = "list"
  }

  // --- confirm: trash selected old backups, then upload -------------------

  function confirmBackup() {
    if (root.busy || root.pendingLocalPath === "") return
    root.busy = true
    root.lastError = ""
    var toTrash = []
    for (var k in root.selectedForTrash) if (root.selectedForTrash[k]) toTrash.push(k)
    if (toTrash.length > 0) {
      root.busyLabel = "Deleting old backups…"
      trashProc.command = ["bash", root.pluginDir + "/delete-backups.sh", root.cliPath].concat(toTrash)
      trashProc.running = false
      trashProc.running = true
    } else {
      root.startUpload()
    }
  }

  Process {
    id: trashProc
    stdout: StdioCollector { id: trashStdout; waitForEnd: true }
    onExited: function(exitCode) {
      var raw = (trashStdout.text || "").trim()
      var parsed = null
      try { parsed = JSON.parse(raw) } catch (e) { parsed = null }
      if (!parsed || parsed.ok !== true) {
        root.lastError = "Some old backups could not be deleted — continuing with the new backup anyway."
      }
      root.startUpload()
    }
  }

  function startUpload() {
    root.busyLabel = "Uploading to Proton Drive…"
    uploadProc.command = ["bash", root.pluginDir + "/upload-backup.sh", root.cliPath,
      root.pendingLocalPath, root.pendingRemoteName]
    uploadProc.running = false
    uploadProc.running = true
  }

  Process {
    id: uploadProc
    stdout: StdioCollector { id: uploadStdout; waitForEnd: true }
    onExited: function(exitCode) {
      var raw = (uploadStdout.text || "").trim()
      var parsed = null
      try { parsed = JSON.parse(raw) } catch (e) { parsed = null }
      root.busy = false
      root.busyLabel = ""
      if (parsed && parsed.ok === true) {
        notifyProc.command = ["omarchy-notification-send", "-g", root.cloudGlyph,
          "Backup uploaded", root.pendingRemoteName]
        notifyProc.running = false
        notifyProc.running = true
        root.cancelPending()
        root.refreshList()
      } else {
        root.lastError = "Upload failed: " + (parsed ? parsed.message : raw)
        notifyProc.command = ["omarchy-notification-send", "-g", root.cloudGlyph, "-u", "critical",
          "Backup failed", root.lastError]
        notifyProc.running = false
        notifyProc.running = true
      }
    }
  }

  Process {
    id: notifyProc
  }

  // --- per-row actions on the main list ------------------------------------

  function deleteBackup(name) {
    if (root.busy) return
    root.busy = true
    root.busyLabel = "Deleting…"
    deleteOneProc.command = ["bash", root.pluginDir + "/delete-backups.sh", root.cliPath, name]
    deleteOneProc.running = false
    deleteOneProc.running = true
  }

  Process {
    id: deleteOneProc
    stdout: StdioCollector { id: deleteOneStdout; waitForEnd: true }
    onExited: function(exitCode) {
      root.busy = false
      root.busyLabel = ""
      var raw = (deleteOneStdout.text || "").trim()
      var parsed = null
      try { parsed = JSON.parse(raw) } catch (e) { parsed = null }
      if (!parsed || parsed.ok !== true) root.lastError = "Delete failed."
      root.refreshList()
    }
  }

  function downloadBackup(name) {
    if (root.busy) return
    root.busy = true
    root.busyLabel = "Downloading…"
    downloadProc.command = ["bash", root.pluginDir + "/download-backup.sh", root.cliPath, name, root.downloadDir]
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
          "Backup downloaded", parsed.localPath]
        notifyProc.running = false
        notifyProc.running = true
      } else {
        root.lastError = "Download failed."
        notifyProc.command = ["omarchy-notification-send", "-g", root.cloudGlyph, "-u", "critical",
          "Download failed", name]
        notifyProc.running = false
        notifyProc.running = true
      }
    }
  }

  // --- UI --------------------------------------------------------------

  Flickable {
    id: bodyFlick
    anchors.fill: parent
    clip: true
    contentWidth: width
    contentHeight: root.viewMode === "confirm" ? confirmColumn.implicitHeight : listColumn.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height

    Column {
      id: listColumn
      visible: root.viewMode === "list"
      width: bodyFlick.width
      spacing: Style.space(10)

      Text {
        visible: root.cliChecked && root.cliPath === ""
        width: parent.width
        text: "Proton Drive CLI not found — make sure proton-drive is installed and on PATH."
        color: Color.urgent
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
      }

      Text {
        visible: root.lastError !== ""
        width: parent.width
        text: root.lastError
        color: Color.urgent
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
      }

      Row {
        width: parent.width
        spacing: Style.spacing.sm

        Button {
          text: "+ New backup"
          bordered: true
          enabled: !root.busy && root.cliPath !== ""
          foreground: root.foreground
          accent: Color.accent
          fontFamily: root.fontFamily
          onClicked: root.pickItem()
        }

        Button {
          text: root.loadingList ? "…" : "↻"
          bordered: true
          enabled: !root.loadingList && root.cliPath !== ""
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.refreshList()
        }
      }

      Text {
        visible: root.busy
        width: parent.width
        text: root.busyLabel
        color: Qt.darker(root.foreground, 1.5)
        font.pixelSize: Style.font.bodySmall
      }

      PanelSeparator { foreground: root.foreground }

      Text {
        visible: !root.loadingList && root.backups.length === 0
        width: parent.width
        text: "No backups yet."
        color: Qt.darker(root.foreground, 1.5)
        font.pixelSize: Style.font.bodySmall
      }

      Repeater {
        model: root.backups

        Column {
          id: backupRow
          width: listColumn.width
          required property var modelData

          Row {
            width: parent.width
            spacing: Style.spacing.sm

            Column {
              width: parent.width - dlBtn.width - trashBtn.width - parent.spacing * 2
              spacing: Style.spacing.xxs

              Text {
                width: parent.width
                text: (backupRow.modelData.type === "folder" ? "📁 " : "") + backupRow.modelData.name
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideMiddle
              }

              Text {
                width: parent.width
                text: Format.formatDateTime(backupRow.modelData.modified)
                  + (backupRow.modelData.type === "folder" ? "" : "  ·  " + Format.formatBytes(backupRow.modelData.size))
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
              onClicked: root.downloadBackup(backupRow.modelData.name)
            }

            PanelActionButton {
              id: trashBtn
              iconText: "✕"
              tooltipText: "Delete"
              foreground: root.foreground
              hoverColor: Color.urgent
              enabled: !root.busy
              onClicked: root.deleteBackup(backupRow.modelData.name)
            }
          }

          PanelSeparator { foreground: root.foreground; strength: 0.06 }
        }
      }
    }

    Column {
      id: confirmColumn
      visible: root.viewMode === "confirm"
      width: bodyFlick.width
      spacing: Style.space(10)

      Text {
        width: parent.width
        text: (root.pendingIsFolder ? "📁 " : "") + root.baseNameOf(root.pendingLocalPath)
        color: root.foreground
        font.bold: true
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideMiddle
      }

      Text {
        width: parent.width
        text: "Will be uploaded as: " + root.pendingRemoteName
        color: Qt.darker(root.foreground, 1.5)
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
      }

      PanelSeparator { foreground: root.foreground }

      Text {
        visible: root.relatedBackups.length > 0
        width: parent.width
        text: "Existing backups of this item — check the ones to delete:"
        color: Qt.darker(root.foreground, 1.5)
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
      }

      Text {
        visible: root.relatedBackups.length === 0
        width: parent.width
        text: "No existing backups of this item."
        color: Qt.darker(root.foreground, 1.5)
        font.pixelSize: Style.font.bodySmall
      }

      Repeater {
        model: root.relatedBackups

        Toggle {
          required property var modelData
          width: confirmColumn.width
          label: modelData.name
          description: Format.formatDateTime(modelData.modified)
            + (modelData.type === "folder" ? "" : "  ·  " + Format.formatBytes(modelData.size))
          checked: root.selectedForTrash[modelData.name] === true
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.toggleTrashSelection(modelData.name)
        }
      }

      PanelSeparator { foreground: root.foreground }

      Text {
        visible: root.busy
        width: parent.width
        text: root.busyLabel
        color: Qt.darker(root.foreground, 1.5)
        font.pixelSize: Style.font.bodySmall
      }

      Row {
        width: parent.width
        spacing: Style.spacing.sm

        Button {
          text: "Confirm backup"
          bordered: true
          enabled: !root.busy
          foreground: root.foreground
          accent: Color.accent
          fontFamily: root.fontFamily
          onClicked: root.confirmBackup()
        }

        Button {
          text: "Cancel"
          bordered: true
          enabled: !root.busy
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.cancelPending()
        }
      }
    }
  }
}
