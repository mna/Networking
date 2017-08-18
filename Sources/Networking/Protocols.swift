// MARK: - FileDescriptorRepresentable

/// Any resource that can be represented with a file descriptor.
public protocol FileDescriptorRepresentable {
  var fileDescriptor: Int32 { get }
}

extension Int32: FileDescriptorRepresentable {
  public var fileDescriptor: Int32 {
    return self
  }
}
