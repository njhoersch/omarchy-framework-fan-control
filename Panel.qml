import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model

Panel {
  id: root

  moduleName: "nate.framework.fan-control"
  ipcTarget: "nate.framework.fan-control"

  readonly property string helperPath: "/usr/local/libexec/omarchy-framework-fan-control"
  property var fanState: Model.unavailable("Checking fan control…")
  property int stagedPercent: 50
  property bool stageInitialized: false
  property bool actionBusy: false
  property string actionError: ""
  property string focusSection: "mode"
  property bool cursorActive: false
  property int modeCursorIndex: 0

  readonly property bool available: fanState && fanState.available === true
  readonly property bool manual: available && fanState.mode === "manual"
  readonly property string modeLabel: manual ? "MANUAL " + fanState.percent + "%" : "AUTOMATIC"
  readonly property string statusLabel: available ? fanState.rpm + " RPM" : "UNAVAILABLE"

  function configuredDefaultPercent() {
    return Model.snapPercent(root.setting("defaultManualPercent", 50))
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function acceptStatus(text) {
    var next = Model.parseStatus(text)
    root.fanState = next
    if (!root.stageInitialized) {
      root.stagedPercent = next.available && next.mode === "manual"
        ? Model.snapPercent(next.percent)
        : root.configuredDefaultPercent()
      root.stageInitialized = true
    } else if (next.available && next.mode === "manual" && !root.actionBusy) {
      root.stagedPercent = Model.snapPercent(next.percent)
    }
    if (next.available && !root.actionBusy)
      root.modeCursorIndex = next.mode === "manual" ? 1 : 0
  }

  function runAction(arguments) {
    if (!root.available || root.actionBusy) return
    root.actionError = ""
    root.actionBusy = true
    actionProc.command = ["sudo", "-n", root.helperPath].concat(arguments)
    actionProc.running = true
  }

  function setAutomatic() {
    root.runAction(["auto"])
  }

  function setManual(percent) {
    var snapped = Model.snapPercent(percent)
    root.stagedPercent = snapped
    root.runAction(["manual", String(snapped)])
  }

  function selectMode(mode) {
    if (mode === "automatic") {
      root.modeCursorIndex = 0
      if (root.manual) root.setAutomatic()
    } else if (mode === "manual") {
      root.modeCursorIndex = 1
      if (!root.manual) root.setManual(root.stagedPercent)
    }
  }

  function adjustStage(delta) {
    root.stagedPercent = Model.snapPercent(root.stagedPercent + delta * 10)
    if (root.manual) root.setManual(root.stagedPercent)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: {
    root.stagedPercent = root.configuredDefaultPercent()
    root.refresh()
  }

  onOpenedChanged: {
    if (opened) {
      root.refresh()
      root.focusSection = "mode"
      root.modeCursorIndex = root.manual ? 1 : 0
      root.cursorActive = false
    }
  }

  Timer {
    interval: root.opened ? 1000 : 5000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProc
    command: [root.helperPath, "status"]
    stdout: StdioCollector { id: statusOut; waitForEnd: true }
    stderr: StdioCollector { id: statusErr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0 && String(statusOut.text || "").trim() !== "") {
        root.acceptStatus(statusOut.text)
      } else {
        var detail = String(statusErr.text || "").trim()
        root.fanState = Model.unavailable(detail || "Run the plugin setup to install the fan helper")
      }
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector { id: actionOut; waitForEnd: true }
    stderr: StdioCollector { id: actionErr; waitForEnd: true }
    onExited: function(exitCode) {
      root.actionBusy = false
      if (exitCode !== 0)
        root.actionError = String(actionErr.text || "Fan control command failed").trim()
      root.refresh()
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰈐"
    active: root.manual
    dimmed: !root.available
    tooltipText: Model.tooltip(root.fanState)
    onPressed: function(button) { if (button === Qt.LeftButton) root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(460))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        root.cursorActive = true
        if (dy !== 0) root.focusSection = root.focusSection === "mode" ? "speed" : "mode"
        else if (dx !== 0 && root.available && !root.actionBusy) {
          if (root.focusSection === "mode")
            root.modeCursorIndex = Math.max(0, Math.min(1, root.modeCursorIndex + dx))
          else
            root.adjustStage(dx)
        }
      }
      onActivateRequested: {
        root.cursorActive = true
        if (!root.available || root.actionBusy) return
        if (root.focusSection === "mode")
          root.selectMode(root.modeCursorIndex === 0 ? "automatic" : "manual")
        else if (root.manual) root.setManual(root.stagedPercent)
      }
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: panelColumn
        width: parent.width
        spacing: Style.space(14)

        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

          Text {
            id: heroIcon
            text: "󰈐"
            color: root.manual ? root.bar.urgent : root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Framework Fan"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: root.available ? root.modeLabel + " · " + root.statusLabel : root.statusLabel
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.1
              elide: Text.ElideRight
              width: parent.width
            }
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        Column {
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: "CONTROL MODE"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          ButtonGroup {
            id: modeGroup
            anchors.horizontalCenter: parent.horizontalCenter
            options: [
              { value: "automatic", label: "Automatic" },
              { value: "manual", label: "Manual" }
            ]
            value: root.manual ? "manual" : "automatic"
            cursorIndex: root.cursorActive && root.focusSection === "mode" ? root.modeCursorIndex : -1
            focusable: false
            foreground: root.bar.foreground
            background: root.bar.background
            fontFamily: root.bar.fontFamily
            enabled: root.available && !root.actionBusy
            opacity: enabled ? 1 : 0.45
            onChanged: function(value) { root.selectMode(value) }
            onHovered: function(index, hovered) {
              if (!hovered) return
              root.cursorActive = true
              root.focusSection = "mode"
              root.modeCursorIndex = index
            }
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        Column {
          width: parent.width
          spacing: Style.space(6)

          Item {
            width: parent.width
            implicitHeight: Math.max(speedHeader.implicitHeight, speedValue.implicitHeight)

            PanelSectionHeader {
              id: speedHeader
              text: root.manual ? "FAN SPEED" : "STAGED FAN SPEED"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: speedValue
              text: (fanSlider.dragging ? Model.percentForIndex(fanSlider.liveValue) : root.stagedPercent) + "%"
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              anchors.right: parent.right
              anchors.rightMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          CursorSurface {
            width: parent.width
            height: fanSlider.implicitHeight + Style.spacing.controlGap
            hasCursor: root.cursorActive && root.focusSection === "speed"
            foreground: root.bar.foreground
            outline: true
            enabled: root.available && !root.actionBusy
            opacity: enabled ? 1 : 0.45

            PanelSlider {
              id: fanSlider
              bar: root.bar
              anchors.fill: parent
              anchors.leftMargin: Style.space(6)
              anchors.rightMargin: Style.space(6)
              minimum: 0
              maximum: 9
              step: 1
              integer: true
              tickCount: 10
              value: Model.indexForPercent(root.stagedPercent)
              onMoved: function(value) { root.stagedPercent = Model.percentForIndex(value) }
              onReleased: function(value) {
                root.stagedPercent = Model.percentForIndex(value)
                if (root.manual) root.setManual(root.stagedPercent)
              }
            }

            HoverHandler {
              onHoveredChanged: if (hovered) {
                root.cursorActive = true
                root.focusSection = "speed"
              }
            }
          }
        }

        Text {
          visible: !root.available || root.actionError !== ""
          text: root.actionError !== "" ? root.actionError : root.fanState.reason
          color: root.bar.urgent
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
          width: parent.width
        }

      }
    }
  }
}
