# JFML — Just FML

A standalone C++ foundational library, forked from [Flutter Engine's FML](https://github.com/flutter/engine/tree/main/fml) (Fuchsia Media Library) with extraneous dependencies removed for easier embedding in other projects.

## Overview

JFML provides production-quality primitives for threading, memory management, synchronization, time, and error handling — all without exceptions. It is designed to be dropped into a CMake project as a single static library with no mandatory external dependencies.

## Features

| Module | What it provides |
|---|---|
| **Threading & task scheduling** | Per-thread event loops, task runners, thread priorities, concurrent (pool) loops |
| **Memory management** | Thread-safe ref-counting, weak pointers, access checkers |
| **Synchronization** | Semaphore, waitable events, countdown latch, atomic objects |
| **Time** | Nanosecond-precision time points and durations, pluggable clock sources |
| **Error handling** | `Status` and `StatusOr<T>` — exception-free result types |
| **Utilities** | Logging, file I/O, memory mapping, path helpers, hex/base32, command-line parsing |

## Requirements

| Tool | Minimum version |
|---|---|
| CMake | 3.22 |
| Ninja | any recent |
| just | any recent |
| C++ compiler | C++20 |

## Getting Started

### Clone

```bash
git clone --recurse-submodules https://github.com/chinmaygarde/jfml.git
cd jfml
```

Or, after a plain clone:

```bash
just sync
```

### Build

```bash
just build
```

### Run tests

```bash
just test
```

### Clean

```bash
just clean
```

### Direct CMake invocation

```bash
cmake -G Ninja -B build -DJFML_BUILD_TESTING=ON
cmake --build build
ctest --test-dir build --output-on-failure
```

## CMake Integration

Add JFML as a subdirectory or `FetchContent` dependency and link against the `jfml` target:

```cmake
target_link_libraries(my_target PRIVATE jfml)
```

Include paths are propagated automatically. Headers are accessed under the `flutter/fml/` prefix:

```cpp
#include "flutter/fml/message_loop.h"
#include "flutter/fml/task_runner.h"
```

## API Reference

All public API lives in the `fml` namespace. Headers are under `src/` in the repository and under `flutter/fml/` on the include path.

### Threading & Task Scheduling

#### `fml::MessageLoop`

A per-thread event loop. Each thread that wants to receive tasks must create and run a `MessageLoop`.

```cpp
#include "flutter/fml/message_loop.h"

// On the thread that should process tasks:
fml::MessageLoop::EnsureInitializedForCurrentThread();
fml::MessageLoop& loop = fml::MessageLoop::GetCurrent();
loop.Run();         // blocks until Terminate() is called
loop.Terminate();   // can be called from any thread
```

#### `fml::TaskRunner`

Posts tasks to a `MessageLoop`. `TaskRunner` objects are ref-counted and safe to share across threads.

```cpp
#include "flutter/fml/task_runner.h"

fml::RefPtr<fml::TaskRunner> runner = loop.GetTaskRunner();

// Post an immediate task
runner->PostTask([]() { /* ... */ });

// Post a delayed task
runner->PostDelayedTask([]() { /* ... */ }, fml::TimeDelta::FromMilliseconds(100));

// Check which runner the current thread is on
bool on_this_runner = runner->RunsTasksOnCurrentThread();
```

#### `fml::Thread`

An OS thread with a message loop and configurable priority.

```cpp
#include "flutter/fml/thread.h"

fml::Thread thread("my_thread", fml::Thread::ThreadConfig{
    fml::Thread::ThreadPriority::kDisplay
});

thread.GetTaskRunner()->PostTask([]() { /* runs on the thread */ });
thread.Join();
```

Thread priorities: `kBackground`, `kNormal`, `kDisplay`, `kRaster`.

#### `fml::ConcurrentMessageLoop`

A multi-threaded task pool backed by `std::thread::hardware_concurrency()` worker threads.

```cpp
#include "flutter/fml/concurrent_message_loop.h"

auto loop = fml::ConcurrentMessageLoop::Create();
fml::RefPtr<fml::TaskRunner> runner = loop->GetTaskRunner();

runner->PostTask([]() { /* runs on a pool thread */ });
```

### Memory Management

#### `fml::RefCountedThreadSafe<T>` + `fml::RefPtr<T>`

Thread-safe intrusive reference counting. Constructors are private; use `fml::MakeRefCounted<T>()`.

```cpp
#include "flutter/fml/memory/ref_counted.h"
#include "flutter/fml/memory/ref_ptr.h"

class MyObject : public fml::RefCountedThreadSafe<MyObject> {
  FML_FRIEND_REF_COUNTED_THREAD_SAFE(MyObject);
  FML_FRIEND_MAKE_REF_COUNTED(MyObject);
  explicit MyObject(int value) : value_(value) {}
 public:
  int value_;
};

fml::RefPtr<MyObject> obj = fml::MakeRefCounted<MyObject>(42);
fml::RefPtr<MyObject> copy = obj;  // ref count = 2
```

#### `fml::WeakPtr<T>`

Non-owning reference that becomes null when the object is destroyed. Created via `fml::WeakPtrFactory<T>`.

```cpp
#include "flutter/fml/memory/weak_ptr.h"

class MyObject {
 public:
  fml::WeakPtr<MyObject> GetWeakPtr() { return weak_factory_.GetWeakPtr(); }
 private:
  fml::WeakPtrFactory<MyObject> weak_factory_{this};
};

fml::WeakPtr<MyObject> weak = obj.GetWeakPtr();
if (auto* ptr = weak.get()) { /* still alive */ }
```

#### `fml::TaskRunnerChecker` / `fml::ThreadChecker`

Debug-mode assertions that code runs on the expected task runner or thread.

```cpp
#include "flutter/fml/memory/task_runner_checker.h"

class MyService {
  fml::TaskRunnerChecker checker_;
 public:
  void DoWork() {
    FML_DCHECK(checker_.RunsOnCreationTaskRunner());
  }
};
```

### Synchronization

#### `fml::AutoResetWaitableEvent` / `fml::ManualResetWaitableEvent`

```cpp
#include "flutter/fml/synchronization/waitable_event.h"

fml::AutoResetWaitableEvent event;

std::thread worker([&] {
  // do work...
  event.Signal();
});

event.Wait();
worker.join();
```

`ManualResetWaitableEvent` stays signalled until explicitly `Reset()`.

#### `fml::Semaphore`

```cpp
#include "flutter/fml/synchronization/semaphore.h"

fml::Semaphore sem(0);
sem.Signal();   // increment
sem.Wait();     // decrement (blocks if zero)
```

#### `fml::CountDownLatch`

```cpp
#include "flutter/fml/synchronization/count_down_latch.h"

fml::CountDownLatch latch(3);
// in each of 3 threads:
latch.CountDown();
// on the waiting thread:
latch.Wait();
```

#### `fml::AtomicObject<T>`

Mutex-protected read/write of any copyable type.

```cpp
#include "flutter/fml/synchronization/atomic_object.h"

fml::AtomicObject<std::string> name;
name.Set("hello");
std::string val = name.Get();
```

#### `fml::SyncSwitch`

Executes one of two branches depending on an internal boolean state, with thread-safe observer notifications.

```cpp
#include "flutter/fml/synchronization/sync_switch.h"

fml::SyncSwitch sw;
sw.Execute(fml::SyncSwitch::Handlers()
    .SetIfTrue([]() { /* state is true */ })
    .SetIfFalse([]() { /* state is false */ }));
sw.SetSwitch(true);
```

### Time

#### `fml::TimeDelta`

```cpp
#include "flutter/fml/time/time_delta.h"

auto delta = fml::TimeDelta::FromMilliseconds(500);
auto ns    = delta.ToNanoseconds();
auto ms    = delta.ToMilliseconds();
auto secs  = delta.ToSecondsF();
```

#### `fml::TimePoint`

```cpp
#include "flutter/fml/time/time_point.h"

fml::TimePoint now  = fml::TimePoint::Now();
fml::TimePoint then = now + fml::TimeDelta::FromSeconds(5);
fml::TimeDelta diff = then - now;   // 5 seconds
```

### Error Handling

#### `fml::Status`

```cpp
#include "flutter/fml/status.h"

fml::Status ok;                                    // kOk
fml::Status err(fml::StatusCode::kNotFound, "missing file");

if (!err.ok()) {
  FML_LOG(ERROR) << err.message();
}
```

Status codes: `kOk`, `kCancelled`, `kUnknown`, `kInvalidArgument`, `kNotFound`, `kPermissionDenied`, `kResourceExhausted`, `kUnimplemented`, `kInternal`, and more.

#### `fml::StatusOr<T>`

```cpp
#include "flutter/fml/status_or.h"

fml::StatusOr<int> Parse(const std::string& s) {
  if (s.empty())
    return fml::Status(fml::StatusCode::kInvalidArgument, "empty");
  return std::stoi(s);
}

auto result = Parse("42");
if (result.ok()) {
  int value = result.value();
}
```

### Logging

```cpp
#include "flutter/fml/logging.h"

FML_LOG(INFO)    << "informational";
FML_LOG(WARNING) << "something looks off";
FML_LOG(ERROR)   << "non-fatal error";
FML_LOG(FATAL)   << "aborts the process";

FML_CHECK(condition) << "message if condition is false";
FML_DCHECK(condition);   // debug-only check
```

### Utilities

| Header | Provides |
|---|---|
| `flutter/fml/closure.h` | `fml::closure` (`std::function<void()>`), `ScopedCleanupClosure` |
| `flutter/fml/make_copyable.h` | `fml::MakeCopyable()` — wrap move-only lambdas for `std::function` |
| `flutter/fml/file.h` | `OpenFile`, `OpenDirectory`, `ScopedTemporaryDirectory` |
| `flutter/fml/mapping.h` | `FileMapping`, `MallocMapping` (RAII memory-mapped files) |
| `flutter/fml/paths.h` | `JoinPaths`, `GetExecutablePath`, `GetExecutableDirectoryPath` |
| `flutter/fml/command_line.h` | `CommandLineFromArgcArgv`, option/flag parsing |
| `flutter/fml/base32.h` | `Base32Encode` / `Base32Decode` |
| `flutter/fml/hex_codec.h` | `HexEncode` / `HexDecode` |
| `flutter/fml/endianness.h` | `ByteSwap`, `BigEndianToArch`, `LittleEndianToArch` |
| `flutter/fml/hash_combine.h` | `HashCombine` — combine multiple hash values |
| `flutter/fml/unique_fd.h` | `fml::UniqueFD` — RAII file descriptor |

## Supported Platforms

| Platform | Status |
|---|---|
| macOS | Supported (CI tested) |
| Linux | Supported (CI tested) |
| iOS | Supported |
| Android | Supported |
| Windows | Supported |
| Fuchsia | Supported |

Platform-specific code lives under `src/flutter/fml/platform/` with subdirectories per OS. Darwin targets are Objective-C++ (`.mm`) and link against `-framework Foundation`.

## Code Style

Uses **clang-format** with the Chromium style. Run against changed files before committing:

```bash
clang-format -i <changed files>
```

**Conventions:**
- `PascalCase` classes
- `snake_case_` members with trailing underscore
- `FML_` prefix for all macros
- Test files named `*_unittest.cc` or `*_unittests.cc`
- `FML_FRIEND_TEST()` macro to grant test access to private members

## License

MIT License — Copyright (c) 2026 Chinmay Garde. See [LICENSE](LICENSE).
