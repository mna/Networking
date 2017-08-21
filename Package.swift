// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "Networking",
    targets: [
      Target(name: "Libc"),
      Target(name: "OS", dependencies: ["Linux"]),
      Target(name: "LowSockets", dependencies: ["Libc", "OS"]),
    ]
)

#if os(Linux)
  let epollTarget = Target(name: "Epoll", dependencies: ["OS"])
  let linuxTarget = Target(name: "Linux", dependencies: [])
  let cepollDep = Package.Dependency.Package(url: "git@bitbucket.org:___mna___/cepoll.git", majorVersion: 1)
  package.exclude = ["Sources/Kqueue", "Tests/KqueueTests"]
  package.dependencies.append(cepollDep)
  package.targets.append(epollTarget)
  package.targets.append(linuxTarget)
#else
  let kqueueTarget = Target(name: "Kqueue", dependencies: ["OS"])
  package.exclude = ["Sources/Epoll", "Tests/EpollTests"]
  package.targets.append(kqueueTarget)
#endif
