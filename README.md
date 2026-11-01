# Quizzer

Quizzer is an offline quiz-practice app built with Go and Fyne. It is being
bootstrapped; the product plan is in [docs/product.md](docs/product.md).

## Go dependencies

Go and C toolchains are pinned and managed by Bazel; Go module requirements
live in `go.mod`, which Gazelle's `go_deps` extension uses to provide
dependencies to Bazel. The Linux x86_64 C toolchain uses a downloaded LLVM
distribution and a checksum-pinned Debian sysroot.

Run Go commands through the Bazel-managed SDK. To add or update a dependency:

```sh
bazel run //:go -- get example.com/module@version
```

Choose the Go module command based on the state of the source. When Go imports
are in place, run `bazel run //:go -- mod tidy` to reconcile `go.mod` and
`go.sum` with those imports; it can remove requirements that are not used by
the current source. Before source imports exist, or when you only need
checksums for declared modules, run `bazel run //:go -- mod download all`. It
generates or updates `go.sum` without pruning `go.mod` requirements.

After changing `go.mod`, run:

```sh
bazel mod tidy
```

`bazel mod tidy` synchronizes Bazel's Bzlmod dependencies and lockfile from
`MODULE.bazel` and the Go module data; it does not generate `go.sum`. Run it
also after changing Bazel module declarations or extension imports. Do not edit
`go.sum` by hand.

Write project `BUILD.bazel` files by hand; Gazelle is used for external Go
dependency management, not for generating project BUILD files. Use `bazel
build` and `bazel test` for project builds and tests.
