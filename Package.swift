// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "Networking",
    targets: [
      Target(name: "Libc"),
      Target(name: "OS"),
      Target(name: "LowSockets", dependencies: ["Libc", "OS"]),
    ]
)

#if !os(Linux)
  let kqueueTarget = Target(name: "Kqueue", dependencies: ["OS"])
  package.targets.append(kqueueTarget)
#endif
