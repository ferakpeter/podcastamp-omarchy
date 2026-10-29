// Model.js as the shell loads it: plain functions in one scope.
import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync, readdirSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import vm from "node:vm"

const root = join(dirname(fileURLToPath(import.meta.url)), "..")
const M = {}
vm.runInNewContext(readFileSync(join(root, "Model.js"), "utf8"), M)

const line = (o) => JSON.stringify({ pid: 7, updated: "2026-10-29T09:00:00Z", status: "playing", id: "ab12", episode: "Episode", show: "Show", position: 61, duration: 3600, speed: 1, ...o })

test("a playing line is read", () => {
  const now = M.parseNow(line({ topic: "Ranking", link: "https://example.invalid/e" }))
  assert.equal(now.status, "playing")
  assert.equal(now.episode, "Episode")
  assert.equal(now.topic, "Ranking")
  assert.equal(now.link, "https://example.invalid/e")
  assert.equal(M.glyph(now), M.GLYPH_PAUSE)
})

test("nothing playing: an empty line, a stopped state, garbage", () => {
  for (const l of ["", line({ status: "stopped" }), "not json", "[]", "null", line({ id: "" }), line({ status: "<b>" })]) {
    assert.equal(M.parseNow(l), null, l)
  }
  assert.equal(M.glyph(null), M.GLYPH_IDLE)
})

test("bounds: oversized lines and fields", () => {
  assert.equal(M.parseNow("x".repeat(M.MAX_LINE + 1)), null)
  const now = M.parseNow(line({ episode: "e".repeat(5000), show: "s".repeat(301) }))
  assert.equal(Array.from(now.episode).length, M.MAX_TEXT)
  assert.ok(now.episode.endsWith("…"))
  assert.equal(Array.from(now.show).length, M.MAX_TEXT)
  assert.equal(M.parseNow(line({ link: "https://e.invalid/" + "a".repeat(3000) })).link, "")
  assert.equal(M.parseNow(line({ link: "javascript:alert(1)" })).link, "")
  assert.equal(M.parseNow(line({ episode: "a\u0000b\nc" })).episode, "a b c")
})

test("numbers are clamped", () => {
  const now = M.parseNow(line({ position: -5, duration: "x", speed: 99 }))
  assert.equal(now.position, 0)
  assert.equal(now.duration, 0)
  assert.equal(now.speed, 1)
  assert.equal(M.minutesLeft(now), -1)
  assert.equal(M.progress(now), 0)
})

test("markup in feed text stays inert in the tooltip", () => {
  const out = M.neutralize('<img src="https://example.invalid/tracker"> & <b>bold</b>')
  assert.ok(!/[<>&]/.test(out), out)
  assert.ok(out.includes("img src"))
})

test("clock, minutes left at speed, progress", () => {
  assert.equal(M.clock(0), "0:00")
  assert.equal(M.clock(65), "1:05")
  assert.equal(M.clock(3723), "1:02:03")
  const now = M.parseNow(line({ position: 600, duration: 3600, speed: 2 }))
  assert.equal(M.minutesLeft(now), 25)
  assert.ok(Math.abs(M.progress(now) - 1 / 6) < 1e-9)
})

test("bar title is clipped to the setting, within 8 and 80", () => {
  const now = M.parseNow(line({ episode: "A fairly long episode title about many things" }))
  assert.equal(Array.from(M.barTitle(now, 10)).length, 10)
  assert.equal(Array.from(M.barTitle(now, 2)).length, 8)
  assert.equal(M.barTitle(null, 30), "")
})

test("backoff doubles to a minute", () => {
  assert.deepEqual([0, 1, 2, 5, 6, 20].map(M.backoff), [1000, 2000, 4000, 32000, 60000, 60000])
})

test("seek arguments carry a sign and stay in an hour", () => {
  assert.equal(M.seekArg(30), "+30")
  assert.equal(M.seekArg(-10), "-10")
  assert.equal(M.seekArg(1e9), "+3600")
  assert.equal(M.seekArg("x"), "+0")
})

test("every string the QML asks for is in en.json", () => {
  const en = JSON.parse(readFileSync(join(root, "i18n", "en.json"), "utf8"))
  for (const f of readdirSync(root).filter((n) => n.endsWith(".qml"))) {
    const src = readFileSync(join(root, f), "utf8")
    for (const [, key] of src.matchAll(/strings\.tn?\("([^"]+)"/g)) {
      assert.ok(key in en, `${f}: ${key} missing from en.json`)
    }
  }
})

test("every Text in the QML is plain text", () => {
  for (const f of readdirSync(root).filter((n) => n.endsWith(".qml"))) {
    const src = readFileSync(join(root, f), "utf8")
    const texts = src.match(/^\s*Text \{/gm) || []
    const plain = src.match(/textFormat: Text\.PlainText/g) || []
    assert.equal(plain.length, texts.length, `${f}: ${texts.length} Text, ${plain.length} PlainText`)
  }
})
