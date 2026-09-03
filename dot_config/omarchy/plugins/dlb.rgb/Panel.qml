import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "dlb.rgb"
  ipcTarget: "dlb.rgb"

  readonly property string controlCommand: Quickshell.env("HOME")
    + "/.local/bin/openrgb-msi7e49-control"
  readonly property string advancedCommand: Quickshell.env("HOME")
    + "/.local/bin/openrgb-msi7e49"
  readonly property string appearancePath: Quickshell.env("HOME")
    + "/.local/state/openrgb-msi7e49/appearance.json"
  readonly property string statePath: Quickshell.env("HOME")
    + "/.local/state/openrgb-msi7e49/state.json"
  readonly property string themeSyncPath: Quickshell.env("HOME")
    + "/.local/state/openrgb-msi7e49/theme-sync.json"
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color barIconForeground: bar ? bar.barForeground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool busy: actionProcess.running

  property string motherboardColor: "FF0000"
  property string ramColor: "00AAFF"
  property string savedMotherboardColor: "FF0000"
  property string savedRamColor: "00AAFF"
  property bool lightsOn: true
  property bool syncEnabled: false
  property string errorText: ""
  property bool lastActionFailed: false
  property string pickerTarget: "motherboard"
  property string pickerMotherboardColor: "FF0000"
  property string pickerRamColor: "00AAFF"
  property real pickerHue: 0
  property real pickerSaturation: 1
  property real pickerValue: 1
  property int barIconStyle: 3
  property bool iconColorSync: true
  property bool appearanceLoaded: false
  property var recentColors: []
  property var favoriteColors: []
  property var pendingRecentColors: []
  property bool themeSyncEnabled: false
  property bool themeSyncArmed: false
  property string themeSyncTheme: ""
  property string themeSyncMotherboard: ""
  property string themeSyncRam: ""
  property string themeSyncMapping: ""
  property string themeSyncPaletteSource: "theme"
  property string themeSyncWallpaper: ""
  property string themeSyncStatus: "disabled"
  property string themeSyncMessage: ""

  readonly property int savedColorLimit: 5
  readonly property string pickerHex: root.hsvToHex(root.pickerHue, root.pickerSaturation, root.pickerValue)
  readonly property color barIconOutline: root.lastActionFailed ? Color.urgent : root.barIconForeground
  readonly property color iconMotherboardColor: root.iconColorSync
    ? root.displayHex(root.lightsOn ? root.motherboardColor : root.savedMotherboardColor)
    : root.barIconForeground
  readonly property color iconRamColor: root.iconColorSync
    ? root.displayHex(root.lightsOn ? root.ramColor : root.savedRamColor)
    : root.barIconForeground
  readonly property real iconStateOpacity: root.iconColorSync && !root.lightsOn ? 0.5 : 1
  function validHex(value) {
    return /^#?[0-9A-Fa-f]{6}$/.test(String(value || ""))
  }

  function cleanHex(value) {
    return String(value || "").replace(/^#/, "").toUpperCase()
  }

  function displayHex(value) {
    return "#" + cleanHex(value)
  }

  function displayThemeName(value) {
    var words = String(value || "").replace(/[-_]+/g, " ").split(" ")
    for (var i = 0; i < words.length; i++) {
      if (words[i].length > 0)
        words[i] = words[i].charAt(0).toUpperCase() + words[i].slice(1)
    }
    return words.join(" ")
  }

  function validBarIconStyle(value) {
    var style = Number(value)
    return Number.isInteger(style) && style >= 0 && style <= 3
  }

  function clearError() {
    root.lastActionFailed = false
    root.errorText = ""
  }

  function showError(message) {
    root.errorText = String(message || "RGB action failed")
    root.lastActionFailed = true
  }

  function setBarIconStyle(value) {
    if (!root.validBarIconStyle(value)) return
    root.barIconStyle = Number(value)
    root.scheduleAppearanceSave()
  }

  function setIconColorSync(enabled) {
    root.iconColorSync = !!enabled
    root.scheduleAppearanceSave()
  }

  function scheduleAppearanceSave() {
    if (root.appearanceLoaded) appearanceSaveTimer.restart()
  }

  function loadAppearance(raw) {
    if (root.appearanceLoaded) return

    var needsSave = false
    var text = String(raw || "").trim()
    if (text !== "") {
      try {
        var appearance = JSON.parse(text)
        if (root.validBarIconStyle(appearance.barIconStyle))
          root.barIconStyle = Number(appearance.barIconStyle)
        else
          needsSave = true

        if (typeof appearance.iconColorSync === "boolean")
          root.iconColorSync = appearance.iconColorSync
        else
          needsSave = true

        root.recentColors = root.normalizeColorList(appearance.recentColors, root.savedColorLimit)
        root.favoriteColors = root.normalizeColorList(appearance.favoriteColors, root.savedColorLimit)
        if (appearance.version !== 2
            || !root.sameColorList(appearance.recentColors, root.recentColors)
            || !root.sameColorList(appearance.favoriteColors, root.favoriteColors))
          needsSave = true
      } catch (error) {
        needsSave = true
      }
    } else {
      needsSave = true
    }

    root.appearanceLoaded = true
    if (needsSave) root.scheduleAppearanceSave()
  }

  function flushAppearance() {
    appearanceFile.setText(JSON.stringify({
      version: 2,
      barIconStyle: root.barIconStyle,
      iconColorSync: root.iconColorSync,
      recentColors: root.recentColors.slice(0, root.savedColorLimit),
      favoriteColors: root.favoriteColors.slice(0, root.savedColorLimit)
    }, null, 2) + "\n")
  }

  function normalizeColorList(values, limit) {
    var normalized = []
    if (!Array.isArray(values)) return normalized

    for (var i = 0; i < values.length; i++) {
      if (!root.validHex(values[i])) continue
      var color = root.cleanHex(values[i])
      if (normalized.indexOf(color) !== -1) continue
      normalized.push(color)
      if (normalized.length >= limit) break
    }
    return normalized
  }

  function sameColorList(values, normalized) {
    if (!Array.isArray(values) || values.length !== normalized.length) return false
    for (var i = 0; i < normalized.length; i++) {
      if (!root.validHex(values[i]) || root.cleanHex(values[i]) !== normalized[i]) return false
    }
    return true
  }

  function rememberRecentColors(values) {
    var selected = root.normalizeColorList(values, root.savedColorLimit)
    var next = root.normalizeColorList(selected.concat(root.recentColors), root.savedColorLimit)
    if (root.sameColorList(root.recentColors, next)) return
    root.recentColors = next
    root.scheduleAppearanceSave()
  }

  function isFavoriteColor(value) {
    return root.validHex(value) && root.favoriteColors.indexOf(root.cleanHex(value)) !== -1
  }

  function toggleFavoriteColor(value) {
    if (!root.validHex(value)) return
    var color = root.cleanHex(value)
    var next = root.favoriteColors.slice()
    var index = next.indexOf(color)
    if (index === -1) {
      if (next.length >= root.savedColorLimit) {
        root.showError("Favorites are full; remove one before adding another")
        return
      }
      next.unshift(color)
    } else {
      next.splice(index, 1)
    }
    root.favoriteColors = root.normalizeColorList(next, root.savedColorLimit)
    root.scheduleAppearanceSave()
  }

  function selectSavedColor(value) {
    if (!root.validHex(value)) return
    var color = root.cleanHex(value)
    var hsv = root.rgbToHsv(color)
    if (root.syncEnabled) {
      root.pickerMotherboardColor = color
      root.pickerRamColor = color
    } else if (root.pickerTarget === "ram") {
      root.pickerRamColor = color
    } else {
      root.pickerMotherboardColor = color
    }
    if (hsv) {
      root.pickerHue = hsv.h
      root.pickerSaturation = hsv.s
      root.pickerValue = hsv.v
    }
  }

  function focusPanelControl(direction) {
    var forward = direction >= 0
    var next = keyCatcher.nextItemInFocusChain(forward)
    if (next && next !== keyCatcher && root.isPanelDescendant(next)) {
      next.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason)
      return true
    }
    return root.switchPanel(direction)
  }

  function isPanelDescendant(item) {
    var current = item
    while (current) {
      if (current === keyCatcher) return true
      current = current.parent
    }
    return false
  }

  function clampUnit(value) {
    return Math.max(0, Math.min(1, Number(value)))
  }

  function colorByte(value) {
    var text = Math.round(root.clampUnit(value) * 255).toString(16).toUpperCase()
    return text.length < 2 ? "0" + text : text
  }

  function hsvToHex(hue, saturation, value) {
    var h = ((Number(hue) % 1) + 1) % 1
    var s = root.clampUnit(saturation)
    var v = root.clampUnit(value)
    var sector = Math.floor(h * 6)
    var fraction = h * 6 - sector
    var p = v * (1 - s)
    var q = v * (1 - fraction * s)
    var t = v * (1 - (1 - fraction) * s)
    var r = 0
    var g = 0
    var b = 0

    switch (sector % 6) {
    case 0: r = v; g = t; b = p; break
    case 1: r = q; g = v; b = p; break
    case 2: r = p; g = v; b = t; break
    case 3: r = p; g = q; b = v; break
    case 4: r = t; g = p; b = v; break
    case 5: r = v; g = p; b = q; break
    }

    return root.colorByte(r) + root.colorByte(g) + root.colorByte(b)
  }

  function rgbToHsv(value) {
    var hex = root.cleanHex(value)
    if (!root.validHex(hex)) return null

    var r = parseInt(hex.substring(0, 2), 16) / 255
    var g = parseInt(hex.substring(2, 4), 16) / 255
    var b = parseInt(hex.substring(4, 6), 16) / 255
    var maximum = Math.max(r, g, b)
    var minimum = Math.min(r, g, b)
    var delta = maximum - minimum
    var hue = root.pickerHue

    if (delta > 0) {
      if (maximum === r) hue = ((g - b) / delta) % 6
      else if (maximum === g) hue = (b - r) / delta + 2
      else hue = (r - g) / delta + 4
      hue /= 6
      if (hue < 0) hue += 1
    }

    return {
      h: hue,
      s: maximum === 0 ? 0 : delta / maximum,
      v: maximum
    }
  }

  function syncPickerFromSelection(target) {
    var resolvedTarget = root.syncEnabled ? "motherboard" : target
    var value = resolvedTarget === "ram"
      ? root.pickerRamColor : root.pickerMotherboardColor
    var hsv = root.rgbToHsv(value)
    if (!hsv) return
    root.pickerHue = hsv.h
    root.pickerSaturation = hsv.s
    root.pickerValue = hsv.v
  }

  function setPickerTarget(target) {
    root.pickerTarget = root.syncEnabled ? "motherboard" : (target === "ram" ? "ram" : "motherboard")
    root.syncPickerFromSelection(root.pickerTarget)
  }

  function updatePickerSelection() {
    if (root.syncEnabled) {
      root.pickerMotherboardColor = root.pickerHex
      root.pickerRamColor = root.pickerHex
    } else if (root.pickerTarget === "ram") {
      root.pickerRamColor = root.pickerHex
    } else {
      root.pickerMotherboardColor = root.pickerHex
    }
  }

  function updatePickerSaturationValue(x, y, width, height) {
    root.pickerSaturation = root.clampUnit(x / Math.max(1, width))
    root.pickerValue = root.clampUnit(1 - y / Math.max(1, height))
    root.updatePickerSelection()
  }

  function updatePickerHue(x, width) {
    root.pickerHue = root.clampUnit(x / Math.max(1, width))
    root.updatePickerSelection()
  }

  function applyPickerTarget() {
    if (root.syncEnabled) root.applySynced()
    else if (root.pickerTarget === "ram") root.applyRam()
    else root.applyMotherboard()
  }

  function consumeResult(raw, actionResult) {
    var text = String(raw || "").trim()
    if (text === "") return

    try {
      var result = JSON.parse(text)
      if (result.motherboard) root.motherboardColor = String(result.motherboard).toUpperCase()
      if (result.ram) root.ramColor = String(result.ram).toUpperCase()
      if (result.savedMotherboard) root.savedMotherboardColor = String(result.savedMotherboard).toUpperCase()
      else root.savedMotherboardColor = root.motherboardColor
      if (result.savedRam) root.savedRamColor = String(result.savedRam).toUpperCase()
      else root.savedRamColor = root.ramColor
      if (typeof result.lightsOn === "boolean") root.lightsOn = result.lightsOn
      if (typeof result.syncEnabled === "boolean") root.syncEnabled = result.syncEnabled
      if (result.themeSync && typeof result.themeSync === "object") {
        var themeSync = result.themeSync
        if (typeof themeSync.enabled === "boolean") root.themeSyncEnabled = themeSync.enabled
        if (typeof themeSync.armed === "boolean") root.themeSyncArmed = themeSync.armed
        root.themeSyncTheme = String(themeSync.theme || "")
        root.themeSyncMotherboard = String(themeSync.motherboard || "").toUpperCase()
        root.themeSyncRam = String(themeSync.ram || "").toUpperCase()
        root.themeSyncMapping = String(themeSync.mapping || "")
        root.themeSyncPaletteSource = String(themeSync.paletteSource || "theme")
        root.themeSyncWallpaper = String(themeSync.wallpaper || "")
        root.themeSyncStatus = String(themeSync.status || (root.themeSyncEnabled ? "ready" : "disabled"))
        root.themeSyncMessage = String(themeSync.message || "")
      }

      var displayMotherboard = root.lightsOn ? root.motherboardColor : root.savedMotherboardColor
      var displayRam = root.lightsOn ? root.ramColor : root.savedRamColor
      if (root.syncEnabled) {
        root.pickerTarget = "motherboard"
        root.pickerMotherboardColor = displayMotherboard
        root.pickerRamColor = displayMotherboard
      } else {
        root.pickerMotherboardColor = displayMotherboard
        root.pickerRamColor = displayRam
      }
      root.syncPickerFromSelection(root.pickerTarget)
      if (result.ok === true) {
        if (actionResult && root.pendingRecentColors.length > 0)
          root.rememberRecentColors(root.pendingRecentColors)
        if (actionResult) root.pendingRecentColors = []
        root.clearError()
      } else {
        if (actionResult) root.pendingRecentColors = []
        root.showError(result.message || "RGB action failed")
      }
      if (root.themeSyncStatus === "error")
        root.showError(root.themeSyncMessage || "Omarchy theme sync failed")
    } catch (error) {
      if (actionResult) root.pendingRecentColors = []
      root.showError("Could not read the RGB controller response")
    }
  }

  function refreshStatus() {
    if (!statusProcess.running) statusProcess.running = true
  }

  function runAction(arguments, recentColors) {
    if (root.busy) return
    root.clearError()
    root.pendingRecentColors = root.normalizeColorList(recentColors || [], root.savedColorLimit)
    actionProcess.command = [root.controlCommand].concat(arguments)
    actionProcess.running = true
  }

  function requestLightsEnabled(enabled) {
    runAction(["power", enabled ? "on" : "off"])
  }

  function requestSyncEnabled(enabled) {
    runAction(["mode", enabled ? "sync" : "individual"])
  }

  function requestThemeSyncEnabled(enabled) {
    runAction(["theme-mode", enabled ? "on" : "off"])
  }

  function requestThemePaletteSource(source) {
    runAction(["palette-source", source])
  }

  function applyCurrentTheme() {
    if (!root.themeSyncEnabled || root.themeSyncTheme === "") return
    runAction(["theme-apply", root.themeSyncTheme])
  }

  function dismissError() {
    if (root.themeSyncStatus === "error") runAction(["theme-error", "dismiss"])
    else root.clearError()
  }

  function applySynced() {
    if (!validHex(root.pickerMotherboardColor)) {
      root.showError("Synced color must be six hex digits")
      return
    }
    var color = cleanHex(root.pickerMotherboardColor)
    root.pickerMotherboardColor = color
    root.pickerRamColor = color
    runAction(["apply", "all", color, color], [color])
  }

  function applyMotherboard() {
    if (!validHex(root.pickerMotherboardColor)) {
      root.showError("Motherboard color must be six hex digits")
      return
    }
    var color = cleanHex(root.pickerMotherboardColor)
    runAction(["apply", "motherboard", color], [color])
  }

  function applyRam() {
    if (!validHex(root.pickerRamColor)) {
      root.showError("RAM color must be six hex digits")
      return
    }
    var color = cleanHex(root.pickerRamColor)
    runAction(["apply", "ram", color], [color])
  }

  function openAdvanced() {
    if (root.busy) return
    root.close()
    Quickshell.execDetached([root.advancedCommand])
  }

  onOpenedChanged: if (opened) {
    root.syncPickerFromSelection(root.pickerTarget)
    root.refreshStatus()
  }

  implicitWidth: barButton.implicitWidth
  implicitHeight: barButton.implicitHeight

  Component {
    id: linkedStateGlyph

    Item {
      id: linkedIcon
      opacity: root.iconStateOpacity

      Rectangle {
        x: 5
        y: 7
        width: 6
        height: 2
        radius: 1
        color: root.barIconOutline
      }

      Rectangle {
        x: 0
        y: 4
        width: 8
        height: 8
        radius: 4
        color: root.iconMotherboardColor
        border.width: 1
        border.color: root.barIconOutline
      }

      Rectangle {
        x: 8
        y: 4
        width: 8
        height: 8
        radius: 4
        color: root.iconRamColor
        border.width: 1
        border.color: root.barIconOutline
      }

      RotationAnimation on rotation {
        from: 0
        to: 360
        duration: 900
        loops: Animation.Infinite
        running: root.busy
        onRunningChanged: if (!running) linkedIcon.rotation = 0
      }
    }
  }

  Component {
    id: stackedStateGlyph

    Item {
      id: stackedIcon
      opacity: root.iconStateOpacity

      Rectangle {
        x: 1
        y: 1
        width: 9
        height: 9
        radius: 4.5
        color: root.iconMotherboardColor
        border.width: 1
        border.color: root.barIconOutline
      }

      Rectangle {
        x: 6
        y: 6
        width: 9
        height: 9
        radius: 4.5
        color: root.iconRamColor
        border.width: 1
        border.color: root.barIconOutline
      }

      RotationAnimation on rotation {
        from: 0
        to: 360
        duration: 900
        loops: Animation.Infinite
        running: root.busy
        onRunningChanged: if (!running) stackedIcon.rotation = 0
      }
    }
  }

  Component {
    id: splitStateGlyph

    Item {
      id: splitIcon
      opacity: root.iconStateOpacity

      Item {
        x: 3
        y: 4
        width: 10
        height: 8
        clip: true

        Rectangle {
          width: 5
          height: parent.height
          color: root.iconMotherboardColor
        }

        Rectangle {
          x: 5
          width: 5
          height: parent.height
          color: root.iconRamColor
        }
      }

      Rectangle {
        x: 1
        y: 2
        width: 14
        height: 12
        radius: 3
        color: "transparent"
        border.width: 1
        border.color: root.barIconOutline
      }

      Rectangle {
        x: 7.5
        y: 3
        width: 1
        height: 10
        color: root.barIconOutline
      }

      RotationAnimation on rotation {
        from: 0
        to: 360
        duration: 900
        loops: Animation.Infinite
        running: root.busy
        onRunningChanged: if (!running) splitIcon.rotation = 0
      }
    }
  }

  Component {
    id: maingearStateGlyph

    Item {
      id: maingearIcon
      opacity: root.iconStateOpacity

      Image {
        id: maingearMarkSource
        anchors.fill: parent
        anchors.margins: 2
        source: Qt.resolvedUrl("maingear-mark.svg")
        sourceSize.width: 60
        sourceSize.height: 60
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: false
        visible: false
        layer.enabled: true
      }

      MultiEffect {
        anchors.fill: maingearMarkSource
        source: maingearMarkSource
        autoPaddingEnabled: false
        colorization: 1
        colorizationColor: root.iconMotherboardColor
      }

      RotationAnimation on rotation {
        from: 0
        to: 360
        duration: 900
        loops: Animation.Infinite
        running: root.busy
        onRunningChanged: if (!running) maingearIcon.rotation = 0
      }
    }
  }

  Process {
    id: statusProcess
    command: [root.controlCommand, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.consumeResult(text, false)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.showError("RGB status check failed")
      }
    }
  }

  Process {
    id: actionProcess
    command: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.consumeResult(text, true)
        root.pendingRecentColors = []
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.pendingRecentColors = []
      if (exitCode !== 0 && !root.lastActionFailed) {
        root.showError("RGB action failed with code " + exitCode)
      }
    }
  }

  FileView {
    id: appearanceFile
    path: root.appearancePath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadAppearance(text())
    onLoadFailed: root.loadAppearance("")
  }

  FileView {
    path: root.statePath
    watchChanges: true
    printErrors: false
    onFileChanged: stateRefreshTimer.restart()
  }

  FileView {
    path: root.themeSyncPath
    watchChanges: true
    printErrors: false
    onFileChanged: stateRefreshTimer.restart()
  }

  Timer {
    id: appearanceSaveTimer
    interval: 150
    repeat: false
    onTriggered: root.flushAppearance()
  }

  Timer {
    id: stateRefreshTimer
    interval: 150
    repeat: false
    onTriggered: {
      if (root.busy) restart()
      else root.refreshStatus()
    }
  }

  Timer {
    interval: 100
    running: true
    repeat: false
    onTriggered: root.refreshStatus()
  }

  BarIconButton {
    id: barButton
    anchors.fill: parent
    bar: root.bar
    iconComponent: root.barIconStyle === 1
      ? stackedStateGlyph
      : (root.barIconStyle === 2
          ? splitStateGlyph
          : (root.barIconStyle === 3 ? maingearStateGlyph : linkedStateGlyph))
    active: root.busy || root.lastActionFailed
    onPressed: function(button) {
      if (button === Qt.MiddleButton) root.openAdvanced()
      else if (button === Qt.RightButton) root.refreshStatus()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: barButton
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: !keyCatcher.activeFocus
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.focusPanelControl(direction) }

      Flickable {
        id: panelFlickable
        anchors.fill: parent
        contentWidth: width
        contentHeight: panelColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Keys.onEscapePressed: function(event) {
          root.close()
          event.accepted = true
        }

        Column {
          id: panelColumn
          width: parent.width
          spacing: Style.space(12)

          Item {
            width: parent.width
            implicitHeight: Math.max(heroGlyph.implicitHeight, heroLabels.implicitHeight)

            Item {
              id: heroGlyph
              width: Style.space(52)
              height: Style.space(42)
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter

              Loader {
                width: 16
                height: 16
                anchors.centerIn: parent
                scale: 2.3
                sourceComponent: root.barIconStyle === 1
                  ? stackedStateGlyph
                  : (root.barIconStyle === 2
                      ? splitStateGlyph
                      : (root.barIconStyle === 3 ? maingearStateGlyph : linkedStateGlyph))
              }
            }

            Column {
              id: heroLabels
              anchors.left: heroGlyph.right
              anchors.leftMargin: Style.space(14)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                text: "RGB STUDIO"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }

              Text {
                width: parent.width
                text: "MSI MS-7E49 · VOLATILE STATIC CONTROL"
                color: Qt.darker(root.foreground, 1.4)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1
                elide: Text.ElideRight
              }
            }
          }

          Rectangle {
            width: parent.width
            visible: root.lastActionFailed
            implicitHeight: visible ? errorRow.implicitHeight + Style.space(14) : 0
            radius: Style.cornerRadius
            color: Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.14)

            Row {
              id: errorRow
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(9)
              anchors.rightMargin: Style.space(9)
              spacing: Style.space(8)

              Text {
                id: errorIcon
                anchors.verticalCenter: parent.verticalCenter
                text: "󰅙"
                color: Color.urgent
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }

              Text {
                width: parent.width - errorIcon.implicitWidth
                  - dismissErrorButton.implicitWidth - parent.spacing * 2
                anchors.verticalCenter: parent.verticalCenter
                text: root.errorText
                color: Color.urgent
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.Wrap
              }

              PanelActionButton {
                id: dismissErrorButton
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰅖"
                tooltipText: "Dismiss error"
                foreground: Color.urgent
                hoverColor: Color.urgent
                fontFamily: root.fontFamily
                focusable: true
                onClicked: root.dismissError()
              }
            }
          }

          PanelSeparator { foreground: root.foreground }
          PanelSectionHeader {
            text: "VISUAL COLOR PICKER"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Rectangle {
            width: parent.width
            implicitHeight: pickerColumn.implicitHeight + Style.space(18)
            radius: Style.cornerRadius
            color: Style.normalFillFor(root.foreground, Color.accent)
            opacity: root.lightsOn ? 1 : 0.45

            Column {
              id: pickerColumn
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Style.space(9)
              spacing: Style.space(9)

              Row {
                width: parent.width
                visible: !root.syncEnabled
                spacing: Style.space(6)

                Button {
                  width: (parent.width - parent.spacing) / 2
                  text: "MOTHERBOARD"
                  focusable: true
                  bordered: true
                  selected: root.pickerTarget === "motherboard"
                  foreground: root.foreground
                  enabled: !root.busy && root.lightsOn
                  onClicked: root.setPickerTarget("motherboard")
                }

                Button {
                  width: (parent.width - parent.spacing) / 2
                  text: "RAM PAIR"
                  focusable: true
                  bordered: true
                  selected: root.pickerTarget === "ram"
                  foreground: root.foreground
                  enabled: !root.busy && root.lightsOn
                  onClicked: root.setPickerTarget("ram")
                }
              }

              Rectangle {
                id: saturationValuePicker
                width: parent.width
                height: Style.space(150)
                radius: Style.cornerRadius
                clip: true
                color: root.displayHex(root.hsvToHex(root.pickerHue, 1, 1))

                Rectangle {
                  anchors.fill: parent
                  gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 1) }
                    GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
                  }
                }

                Rectangle {
                  anchors.fill: parent
                  gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0) }
                    GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 1) }
                  }
                }

                Rectangle {
                  width: Style.space(16)
                  height: width
                  radius: width / 2
                  x: Math.max(0, Math.min(parent.width - width,
                                          root.pickerSaturation * parent.width - width / 2))
                  y: Math.max(0, Math.min(parent.height - height,
                                          (1 - root.pickerValue) * parent.height - height / 2))
                  color: "transparent"
                  border.width: Style.space(2)
                  border.color: "white"
                  z: 3
                }

                MouseArea {
                  anchors.fill: parent
                  enabled: !root.busy && root.lightsOn
                  cursorShape: Qt.CrossCursor
                  z: 4
                  onPressed: function(mouse) {
                    root.updatePickerSaturationValue(mouse.x, mouse.y, width, height)
                  }
                  onPositionChanged: function(mouse) {
                    if (pressed) root.updatePickerSaturationValue(mouse.x, mouse.y, width, height)
                  }
                }

                Rectangle {
                  anchors.fill: parent
                  radius: parent.radius
                  color: "transparent"
                  border.width: 1
                  border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.65)
                  z: 5
                }
              }

              Rectangle {
                id: huePicker
                width: parent.width
                height: Style.space(22)
                radius: height / 2
                clip: true

                gradient: Gradient {
                  orientation: Gradient.Horizontal
                  GradientStop { position: 0; color: "#FF0000" }
                  GradientStop { position: 0.1667; color: "#FFFF00" }
                  GradientStop { position: 0.3333; color: "#00FF00" }
                  GradientStop { position: 0.5; color: "#00FFFF" }
                  GradientStop { position: 0.6667; color: "#0000FF" }
                  GradientStop { position: 0.8333; color: "#FF00FF" }
                  GradientStop { position: 1; color: "#FF0000" }
                }

                Rectangle {
                  width: Style.space(8)
                  height: parent.height
                  radius: width / 2
                  x: Math.max(0, Math.min(parent.width - width,
                                          root.pickerHue * parent.width - width / 2))
                  color: "transparent"
                  border.width: Style.space(2)
                  border.color: "white"
                  z: 3
                }

                MouseArea {
                  anchors.fill: parent
                  enabled: !root.busy && root.lightsOn
                  cursorShape: Qt.PointingHandCursor
                  z: 4
                  onPressed: function(mouse) { root.updatePickerHue(mouse.x, width) }
                  onPositionChanged: function(mouse) {
                    if (pressed) root.updatePickerHue(mouse.x, width)
                  }
                }

                Rectangle {
                  anchors.fill: parent
                  radius: parent.radius
                  color: "transparent"
                  border.width: 1
                  border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.65)
                  z: 5
                }
              }

              Row {
                width: parent.width
                spacing: Style.space(8)

                Rectangle {
                  width: Style.space(34)
                  height: width
                  radius: width / 2
                  anchors.verticalCenter: parent.verticalCenter
                  color: root.displayHex(root.pickerHex)
                  border.width: 1
                  border.color: root.foreground
                }

                Column {
                  width: parent.width - applySelectedButton.width - Style.space(50)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(1)

                  Text {
                    text: root.syncEnabled
                      ? "SYNCED PREVIEW"
                      : (root.pickerTarget === "ram" ? "RAM PAIR PREVIEW" : "MOTHERBOARD PREVIEW")
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }

                  Text {
                    text: root.displayHex(root.pickerHex)
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                  }
                }

                Button {
                  id: applySelectedButton
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.syncEnabled ? "APPLY SYNCED" : "APPLY SELECTED"
                  focusable: true
                  bordered: true
                  foreground: root.foreground
                  enabled: !root.busy && root.lightsOn
                  onClicked: root.applyPickerTarget()
                }
              }

              Text {
                width: parent.width
                text: root.lightsOn
                  ? "PREVIEW ONLY · PICKING A COLOR DOES NOT ACCESS HARDWARE"
                  : "LIGHTS OFF · SWITCH THEM ON TO EDIT OR APPLY COLORS"
                color: Qt.darker(root.foreground, 1.45)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
              }
            }
          }

          PanelSeparator { foreground: root.foreground }
          PanelSectionHeader {
            text: "SAVED COLORS"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Text {
            width: parent.width
            text: root.favoriteColors.length > 0
              ? "FAVORITES · " + root.favoriteColors.length + "/" + root.savedColorLimit
              : "NO FAVORITES YET"
            color: Qt.darker(root.foreground, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Grid {
            width: parent.width
            visible: root.favoriteColors.length > 0
            columns: 5
            columnSpacing: Style.space(4)
            rowSpacing: Style.space(4)

            Repeater {
              model: root.favoriteColors

              Item {
                width: (parent.width - Style.space(16)) / 5
                implicitHeight: favoriteColorButton.implicitHeight
                opacity: root.busy ? 0.55 : 1

                Button {
                  id: favoriteColorButton
                  anchors.fill: parent
                  text: modelData
                  tooltipText: "Preview #" + modelData + " · right-click to remove favorite"
                  fontSize: Style.font.caption
                  horizontalPadding: Style.space(4)
                  verticalPadding: Style.space(5)
                  focusable: true
                  bordered: true
                  foreground: root.foreground
                  enabled: !root.busy
                  onClicked: root.selectSavedColor(modelData)
                  onRightClicked: root.toggleFavoriteColor(modelData)
                }

                Rectangle {
                  width: Style.space(11)
                  height: width
                  radius: width / 2
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(5)
                  anchors.verticalCenter: parent.verticalCenter
                  color: root.displayHex(modelData)
                  border.width: 1
                  border.color: root.foreground
                  z: 2
                }

                Text {
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(5)
                  anchors.verticalCenter: parent.verticalCenter
                  text: "★"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  z: 2
                }
              }
            }
          }

          Text {
            width: parent.width
            text: root.recentColors.length > 0
              ? "RECENTLY APPLIED · " + root.recentColors.length + "/" + root.savedColorLimit
              : "NO RECENTLY APPLIED COLORS"
            color: Qt.darker(root.foreground, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Grid {
            width: parent.width
            visible: root.recentColors.length > 0
            columns: 5
            columnSpacing: Style.space(4)
            rowSpacing: Style.space(4)

            Repeater {
              model: root.recentColors

              Item {
                width: (parent.width - Style.space(16)) / 5
                implicitHeight: recentColorButton.implicitHeight
                opacity: root.busy ? 0.55 : 1

                Button {
                  id: recentColorButton
                  anchors.fill: parent
                  text: modelData
                  tooltipText: "Preview #" + modelData + " · right-click to toggle favorite"
                  fontSize: Style.font.caption
                  horizontalPadding: Style.space(4)
                  verticalPadding: Style.space(5)
                  focusable: true
                  bordered: true
                  foreground: root.foreground
                  enabled: !root.busy
                  onClicked: root.selectSavedColor(modelData)
                  onRightClicked: root.toggleFavoriteColor(modelData)
                }

                Rectangle {
                  width: Style.space(11)
                  height: width
                  radius: width / 2
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(5)
                  anchors.verticalCenter: parent.verticalCenter
                  color: root.displayHex(modelData)
                  border.width: 1
                  border.color: root.foreground
                  z: 2
                }

                Text {
                  visible: root.isFavoriteColor(modelData)
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(5)
                  anchors.verticalCenter: parent.verticalCenter
                  text: "★"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  z: 2
                }
              }
            }
          }

          Text {
            width: parent.width
            text: "CLICK TO PREVIEW · RIGHT-CLICK TO FAVORITE · APPLY STILL CONTROLS HARDWARE"
            color: Qt.darker(root.foreground, 1.45)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
          }

          PanelSeparator { foreground: root.foreground }
          PanelSectionHeader {
            text: "LIGHTING"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Toggle {
            width: parent.width
            label: root.lightsOn ? "TURN LIGHTS OFF" : "TURN LIGHTS ON"
            description: root.lightsOn
              ? "Turn off for the night and remember both current colors"
              : "Restore motherboard " + root.displayHex(root.savedMotherboardColor)
                + " · RAM " + root.displayHex(root.savedRamColor)
            checked: root.lightsOn
            foreground: root.foreground
            fontFamily: root.fontFamily
            enabled: !root.busy
            opacity: enabled ? 1 : 0.55
            onClicked: root.requestLightsEnabled(!root.lightsOn)
          }

          Toggle {
            width: parent.width
            label: "SYNC DEVICE COLORS"
            description: root.syncEnabled
              ? "One color controls the motherboard and both RAM DIMMs"
              : "Choose motherboard and RAM colors individually"
            checked: root.syncEnabled
            foreground: root.foreground
            fontFamily: root.fontFamily
            enabled: !root.busy
            opacity: enabled ? 1 : 0.55
            onClicked: root.requestSyncEnabled(!root.syncEnabled)
          }

          Toggle {
            width: parent.width
            label: "AUTO-SYNC THEME SELECTIONS"
            description: root.themeSyncEnabled
              ? (root.themeSyncArmed
                  ? "On · future themes apply the "
                    + (root.themeSyncPaletteSource === "wallpaper" ? "wallpaper" : "theme accent")
                    + " palette"
                  : "On · apply the preview once below to start automatic updates")
              : "Off · theme selections will not change your lights"
            checked: root.themeSyncEnabled
            foreground: root.foreground
            fontFamily: root.fontFamily
            enabled: !root.busy
            opacity: enabled ? 1 : 0.55
            onClicked: root.requestThemeSyncEnabled(!root.themeSyncEnabled)
          }

          PanelSectionHeader {
            visible: root.themeSyncEnabled
            text: "PALETTE SOURCE"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Row {
            width: parent.width
            visible: root.themeSyncEnabled
            spacing: Style.space(6)

            Button {
              width: (parent.width - parent.spacing) / 2
              text: "THEME ACCENT"
              focusable: true
              bordered: true
              selected: root.themeSyncPaletteSource === "theme"
              foreground: root.foreground
              enabled: !root.busy
              onClicked: root.requestThemePaletteSource("theme")
            }

            Button {
              width: (parent.width - parent.spacing) / 2
              text: "WALLPAPER"
              focusable: true
              bordered: true
              selected: root.themeSyncPaletteSource === "wallpaper"
              foreground: root.foreground
              enabled: !root.busy
              onClicked: root.requestThemePaletteSource("wallpaper")
            }
          }

          Rectangle {
            width: parent.width
            height: root.themeSyncEnabled ? Style.space(62) : 0
            visible: root.themeSyncEnabled
            radius: Style.cornerRadius
            color: Style.normalFillFor(root.foreground, Color.accent)

            Column {
              anchors.left: parent.left
              anchors.right: themePaletteSwatches.left
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                width: parent.width
                text: root.displayThemeName(root.themeSyncTheme).toUpperCase()
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: root.syncEnabled
                  ? (root.themeSyncPaletteSource === "wallpaper"
                      ? "Wallpaper primary · both devices"
                      : "Accent · both devices")
                  : (root.themeSyncPaletteSource === "wallpaper"
                      ? "Wallpaper primary · MB   Companion · RAM"
                      : "Accent · motherboard   Magenta · RAM")
                color: Qt.darker(root.foreground, 1.35)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                visible: root.themeSyncPaletteSource === "wallpaper"
                  && root.themeSyncWallpaper !== ""
                text: root.themeSyncWallpaper
                color: Qt.darker(root.foreground, 1.5)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }

            Row {
              id: themePaletteSwatches
              anchors.right: parent.right
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              Column {
                spacing: Style.space(2)

                Rectangle {
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: Style.space(21)
                  height: width
                  radius: width / 2
                  color: root.validHex(root.themeSyncMotherboard)
                    ? root.displayHex(root.themeSyncMotherboard) : "transparent"
                  border.width: 1
                  border.color: root.foreground
                }

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "MB"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }

              Column {
                spacing: Style.space(2)

                Rectangle {
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: Style.space(21)
                  height: width
                  radius: width / 2
                  color: root.validHex(root.themeSyncRam)
                    ? root.displayHex(root.themeSyncRam) : "transparent"
                  border.width: 1
                  border.color: root.foreground
                }

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "RAM"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }
            }
          }

          Button {
            width: parent.width
            visible: root.themeSyncEnabled
            text: root.themeSyncArmed ? "APPLY CURRENT THEME" : "APPLY & START THEME SYNC"
            focusable: true
            bordered: true
            foreground: root.foreground
            enabled: !root.busy
              && root.themeSyncTheme !== ""
              && root.validHex(root.themeSyncMotherboard)
              && root.validHex(root.themeSyncRam)
            onClicked: root.applyCurrentTheme()
          }

          Text {
            width: parent.width
            visible: root.themeSyncEnabled
            text: root.lightsOn
              ? "THEME CHANGES USE ONE GUARDED COMBINED ACTION · NO RETRY"
              : "LIGHTS STAY OFF · NEW THEME COLORS ARE SAVED FOR RESUME"
            color: Qt.darker(root.foreground, 1.45)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
          }

          PanelSeparator { foreground: root.foreground }

          PanelSectionHeader {
            text: "ICON APPEARANCE"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Rectangle {
            width: parent.width
            height: Style.space(42)
            radius: Style.cornerRadius
            color: Style.normalFillFor(root.foreground, Color.accent)

            Column {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(9)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(1)

              Text {
                text: "BAR ICON"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }

              Text {
                text: "LIVE PREVIEW"
                color: Qt.darker(root.foreground, 1.5)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Row {
              anchors.right: parent.right
              anchors.rightMargin: Style.space(7)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(4)

              Button {
                width: Style.space(58)
                text: "LINK"
                fontSize: Style.font.caption
                horizontalPadding: Style.space(5)
                focusable: true
                bordered: true
                selected: root.barIconStyle === 0
                foreground: root.foreground
                onClicked: root.setBarIconStyle(0)
              }

              Button {
                width: Style.space(58)
                text: "STACK"
                fontSize: Style.font.caption
                horizontalPadding: Style.space(5)
                focusable: true
                bordered: true
                selected: root.barIconStyle === 1
                foreground: root.foreground
                onClicked: root.setBarIconStyle(1)
              }

              Button {
                width: Style.space(58)
                text: "SPLIT"
                fontSize: Style.font.caption
                horizontalPadding: Style.space(5)
                focusable: true
                bordered: true
                selected: root.barIconStyle === 2
                foreground: root.foreground
                onClicked: root.setBarIconStyle(2)
              }

              Button {
                width: Style.space(58)
                text: "MG"
                tooltipText: "Maingear mark"
                fontSize: Style.font.caption
                horizontalPadding: Style.space(5)
                focusable: true
                bordered: true
                selected: root.barIconStyle === 3
                foreground: root.foreground
                onClicked: root.setBarIconStyle(3)
              }
            }
          }

          Toggle {
            width: parent.width
            label: "SYNC ICON COLORS"
            description: root.iconColorSync
              ? "Use the motherboard and RAM lighting colors"
              : "Use the standard Omarchy plugin color"
            checked: root.iconColorSync
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.setIconColorSync(!root.iconColorSync)
          }

          PanelSeparator { foreground: root.foreground }

          Row {
            width: parent.width
            spacing: Style.space(6)

            Button {
              width: (parent.width - parent.spacing) / 2
              text: "REFRESH STATE"
              focusable: true
              foreground: root.foreground
              enabled: !root.busy
              onClicked: root.refreshStatus()
            }

            Button {
              width: (parent.width - parent.spacing) / 2
              text: "ADVANCED OPENRGB"
              focusable: true
              foreground: root.foreground
              enabled: !root.busy
              onClicked: root.openAdvanced()
            }
          }

          Text {
            width: parent.width
            text: "Writes are volatile. Loading this panel and refreshing state never access hardware."
            color: Qt.darker(root.foreground, 1.55)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
          }
        }
      }
    }
  }
}
