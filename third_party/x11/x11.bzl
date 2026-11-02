"""Repository rule that unpacks the vendored X11/GL development files.

The archive lives in this package (tracked with git LFS), so the build needs no
network access for the X11/GL headers and libraries.
"""

_BUILD_FILE = """\
load("@rules_cc//cc:defs.bzl", "cc_library")

# The X11/GL headers the cgo compile includes, and the unversioned shared
# objects the link resolves against. See third_party/x11/README.md.
cc_library(
    name = "x11_gl",
    srcs = glob(["usr/lib/x86_64-linux-gnu/*.so"]),
    hdrs = glob(["usr/include/**/*.h"]),
    strip_include_prefix = "usr/include",
    visibility = ["//visibility:public"],
)
"""

def _x11_impl(rctx):
    rctx.extract(rctx.path(rctx.attr.archive), output = "")
    rctx.file("BUILD.bazel", _BUILD_FILE)

x11 = repository_rule(
    implementation = _x11_impl,
    attrs = {
        "archive": attr.label(mandatory = True),
    },
)