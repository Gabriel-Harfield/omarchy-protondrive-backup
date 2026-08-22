.pragma library

// Shared pure formatting helpers used by both BackupTab.qml and
// BrowseTab.qml. Deliberately just formatting — no CLI paths, no state —
// so pulling this in doesn't couple the two tabs' actual behavior together.

function pad2(n) { return (n < 10 ? "0" : "") + n }

function formatBytes(n) {
  var v = Number(n) || 0
  var units = ["B", "KB", "MB", "GB", "TB"]
  var i = 0
  while (v >= 1024 && i < units.length - 1) { v /= 1024; i++ }
  return v.toFixed(v >= 10 || i === 0 ? 0 : 1) + " " + units[i]
}

function formatDateTime(epochMs) {
  if (!epochMs) return ""
  var d = new Date(epochMs)
  return pad2(d.getDate()) + "/" + pad2(d.getMonth() + 1) + "/" + d.getFullYear()
    + " " + pad2(d.getHours()) + ":" + pad2(d.getMinutes())
}

function timestampSuffix(date) {
  var d = date || new Date()
  return "_" + pad2(d.getDate()) + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getFullYear() % 100)
    + "_" + pad2(d.getHours()) + "h" + pad2(d.getMinutes())
}
