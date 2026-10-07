import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "m19182.vpn"
  ipcTarget: "m19182.vpn"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  property var profiles: []
  property string errorText: ""
  property string pending: ""
  property int selected: 0
  readonly property string helper: Quickshell.env("HOME") + "/.config/omarchy/plugins/m19182.vpn/vpn.py"
  readonly property var activeProfiles: profiles.filter(function(p) { return p.active })
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string statusText: pending !== "" ? "Updating VPN…" : (activeProfiles.length ? activeProfiles.map(function(p) { return p.name }).join(", ") + " connected" : "VPN disconnected")

  function refresh() { if (!poll.running) poll.running = true }
  function choose(profile) {
    if (action.running) return
    pending = profile.name
    errorText = ""
    action.command = ["python3", helper, profile.uuid]
    action.running = true
  }
  onOpenedChanged: if (opened) refresh()

  Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
  Process {
    id: poll
    command: ["python3", root.helper]
    stdout: StdioCollector { id: pollOut }
    stderr: StdioCollector { id: pollErr }
    onExited: function(code) {
      if (code === 0) {
        try { root.profiles = JSON.parse(pollOut.text); root.selected = Math.min(root.selected, Math.max(0, root.profiles.length - 1)) }
        catch (e) { root.errorText = "Could not read VPN status" }
      } else root.errorText = pollErr.text.trim()
    }
  }
  Process {
    id: action
    stderr: StdioCollector { id: actionErr }
    onExited: function(code) {
      root.pending = ""
      if (code !== 0) {
        root.errorText = actionErr.text.trim() || "VPN action failed"
        Quickshell.execDetached(["notify-send", "VPN", root.errorText])
      }
      root.refresh()
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰦝"
    foreground: root.errorText !== "" ? Color.urgent : (root.activeProfiles.length ? "#a6da95" : Qt.darker(root.barForeground, 1.55))
    tooltipText: root.statusText + " · Click to choose VPN"
    onPressed: root.toggle()
  }

  KeyboardPanel {
    id: popup
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keys
    contentWidth: popup.fittedContentWidth(Style.space(340))
    contentHeight: popup.fittedContentHeight(column.implicitHeight, Style.space(520))
    PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) { root.selected = Math.max(0, Math.min(root.profiles.length - 1, root.selected + dy)) }
      onActivateRequested: if (root.profiles.length) root.choose(root.profiles[root.selected])
      Flickable {
        anchors.fill: parent
        clip: true
        contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        Column {
          id: column
          width: parent.width
          spacing: Style.space(10)
          Text { text: "VPN"; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.display }
          Text { width: parent.width; text: root.statusText; color: root.foreground; font.pixelSize: Style.font.body; wrapMode: Text.WordWrap }
          Text { visible: root.errorText !== ""; width: parent.width; text: root.errorText; color: Color.urgent; wrapMode: Text.WordWrap }
          Repeater {
            model: root.profiles
            CursorSurface {
              required property var modelData
              required property int index
              width: column.width
              implicitHeight: Style.space(62)
              foreground: root.foreground
              current: modelData.active
              hasCursor: root.selected === index
              opacity: action.running ? 0.55 : 1
              Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Style.space(12)
                spacing: Style.space(4)
                Text { width: parent.width; text: modelData.name; elide: Text.ElideRight; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body }
                Text { text: (modelData.kind === "wireguard" ? "WireGuard" : "OpenVPN / VPN") + " · " + (modelData.active ? "Disconnect" : (root.activeProfiles.length ? "Switch to this VPN" : "Connect")); color: Qt.darker(root.foreground, 1.4); font.pixelSize: Style.font.bodySmall }
              }
              MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: !action.running; onEntered: root.selected = index; onClicked: root.choose(modelData) }
            }
          }
          Text { visible: !root.profiles.length; text: "No saved VPN profiles"; color: root.foreground }
          Button { text: "Manage / import VPNs"; enabled: !action.running; onClicked: { Quickshell.execDetached(["nm-connection-editor"]); root.close() } }
        }
      }
    }
  }
}
