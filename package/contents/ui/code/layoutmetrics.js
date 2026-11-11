/* eslint-disable */
// @ts-nocheck
/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2024 Kisaragi Hiu <mail@kisaragi-hiu.com>
    SPDX-FileCopyrightText: 2024 Marco Martin <notmart@gmail.com>
    SPDX-FileCopyrightText: 2024 ivan tkachenko <me@ratijas.tk>
    SPDX-FileCopyrightText: 2012-2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

.import org.kde.kirigami as Kirigami

const iconMargin = Math.round(Kirigami.Units.smallSpacing / 4);
const labelMargin = Kirigami.Units.smallSpacing;
function leftMargin(panel) {
    return panel.taskFrame.margins.left * (panel.vertical ? 1 : (Kirigami.Settings.tabletMode ? 1.5 : panel.config.iconSpacing));
}
function rightMargin(panel) {
    return panel.taskFrame.margins.right * (panel.vertical ? 1 : (Kirigami.Settings.tabletMode ? 1.5 : panel.config.iconSpacing));
}
function topMargin(panel) {
    return panel.taskFrame.margins.top * (panel.vertical ? (Kirigami.Settings.tabletMode ? 1.5 : panel.config.iconSpacing) : 1);
}
function bottomMargin(panel) {
    return panel.taskFrame.margins.bottom * (panel.vertical ? (Kirigami.Settings.tabletMode ? 1.5 : panel.config.iconSpacing) : 1);
}



function horizontalMargins(panel) {
    return leftMargin(panel) + rightMargin(panel);
}

function verticalMargins(panel) {
    return topMargin(panel) + bottomMargin(panel);
}

function adjustMargin(panel, height, margin) {
    const available = height - verticalMargins(panel);

    if (available < Kirigami.Units.iconSizes.small) {
        return Math.floor((margin * (Kirigami.Units.iconSizes.small / available)) / 3);
    }

    return margin;
}

function maxStripes(panel) {
    const length = panel.vertical ? panel.width : panel.height;
    const minimum = panel.vertical ? preferredMinWidth(panel) : preferredMinHeight(panel);

    return Math.min(panel.config.maxStripes, Math.max(1, Math.floor(length / minimum)));
}

function optimumCapacity(panel, width, height) {
    const length = panel.vertical ? height : width;
    const maximum = panel.vertical ? preferredMaxHeight(panel) : preferredMaxWidth(panel);

    if (!panel.vertical) {
        //  Fit more tasks in this case, that is possible to cut text, before combining tasks.
        return Math.ceil(length / maximum) * maxStripes(panel) + 1;
    }

    return Math.floor(length / maximum) * maxStripes(panel);
}

function preferredMinWidth(panel) {
    let width = preferredMinLauncherWidth(panel);

    if (!panel.vertical && !panel.iconsOnly) {
        width +=
            (Kirigami.Units.smallSpacing * 2) +
            (Kirigami.Units.gridUnit * 8);
        // A classic button is never narrower than its configured width, which
        // can be well below the default minimum; going by the default would
        // keep the applet wider than a button and start new rows too late.
        width = Math.min(width, classicMinButtonWidth(panel));
    }

    return width;
}

function classicMinButtonWidth(panel) {
    const config = panel.config;
    return config.fitButtonToText
        ? Math.min(config.minFitButtonLength, config.maxButtonLength)
        : config.maxButtonLength;
}

function preferredMaxWidth(panel) {
    if (panel.iconsOnly) {
        if (panel.vertical) {
            return panel.width + verticalMargins(panel);
        } else {
            return panel.height + horizontalMargins(panel);
        }
    }

    // Avoid doing a bunch of unnecessary work below in vertical mode
    if (panel.vertical) {
        return preferredMinWidth(panel);
    }

    // Visually, a large max item width on a tall panel looks cluttered even
    // with just a task or two open. This clutter is less pronounced on panels
    // lower in height, as there is generally more horizontal space.
    //
    // This allows for one default value for max item width where clutter is
    // reduced at low task counts for tall panels, while leaving low height
    // panels less affected (unaffected at 20px).
    // For Classic mode (Horizontal)
    return panel.config.maxButtonLength;
}

function preferredMinHeight(panel) {
    // TODO FIXME UPSTREAM: Port to proper font metrics for descenders once we have access to them.
    return Kirigami.Units.iconSizes.sizeForLabels + 4;
}

function preferredMaxHeight(panel) {
    if (panel.vertical) {
        let taskPreferredSize = 0;
        if (panel.iconsOnly) {
            taskPreferredSize = panel.width / maxStripes(panel);
        } else {
            taskPreferredSize = Math.max(Kirigami.Units.iconSizes.sizeForLabels,
                Kirigami.Units.iconSizes.medium);
        }
        return verticalMargins(panel) +
            Math.min(
                // Do not allow the preferred icon size to exceed the width of
                // the vertical task manager.
                panel.width / maxStripes(panel),
                taskPreferredSize);
    } else {
        return verticalMargins(panel) +
            Math.min(
                Kirigami.Units.iconSizes.small * 3,
                Kirigami.Units.iconSizes.sizeForLabels * 3);
    }
}

function preferredHeightInPopup(panel) {
    return verticalMargins(panel) + Math.max(Kirigami.Units.iconSizes.sizeForLabels,
        Kirigami.Units.iconSizes.medium);
}

function spaceRequiredToShowText(panel) {
    // gridUnit is the height of the default font, but only one isn't enough to
    // show anything but the elision character. 2 is too high and results in
    // text appearing only at excessively high widths.
    return Math.round(Kirigami.Units.gridUnit * 1.5);
}

function preferredMinLauncherWidth(panel) {
    const baseWidth = panel.vertical ? preferredMinHeight(panel) : Math.min(panel.height, Kirigami.Units.iconSizes.small * 3);

    return (baseWidth + horizontalMargins(panel))
        - (adjustMargin(panel, baseWidth, panel.taskFrame.margins.top) + adjustMargin(panel, baseWidth, panel.taskFrame.margins.bottom));
}


