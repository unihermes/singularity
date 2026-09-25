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

    // Every row is the height of two lines, whether or not it has a second,
    // so the fill and stroke of the current row always clear its text and
    // the box stays one size from mode to mode.
    FontMetrics { id: bodyMetrics; font.family: Theme.fontText; font.pixelSize: Theme.fontBody }
    FontMetrics { id: captionMetrics; font.family: Theme.fontText; font.pixelSize: Theme.fontCaption }
    readonly property int rowHeight: Math.max(Theme.fieldHeight,
        Math.ceil(bodyMetrics.height + 1 + captionMetrics.height) + Theme.spaceM)

    // the key hints over the field, for the mode on show
    readonly property var hints: (clipMode ? ["Enter copy", "Shift+Del remove"]
            : calcMode ? ["Enter copy"]
            : fileMode ? ["Enter open", "Shift+Enter folder"]
            : ["Enter open"]).concat(["Tab " + nextModeName])

    PanelFrame {
        id: box
        width: Theme.fit(760)
        height: body.implicitHeight + Theme.panelPad * 4
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
            x: Theme.panelPad * 2
            y: Theme.panelPad * 2
            width: parent.width - Theme.panelPad * 4
            spacing: Theme.spaceL

            // the mode's name cut into a rule, as a flyout's headings are,
            // with the key hints at its far end rather than in a footer
            Item {
                width: parent.width
                height: Math.max(title.implicitHeight, hintRow.implicitHeight)

                Text {
                    id: title
                    anchors.verticalCenter: parent.verticalCenter
                    text: Theme.heading(root.clipMode ? "CLIPBOARD"
                        : root.calcMode ? "CALCULATOR"
                        : root.fileMode ? "FILES" : "APPLICATIONS")
                    color: Theme.headingColor
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontSmall
                    font.bold: Theme.headingBold
                    font.letterSpacing: Theme.headingSpacing
                }

                Rectangle {
                    visible: Theme.headingRule
                    anchors.left: title.right
                    anchors.leftMargin: Theme.spaceL
                    anchors.right: hintRow.left
                    anchors.rightMargin: Theme.spaceL
                    anchors.verticalCenter: parent.verticalCenter
                    height: Theme.borderWidth
                    color: Theme.stroke
                }

                Row {
                    id: hintRow
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spaceXl

                    Repeater {
                        model: root.hints

                        Text {
                            required property string modelData
                            text: modelData.toUpperCase()
                            color: Theme.subtext
                            font.family: Theme.fontText
                            font.pixelSize: Theme.fontEyebrow
                            font.letterSpacing: 1
                        }
                    }
                }
            }

            // the search field, drawn as Settings' is: the mode's glyph, lit
            // while the field has focus, then the query
            Rectangle {
                id: searchBar
                width: parent.width
                height: Theme.rowHeightTall + Theme.spaceM
                radius: Theme.radiusInner
                color: Theme.fieldFill
                border.width: Theme.borderWidth
                border.color: search.activeFocus ? Theme.strokeFocus : Theme.stroke

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    onClicked: search.forceActiveFocus()
                }

                Item {
                    id: modeGlyph
                    x: Theme.spaceL
                    width: Theme.iconCell
                    height: parent.height

                    Text {
                        anchors.centerIn: parent
                        text: root.clipMode ? "󰅍" : root.calcMode ? "󰃬"
                            : root.fileMode ? "󰉋" : "󰀻"
                        color: search.activeFocus ? Theme.accent : Theme.subtext
                        font.family: Theme.fontIcon
                        font.pixelSize: Theme.fontIconSize
                    }
                }

                Text {
                    anchors.left: search.left
                    anchors.right: search.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: search.text === ""
                    text: root.clipMode ? "Search clipboard"
                        : root.calcMode ? "2 + 2 * 3, sqrt(16), 200 * 15%"
                        : root.fileMode ? "Search files in ~"
                        : "Search applications"
                    elide: Text.ElideRight
                    color: Theme.textDisabled
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontBody
                }

                TextInput {
                    id: search
                    anchors.left: modeGlyph.right
                    anchors.leftMargin: Theme.spaceM
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spaceL
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    color: Theme.textStrong
                    selectionColor: Theme.muted
                    selectedTextColor: Theme.textStrong
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontBody

                    function forceFocus() {
                        forceActiveFocus()
                        selectAll()
                    }
                    // after inserting text: keep typing where the insert
                    // left off, not with the whole field selected
                    function moveToEnd() {
                        forceActiveFocus()
                        cursorPosition = text.length
                    }

                    onTextChanged: {
                        root.query = text
                        list.currentIndex = 0
                        if (root.fileMode) Files.search(text)
                    }
                    onAccepted: if (list.count > 0) root.activate(root.items[list.currentIndex])
                    Keys.onDownPressed: if (list.currentIndex < list.count - 1) list.currentIndex++
                    Keys.onUpPressed: if (list.currentIndex > 0) list.currentIndex--
                    Keys.onEscapePressed: root.requestClose()
                    Keys.onTabPressed: root.stepMode(1)
                    Keys.onBacktabPressed: root.stepMode(-1)
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
                            root.removeCurrent()
                            event.accepted = true
                        }
                        // caught here rather than in onAccepted, which can't
                        // tell a plain Enter from a shifted one
                        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                && (event.modifiers & Qt.ShiftModifier)) {
                            if (list.count > 0) root.activateAlt(root.items[list.currentIndex])
                            event.accepted = true
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: root.visibleRows * (root.rowHeight + list.spacing) - list.spacing

                Text {
                    visible: list.count === 0
                    x: Theme.spaceL + Theme.iconCell + Theme.spaceM
                    width: parent.width - x
                    height: root.rowHeight
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
                        readonly property bool current: ListView.isCurrentItem
                        readonly property bool isResult: root.calcMode && modelData.kind === "result"
                        width: list.width
                        height: root.rowHeight

                        // the row the keys are on, lit as Settings lights
                        // its search hits: a fill and a quiet stroke
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusInner
                            color: row.current ? Theme.selectedFill : "transparent"
                            border.width: Theme.borderWidth
                            border.color: row.current ? Theme.strokeHover : "transparent"
                        }

                        Item {
                            id: iconCell
                            x: Theme.spaceL
                            width: Theme.iconCell
                            height: parent.height

                            IconImage {
                                id: appIcon
                                visible: !root.clipMode && !root.calcMode && !root.fileMode
                                anchors.centerIn: parent
                                implicitSize: Theme.iconCell
                                source: appIcon.visible ? Quickshell.iconPath(row.modelData.icon, true) : ""
                            }

                            Text {
                                visible: !appIcon.visible
                                anchors.centerIn: parent
                                text: root.calcMode
                                        ? (row.modelData.kind === "ref" ? "󰘧" : "󰃬")
                                    : root.fileMode ? (row.modelData.isDir ? "󰉋" : "󰈔")
                                    : row.modelData.isImage ? "󰋩" : "󰅍"
                                color: row.current ? Theme.textStrong : Theme.subtext
                                font.family: Theme.fontIcon
                                font.pixelSize: Theme.fontIconSize
                            }
                        }

                        Column {
                            anchors.left: iconCell.right
                            anchors.leftMargin: Theme.spaceM
                            anchors.right: chevron.left
                            anchors.rightMargin: Theme.spaceS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

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
                                // a copied page's HTML shows as its markup,
                                // not as rich text with the images missing
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                color: row.isResult && !row.modelData.ok ? Theme.subtext
                                    : row.current || row.isResult ? Theme.textStrong : Theme.text
                                font.family: Theme.fontText
                                font.pixelSize: Theme.fontBody
                                font.bold: row.isResult
                            }

                            // what the app is, where the file is (so two of
                            // the same name are told apart without opening
                            // either), or what the syntax does
                            Text {
                                visible: text !== ""
                                width: parent.width
                                text: (root.fileMode ? Files.pretty(row.modelData.dir)
                                    : root.calcMode ? row.modelData.hint
                                    : root.clipMode ? ""
                                    : row.modelData.genericName || row.modelData.comment) || ""
                                elide: root.fileMode ? Text.ElideLeft : Text.ElideRight
                                maximumLineCount: 1
                                color: Theme.subtext
                                font.family: Theme.fontText
                                font.pixelSize: Theme.fontCaption
                            }
                        }

                        Text {
                            id: chevron
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spaceL
                            anchors.verticalCenter: parent.verticalCenter
                            text: ">"
                            opacity: row.current ? 1 : 0
                            color: Theme.subtext
                            font.family: Theme.fontText
                            font.pixelSize: Theme.fontSmall
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

                ScrollBar {
                    anchors.right: parent.right
                    anchors.rightMargin: -Theme.spaceM
                    flickable: list
                }
            }
        }
    }
}
