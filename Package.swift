// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "Networking",
    targets: [
      Target(name: "Libc"),
      Target(name: "Networking"),
      Target(name: "LowSockets", dependencies: ["Libc", "Networking"]),
    ]
)

#if !os(Linux)
  let kqueueTarget = Target(name: "Kqueue", dependencies: ["Networking"])
  package.targets.append(kqueueTarget)
#endif
