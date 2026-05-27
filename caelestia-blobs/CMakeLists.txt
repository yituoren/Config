cmake_minimum_required(VERSION 3.19)

project(caelestia-blobs VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(Qt6 REQUIRED COMPONENTS Quick ShaderTools)
qt_standard_project_setup(REQUIRES 6.5)

# 安装到用户级 QML import dir,Quickshell / Qt 自动从这里找 Caelestia.Blobs 模块
set(INSTALL_QMLDIR "$ENV{HOME}/.local/share/qt6/qml" CACHE STRING "QML install dir")

qt_add_qml_module(caelestia-blobs
    URI Caelestia.Blobs
    VERSION 1.0
    SOURCES
        src/blobgroup.cpp src/blobgroup.hpp
        src/blobshape.cpp src/blobshape.hpp
        src/blobrect.cpp src/blobrect.hpp
        src/blobinvertedrect.cpp src/blobinvertedrect.hpp
        src/blobmaterial.cpp src/blobmaterial.hpp
)

qt_add_shaders(caelestia-blobs "blob_shaders"
    BATCHABLE OPTIMIZED NOHLSL NOMSL
    GLSL "300es,330"
    PREFIX "/"
    BASE src  # 让 resource 路径去掉 src/ 前缀,变成 :/shaders/blob.frag.qsb(plugin C++ 代码里用的就是这个)
    FILES
        src/shaders/blob.frag
        src/shaders/blob.vert
)

target_include_directories(caelestia-blobs PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/src")
target_link_libraries(caelestia-blobs PRIVATE Qt::Core Qt::Qml Qt::Quick)

# 安装到 ~/.local/share/qt6/qml/Caelestia/Blobs/
qt_query_qml_module(caelestia-blobs
    URI module_uri
    VERSION module_version
    PLUGIN_TARGET module_plugin_target
    TARGET_PATH module_target_path
    QMLDIR module_qmldir
    TYPEINFO module_typeinfo
)

set(module_dir "${INSTALL_QMLDIR}/${module_target_path}")
install(TARGETS caelestia-blobs LIBRARY DESTINATION "${module_dir}" RUNTIME DESTINATION "${module_dir}")
install(TARGETS "${module_plugin_target}" LIBRARY DESTINATION "${module_dir}" RUNTIME DESTINATION "${module_dir}")
install(FILES "${module_qmldir}" DESTINATION "${module_dir}")
install(FILES "${module_typeinfo}" DESTINATION "${module_dir}")
