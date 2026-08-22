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

// Neutralizes a remote-controlled string (a Proton Drive file/folder name)
// before it can reach a rich-text-capable sink. Plain `Text {}` elements in
// this plugin set `textFormat: Text.PlainText` directly instead, which is
// the more foolproof mechanism — but that property lives on qs.Ui's own
// Toggle component (used for the "related backups" list), which this
// plugin doesn't own and can't set it on, so its `label` input is
// neutralized here instead.
//
// Only "<" and ">" are escaped, not "&": Qt's Text.AutoText only switches
// into rich-text interpretation (and its "<img>" resource-loading, the
// actual risk here) when it sees a literal "<" — never on a bare "&". An
// ordinary filename with an ampersand ("Q&A.pdf") but no "<" is left
// untouched and displays correctly either way; escaping it too would
// render literally as "Q&amp;A.pdf" once AutoText decides (correctly)
// that a string with no "<" isn't rich text and stops decoding entities
// at all. Escaping "<"/">" removes every literal "<" from the string, so
// the rich-text heuristic never fires in the first place — regardless of
// which mode Qt ends up choosing, the name can't turn into markup.
function plainText(s) {
  return String(s == null ? "" : s)
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
}
