# SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
# SPDX-License-Identifier: GPL-2.0-or-later
cmake_minimum_required(VERSION 3.16)
project(fancytasksng_unityplugin)
find_package(Qt6 COMPONENTS Core Qml DBus REQUIRED)
set(CMAKE_AUTOMOC ON)
add_library(fancytasksng_unityplugin SHARED unitylauncher.cpp)
target_link_libraries(fancytasksng_unityplugin PRIVATE Qt6::Core Qt6::Qml Qt6::DBus)
