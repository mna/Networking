#if os(Linux)

@_exported import Glibc
@_exported import Cepoll
@_exported import Csignal
@_exported import Ctimer
@_exported import Cevent

#else

@_exported import Darwin.C

#endif
