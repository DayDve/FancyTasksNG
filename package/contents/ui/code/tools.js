/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2023-2024 Fushan Wen <qydwhotmail@gmail.com>
    SPDX-FileCopyrightText: 2024 ivan tkachenko <me@ratijas.tk>
    SPDX-FileCopyrightText: 2020-2023 Nate Graham <nate@kde.org>
    SPDX-FileCopyrightText: 2022-2023 Alexandra <alexankitty@gmail.com>
    SPDX-FileCopyrightText: 2023 Marco Martin <notmart@gmail.com>
    SPDX-FileCopyrightText: 2012-2016 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

.pragma library
.import org.kde.taskmanager as TaskManager
.import org.kde.plasma.core as PlasmaCore // Needed by TaskManager

// Can't be `let`, or else QML counterpart won't be able to assign to it.
var taskManagerInstanceCount = 0;

function activateNextPrevTask(anchor, next, wheelSkipMinimized, tasks, groupOnly) {
    let taskIndexList = [];
    const activeTaskIndex = tasks.tasksModel.activeTask;

    const collectTasksFromGroup = (modelIndex) => {
        for (let j = 0; j < tasks.tasksModel.rowCount(modelIndex); ++j) {
            const childModelIndex = tasks.tasksModel.makeModelIndex(modelIndex.row, j);
            const childHidden = tasks.tasksModel.data(childModelIndex, TaskManager.AbstractTasksModel.IsHidden);
            if (!wheelSkipMinimized || !childHidden) {
                taskIndexList.push(childModelIndex);
            }
        }
    };

    if (groupOnly) {
        if (anchor && anchor.model && anchor.model.IsGroupParent) {
            collectTasksFromGroup(anchor.modelIndex());
        } else {
            return;
        }
    } else {
        // We subtract 1 from length because the last child is usually an invisible spacer or highlight item
        for (let i = 0; i < tasks.taskList.children.length - 1; ++i) {
            const task = tasks.taskList.children[i];
            if (!task.model || task.model.IsLauncher || task.model.IsStartup) {
                continue;
            }
            if (task.model.IsGroupParent) {
                collectTasksFromGroup(task.modelIndex());
            } else if (!wheelSkipMinimized || !task.model.IsHidden) {
                taskIndexList.push(task.modelIndex());
            }
        }
    }

    if (!taskIndexList.length) {
        return;
    }

    let target = taskIndexList[0];

    for (let i = 0; i < taskIndexList.length; ++i) {
        // Compare model indices. In QML/JS they might need special comparison or use a key
        if (tasks.tasksModel.data(taskIndexList[i], TaskManager.AbstractTasksModel.AppId) === tasks.tasksModel.data(activeTaskIndex, TaskManager.AbstractTasksModel.AppId) &&
            tasks.tasksModel.data(taskIndexList[i], TaskManager.AbstractTasksModel.WinIdList)[0] === tasks.tasksModel.data(activeTaskIndex, TaskManager.AbstractTasksModel.WinIdList)[0]) {
            
            if (next) {
                target = taskIndexList[(i + 1) % taskIndexList.length];
            } else {
                target = taskIndexList[(i - 1 + taskIndexList.length) % taskIndexList.length];
            }
            break;
        }
    }

    tasks.tasksModel.requestActivate(target);
}

