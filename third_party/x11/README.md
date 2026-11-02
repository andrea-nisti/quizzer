# Vendored X11/GL development files

These are the X11, GL, EGL, KHR and GLES2/GLES3 headers, plus the unversioned
`libX11.so`, `libXcursor.so`, `libXrandr.so`, `libXinerama.so`, `libXi.so`,
`libXxf86vm.so`, `libGL.so` and `libEGL.so` link-time libraries that GLFW's cgo
bindings need on Linux.

They were taken from the pinned chrome-linux-sysroot archive:

    https://commondatastorage.googleapis.com/chrome-linux-sysroot/f851add76bdae472fb6c94b4f920bc4a132d85ac607951391297f636af7e934e
    sha256 f851add76bdae472fb6c94b4f920bc4a132d85ac607951391297f636af7e934e

Only the development files were kept. The archive's libc is not needed: the
`llvm` toolchain module builds its own. Its runtime libraries are not wanted
either: rules_go puts every shared library it links on the binary's RUNPATH, so
shipping them would load a partial copy of the graphics stack next to the
system's driver stack.

Upstream projects, each vendored file carrying its own license notice:

- X11 headers: libX11 and xorgproto (MIT/X11 license)
- GL and EGL headers: Mesa (MIT license)
- KHR headers: The Khronos Group Inc. (MIT license)

To refresh the set: download the pinned archive, copy
`usr/include/{X11,GL,EGL,KHR,GLES2,GLES3}` and the unversioned
`usr/lib/x86_64-linux-gnu/lib*.so` files into a staging `usr/` tree, replace each
library symlink with a copy of its target so the runtime keeps resolving the
system's libraries, and repack:

    tar -cJf third_party/x11/x11-gl.tar.xz -C <staging-dir> usr

The archive is tracked with git LFS; `third_party/x11/x11.bzl` unpacks it into
the local repository the build consumes.