// Glass's Focus and Screen tools pages: their choices as action tiles that
// fill the height they are given.

import QtQuick
import "../services"

GlassTileGrid {
    id: root

    required property var cc
    readonly property string page: cc.page

    model: page === "focus" ? [
        { id: "quiet", icon: "󰂚", title: "Quiet", lit: Notifications.dnd,
          caption: Notifications.dnd ? "Banners held" : "Allow notifications" },
        { id: "awake", icon: "󰅶", title: "Keep Awake", lit: cc.shellRoot.keepAwake,
          caption: cc.shellRoot.keepAwake ? "No sleep" : "Allow idle sleep" },
        { id: "game", icon: "󰊴", title: "Game Mode", lit: GameMode.active,
          caption: GameMode.active ? "On" : "Off" },
    ] : page === "tools" ? cc.toolActions.map(t => ({ id: t.act, icon: t.icon, title: t.name })) : []

    onActivated: item => {
        if (page === "tools") cc.run(item.id)
        else if (item.id === "quiet") Notifications.toggleDnd()
        else if (item.id === "awake") cc.shellRoot.keepAwake = !cc.shellRoot.keepAwake
        else if (item.id === "game") GameMode.toggle()
    }
}
