#if os(Linux)
@_exported import Glibc
@_exported import Cepoll
@_exported import Csignal
#else
@_exported import Darwin.C
#endif

