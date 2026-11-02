"""Prunes the chrome-linux-sysroot archive down to its X11/GL development files.

The cc_toolchain (the llvm module) builds its own libc, and rules_go forwards a
cdep's include paths as plain -I, which is searched before the toolchain's
-isystem paths. Keeping the archive's glibc headers would therefore shadow the
toolchain's own libc headers, so everything except X11/GL is deleted here.
"""

_INCLUDE_DIRS = [
    "X11",
    "GL",
    "EGL",
    "KHR",
    "GLES2",
    "GLES3",
    "vulkan",
]

# The unversioned development names the linker needs.
_LIBRARIES = [
    "libX11.so",
    "libXcursor.so",
    "libXrandr.so",
    "libXinerama.so",
    "libXi.so",
    "libXxf86vm.so",
    "libGL.so",
    "libEGL.so",
]

_OTHER_DIRS = [
    "bin",
    "debian",
    "etc",
    "lib",
    "lib64",
    "sbin",
    "var",
    "usr/bin",
    "usr/libexec",
    "usr/sbin",
    "usr/share",
]

_BUILD_FILE = """\
load("@rules_cc//cc:defs.bzl", "cc_library")

# Serves the X11/GL headers as an include path and the shared libraries as
# link inputs: rules_go turns each unversioned lib<name>.so into -L/-l.
cc_library(
    name = "x11_gl",
    srcs = glob(["usr/lib/x86_64-linux-gnu/*.so*"]),
    hdrs = glob(["usr/include/**/*.h"]),
    includes = ["usr/include"],
    visibility = ["//visibility:public"],
)
"""

def _keeps_dir(name):
    for d in _INCLUDE_DIRS:
        return name == d

def _keeps_library(name):
    for library in _LIBRARIES:
        if name == library:
            return True
    return False

def _x11_sysroot_impl(rctx):
    # The archive has no file extension and its root is the filesystem root.
    rctx.download_and_extract(
        type = "tar.xz",
        sha256 = rctx.attr.sha256,
        url = rctx.attr.urls,
    )

    for entry in rctx.path("usr/include").readdir():
        if not _keeps_dir(entry.basename):
            rctx.delete(entry)

    # rules_go puts every shared library it links onto the binary's RUNPATH, so
    # these files must not shadow the system's runtime libraries. Keep only the
    # unversioned names, as plain copies of their targets: the linker reads the
    # SONAME (libX11.so.6) from them, and the loader then finds nothing under
    # that name in this directory and falls back to the system.
    lib_dir = "usr/lib/x86_64-linux-gnu/"
    present = [entry.basename for entry in rctx.path(lib_dir).readdir()]

    # Dereference before pruning: the symlink targets are deleted below.
    for name in _LIBRARIES:
        if name not in present:
            fail("{} does not ship {}".format(rctx.name, name))
        copy = lib_dir + name + ".copy"
        result = rctx.execute(["cp", "-L", str(rctx.path(lib_dir + name)), str(rctx.path(copy))])
        if result.return_code != 0:
            fail(result.stderr)
        rctx.delete(rctx.path(lib_dir + name))
        rctx.rename(copy, lib_dir + name)

    for entry in rctx.path(lib_dir).readdir():
        if not _keeps_library(entry.basename):
            rctx.delete(entry)

    for d in _OTHER_DIRS:
        path = rctx.path(d)
        if path.exists:
            rctx.delete(path)

    rctx.file("BUILD.bazel", _BUILD_FILE)

x11_sysroot = repository_rule(
    implementation = _x11_sysroot_impl,
    attrs = {
        "sha256": attr.string(mandatory = True),
        "urls": attr.string_list(mandatory = True),
    },
)
