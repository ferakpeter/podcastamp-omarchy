// What the podcastamp widget shows, as pure functions: a line of
// `podcastamp now --follow --json` read into a bounded state, and the
// labels made of it. No QML here, so tests run it without a shell.

var MAX_LINE = 16384
var MAX_TEXT = 300
var MAX_URL = 2048

var GLYPH_PLAY = "\u{f040a}"    // 󰐊
var GLYPH_PAUSE = "\u{f03e4}"   // 󰏤
var GLYPH_IDLE = "\u{f02cb}"    // 󰋋 headphones

function clipText(value, max) {
  var text = String(value === undefined || value === null ? "" : value).replace(/[\u0000-\u001f\u007f]/g, " ")
  var chars = Array.from(text)
  if (chars.length <= max) return text
  return chars.slice(0, Math.max(0, max - 1)).join("") + "…"
}

// neutralize keeps feed text inert in a sink that may read it as rich
// text (the bar's tooltip): the markup characters become look-alikes.
function neutralize(value) {
  return String(value === undefined || value === null ? "" : value)
    .replace(/&/g, "\uff06").replace(/</g, "\u2039").replace(/>/g, "\u203a")
}

function seconds(value) {
  var n = Number(value)
  return isFinite(n) && n > 0 ? n : 0
}

// A link the popout may open: http(s) only, bounded.
function safeURL(value) {
  var url = String(value || "")
  if (url.length > MAX_URL || !/^https?:\/\//i.test(url)) return ""
  return url
}

// parseNow reads one line: null when nothing plays (an empty line), or the
// line is not a state podcastamp wrote.
function parseNow(line) {
  var text = String(line || "")
  if (text.length === 0 || text.length > MAX_LINE) return null
  var raw
  try { raw = JSON.parse(text) } catch (error) { return null }
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null
  var status = String(raw.status || "")
  if (status !== "playing" && status !== "paused") return null
  var id = String(raw.id || "")
  if (id === "" || id.length > 128) return null
  var speed = Number(raw.speed)
  return {
    id: id,
    status: status,
    episode: clipText(raw.episode, MAX_TEXT),
    show: clipText(raw.show, MAX_TEXT),
    topic: clipText(raw.topic, MAX_TEXT),
    position: seconds(raw.position),
    duration: seconds(raw.duration),
    speed: isFinite(speed) && speed > 0 && speed <= 4 ? speed : 1,
    link: safeURL(raw.link)
  }
}

// clock writes seconds as 4:05 or 1:02:03.
function clock(value) {
  var total = Math.floor(seconds(value))
  var h = Math.floor(total / 3600), m = Math.floor(total % 3600 / 60), s = total % 60
  var two = function(n) { return (n < 10 ? "0" : "") + n }
  return h > 0 ? h + ":" + two(m) + ":" + two(s) : m + ":" + two(s)
}

// minutesLeft is the listening time left at the playing speed, rounded;
// -1 when the length is unknown.
function minutesLeft(now) {
  if (!now || now.duration <= 0) return -1
  return Math.max(0, Math.round((now.duration - now.position) / now.speed / 60))
}

function progress(now) {
  if (!now || now.duration <= 0) return 0
  return Math.min(1, Math.max(0, now.position / now.duration))
}

function glyph(now) {
  if (!now) return GLYPH_IDLE
  return now.status === "playing" ? GLYPH_PAUSE : GLYPH_PLAY
}

// barTitle is the episode for a horizontal bar, clipped to maxChars.
function barTitle(now, maxChars) {
  if (!now) return ""
  var max = Math.min(80, Math.max(8, Math.floor(Number(maxChars) || 32)))
  return clipText(now.episode || now.show, max)
}

// backoff is how long to wait before starting the follower again after its
// n-th exit in a row: 1 s doubling to a minute.
function backoff(n) {
  return Math.min(60000, 1000 * Math.pow(2, Math.max(0, Math.min(n, 6))))
}

// seekArg is the argument of `podcastamp ctl seek`: whole seconds with a sign.
function seekArg(delta) {
  var n = Math.round(Number(delta) || 0)
  n = Math.max(-3600, Math.min(3600, n))
  return (n >= 0 ? "+" : "") + n
}
