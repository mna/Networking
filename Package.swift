// swift-tools-version:3.1

import PackageDescription

#if os(Linux)

let package = Package(
  name: "Networking",
  targets: [
    Target(name: "Csignal"),
    Target(name: "Cepoll"),
    Target(name: "Ctimer"),
    Target(name: "Cevent"),
    Target(name: "Libc", dependencies: ["Csignal", "Cepoll", "Ctimer", "Cevent"]),
    Target(name: "OS", dependencies: ["Libc"]),
    Target(name: "LowSockets", dependencies: ["Libc", "OS"]),
    Target(name: "Epoll", dependencies: ["Libc", "OS"]),
  ],
  exclude: [
    "Sources/Kqueue",
    "Tests/KqueueTests",
  ]
)

#else

let package = Package(
  name: "Networking",
  targets: [
    Target(name: "Libc"),
    Target(name: "OS", dependencies: ["Libc"]),
    Target(name: "LowSockets", dependencies: ["Libc", "OS"]),
    Target(name: "Kqueue", dependencies: ["Libc", "OS"]),
  ],
  exclude: [
    "Sources/Epoll",
    "Sources/Csignal",
    "Sources/Cepoll",
    "Sources/Ctimer",
    "Sources/Cevent",
    "Tests/EpollTests",
  ]
)

#endif
