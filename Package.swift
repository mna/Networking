// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "Networking",
    targets: [
      Target(name: "Libc"),
      Target(name: "LowSockets", dependencies: ["Libc"]),
      Target(name: "Sockets", dependencies: ["LowSockets"]),
    ],
    dependencies: [
      .Package(url: "https://github.com/IBM-Swift/BlueSocket.git", majorVersion: 0),
    ]
)
