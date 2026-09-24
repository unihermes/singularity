// Singularity - Quickshell
// ~/.config/quickshell/flyouts/Launcher.qml
//
// The search-first launcher that replaces wofi, drawn with the bar's own
// theme. Four modes, cycled with Tab (Shift+Tab goes back):
//   apps       CTRL+SPACE   -- desktop entries (services/Apps.qml)
//   files      SUPER+S      -- names under $HOME via fd (services/Files.qml)
//   clipboard  SUPER+H      -- cliphist history (services/Clipboard.qml)
//   calc       SUPER+slash  -- arithmetic (services/Calc.js), Enter copies
// All four arrive as `qs ipc call launcher toggle <mode>` (shell.qml), which
// sets scope.launcherMode and opens "launcher" in the shared openFlyout.
//
// calc's list is its result followed by the syntax it understands, filtered
// to whatever is being typed ("sq" narrows it to sqrt). Enter on the result
// copies it; Enter on a syntax row inserts it into the expression. So the
// box is the same shape in every mode and Enter always acts on the current
// row.

import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import "../services"
import "../services/Calc.js" as Calc

OverlayWindow {
    id: root

    readonly property bool open: scope.openFlyout === "launcher"
    readonly property string mode: root.scope.launcherMode
    readonly property bool clipMode: mode === "clipboard"
    readonly property bool calcMode: mode === "calc"
    readonly property bool fileMode: mode === "files"
    property string query: ""

    // Tab order. A mode the shell is asked for but doesn't know falls back
    // to apps rather than showing an empty box.
    readonly property var modes: ["apps", "files", "clipboard", "calc"]
    function stepMode(delta) {
        var i = modes.indexOf(mode)
        if (i === -1) i = 0
        root.scope.launcherMode = modes[(i + delta + modes.length) % modes.length]
    }

    readonly property var modeNames: ({
        "apps": "Applications", "clipboard": "Clipboard",
        "calc": "Calculator", "files": "Files"
    })
    readonly property string nextModeName: {
        var i = modes.indexOf(mode)
        return modeNames[modes[((i === -1 ? 0 : i) + 1) % modes.length]]
    }

    readonly property var calcResult: calcMode ? Calc.evaluate(query) : ({ ok: false, text: "" })

    readonly property var items: {
        if (!open) return []
        if (calcMode) {
            var rows = calcResult.text === "" ? []
                : [{ kind: "result", text: calcResult.text, ok: calcResult.ok,
                     hint: calcResult.ok ? "Enter to copy" : "" }]
            var ref = Calc.reference(query)
            for (var i = 0; i < ref.length; i++)
                rows.push({ kind: "ref", text: ref[i].name, hint: ref[i].desc,
                            insert: ref[i].insert })
            return rows
        }
        // nothing typed: the recent files, so the mode opens with something
        // useful rather than an empty box
        if (fileMode) return query.trim() === "" ? Files.recent : Files.results
        if (clipMode) {
            var q = query.trim().toLowerCase()
            return q === "" ? Clipboard.history
                : Clipboard.history.filter(e => e.preview.toLowerCase().indexOf(q) !== -1)
        }
        return Apps.list(query)
    }

    readonly property int visibleRows: 8

    // Rows scroll under a still pointer when the arrow keys move the list,
    // and that counts as hovering a new row. Only real pointer movement
    // may move the selection, or it snaps back to wherever the mouse sits.
    property point lastPointer: Qt.point(-1, -1)
    function pointerMoved(item, x, y) {
        var p = item.mapToGlobal(x, y)
        if (p.x === lastPointer.x && p.y === lastPointer.y) return false
        lastPointer = p
        return true
    }

    function requestClose() { scope.openFlyout = "" }

    function reset() {
        query = ""
        search.text = ""
        list.currentIndex = 0
        if (clipMode) Clipboard.refresh()
        Files.clear()
        Qt.callLater(search.forceFocus)
    }

    function activate(item) {
        if (!item) return
        // the calculator stays open: one result usually leads to the next
        // expression, and the copy is the whole action
        if (calcMode) {
            // a syntax row types itself into the expression instead of
            // acting, so the list is completion as well as a reminder
            if (item.kind === "ref") {
                search.text = search.text.replace(/[a-zA-Z][a-zA-Z0-9]*$/, "") + item.insert
                Qt.callLater(search.moveToEnd)
                return
            }
            if (item.ok) Quickshell.execDetached(["wl-copy", "--", item.text])
            return
        }
        requestClose()
        if (clipMode) Clipboard.select(item)
        else if (fileMode) Files.open(item)
        else Apps.launch(item)
    }

    // Shift+Enter: the row's second action, where it has one
    function activateAlt(item) {
        if (!fileMode || !item) return
        requestClose()
        Files.reveal(item)
    }

    function removeCurrent() {
        if (!clipMode || list.count === 0) return
        var i = list.currentIndex
        Clipboard.remove(items[i])
        Qt.callLater(() => list.currentIndex = Math.min(i, list.count - 1))
    }

    onOpenChanged: if (open) reset()
    onModeChanged: if (open) reset()

    visible: open
    focusMode: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    layerNamespace: "neutrino-flyout"

    MouseArea {
        anchors.fill: parent
        onClicked: root.requestClose()
    }

    PanelFrame {
        id: box
        width: Theme.fit(760)
        height: body.implicitHeight + Theme.sp(40)
        // Centred on the screen, at a fixed size: the list area is always
        // visibleRows tall, however many results there are, so the box
        // doesn't shrink and re-centre on every keystroke.
        anchors.centerIn: parent

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Column {
            id: body
            x: Theme.sp(22)
            y: Theme.sp(20)
            width: parent.width - Theme.sp(44)
            spacing: Theme.spaceM

            Item {
                width: parent.width
                height: title.implicitHeight

                Text {
                    id: title
                    text: Theme.heading(root.clipMode ? "CLIPBOARD"
                        : root.calcMode ? "CALCULATOR"
                        : root.fileMode ? "FILES" : "APPLICATIONS")
                    color: Theme.headingColor
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontSmall
                    font.bold: Theme.headingBold
                    font.letterSpacing: Theme.headingSpacing
                }

                // the key hints sit inline with the title rather than in a
                // footer, so the box is only as tall as its rows
                Text {
                    anchors.right: parent.right
                    text: (root.clipMode ? "Enter copy   Shift+Del remove   Esc close"
                            : root.calcMode ? "Enter copy   Esc close"
                            : root.fileMode ? "Enter open   Shift+Enter folder   Esc close"
                            : "Enter open   Esc close")
                        + "   Tab " + root.nextModeName
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontSmall
                }
            }

            FlyoutInput {
                id: search
                width: parent.width
                echoPassword: false
                placeholder: root.clipMode ? "Search clipboard"
                    : root.calcMode ? "2 + 2 * 3, sqrt(16), 200 * 15%"
                    : root.fileMode ? "Search files in ~"
                    : "Search applications"
                onTextChanged: {
                    root.query = text
                    list.currentIndex = 0
                    if (root.fileMode) Files.search(text)
                }
                onAccepted: if (list.count > 0) root.activate(root.items[list.currentIndex])
                onShiftReturnPressed: if (list.count > 0) root.activateAlt(root.items[list.currentIndex])
                onDownPressed: if (list.currentIndex < list.count - 1) list.currentIndex++
                onUpPressed: if (list.currentIndex > 0) list.currentIndex--
                onEscapePressed: root.requestClose()
                onTabPressed: root.stepMode(1)
                onBackTabPressed: root.stepMode(-1)
                onShiftDeletePressed: root.removeCurrent()
            }

            Item {
                width: parent.width
                height: root.visibleRows * (Theme.rowHeightTall + list.spacing)

                Text {
                    visible: list.count === 0
                    width: parent.width
                    height: Theme.rowHeightTall
                    verticalAlignment: Text.AlignVCenter
                    text: root.calcMode ? "No matching syntax"
                        : root.fileMode
                            ? (root.query === "" ? "No recent files"
                               : Files.searching ? "Searching..." : "No matches")
                        : root.query !== "" ? "No matches"
                        : root.clipMode ? "Clipboard history is empty" : "No applications"
                    color: Theme.textDisabled
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontBody
                }

                ListView {
                    id: list
                    visible: count > 0
                    width: parent.width
                    height: parent.height
                    clip: true
                    spacing: Theme.spaceXs
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.items
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        width: list.width
                        height: Theme.rowHeightTall

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusInner
                            color: row.ListView.isCurrentItem ? Theme.hoverFill : "transparent"
                        }

                        IconImage {
                            id: appIcon
                            visible: !root.clipMode && !root.calcMode && !root.fileMode
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spaceS
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: Theme.fs(18)
                            source: appIcon.visible ? Quickshell.iconPath(row.modelData.icon, true) : ""
                        }

                        Text {
                            id: glyph
                            visible: !appIcon.visible
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spaceS
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.fs(18)
                            horizontalAlignment: Text.AlignHCenter
                            text: root.calcMode
                                    ? (row.modelData.kind === "ref" ? "󰘧" : "󰃬")
                                : root.fileMode ? (row.modelData.isDir ? "󰉋" : "󰈔")
                                : row.modelData.isImage ? "󰋩" : "󰅍"
                            color: Theme.subtext
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.fontBody
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spaceS + Theme.fs(18) + Theme.sp(10)
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spaceS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0

                            Text {
                                width: parent.width
                                // `|| ""` throughout: switching mode swaps
                                // the model out from under the delegates,
                                // and for an instant a row of the old shape
                                // is asked for the new mode's field
                                text: (root.clipMode
                                        ? (row.modelData.isImage ? "Image" : row.modelData.preview)
                                    : root.calcMode ? row.modelData.text
                                    : row.modelData.name) || ""
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                color: root.calcMode && row.modelData.kind === "result"
                                        ? (row.modelData.ok ? Theme.textStrong : Theme.subtext)
                                    : row.ListView.isCurrentItem ? Theme.textStrong : Theme.text
                                font.family: Theme.fontText
                                font.pixelSize: Theme.fontBody
                                font.bold: root.calcMode && row.modelData.kind === "result"
                            }

                            // where the file is, so two files with the same
                            // name are told apart without opening either
                            Text {
                                visible: (root.fileMode || root.calcMode) && text !== ""
                                width: parent.width
                                text: root.fileMode ? Files.pretty(row.modelData.dir)
                                    : root.calcMode ? (row.modelData.hint || "") : ""
                                elide: root.fileMode ? Text.ElideLeft : Text.ElideRight
                                maximumLineCount: 1
                                color: Theme.subtext
                                font.family: Theme.fontText
                                font.pixelSize: Theme.fontSmall
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: mouse => {
                                if (root.pointerMoved(rowMouse, mouse.x, mouse.y)) list.currentIndex = row.index
                            }
                            onClicked: root.activate(row.modelData)
                        }
                    }
                }
            }
        }
    }
}
