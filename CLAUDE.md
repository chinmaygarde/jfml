# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About

JFML (Just FML) is a standalone C++ foundational library forked from Flutter Engine's FML (Fuchsia Media Library) base library, with extraneous dependencies removed for easier embedding in other projects.

## Build Commands

```bash
# First-time setup: initialize git submodules
just sync

# Build
just build

# Clean
just clean

# Equivalent CMake commands:
cmake -G Ninja -B build
cmake --build build
```

Requires CMake 3.22+, Ninja, and `just`. The only external dependency is the `third_party/cmake_toolbox` git submodule.

## Code Formatting

Uses clang-format with Chromium style. Run `clang-format` against changed files before committing.

## Architecture

The library lives under `src/flutter/fml/` and provides:

- **Threading & Task Scheduling**: `MessageLoop` (per-thread event loop), `TaskRunner` (schedules tasks on a loop), `Thread` (thread with priority), `ConcurrentMessageLoop` (multi-threaded). Tasks can be immediate or delayed.
- **Memory Management**: `RefCountedThreadSafe<T>` + `RefPtr<T>` for ref-counting, `WeakPtr<T>` for weak references, `TaskRunnerChecker`/`ThreadChecker` for access validation.
- **Synchronization**: `Semaphore`, `CountDownLatch`, `WaitableEvent`, `SyncSwitch`, `AtomicObject<T>`.
- **Time**: `TimePoint`, `TimeDelta`, `TimestampProvider` interface, `DelayedTask`.
- **Error Handling**: `Status` and `StatusOr<T>` — status-based error model without exceptions.
- **Platform Abstraction**: Platform-specific files under `platform/posix/`, `platform/darwin/`, `platform/linux/`, `platform/android/`, `platform/win/`, `platform/fuchsia/`.

### Key Patterns

- **Macros**: `FML_DISALLOW_COPY_AND_ASSIGN`, `FML_DISALLOW_COPY_ASSIGN_AND_MOVE` are used pervasively for ownership control.
- **Namespace**: All public API is in the `fml` namespace; internals in `fml::internal`; test utilities in `fml::testing`.
- **Naming**: PascalCase classes, snake_case members with trailing underscore (`task_runner_`), `FML_` prefix for macros.
- **Tests**: Unit test files follow `*_unittest.cc` / `*_unittests.cc` naming and use `FML_FRIEND_TEST()` to access private members.
- **Darwin sources**: `.mm` files use Objective-C++ and link against `-framework Foundation`.
