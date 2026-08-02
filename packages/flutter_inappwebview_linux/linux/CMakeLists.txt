# Stub Linux build for flutter_inappwebview — no WPE WebKit required.
# Real playback targets Android / iOS / Web. Desktop Linux shows a UI message.
cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "flutter_inappwebview_linux")
project(${PROJECT_NAME} LANGUAGES CXX)

set(PLUGIN_NAME "flutter_inappwebview_linux_plugin")

find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)

add_library(${PLUGIN_NAME} SHARED
  "flutter_inappwebview_linux_plugin_stub.cc"
)

apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden
)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)

set(flutter_inappwebview_linux_bundled_libraries "" PARENT_SCOPE)
