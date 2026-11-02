# Architecture

Status: initial design. Keep aligned with implementation.

## Overview

Quizzer is an offline Go/Fyne application.

External JSON files supply question banks. Users create quiz definitions
from those banks. Pressing Play constructs a new practice session from
a definition.

The MVP has no backend service or database.
Banks, definitions, and sessions live in memory.

Product requirements are defined in product.md.
The import contract is defined in question-format.md.

## Components

- cmd/quizzer: startup and dependency wiring.
- internal/quiz: domain models, validation, session construction,
  grading, and practice transitions; standard library only.
- internal/importer: JSON decoding and mapping into domain models.
- internal/service: bank registration, quiz management, and session lifecycle.
- internal/ui: Fyne views, menus, file selection, and presentation state.

Create packages when needed, not as empty scaffolding.

Dependency direction:

    cmd/quizzer -> ui, service
    ui -> service, quiz
    service -> importer, quiz
    importer -> quiz

Domain code must not depend on Fyne, JSON encoding details, or storage.
Introduce interfaces only where substitution or isolation is useful.

## Data ownership

### Question bank

Contains topics and their questions in source order.

Treat registered banks as immutable during the MVP.
Quiz construction and practice must not mutate bank content.

### Quiz definition

Contains:

- Identity and display name.
- Bank reference.
- Selected topic references.
- Ordered or shuffle mode.
- Maximum questions per topic.

Definitions describe session construction.
They do not store a sampled sequence, submitted answers, or results.

The service owns the in-memory bank and quiz collections.

### Practice session

Contains:

- Source quiz identity.
- Fixed question sequence.
- Current question position.
- Submitted answers and results.
- Completion state.

Each Play action creates fresh session state.
Rendering and navigation must not resample questions.

## Application flow

### Startup

Create application services and display an empty quiz list.
Do not preload embedded question banks or example quizzes.

The + button opens an action menu containing Add quiz.

### Import and quiz creation

1. The UI collects a quiz name and obtains a bank through file import
   or selection from registered banks.
2. The importer decodes and validates imported content.
3. The service registers successfully imported banks.
4. The user selects topics and configures the quiz.
5. The service validates and adds the completed definition.
6. The UI updates the quiz list and exposes Play.

Pass an io.Reader into the importer, not a Fyne file type.
The caller closes the selected file.

Failed imports leave existing state unchanged.
Canceling quiz creation leaves no partial definition.

Registering a new bank must not silently overwrite a bank referenced
by existing definitions.

### Session construction

When Play is pressed:

1. Resolve the definition and referenced bank/topics.
2. Validate selection and question limits.
3. Process selected topics in bank source order.
4. Copy each topic's candidate sequence.
5. In shuffle mode, shuffle the copied sequence.

## Build dependencies

The desktop application builds as a native binary through cgo. Both targets share
one hermetic C toolchain: the `llvm` Bzlmod module is registered for exec
linux/x86_64 against targets linux/x86_64 and windows/amd64, and cross-builds the
runtimes it links against (glibc, libc++, compiler-rt, MinGW-w64). No libc
sysroot is pinned.

### Linux/amd64 (native)

    cmd/quizzer -> fyne app -> internal driver/glfw -> go-gl/glfw, go-gl/gl
        -> bundled GLFW C sources -> X11/GL from third_party/x11
        -> glibc and libc++ from the llvm module

### Windows/amd64 (cgo cross-compilation)

    cmd/quizzer -> fyne app -> internal driver/glfw -> go-gl/glfw, go-gl/gl
        -> bundled GLFW C sources -> MinGW-w64 CRT and clang from the llvm module

Two build-time indirections carry the Linux-only C dependencies:

- The X11/GL development files are vendored as the git LFS archive
  `third_party/x11/x11-gl.tar.xz`; the repository rule in
  `third_party/x11/x11.bzl` unpacks it into a local repository, and
  `third_party/x11/BUILD.bazel` aliases its `x11_gl` target. The archive holds
  the headers the cgo compile includes plus the unversioned shared objects the
  link resolves against. Those objects are link-time only, because rules_go
  forwards a `cdeps` include path as `-I` (which would shadow the toolchain's
  libc headers) and puts linked shared libraries on the binary's `RUNPATH` (a
  runtime copy of the graphics stack would mix with the system's driver stack).
- The injected module BUILD files under `third_party/glfw/` and `third_party/gl/`
  exist because rules_go compiles the generated cgo translation unit outside the
  module directory: GLFW's sources include each other relative to the module root,
  and `go-gl/gl` includes `<GL/glx.h>` and `<KHR/khrplatform.h>` without an
  include path. They are injected with `gazelle_override` and `module_override`
  (`patch_strip = 1`) and reach the artifact through the canonical label
  `@@//third_party/x11:x11_gl`, since a Gazelle-generated repository cannot resolve
  the main module's repository names; `third_party/x11/BUILD.bazel` holds the
  `alias` that resolves them in the main module's mapping.
