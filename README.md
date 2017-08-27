![macOS](https://img.shields.io/badge/os-macOS-green.svg?style=flat-square)
![iOS](https://img.shields.io/badge/os-iOS-green.svg?style=flat-square)
![Linux](https://img.shields.io/badge/os-linux-green.svg?style=flat-square)
![BSD](https://img.shields.io/badge/license-BSD-blue.svg?style=flat-square)
![Swift 3.1](https://img.shields.io/badge/Swift-version_3.1-orange.svg?style=flat-square)

# Networking Swift Package

Networking is a low-level Swift package that provides a thin Swift layer over the native **POSIX sockets** and the kernel's polling mechanism (**epoll** for Linux, **kqueue** for Darwin).

## Table Of Contents

- [Features](#features)
- [Guiding Principles](#guiding-principles)
- [Installation](#installation)
- [Usage](#usage)
- [Documentation](#documentation)
- [License](#license)

## Features

* IPv4 and IPv6
* TCP, UDP and Unix Domain Sockets
* Host and service resolution (`getaddrinfo` exposed as `Address.resolve`)
* Client and server support (`connect`, `bind`, `listen`, `accept`)
* Blocking and non-blocking support
* Polling mechanisms (`epoll` on Linux, `kqueue` on Darwin)
* `signalfd`, `timerfd` and `eventfd` support on Linux for use with `epoll` (natively supported by `kqueue` on Darwin)

The package exports the following modules:

* [OS][os]: basic types used by many modules: errors, signals, and on Linux: signalfd(2), timerfd\_create(2), eventfd(2).
* [LowSockets][lowsockets]: cross-platform POSIX sockets, basically socket(2) and getaddrinfo(3).
* [Epoll][epoll]: Linux-only, epoll(7).
* [Kqueue][kqueue]: Darwin-only, kqueue(2).

## Guiding Principles

* Just a thin layer over the system calls;
* Provide a "swifty" API - strongly typed flags and enums, file descriptor resources exposed as classes to close on deinit, etc.;
* No API sugar - this belongs in higher-level packages built on top of Networking;
* Every idiomatic use of the underlying C API should be supported (if it can be done in C and is not a hack, it should be doable);
* As efficient as possible, as little allocations as possible - this is a low-level building block;

## Installation

The `master` branch of the Networking package is developed and tested with Swift 3.1.1. To build from source:

```
$ git clone github.com/mna/Networking
$ cd <clone directory>
$ swift build

# optional, to run tests
$ swift test

# optional, to run test with coverage report (mac only)
# requires installation of https://github.com/nakiostudio/xcov
$ make test-cov
```

## Usage

To add the package as a dependency with the Swift Package Manager:

```
dependencies: [
  .Package(url: "https://github.com/mna/Networking.git", majorVersion: M),
]
```

## Documentation

Full API documentation is available [here][doc]. Note that in order to generate the jazzy documentation, the following requirements must be met:

1. Install a Swift version that includes SourceKit (on Ubuntu, the official version 3.1.1 on the swift.org does not include it, but 4.0 does).
2. Install SourceKitten (https://github.com/jpsim/SourceKitten).
3. On Ubuntu, SourceKitten must be able to find `libsourcekitdInProc.so`, which means setting the `LINUX_SOURCEKIT_LIB_PATH` environment variable to its directory.
4. On Ubuntu, `libsourcekitdInProc.so` must be able to find `libBlocksRuntime.so.0`, which may not be installed. It can be installed with `apt install libblocksruntime0`.
5. Ruby must be installed (ruby-dev on Ubuntu), and then jazzy itself by running `gem install jazzy`.

## License

The [BSD 3-Clause license][bsd]. See the LICENSE file for details.

[bsd]: http://opensource.org/licenses/BSD-3-Clause
[doc]: http://mna.github.io/Networking
[os]: http://mna.github.io/Networking/OS
[lowsockets]: http://mna.github.io/Networking/LowSockets
[epoll]: http://mna.github.io/Networking/Epoll
[kqueue]: http://mna.github.io/Networking/Kqueue

