// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "Networking",
    targets: [
      Target(name: "Libc"),
      Target(name: "Networking"),
      Target(name: "LowSockets", dependencies: ["Libc", "Networking"]),
      Target(name: "Kqueue", dependencies: ["Networking"]),
    ]
)
