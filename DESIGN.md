# Design

* Libc: os-dependent import of Glibc or Darwin.C
* LowSockets: low-level, thin Swift layer over the POSIX system calls
  - imports Libc
* Sockets: higher-level API built on top of LowSockets
  - never calls Libc directly

