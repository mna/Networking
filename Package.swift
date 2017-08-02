// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "Sockets",
    targets: [
      Target(name: "Libc"),
      Target(name: "LowSockets", dependencies: ["Libc"]),
      Target(name: "Sockets", dependencies: ["LowSockets"]),
    ]
)
