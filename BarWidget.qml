import QtQuick
import Quickshell
import qs.Ui
import qs.Commons
import qs.Commons as Commons
import "Model.js" as Model

// What podcastamp plays, in the bar. Click plays or pauses (or opens the
// player when nothing plays), middle click skips to the next topic, the
// wheel seeks, right click opens the popout. Every bar shares one service.
BarWidget {
  id: root
  moduleName: "io.github.ferakp.podcastamp"

  // The service may be created after this bar; look until it is there, for
  // a minute at most. Under a replacement bar there is none, and the widget
  // says so instead of starting a follower of its own.
  property var service: null
  property int lookups: 0

  function lookUp() {
    var api = root.bar ? root.bar.shell : null
    var found = api && typeof api.serviceFor === "function" ? api.serviceFor(root.moduleName) : null
    if (found) root.service = found
    root.lookups += 1
  }

  Timer {
    interval: 1000
    repeat: true
    triggeredOnStart: true
    running: root.service === null && root.lookups < 60
    onTriggered: root.lookUp()
  }

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  readonly property var now: service ? service.now : null
  readonly property string serviceState: service ? service.state : "unavailable"
  readonly property bool showIdle: setting("showWhenIdle", true) === true
  readonly property int maxTitleChars: Math.min(80, Math.max(8, Number(setting("maxTitleChars", 32)) || 32))
  readonly property int minutes: Model.minutesLeft(now)

  // The popout contract: the bar coordinates popouts through these.
  property bool popupOpen: false
  readonly property bool opened: popupOpen
  function open() { popupOpen = true }
  function close() { popupOpen = false }

  function act(verb, delta) {
    if (service) service.control(verb, delta)
  }

  function primary() {
    act(root.now ? "toggle" : "show")
  }

  readonly property string label: {
    if (root.vertical || !root.now) return Model.glyph(root.now)
    var text = Model.glyph(root.now) + "  " + Model.barTitle(root.now, root.maxTitleChars)
    if (root.minutes >= 0) text += "  ·  " + strings.tn("minutesLeft", root.minutes).arg(Commons.I18n.formatNumber(root.minutes))
    return text
  }

  readonly property string tooltip: {
    if (root.serviceState === "unavailable") return strings.t("tooltip.unavailable")
    if (!root.now) return strings.t("tooltip.idle")
    var lines = [Model.neutralize(root.now.show), Model.neutralize(root.now.episode)]
    if (root.now.topic !== "") lines.push("§ " + Model.neutralize(root.now.topic))
    lines.push(strings.t("time").arg(Model.clock(root.now.position)).arg(Model.clock(root.now.duration)))
    lines.push(strings.t("tooltip.hint"))
    return lines.join("\n")
  }

  visible: root.now !== null || root.showIdle
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.label
    // The bar's tooltip sink may read rich text; tooltip neutralizes the
    // feed's text in it.
    tooltipText: root.tooltip
    dimmed: root.now === null
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.popupOpen = !root.popupOpen
      else if (mouseButton === Qt.MiddleButton) { if (root.now) root.act("next") }
      else root.primary()
    }
    onWheelMoved: function(delta) {
      if (!root.now || delta === 0) return
      root.act("seek", delta > 0 ? 30 : -10)
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(340))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Item {
      anchors.fill: parent
      focus: root.popupOpen
      Keys.onEscapePressed: root.close()

      Column {
        id: column
        width: parent.width
        spacing: Style.space(8)

        Text {
          textFormat: Text.PlainText
          width: parent.width
          visible: root.now !== null
          text: root.now ? root.now.show : ""
          color: Qt.darker(root.bar ? root.bar.foreground : Commons.Color.foreground, 1.3)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: root.now ? root.now.episode
            : (root.serviceState === "unavailable" ? strings.t("popout.unavailable") : strings.t("popout.nothing"))
          color: root.bar ? root.bar.foreground : Commons.Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
          wrapMode: Text.Wrap
          maximumLineCount: 3
          elide: Text.ElideRight
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          visible: text !== ""
          text: root.now && root.now.topic !== "" ? "§ " + root.now.topic : ""
          color: Qt.darker(root.bar ? root.bar.foreground : Commons.Color.foreground, 1.3)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
        }

        Item {
          width: parent.width
          height: Style.space(4)
          visible: root.now !== null && root.now.duration > 0

          Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.15)
          }
          Rectangle {
            width: parent.width * Model.progress(root.now)
            height: parent.height
            radius: height / 2
            color: Commons.Color.accent
          }
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          visible: root.now !== null
          text: {
            if (!root.now) return ""
            var time = strings.t("time").arg(Model.clock(root.now.position)).arg(Model.clock(root.now.duration))
            if (root.minutes < 0) return time
            return strings.t("timeLeft").arg(time).arg(strings.tn("minutesLeft", root.minutes).arg(Commons.I18n.formatNumber(root.minutes)))
          }
          color: Qt.darker(root.bar ? root.bar.foreground : Commons.Color.foreground, 1.3)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(6)
          visible: root.now !== null
          // Transport controls read back, play, forward in every language.
          LayoutMirroring.enabled: false
          LayoutMirroring.childrenInherit: true

          Button {
            text: strings.t("popout.back")
            tooltipText: strings.t("popout.backHint")
            foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
            onClicked: root.act("seek", -10)
          }
          Button {
            iconText: root.now && root.now.status === "playing" ? Model.GLYPH_PAUSE : Model.GLYPH_PLAY
            tooltipText: strings.t("popout.playPause")
            foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
            iconSize: Style.font.iconLarge
            horizontalPadding: Style.spacing.panelGap
            onClicked: root.act("toggle")
          }
          Button {
            text: strings.t("popout.forward")
            tooltipText: strings.t("popout.forwardHint")
            foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
            onClicked: root.act("seek", 30)
          }
          Button {
            text: strings.t("popout.nextTopic")
            foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
            onClicked: root.act("next")
          }
        }

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(6)

          Button {
            visible: root.now !== null
            text: strings.t("popout.quote")
            tooltipText: strings.t("popout.quoteHint")
            foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
            onClicked: root.act("quote")
          }
          Button {
            text: strings.t("popout.open")
            foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
            onClicked: { root.act("show"); root.close() }
          }
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          visible: text !== ""
          text: {
            var s = root.service
            if (!s) return root.lookups >= 60 ? strings.t("status.noService") : ""
            if (s.lastError !== "") return strings.t("status.failed").arg(s.lastError)
            if (s.lastAction === "quote" && s.lastActionOk) return strings.t("status.quoted")
            return ""
          }
          color: root.service && root.service.lastError !== "" ? Commons.Color.urgent
            : Qt.darker(root.bar ? root.bar.foreground : Commons.Color.foreground, 1.3)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.Wrap
          maximumLineCount: 3
          elide: Text.ElideRight
        }
      }
    }
  }
}
