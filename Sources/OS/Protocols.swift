// MARK: - FileDescriptorRepresentable

/// Any resource that can be represented with a file descriptor.
public protocol FileDescriptorRepresentable {
  var fileDescriptor: Int32 { get }
}

// MARK: - Int32+FileDescriptorRepresentable

extension Int32: FileDescriptorRepresentable {
  /// The file descriptor for an Int32 is the value of the Int32 itself.
  public var fileDescriptor: Int32 {
    return self
  }
}
