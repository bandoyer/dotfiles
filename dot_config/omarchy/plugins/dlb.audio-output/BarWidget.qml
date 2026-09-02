import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui

BarWidget {
  id: root
  moduleName: "dlb.audio-output"

  property string mode: "unknown"
  property bool switching: false

  readonly property bool arenaActive: mode === "arena"
  readonly property bool headsetActive: mode === "headset"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!statusProcess.running) statusProcess.running = true
  }

  function toggleOutput() {
    if (switching) return
    switching = true
    toggleProcess.running = true
  }

  Process {
    id: statusProcess
    command: [Quickshell.env("HOME") + "/.local/bin/asm-output-toggle", "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var value = String(text || "").trim()
        if (value !== "") root.mode = value
      }
    }
  }

  Process {
    id: toggleProcess
    command: [Quickshell.env("HOME") + "/.local/bin/asm-output-toggle", "toggle"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var value = String(text || "").trim()
        if (value !== "") root.mode = value
      }
    }
    onExited: function(exitCode) {
      root.switching = false
      refreshDelay.restart()
    }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: refreshDelay
    interval: 250
    repeat: false
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.arenaActive ? "󰓃" : (root.headsetActive ? "󰋋" : "󰋎")
    active: root.switching
    tooltipText: root.switching
      ? "Switching audio output…"
      : root.arenaActive
        ? "ASM output: Arena 7 · click for Arctis"
        : root.headsetActive
          ? "ASM output: Arctis · click for Arena 7"
          : "ASM output: custom · click for Arena 7"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggleOutput()
      else root.refresh()
    }
  }
}
