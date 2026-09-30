// Singularity - Quickshell
// ~/.config/quickshell/flyouts/BrightnessFlyout.qml
//
// Needs root's Night Light state --
// see the toggle in ControlCentre's Quick Actions for the same fields.
// Night Light's schedule is set here and run by shell.qml.

import "../services"
import "../services/TimeWindow.js" as TimeWindow
import QtQuick

FlyoutPanel {
    id: brightnessFlyout
    flyout: "brightness"
    menuWidth: 290

    required property var shellRoot

    FlyoutHeading { text: "BRIGHTNESS  " + Brightness.level + "%" }

    Slider {
        width: parent.width
        value: Brightness.level
        onMoved: v => Brightness.set(v)
    }

    FlyoutDivider {}

    FlyoutAction {
        icon: shellRoot.nightLight ? "󰖔" : "󰖙"
        label: "Night Light"
        status: !shellRoot.hasHyprsunset ? "hyprsunset not installed"
            : Settings.nightLightSchedule === "off" ? ""
            : (shellRoot.nightLight ? "Until " + brightnessFlyout.time(shellRoot.nightWindow[1])
                                    : "From " + brightnessFlyout.time(shellRoot.nightWindow[0]))
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

    FlyoutSegmented {
        label: "Schedule"
        labelInset: Theme.iconCell + Theme.spaceL
        enabled: shellRoot.hasHyprsunset
        model: [{ value: "off", text: "Off" }, { value: "sun", text: "Sunset" }, { value: "custom", text: "Custom" }]
        current: Settings.nightLightSchedule
        onPicked: v => Settings.setNightLightSchedule(v)
    }

    // sunset to sunrise comes from the weather; until it has loaded, 19:00 to 07:00
    FlyoutRow {
        visible: Settings.nightLightSchedule === "sun"
        enabled: false
        label: Weather.sunsetMin >= 0 ? "Sunset to sunrise" : "Until the weather loads"
        trailing: brightnessFlyout.time(shellRoot.nightWindow[0]) + "–" + brightnessFlyout.time(shellRoot.nightWindow[1])
        trailingIsValue: true
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
