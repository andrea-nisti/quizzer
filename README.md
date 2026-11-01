# Quizzer

Quizzer is an offline quiz-practice app built with Go and Fyne. It is being
bootstrapped; the product plan is in [docs/product.md](docs/product.md).

## Host Requirements

- Linux x86_64; the configured C toolchain and sysroot target this platform.
- Bash and `readlink -f` for the `tools/` wrapper scripts.
- Install Bazelisk as `bazel` on `PATH`. It honors `.bazelversion` and
automatically invokes the checked-in Bazel wrapper with the selected Bazel
binary.
- Network access on initial builds so Bazel can download the pinned SDKs, toolchain, sysroot, and dependencies.

No separate host Go, Java, clang, linker, or C development headers are needed;
these are supplied by the Bazel-managed Go SDK, Bazel runtime, and C toolchain.

## Bazel Commands

Run commands as `bazel <command> [args...]`. Bazelisk reads `.bazelversion`
(9.3.1) and automatically calls the checked-in `tools/bazel` wrapper, passing
the selected Bazel binary as `BAZEL_REAL`. The wrapper forwards Bazel's bundled
Java runtime to repository rules through `.bazelrc`'s `JAVA_HOME` setting, so
rules such as Coursier do not depend on host Java.

```sh
bazel fetch //...
bazel build //cmd:main
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
