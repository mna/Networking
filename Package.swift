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

#if os(Linux)
  let epollTarget = Target(name: "Epoll", dependencies: ["OS"])
  let cepollDep = Package.Dependency.Package(url: "git clone git@bitbucket.org:___mna___/cepoll.git", majorVersion: 1)
  package.exclude = ["Sources/Kqueue", "Tests/KqueueTests"]
  package.dependencies.append(cepollDep)
  package.targets.append(epollTarget)
#else
  let kqueueTarget = Target(name: "Kqueue", dependencies: ["OS"])
  package.exclude = ["Sources/Epoll", "Tests/EpollTests"]
  package.targets.append(kqueueTarget)
#endif
