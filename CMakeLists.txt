# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# WattWatch — KDE Plasma 6 面板小部件
# 基于参考实现：bcdt-rust_plasmoid_example (MPL-2.0)
# 架构：Rust staticlib → cxx 桥接 → C++ QML Plugin → QML Plasmoid

cmake_minimum_required(VERSION 3.24)

project(wattwatch_plasmoid)

set(KF6_MIN_VERSION "6.1.0")
set(QT6_MIN_VERSION "6.6.0")

find_package(ECM ${KF6_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(FeatureSummary)
include(ECMFeatureSummary)

find_package(Corrosion REQUIRED)
find_package(Plasma REQUIRED)
find_package(KF6 ${KF6_MIN_VERSION} REQUIRED COMPONENTS
    KCMUtils
    Config
)
find_package(Qt6 ${QT6_MIN_VERSION} CONFIG REQUIRED COMPONENTS
    Qml
    Gui
    Quick
    Core
)

# ── 项目参数 ──

set(PLASMOID_NAME        "org.murasaki.wattwatch")

set(PLUGIN_NAME          "wattwatch_plugin")
set(PLUGIN_URI           "WattWatch")
set(PLUGIN_DIR           "${CMAKE_SOURCE_DIR}/plugin/cpp")
set(PLUGIN_SOURCE_DIR    "${PLUGIN_DIR}/src")
set(PLUGIN_ARTIFACT_QML  "${PLUGIN_DIR}/qmldir")
set(PLUGIN_ARTIFACT      "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/lib${PLUGIN_NAME}.so")
set(PLUGIN_INSTALL_DIR   "${KDE_INSTALL_QMLDIR}/WattWatch")

set(BINDINGS_NAME        "cxxbridge_wattwatch")
set(BINDINGS_DIR         "${CMAKE_BINARY_DIR}/${BINDINGS_NAME}")
set(BINDINGS_INCLUDE_DIR "${BINDINGS_DIR}/include/cxxbridge")
set(BINDINGS_SOURCE_DIR  "${BINDINGS_DIR}/src")

set(CRATE_NAME           "wattwatch_backend")  # CMake target 名 (= [lib] name in Cargo.toml)
set(PACKAGE_NAME         "WattWatch")          # Cargo package name
set(CRATE_SOURCE_DIR     "${CMAKE_SOURCE_DIR}/src")

if(${CMAKE_BUILD_TYPE} STREQUAL "Debug")
    set(CRATE_PROFILE "dev")
elseif(${CMAKE_BUILD_TYPE} STREQUAL "Release")
    set(CRATE_PROFILE "release")
else()
    message(FATAL_ERROR "Unsupported build type ${CMAKE_BUILD_TYPE}")
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# ── cxxbridge：Rust ↔ C++ 绑定生成 ──

find_program(CXXBRIDGE cxxbridge REQUIRED)

add_custom_target(
    ${BINDINGS_NAME}
    COMMAND rm -rf   ${BINDINGS_DIR}
    COMMAND mkdir -p ${BINDINGS_INCLUDE_DIR}
    COMMAND mkdir -p ${BINDINGS_SOURCE_DIR}
    COMMAND "${CXXBRIDGE}" "${CRATE_SOURCE_DIR}/bridge.rs" --header --output "${BINDINGS_INCLUDE_DIR}/bridge.rs.hpp"
    COMMAND "${CXXBRIDGE}" "${CRATE_SOURCE_DIR}/bridge.rs"          --output "${BINDINGS_SOURCE_DIR}/bridge.rs.cpp"
    BYPRODUCTS "${BINDINGS_SOURCE_DIR}/bridge.rs.cpp"
)

# ── Rust staticlib ──

corrosion_import_crate(
    MANIFEST_PATH ${CMAKE_SOURCE_DIR}/Cargo.toml
    CRATES ${PACKAGE_NAME}
    PROFILE ${CRATE_PROFILE}
)

# ── C++ QML 插件 ──

add_library(
    ${PLUGIN_NAME}
    SHARED
        ${PLUGIN_SOURCE_DIR}/GaugeProxy.cpp
        ${PLUGIN_SOURCE_DIR}/Plugin.cpp
        ${BINDINGS_SOURCE_DIR}/bridge.rs.cpp
)

add_dependencies(${PLUGIN_NAME} ${BINDINGS_NAME})

target_compile_definitions(
    ${PLUGIN_NAME}
    PRIVATE
        PLUGIN_URI="${PLUGIN_URI}"
)

target_include_directories(
    ${PLUGIN_NAME}
    PRIVATE
        "${BINDINGS_DIR}/include"
        "${PLUGIN_DIR}/include"
)

target_link_libraries(
    ${PLUGIN_NAME}
    ${CRATE_NAME}
    Qt6::Core
    Qt6::Qml
)

# ── 安装 ──

plasma_install_package(package ${PLASMOID_NAME})
install(FILES ${PLUGIN_ARTIFACT_QML} DESTINATION ${PLUGIN_INSTALL_DIR})
install(FILES ${PLUGIN_ARTIFACT}     DESTINATION ${PLUGIN_INSTALL_DIR})

feature_summary(WHAT ALL FATAL_ON_MISSING_REQUIRED_PACKAGES)
ecm_feature_summary(WHAT ALL FATAL_ON_MISSING_REQUIRED_PACKAGES)