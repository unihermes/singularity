// Singularity - Quickshell
// ~/.config/quickshell/flyouts/BrightnessFlyout.qml
//
// One slider per display it can set (see `controls`), then Night Light.
// Needs root's Night Light state --
// see the toggle in ControlCentre's Quick Actions for the same fields.
// Night Light's schedule is set here and run by shell.qml.

import "../services"
import "../services/TimeWindow.js" as TimeWindow
import QtQuick

FlyoutPanel {
    id: brightnessFlyout
    flyout: "brightness"
    menuWidth: 220

    required property var shellRoot

    // Every display it can set: the backlight, and each monitor that
    // answers DDC/CI, the one under this bar first. One is a bare slider
    // as before; more get a labelled slider each. Built from who has
    // answered, not from the levels: the levels change on every read and
    // drag, and each change would rebuild the sliders -- twice over, a
    // moment after opening, when the refresh below comes back.
    readonly property string output: scope.modelData.name
    readonly property var controls: {
        var out = []
        var ds = DdcBrightness.displays.slice()
            .filter(d => DdcBrightness.answered.indexOf(d.output) >= 0)
            .sort((a, b) => (b.output === output) - (a.output === output))
        for (var i = 0; i < ds.length; i++)
            out.push({ output: ds[i].output, label: ds[i].model || ds[i].output })
        if (Brightness.available) out.push({ output: "", label: "Built-in display" })
        return out
    }
    function levelOf(o) { return o === "" ? Brightness.level : DdcBrightness.level(o) }
    function setOf(o, v) { if (o === "") Brightness.set(v); else DdcBrightness.set(o, v) }

    // the monitors' own buttons may have moved them since the last look
    onOpenChanged: if (open) DdcBrightness.refresh()
    Component.onCompleted: if (open) DdcBrightness.refresh()

    FlyoutHeading {
        text: "BRIGHTNESS  " + (brightnessFlyout.controls.length > 0
            ? brightnessFlyout.levelOf(brightnessFlyout.controls[0].output) + "%" : "—")
    }

    Slider {
        visible: brightnessFlyout.controls.length === 1
        width: parent.width
        value: visible ? brightnessFlyout.levelOf(brightnessFlyout.controls[0].output) : 0
        onMoved: v => brightnessFlyout.setOf(brightnessFlyout.controls[0].output, v)
    }

    Repeater {
        model: brightnessFlyout.controls.length > 1 ? brightnessFlyout.controls : []

        FlyoutSliderRow {
            required property var modelData
            label: modelData.label
            suffix: "%"
            value: brightnessFlyout.levelOf(modelData.output)
            onMoved: v => brightnessFlyout.setOf(modelData.output, v)
        }
    }

    FlyoutDivider {}

    FlyoutAction {
        icon: shellRoot.nightLight ? "󰖔" : "󰖙"
        label: "Night Light"
        status: !shellRoot.hasHyprsunset ? "hyprsunset not installed"
            : Settings.nightLightSchedule === "off" ? ""
            : shellRoot.nightLight ? "Until " + brightnessFlyout.time(shellRoot.nightWindow[1])
            : "From " + brightnessFlyout.time(shellRoot.nightWindow[0])
        enabled: shellRoot.hasHyprsunset
        checked: shellRoot.nightLight
        onActivated: shellRoot.nightLight = !shellRoot.nightLight
    }

    // Same reasoning as Quick Actions' stepper: only shown while there's an
    // effect to see.
    FlyoutStepper {
        visible: shellRoot.nightLight
        label: "Warmth"
        labelInset: Theme.iconCell + Theme.spaceL
        valueWidth: 52
        suffix: "K"
        value: Settings.nightLightKelvin
        minimum: Settings.limits.nightLightKelvin.min
        maximum: Settings.limits.nightLightKelvin.max
        onStepped: d => Settings.step("nightLightKelvin", d * 250)
    }

    function time(m) { return TimeWindow.format(m, Theme.hours("HH:mm")) }

    // the schedule: off, sunset to sunrise (from the weather; 19:00 to
    // 07:00 until it loads), or two set times
    FlyoutSegmented {
        enabled: shellRoot.hasHyprsunset
        model: [{ value: "off", text: "Manual" }, { value: "sun", text: "Sunset" }, { value: "custom", text: "Custom" }]
        current: Settings.nightLightSchedule
        onPicked: v => Settings.setNightLightSchedule(v)
    }

    Repeater {
        model: Settings.nightLightSchedule === "custom"
            ? [{ key: "nightLightFrom", label: "From" }, { key: "nightLightTo", label: "To" }] : []

        FlyoutStepper {
            required property var modelData
            label: modelData.label
            labelInset: Theme.iconCell + Theme.spaceL
            valueWidth: 72
            // never inert at an end: the time wraps past midnight
            minimum: -1
            maximum: 1440
            value: Settings[modelData.key]
            displayValue: brightnessFlyout.time(value)
            onStepped: d => Settings.setScheduleTime(modelData.key, value + d * 30)
        }
    }
}
