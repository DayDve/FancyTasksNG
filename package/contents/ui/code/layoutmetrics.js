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
function leftMargin() {
    return taskFrame.margins.left * (tasks.vertical ? 1 : (Kirigami.Settings.tabletMode ? 1.5 : tasks.plasmoid.configuration.iconSpacing));
}
function rightMargin() {
    return taskFrame.margins.right * (tasks.vertical ? 1 : (Kirigami.Settings.tabletMode ? 1.5 : tasks.plasmoid.configuration.iconSpacing));
}
function topMargin() {
    return taskFrame.margins.top * (tasks.vertical ? (Kirigami.Settings.tabletMode ? 1.5 : tasks.plasmoid.configuration.iconSpacing) : 1);
}
function bottomMargin() {
    return taskFrame.margins.bottom * (tasks.vertical ? (Kirigami.Settings.tabletMode ? 1.5 : tasks.plasmoid.configuration.iconSpacing) : 1);
}

function rawLeftMargin() { return taskFrame.margins.left; }
function rawRightMargin() { return taskFrame.margins.right; }
function rawTopMargin() { return taskFrame.margins.top; }
function rawBottomMargin() { return taskFrame.margins.bottom; }

function horizontalMargins() {
    return leftMargin() + rightMargin();
}

function verticalMargins() {
    return topMargin() + bottomMargin();
}

function adjustMargin(height, margin) {
    const available = height - verticalMargins();

    if (available < Kirigami.Units.iconSizes.small) {
        return Math.floor((margin * (Kirigami.Units.iconSizes.small / available)) / 3);
    }

    return margin;
}

function maxStripes() {
    const length = tasks.vertical ? tasks.width : tasks.height;
    const minimum = tasks.vertical ? preferredMinWidth() : preferredMinHeight();

    return Math.min(tasks.plasmoid.configuration.maxStripes, Math.max(1, Math.floor(length / minimum)));
}

function optimumCapacity(width, height) {
    const length = tasks.vertical ? height : width;
    const maximum = tasks.vertical ? preferredMaxHeight() : preferredMaxWidth();

    if (!tasks.vertical) {
        //  Fit more tasks in this case, that is possible to cut text, before combining tasks.
        return Math.ceil(length / maximum) * maxStripes() + 1;
    }

    return Math.floor(length / maximum) * maxStripes();
}

function preferredMinWidth() {
    let width = preferredMinLauncherWidth();

    if (!tasks.vertical && !tasks.iconsOnly) {
        width +=
            (Kirigami.Units.smallSpacing * 2) +
            (Kirigami.Units.gridUnit * 8);
    }

    return width;
}

function preferredMaxWidth() {
    if (tasks.iconsOnly) {
        if (tasks.vertical) {
            return tasks.width + verticalMargins();
        } else {
            return tasks.height + horizontalMargins();
        }
    }

    // Avoid doing a bunch of unnecessary work below in vertical mode
    if (tasks.vertical) {
        return preferredMinWidth();
    }

    // Visually, a large max item width on a tall panel looks cluttered even
    // with just a task or two open. This clutter is less pronounced on panels
    // lower in height, as there is generally more horizontal space.
    //
    // This allows for one default value for max item width where clutter is
    // reduced at low task counts for tall panels, while leaving low height
    // panels less affected (unaffected at 20px).
    // For Classic mode (Horizontal)
    return tasks.plasmoid.configuration.maxButtonLength;
}

function preferredMinHeight() {
    // TODO FIXME UPSTREAM: Port to proper font metrics for descenders once we have access to them.
    return Kirigami.Units.iconSizes.sizeForLabels + 4;
}

function preferredMaxHeight() {
    if (tasks.vertical) {
        let taskPreferredSize = 0;
        if (tasks.iconsOnly) {
            taskPreferredSize = tasks.width / maxStripes();
        } else {
            taskPreferredSize = Math.max(Kirigami.Units.iconSizes.sizeForLabels,
                Kirigami.Units.iconSizes.medium);
        }
        return verticalMargins() +
            Math.min(
                // Do not allow the preferred icon size to exceed the width of
                // the vertical task manager.
                tasks.width / maxStripes(),
                taskPreferredSize);
    } else {
        return verticalMargins() +
            Math.min(
                Kirigami.Units.iconSizes.small * 3,
                Kirigami.Units.iconSizes.sizeForLabels * 3);
    }
}

function preferredHeightInPopup() {
    return verticalMargins() + Math.max(Kirigami.Units.iconSizes.sizeForLabels,
        Kirigami.Units.iconSizes.medium);
}

function spaceRequiredToShowText() {
    // gridUnit is the height of the default font, but only one isn't enough to
    // show anything but the elision character. 2 is too high and results in
    // text appearing only at excessively high widths.
    return Math.round(Kirigami.Units.gridUnit * 1.5);
}

function preferredMinLauncherWidth() {
    const baseWidth = tasks.vertical ? preferredMinHeight() : Math.min(tasks.height, Kirigami.Units.iconSizes.small * 3);

    return (baseWidth + horizontalMargins())
        - (adjustMargin(baseWidth, taskFrame.margins.top) + adjustMargin(baseWidth, taskFrame.margins.bottom));
}

function maximumContextMenuTextWidth() {
    return (Kirigami.Units.iconSizes.sizeForLabels * 28);
}

