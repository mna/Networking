import Libc
import OS

// MARK: - Kevent

public struct Kevent {

  // MARK: - Properties

  public let identifier: Int
  public let filter: Filter
  public let flags: Flags
  public let filterFlags: FilterFlags
  public let data: Int

  // MARK: - Constructors

  public init() {
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

  public init(fd: FileDescriptorRepresentable, filter: Filter = .read, flags: Flags = [.add], filterFlags: FilterFlags = [], data: Int = 0) {
    self.identifier = Int(fd.fileDescriptor)
    self.filter = filter
    self.flags = flags
    self.filterFlags = filterFlags
    self.data = data
  }

  public init(identifier: Int, filter: Filter = .read, flags: Flags = [.add], filterFlags: FilterFlags = [], data: Int = 0) {
    self.identifier = identifier
    self.filter = filter
    self.flags = flags
    self.filterFlags = filterFlags
    self.data = data
  }

  public init(signal: Signal, flags: Flags = [.add]) {
    self.init(identifier: Int(signal.value), filter: .signal, flags: flags)
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
  public struct Flags: OptionSet {
    public let rawValue: Int32

    public init(rawValue: Int32) {
      self.rawValue = rawValue
    }

    public static let add = Flags(rawValue: EV_ADD)
    public static let enable = Flags(rawValue: EV_ENABLE)
    public static let disable = Flags(rawValue: EV_DISABLE)
    public static let delete = Flags(rawValue: EV_DELETE)
    public static let receipt = Flags(rawValue: EV_RECEIPT)
    public static let oneShot = Flags(rawValue: EV_ONESHOT)
    public static let clear = Flags(rawValue: EV_CLEAR)
    public static let eof = Flags(rawValue: EV_EOF)
    public static let ooband = Flags(rawValue: EV_OOBAND)
    public static let error = Flags(rawValue: EV_ERROR)
  }
}

// MARK: - Kevent+FilterFlags

extension Kevent {
  public struct FilterFlags: OptionSet {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
      self.rawValue = rawValue
    }

    // for sockets on .read, .write:
    public static let lowat = FilterFlags(rawValue: UInt32(NOTE_LOWAT))

    // for .except:
    public static let oob = FilterFlags(rawValue: UInt32(NOTE_OOB))

    // for .vnode:
    public static let delete = FilterFlags(rawValue: UInt32(NOTE_DELETE))
    public static let write = FilterFlags(rawValue: UInt32(NOTE_WRITE))
    public static let extend = FilterFlags(rawValue: UInt32(NOTE_EXTEND))
    public static let attrib = FilterFlags(rawValue: UInt32(NOTE_ATTRIB))
    public static let link = FilterFlags(rawValue: UInt32(NOTE_LINK))
    public static let rename = FilterFlags(rawValue: UInt32(NOTE_RENAME))
    public static let revoke = FilterFlags(rawValue: UInt32(NOTE_REVOKE))
    public static let funlock = FilterFlags(rawValue: UInt32(NOTE_FUNLOCK))

    // for .proc:
    public static let exit = FilterFlags(rawValue: UInt32(NOTE_EXIT))
    public static let exitStatus = FilterFlags(rawValue: UInt32(NOTE_EXITSTATUS))
    public static let fork = FilterFlags(rawValue: UInt32(NOTE_FORK))
    public static let exec = FilterFlags(rawValue: UInt32(NOTE_EXEC))
    public static let signal = FilterFlags(rawValue: UInt32(NOTE_SIGNAL))

    // for .timer:
    public static let seconds = FilterFlags(rawValue: UInt32(NOTE_SECONDS))
    public static let useconds = FilterFlags(rawValue: UInt32(NOTE_USECONDS))
    public static let nseconds = FilterFlags(rawValue: UInt32(NOTE_NSECONDS))
    public static let absolute = FilterFlags(rawValue: UInt32(NOTE_ABSOLUTE))
    public static let critical = FilterFlags(rawValue: UInt32(NOTE_CRITICAL))
    public static let background = FilterFlags(rawValue: UInt32(NOTE_BACKGROUND))
    // leeway not supported for now, as only kevent is used (not kevent64)

    // for .user:
    public static let ffnop = FilterFlags(rawValue: UInt32(NOTE_FFNOP))
    public static let ffand = FilterFlags(rawValue: UInt32(NOTE_FFAND))
    public static let ffor = FilterFlags(rawValue: UInt32(NOTE_FFOR))
    public static let ffcopy = FilterFlags(rawValue: UInt32(NOTE_FFCOPY))
    public static let ffctrlMask = FilterFlags(rawValue: UInt32(NOTE_FFCTRLMASK))
    public static let fflagsMask = FilterFlags(rawValue: UInt32(NOTE_FFLAGSMASK))
    public static let trigger = FilterFlags(rawValue: UInt32(NOTE_TRIGGER))
  }
}

// MARK: - Kevent+Filter

extension Kevent {
  public enum Filter {
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