function activateTask(index, model, modifiers, task, plasmoid, tasks, windowViewAvailable) {
    if (modifiers & Qt.ShiftModifier) {
        tasks.tasksModel.requestNewInstance(index);
        return;
    }
    // Publish delegate geometry again if there are more than one task manager instance
    if (taskManagerInstanceCount >= 2) {
        tasks.tasksModel.requestPublishDelegateGeometry(task.modelIndex(), task.getGlobalRect(), task);
    }

    if (model.IsGroupParent) {
        // Option 1 (default): Cycle through this group's tasks
        // ====================================================
        // If the grouped task does not include the currently active task, bring
        // forward the most recently used task in the group according to the
        // Stacking order.
        // Otherwise cycle through all tasks in the group without paying attention
        // to the stacking order, which otherwise would change with every click
        if (plasmoid.configuration.groupedTaskVisualization === 0) {
            let childTaskList = [];
            let highestStacking = -1;
            let lastUsedTask = undefined;

            // Build list of child tasks and get stacking order data for them
            for (let i = 0; i < tasks.tasksModel.rowCount(index); ++i) {
                const childTaskModelIndex = tasks.tasksModel.makeModelIndex(index.row, i);
                childTaskList.push(childTaskModelIndex);
                const stacking = tasks.tasksModel.data(childTaskModelIndex, TaskManager.AbstractTasksModel.StackingOrder);
                if (stacking > highestStacking) {
                    highestStacking = stacking;
                    lastUsedTask = childTaskModelIndex;
                }
            }

            // If the active task is from a different app from the group that
            // was clicked on switch to the last-used task from that app.
            if (!childTaskList.some(index => tasks.tasksModel.data(index, TaskManager.AbstractTasksModel.IsActive))) {
                tasks.tasksModel.requestActivate(lastUsedTask);
            } else {
                // If the active task is already among in the group that was
                // activated, cycle through all tasks according to the order of
                // the immutable model index so the order doesn't change with
                // every click.
                for (let j = 0; j < childTaskList.length; ++j) {
                    const childTask = childTaskList[j];
                    if (tasks.tasksModel.data(childTask, TaskManager.AbstractTasksModel.IsActive)) {
                        // Found the current task. Activate the next one
                        let nextTask = j + 1;
                        if (nextTask >= childTaskList.length) {
                            nextTask = 0;
                        }
                        tasks.tasksModel.requestActivate(childTaskList[nextTask]);
                        break;
                    }
                }
            }
        }

        // Option 2: show tooltips for all child tasks
        // ===========================================
        else if (plasmoid.configuration.groupedTaskVisualization === 1) {
            if (tasks.toolTipOpenedByClick) {
                tasks.toolTipOpenedByClick.closeTooltip();
            } else {
                tasks.toolTipOpenedByClick = task;
                tasks.currentHoveredTask = task;
                task.toolTipOpen = true;
                tasks.toolTipAreaItem = task;
            }
        }

        // Option 3: show Window View for all child tasks
        // ==================================================
        // Make sure the Window View effect is  are actually enabled though;
        // if not, fall through to the next option.
        else if (plasmoid.configuration.groupedTaskVisualization === 2 && windowViewAvailable) {
            task.closeTooltip();
            tasks.activateWindowView(model.WinIdList);
        }

        // Option 4: show textual list (now using text tooltips instead of GroupDialog)
        // ========================================
        // This is also the final fallback option if Window View
        // is chosen but not actually available
        else {
            if (tasks.toolTipOpenedByClick) {
                tasks.toolTipOpenedByClick.closeTooltip();
            } else {
                tasks.toolTipOpenedByClick = task;
                tasks.currentHoveredTask = task;
                task.toolTipOpen = true;
                tasks.toolTipAreaItem = task;
            }
        }
    } else {
        if (model.IsMinimized) {
            tasks.tasksModel.requestToggleMinimized(index);
            tasks.tasksModel.requestActivate(index);
        } else if (model.IsActive && plasmoid.configuration.minimizeActiveTaskOnClick) {
            tasks.tasksModel.requestToggleMinimized(index);
        } else {
            tasks.tasksModel.requestActivate(index);
        }
    }
}

function taskPrefix(prefix, location) {
    let effectivePrefix;

    switch (location) {
        case PlasmaCore.Types.LeftEdge:
            effectivePrefix = "west-" + prefix;
            break;
        case PlasmaCore.Types.TopEdge:
            effectivePrefix = "north-" + prefix;
            break;
        case PlasmaCore.Types.RightEdge:
            effectivePrefix = "east-" + prefix;
            break;
        default:
            effectivePrefix = "south-" + prefix;
    }
    return [effectivePrefix, prefix];
}

function taskPrefixHovered(prefix, location, config) {
    return [
        ...taskPrefix((prefix || "launcher") + "-hover", location, config),
        ...prefix ? taskPrefix("hover", location, config) : [],
        ...taskPrefix(prefix, location, config),
    ];
}

