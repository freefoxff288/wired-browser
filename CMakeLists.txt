cmake_minimum_required(VERSION 3.21)
project(WiredBrowser VERSION 1.0.0 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)

find_package(Qt6 6.9 REQUIRED COMPONENTS Gui Qml Quick WebEngineQuick)
qt_standard_project_setup()

qt_add_executable(WiredBrowser WIN32 main.cpp)
if(WIN32)
    target_sources(WiredBrowser PRIVATE app.rc)   # значок .exe
endif()
qt_add_resources(WiredBrowser app PREFIX "/" BASE src FILES
    src/browser.qml src/autoscroll.js src/icon.png src/fonts/FiraCodeNerdFontMono-Regular.ttf)
target_link_libraries(WiredBrowser PRIVATE Qt6::Gui Qt6::Qml Qt6::Quick Qt6::WebEngineQuick)
