import Darwin.C
import OS
import Foundation

// to avoid ambiguity between the Kqueue methods and the system calls.
private let cclose = close

// MARK: - Kqueue

class Kqueue: FileDescriptorRepresentable {

  // MARK: - Properties

  public let fileDescriptor: Int32

  // MARK: - Constructors

  init() throws {
    let ret = kqueue()
    try CError.makeAndThrow(fromReturnCode: ret)
    self.fileDescriptor = ret
  }

  deinit {
    try? close()
  }

  // MARK: - Methods

  func query(with changes: [Kevent], into events: inout [Kevent], timeout: TimeInterval? = nil) throws -> Int {
    let inKevs = changes.map({ $0.toCStruct() })
    var outKevs = Array<kevent>(repeating: kevent(), count: events.count)

    let ret: Int32
    if let timeout = timeout {
      var ts = timespec()
      ts.tv_sec = Int(timeout)
      let ns = Int(timeout.truncatingRemainder(dividingBy: 1) * 1_000_000_000)
      ts.tv_nsec = ns
      ret = kevent(fileDescriptor, inKevs, Int32(inKevs.count), &outKevs, Int32(outKevs.count), &ts)
    } else {
      ret = kevent(fileDescriptor, inKevs, Int32(inKevs.count), &outKevs, Int32(outKevs.count), nil)
    }
    try CError.makeAndThrow(fromReturnCode: ret)

    // fill events list with results
    for i in 0..<Int(ret) {
      if let ev = Kevent(outKevs[i]) {
        events[i] = ev
      }
    }
    return Int(ret)
  }

  func close() throws {
    let ret = cclose(fileDescriptor)
    try CError.makeAndThrow(fromReturnCode: ret)
  }
}