/**
 * Resolve the base indicator color based on configuration flags.
 * Shared between production Indicators.qml and config LivePreview.qml.
 *
 * @param {bool} useAccent - indicatorAccentColor config flag
 * @param {bool} useDominant - indicatorDominantColor config flag
 * @param {color} accentColor - Kirigami.Theme.highlightColor (or equivalent)
 * @param {color} dominantColor - tinted icon dominant color
 * @param {color} customColor - indicatorCustomColor config value
 * @returns {color} The resolved base color
 */
function resolveIndicatorBaseColor(useAccent, useDominant, accentColor, dominantColor, customColor) {
    if (useAccent) {
        return accentColor;
    } else if (useDominant) {
        return dominantColor;
    }
    return customColor;
}

/**
 * Calculate the average color based on the Kirigami ImageColors palette swatches weighted by their ratios.
 * Falls back to the raw image average if palette is empty or ratios are zero.
 *
 * @param {list} palette - The palette array from Kirigami.ImageColors
 * @param {color} fallbackAvg - The average property from Kirigami.ImageColors
 * @returns {color} The calculated palette-weighted average color
 */
function getAveragePaletteColor(palette, fallbackAvg) {
    if (!palette || palette.length === 0) {
        return fallbackAvg;
    }
    
    let totalRatio = 0;
    let r = 0, g = 0, b = 0;
    
    for (let i = 0; i < palette.length; ++i) {
        let swatch = palette[i];
        let c = Qt.color(swatch.color);
        let ratio = swatch.ratio;
        
        r += c.r * ratio;
        g += c.g * ratio;
        b += c.b * ratio;
        totalRatio += ratio;
    }
    
    if (totalRatio === 0) {
        return fallbackAvg;
    }
    
    return Qt.rgba(r / totalRatio, g / totalRatio, b / totalRatio, 1.0);
}

/**
 * Harmonize a raw icon color (whether average or dominant) with the theme background.
 * Adjusts saturation and limits lightness to fit perfectly in dark/light panels.
 *
 * @param {color} iconColor - The color to harmonize (e.g. average or dominant)
 * @param {color} dominantColor - The dominant color from Kirigami.ImageColors
 * @param {color} themeBgColor - Kirigami.Theme.backgroundColor
 * @param {bool} isAverageMode - True if using the average color mode
 * @returns {color} The harmonized color
 */
function harmonizeIconColor(iconColor, dominantColor, themeBgColor, isAverageMode) {
    let c = Qt.color(iconColor);
    let dom = Qt.color(dominantColor);
    let bg = Qt.color(themeBgColor);
    
    // Check if the current theme is dark
    let isDark = (bg.r + bg.g + bg.b) / 3 < 0.5;
    
    let targetHue = c.hslHue;
    let targetSat = c.hslSaturation;
    let targetLight = c.hslLightness;
    
    let blendHue = dom.hslHue >= 0 ? dom.hslHue : targetHue;
    let blendSat = dom.hslSaturation >= 0 ? dom.hslSaturation : targetSat;
    
    if (isAverageMode) {
        // Average mode can yield muddy/desaturated mixtures due to linear RGB mixing.
        // We restore pure hue definition by using the dominant hue, which is highly clean.
        if (blendHue >= 0) {
            targetHue = blendHue;
            targetSat = Math.max(targetSat, blendSat * 0.8);
        }
    }
    
    // Cap/adjust lightness based on whether the theme is dark or light
    if (isDark) {
        // Dark theme: cap lightness so the card forms a deep, elegant dark tint.
        // Warm colors (red, orange, yellow, magenta/pink) need a slightly higher lightness
        // limit (up to 30%) to prevent them from becoming an ugly muddy brown/olive.
        let maxLight = 0.22;
        let hueDegrees = targetHue * 360;
        if (hueDegrees >= 0 && (hueDegrees < 75 || hueDegrees > 315)) {
            maxLight = 0.30;
        }
        
        if (targetLight > maxLight) {
            targetLight = maxLight;
        } else if (targetLight < 0.12) {
            targetLight = 0.12;
        }
    } else {
        // Light theme: boost lightness to 88% - 95% and limit saturation for soft, clean pastel tints
        if (targetLight < 0.88) {
            targetLight = 0.88;
        } else if (targetLight > 0.95) {
            targetLight = 0.95;
        }
        if (targetSat > 0.30) {
            targetSat = 0.30;
        }
    }
    
    return Qt.hsla(targetHue, targetSat, targetLight, 1.0);
}
