import QtQuick
import Quickshell.Io
import "Model.js" as Model
import "Command.js" as Command

// One follower for every bar: `podcastamp now --follow --json` prints a line
// whenever what plays changes (each second while playing, nothing while
// paused) and an empty line when nothing plays. The player owns the state;
// this service only reads it and sends the controls.
Item {
  id: root

  property string omarchyPath: ""
  property var shell: null
  property var manifest: null

  // starting, ready (something plays), idle (nothing plays), unavailable
  // (podcastamp did not start), failed (it stopped; trying again).
  property string state: "starting"
  property var now: null
  property string lastError: ""
  // The last control and whether it worked, for the popout to say.
  property string lastAction: ""
  property bool lastActionOk: true
  property int actionSerial: 0

  property int exits: 0
  property bool heard: false
  property bool enabledFollow: true

  readonly property bool playing: now !== null && now.status === "playing"
  readonly property var verbs: ["toggle", "next", "quote", "show"]

  function consume(line) {
    if (!heard) lastError = ""
    heard = true
    exits = 0
    now = Model.parseNow(line)
    state = now ? "ready" : "idle"
  }

  // control runs one fixed verb of `podcastamp ctl`; seek takes whole seconds.
  function control(verb, delta) {
    var args = [Command.path, "ctl"]
    if (verb === "seek") args.push("seek", Model.seekArg(delta))
    else if (verbs.indexOf(verb) >= 0) args.push(verb)
    else return false
    if (action.running) return false
    actionSerial += 1
    action.serial = actionSerial
    action.verb = verb
    action.command = args
    action.running = true
    actionWatchdog.restart()
    return true
  }

  function startFollow() {
    if (!enabledFollow || follow.running) return
    heard = false
    follow.running = true
  }

  Process {
    id: follow
    command: [Command.path, "now", "--follow", "--json"]
    running: false
    stdout: SplitParser { onRead: function(line) { root.consume(line) } }
    stderr: SplitParser { onRead: function(line) { root.lastError = Model.clipText(line, 200) } }
    onExited: function(exitCode) {
      root.now = null
      root.state = root.heard ? "failed" : "unavailable"
      if (!root.heard && root.lastError === "")
        root.lastError = "podcastamp did not start (" + Command.path + ")"
      root.exits += 1
      restart.interval = Model.backoff(root.exits - 1)
      restart.restart()
    }
  }

  Timer {
    id: restart
    repeat: false
    onTriggered: root.startFollow()
  }

  Process {
    id: action
    property int serial: 0
    property string verb: ""
    running: false
    command: []
    stderr: SplitParser { onRead: function(line) { action.err = Model.clipText(line, 200) } }
    property string err: ""
    onRunningChanged: if (running) err = ""
    onExited: function(exitCode) {
      actionWatchdog.stop()
      // A later control has taken over the status line.
      if (serial !== root.actionSerial) return
      root.lastAction = verb
      root.lastActionOk = exitCode === 0
      root.lastError = exitCode === 0 ? "" : (err !== "" ? err : "podcastamp ctl " + verb + " failed")
    }
  }

  Timer {
    // ctl answers at once or the player is not answering; do not hold the
    // controls for it.
    id: actionWatchdog
    interval: 5000
    repeat: false
    onTriggered: if (action.running) action.running = false
  }

  IpcHandler {
    target: "io.github.ferakp.podcastamp"
    function toggle(): void { root.control("toggle") }
    function next(): void { root.control("next") }
    function quote(): void { root.control("quote") }
    function show(): void { root.control("show") }
    function seek(seconds: string): void { root.control("seek", Number(seconds)) }
    function status(): string {
      return JSON.stringify({
        state: root.state,
        status: root.now ? root.now.status : "",
        position: root.now ? Math.round(root.now.position) : 0,
        error: root.lastError !== ""
      })
    }
  }

  Component.onCompleted: startFollow()
  Component.onDestruction: {
    enabledFollow = false
    restart.stop()
    follow.running = false
  }
}
