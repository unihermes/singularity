// The taskbar's search: what you type shows in the bar's search box
// (scope.searchQuery) while this panel rises from it with the results --
// the best match large, then more apps and Settings pages. Empty, it shows
// your most used apps. The keys land here; the box only draws the text.
// Arrows walk the results, Enter opens one, Escape clears, then closes.

import Quickshell
import Quickshell.Widgets
import QtQuick
import "../services"
import "../services/SettingsIndex.js" as SettingsIndex

FlyoutPanel {
    id: root
    flyout: "barsearch"
    menuWidth: Theme.flyoutMenuWidth + 120
    edgeMargin: 0
    keyboardExclusive: true

    required property var settingsWin

    readonly property string query: scope.searchQuery.trim()

    // apps then Settings hits, one list for the arrows
    readonly property var results: {
        if (query === "") return []
        var apps = Apps.list(query, false).slice(0, 6).map(e => ({ app: e }))
        var sets = settingsWin && settingsWin.index
            ? SettingsIndex.search(settingsWin.index, query, 4).map(e => ({ setting: e })) : []
        return apps.concat(sets)
    }
    readonly property var topApps: Apps.list("", false).slice(0, 8)
    property int cursor: 0
    onQueryChanged: cursor = 0

    function activate(r) {
        if (!r) return
        scope.openFlyout = ""
        if (r.app) Apps.launch(r.app)
        else {
            settingsWin.open(r.setting.page)
            if (!r.setting.isPage) settingsWin.reveal(r.setting)
        }
    }

    // Enter: the highlighted result, or the top app with nothing typed
    function submit() {
        activate(query === "" ? (topApps[0] ? { app: topApps[0] } : null) : results[cursor])
    }

    onOpenChanged: {
        if (open) Qt.callLater(() => input.forceActiveFocus())
        else scope.searchQuery = ""
    }

    // the keys' sink: its text is the bar box's
    TextInput {
        id: input
        width: 0
        height: 0
        opacity: 0
        text: root.scope.searchQuery
        onTextChanged: if (root.scope.searchQuery !== text) root.scope.searchQuery = text
        Keys.onEscapePressed: {
            if (text !== "") root.scope.searchQuery = ""
            else root.requestClose()
        }
        Keys.onDownPressed: root.cursor = Math.min(root.results.length - 1, root.cursor + 1)
        Keys.onUpPressed: root.cursor = Math.max(0, root.cursor - 1)
        Keys.onReturnPressed: root.submit()
        Keys.onEnterPressed: root.submit()
    }

    // --- empty: the most used apps ----------------------------

    FlyoutHeading {
        visible: root.query === ""
        text: "TOP APPS"
    }

    Grid {
        id: tops
        visible: root.query === ""
        width: parent.width
        columns: 4
        spacing: Theme.spaceS
        readonly property real cell: (width - spacing * (columns - 1)) / columns
        Repeater {
            model: root.query === "" ? root.topApps : []
            Rectangle {
                required property var modelData
                width: tops.cell
                height: Theme.fs(76)
                radius: Theme.radiusInner
                color: topMouse.containsMouse ? Theme.hoverFill : Theme.overlay
                border.width: topMouse.containsMouse ? Theme.borderWidth : 0
                border.color: Theme.muted
                Column {
                    anchors.centerIn: parent
                    width: parent.width - Theme.spaceS * 2
                    spacing: Theme.spaceS
                    IconImage {
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitSize: Theme.fs(28)
                        source: Apps.iconPath(parent.parent.modelData.icon, true)
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: parent.parent.modelData.name
                        elide: Text.ElideRight
                        color: Theme.text
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fontCaption
                    }
                }
                MouseArea {
                    id: topMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activate({ app: parent.modelData })
                }
            }
        }
    }

    // --- typed: the best match, then the rest -----------------

    FlyoutHeading {
        visible: root.query !== ""
        text: "BEST MATCH"
    }

    FlyoutRow {
        visible: root.query !== "" && root.results.length === 0
        enabled: false
        label: "No results for “" + root.query + "”"
    }

    Item {
        id: best
        visible: root.results.length > 0
        readonly property var r: root.results[0] || null
        width: parent.width
        height: Theme.fs(56)
        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -Theme.spaceS
            anchors.rightMargin: -Theme.spaceS
            radius: Theme.radiusInner
            color: root.cursor === 0 || bestMouse.containsMouse ? Theme.hoverFill : "transparent"
        }
        IconImage {
            id: bestIcon
            visible: !!best.r && !!best.r.app
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: Theme.fs(36)
            source: best.r && best.r.app ? Apps.iconPath(best.r.app.icon, true) : ""
        }
        Text {
            visible: !!best.r && !!best.r.setting
            anchors.centerIn: bestIcon
            text: best.r && best.r.setting ? best.r.setting.icon : ""
            color: Theme.textStrong
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fs(28)
        }
        Column {
            anchors.left: bestIcon.right
            anchors.leftMargin: Theme.spaceL
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            Text {
                width: parent.width
                text: !best.r ? "" : best.r.app ? Apps.displayName(best.r.app) : best.r.setting.label
                elide: Text.ElideRight
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightStrong
                font.pixelSize: Theme.fontBody + Theme.spaceXs
            }
            Text {
                width: parent.width
                text: !best.r ? "" : best.r.app ? (best.r.app.genericName || "App")
                    : "Settings · " + best.r.setting.pageLabel
                elide: Text.ElideRight
                color: Theme.subtext
                font.family: Theme.fontText
                font.pixelSize: Theme.fontSmall
            }
        }
        MouseArea {
            id: bestMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activate(best.r)
        }
    }

    FlyoutHeading {
        visible: root.results.length > 1
        text: "MORE"
    }

    Repeater {
        model: ScriptModel { values: root.results.slice(1) }
        FlyoutRow {
            required property var modelData
            required property int index
            leadingIcon: modelData.setting ? modelData.setting.icon : ""
            leadingImage: modelData.app ? Apps.iconPath(modelData.app.icon, true) : ""
            label: modelData.app ? Apps.displayName(modelData.app) : modelData.setting.label
            trailing: modelData.app ? "App" : modelData.setting.pageLabel
            highlighted: root.cursor === index + 1
            onActivated: root.activate(modelData)
        }
    }
}
