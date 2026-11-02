# Quizzer

Quizzer is an offline quiz-practice app built with Go and Fyne. It is being
bootstrapped; the product plan is in [docs/product.md](docs/product.md).

## Host Requirements

- Linux x86_64 host. Targets are linux/amd64 (native) and windows/amd64 (cgo
  cross-compilation).
- Bash and `readlink -f` for the `tools/` wrapper scripts.
- Install Bazelisk as `bazel` on `PATH`. It honors `.bazelversion` and
  automatically invokes the checked-in Bazel wrapper with the selected Bazel
  binary.
- Network access on initial builds so Bazel can download the pinned SDKs, toolchain, and dependencies.

No separate host Go, Java, clang, linker, or C development headers are needed;
these are supplied by the Bazel-managed Go SDK, Bazel runtime, and the `llvm`
C toolchain for both targets.

## Bazel Commands

Run commands as `bazel <command> [args...]`. Bazelisk reads `.bazelversion`
(9.3.1) and automatically calls the checked-in `tools/bazel` wrapper, passing
the selected Bazel binary as `BAZEL_REAL`. The wrapper forwards Bazel's bundled
Java runtime to repository rules through `.bazelrc`'s `JAVA_HOME` setting, so
rules such as Coursier do not depend on host Java.

```sh
bazel fetch //...
bazel build //cmd:main
bazel build --config=windows //cmd:main
bazel mod tidy
```

The root `//:go` target is an alias for rules_go's Go command, using the Go
1.27.2 SDK downloaded by Bazel. Call it explicitly with:

```sh
bazel run //:go -- version
bazel run //:go -- mod tidy
```

The `--` separates Bazel arguments from Go arguments. Everything after it is
passed to the Go executable.

`tools/go <go-args...>` is a convenience wrapper around that target. For
example, `tools/go version` is equivalent to `bazel run //:go -- version`.
VS Code's Go extension uses this wrapper as its alternate Go executable, so
editor Go commands also use the Bazel-managed SDK. The wrapper does not locate
or invoke a host Go installation.

## Go Dependencies

Go module requirements live in `go.mod`; Gazelle's `go_deps` extension reads it
to provide Go dependencies to Bazel. Use the Bazel-managed Go command to change
requirements:

```sh
tools/go get example.com/module@version
```

When Go imports are in place, run `tools/go mod tidy` to reconcile `go.mod` and
`go.sum` with the imports; this can remove unused requirements. Before source
imports exist, or when only checksums are needed, run `tools/go mod download
all`. It updates `go.sum` without pruning `go.mod`. Do not edit `go.sum` by
hand.

After changing `go.mod` or Bazel module declarations, run `bazel mod tidy`.
This updates the Bzlmod dependency graph and lockfile; it does not
generate `go.sum`.

Write project `BUILD.bazel` files by hand; Gazelle is used for external Go
dependency management, not for generating project BUILD files.

## Native dependencies (cgo)

The Fyne desktop driver reaches GLFW through cgo. One hermetic C toolchain serves
both targets: the `llvm` Bzlmod module registers clang for linux/amd64 and
cross-builds the runtimes it links against (glibc, libc++, compiler-rt,
MinGW-w64), so no host compiler or C development headers are involved. `.bazelrc`
pins `build --platforms=@llvm//platforms:linux_x86_64` and defines the Windows
platform under `--config=windows`.

cgo is mandatory for both builds (`pure = "off"` in `cmd/BUILD.bazel`). Without it
rules_go silently falls back to a pure-Go variant whenever no C toolchain
resolves, and the failure then shows up inside the GLFW bindings instead of at
toolchain resolution.

To build for Linux:

```sh
bazel build //cmd:main
```

To build for Windows/amd64 with cgo:

```sh
bazel build --config=windows //cmd:main
```

which is equivalent to:

```sh
bazel build --platforms=@rules_go//go/toolchain:windows_amd64_cgo //cmd:main
```

### X11/GL development files

The `llvm` module ships no X11/GL, and the host has no development files for
them either, so they are vendored here: `third_party/x11/x11-gl.tar.xz` holds
the X11, GL, EGL, KHR and GLES headers that GLFW's cgo bindings include, plus
the unversioned `libX11.so`, `libGL.so`, `libEGL.so` and friends the link
resolves against. The archive is tracked with git LFS, and the repository rule
in `third_party/x11/x11.bzl` unpacks it into a local repository; the
`x11_gl` target in `third_party/x11/BUILD.bazel` aliases it for the injected
module BUILD files. `third_party/x11/README.md` records where the files came
from and their licenses.

The shared objects are link-time only. rules_go puts every linked shared library
on the binary's `RUNPATH`, so vendoring the runtime libraries would load a
partial copy of the graphics stack next to the system's driver stack — the
artifact's 2021-era glvnd `libGL` beside the host's `libGLX` crashed the app at
startup. The vendored files keep the unversioned names only, so the linker
records their SONAMEs (`libX11.so.6`, `libGL.so.1`) and the loader resolves
those from the system.

### Hand-written module BUILD files

`go-gl/glfw` includes its bundled C sources relative to the module root, which
rules_go cannot resolve, and `go-gl/gl` includes `<GL/glx.h>` and
`<KHR/khrplatform.h>` with no include path of its own. Both modules therefore get
a hand-written BUILD file, kept in `third_party/glfw/` and `third_party/gl/` and
injected with `gazelle_override` + `module_override` (`build_file_generation =
"off"`, `patch_strip = 1`). They reach the artifact through the canonical label
`@@//third_party/x11:x11_gl`: a Gazelle-generated repository cannot resolve the
main module's repository names, so `third_party/x11/BUILD.bazel` holds an `alias`
that performs the lookup in the main module's mapping.

Edit a BUILD file and regenerate its patch:

```sh
diff -u --label /dev/null --label b/BUILD.bazel /dev/null third_party/glfw/glfw.BUILD.bazel > third_party/glfw/glfw.patch
diff -u --label /dev/null --label b/v2.1/gl/BUILD.bazel /dev/null third_party/gl/gl.BUILD.bazel > third_party/gl/gl.patch
```

The `b/` path is the BUILD file's location inside the module, because the patches
apply with `patch_strip = 1`; GLFW's BUILD sits at the module root, go-gl/gl's
under `v2.1/gl/`.
