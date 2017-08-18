import Darwin.C
import Networking

// MARK: - Kevent

struct Kevent {

  // MARK: - Properties

  let identifier: Int
  let filter: Filter
  let flags: Flags
  let filterFlags: FilterFlags
  let data: Int

  // MARK: - Constructors

  init() {
    self.identifier = 0
    self.filter = .read
    self.flags = []
    self.filterFlags = []
    self.data = 0
  }

  init?(_ kev: kevent) {
    self.identifier = Int(kev.ident)
    guard let filter = Filter.make(Int32(kev.filter)) else {
      return nil
    }
    self.filter = filter
    self.flags = Flags(rawValue: Int32(kev.flags))
    self.filterFlags = FilterFlags(rawValue: kev.fflags)
    self.data = kev.data
  }

  init(fd: FileDescriptorRepresentable, filter: Filter = .read, flags: Flags = [.add], filterFlags: FilterFlags = [], data: Int = 0) {
    self.identifier = Int(fd.fileDescriptor)
    self.filter = filter
    self.flags = flags
    self.filterFlags = filterFlags
    self.data = data
  }

  // MARK: - Methods

  func toCStruct() -> kevent {
    var kev = kevent()
    kev.ident = UInt(identifier)
    kev.filter = Int16(filter.value)
    kev.flags = UInt16(flags.rawValue)
    kev.fflags = filterFlags.rawValue
    kev.data = data

    return kev
  }
}

// MARK: - Kevent+Flags

extension Kevent {
  struct Flags: OptionSet {
    let rawValue: Int32

    init(rawValue: Int32) {
      self.rawValue = rawValue
    }

    static let add = Flags(rawValue: EV_ADD)
    static let enable = Flags(rawValue: EV_ENABLE)
    static let disable = Flags(rawValue: EV_DISABLE)
    static let delete = Flags(rawValue: EV_DELETE)
    static let receipt = Flags(rawValue: EV_RECEIPT)
    static let oneShot = Flags(rawValue: EV_ONESHOT)
    static let clear = Flags(rawValue: EV_CLEAR)
    static let eof = Flags(rawValue: EV_EOF)
    static let ooband = Flags(rawValue: EV_OOBAND)
    static let error = Flags(rawValue: EV_ERROR)
  }
}

// MARK: - Kevent+FilterFlags

extension Kevent {
  struct FilterFlags: OptionSet {
    let rawValue: UInt32

    init(rawValue: UInt32) {
      self.rawValue = rawValue
    }

    // for sockets on .read, .write:
    static let lowat = FilterFlags(rawValue: UInt32(NOTE_LOWAT))

    // for .except:
    static let oob = FilterFlags(rawValue: UInt32(NOTE_OOB))

    // for .vnode:
    static let delete = FilterFlags(rawValue: UInt32(NOTE_DELETE))
    static let write = FilterFlags(rawValue: UInt32(NOTE_WRITE))
    static let extend = FilterFlags(rawValue: UInt32(NOTE_EXTEND))
    static let attrib = FilterFlags(rawValue: UInt32(NOTE_ATTRIB))
    static let link = FilterFlags(rawValue: UInt32(NOTE_LINK))
    static let rename = FilterFlags(rawValue: UInt32(NOTE_RENAME))
    static let revoke = FilterFlags(rawValue: UInt32(NOTE_REVOKE))
    static let funlock = FilterFlags(rawValue: UInt32(NOTE_FUNLOCK))

    // for .proc:
    static let exit = FilterFlags(rawValue: UInt32(NOTE_EXIT))
    static let exitStatus = FilterFlags(rawValue: UInt32(NOTE_EXITSTATUS))
    static let fork = FilterFlags(rawValue: UInt32(NOTE_FORK))
    static let exec = FilterFlags(rawValue: UInt32(NOTE_EXEC))
    static let signal = FilterFlags(rawValue: UInt32(NOTE_SIGNAL))

    // for .timer:
    static let seconds = FilterFlags(rawValue: UInt32(NOTE_SECONDS))
    static let useconds = FilterFlags(rawValue: UInt32(NOTE_USECONDS))
    static let nseconds = FilterFlags(rawValue: UInt32(NOTE_NSECONDS))
    static let absolute = FilterFlags(rawValue: UInt32(NOTE_ABSOLUTE))
    static let critical = FilterFlags(rawValue: UInt32(NOTE_CRITICAL))
    static let background = FilterFlags(rawValue: UInt32(NOTE_BACKGROUND))
    // leeway not supported for now, as only kevent is used (not kevent64)

    // for .user:
    static let ffnop = FilterFlags(rawValue: UInt32(NOTE_FFNOP))
    static let ffand = FilterFlags(rawValue: UInt32(NOTE_FFAND))
    static let ffor = FilterFlags(rawValue: UInt32(NOTE_FFOR))
    static let ffcopy = FilterFlags(rawValue: UInt32(NOTE_FFCOPY))
    static let ffctrlMask = FilterFlags(rawValue: UInt32(NOTE_FFCTRLMASK))
    static let fflagsMask = FilterFlags(rawValue: UInt32(NOTE_FFLAGSMASK))
    static let trigger = FilterFlags(rawValue: UInt32(NOTE_TRIGGER))
  }
}

// MARK: - Kevent+Filter

extension Kevent {
  enum Filter {
    case read
    case except
    case write
    case vnode
    case proc
    case signal
    case timer
    case user

    var value: Int32 {
      guard let v = Filter.toValues[self] else {
        fatalError("unknown Filter enum: \(self)")
      }
      return v
    }

    static func make(_ value: Int32) -> Filter? {
      return fromValues[value]
    }

    private static let toValues: [Filter: Int32] = [
      .read: EVFILT_READ,
      .except: EVFILT_EXCEPT,
      .write: EVFILT_WRITE,
      .vnode: EVFILT_VNODE,
      .proc: EVFILT_PROC,
      .signal: EVFILT_SIGNAL,
      .timer: EVFILT_TIMER,
      .user: EVFILT_USER,
    ]

    private static let fromValues: [Int32: Filter] = [
      EVFILT_READ: .read,
      EVFILT_EXCEPT: .except,
      EVFILT_WRITE: .write,
      EVFILT_VNODE: .vnode,
      EVFILT_PROC: .proc,
      EVFILT_SIGNAL: .signal,
      EVFILT_TIMER: .timer,
      EVFILT_USER: .user,
    ]
  }
}
