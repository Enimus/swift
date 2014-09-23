//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2015 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import SwiftShims // for putchar

//===----------------------------------------------------------------------===//
// Input/Output interfaces
//===----------------------------------------------------------------------===//

/// A target of text streaming operations.
public protocol OutputStreamType {
  /// Append the given `string` to this stream.
  mutating func write(string: String)
}

/// A source of text streaming operations.  `Streamable` instances can
/// be written to any *output stream*.
///
/// For example: `String`, `Character`, `UnicodeScalar`.
public protocol Streamable {
  /// Write a textual representation of `self` into `target`
  func writeTo<Target : OutputStreamType>(inout target: Target)
}

/// A type with a customized textual representation.
///
/// This textual representation is used when objects are written to an
/// *output stream*, for example, by `print` and `println`.
public protocol Printable {
  /// A textual representation of `self`.
  var description: String { get }
}

/// A type with a customized textual representation for debugging
/// purposes.
///
/// This textual representation is used when objects are written to an
/// *output stream* by `debugPrint` and `debugPrintln`, and is
/// typically more verbose than the text provided by a `Printable`\ 's
/// `description` property.
public protocol DebugPrintable {
  /// A textual representation of `self`, suitable for debugging.
  var debugDescription: String { get }
}

//===----------------------------------------------------------------------===//
// `print`
//===----------------------------------------------------------------------===//

/// Do our best to print a value that can not be printed directly, using one of
/// its conformances to `Streamable`, `Printable` or `DebugPrintable`.
func _adHocPrint<T, TargetStream : OutputStreamType>(
    object: T, inout target: TargetStream
) {
  var mirror = reflect(object)
  // Checking the mirror kind is not a good way to implement this, but we don't
  // have a more expressive reflection API now.
  if mirror is _TupleMirror {
    print("(", &target)
    var first = true
    for i in 0..<mirror.count {
      if first {
        first = false
      } else {
        print(", ", &target)
      }
      var (label, elementMirror) = mirror[i]
      var elt = elementMirror.value
      // FIXME: uncomment for a compiler crash:
      //_adHocPrint(elt, &target)
      // workaround:
      print(elt, &target)
    }
    print(")", &target)
    return
  }
  print(mirror.summary, &target)
}

/// Writes the textual representation of `object` into the stream `target`.
///
/// The textual representation is obtained from the `object` using its protocol
/// conformances, in the following order of preference: `Streamable`,
/// `Printable`, `DebugPrintable`.
///
/// Do not overload this function for your type.  Instead, adopt one of the
/// protocols mentioned above.
public func print<T, TargetStream : OutputStreamType>(
    object: T, inout target: TargetStream
) {
  if let streamableObject =
      _stdlib_dynamicCastToExistential1(object, Streamable.self) {
    streamableObject.writeTo(&target)
    return
  }

  if var printableObject =
      _stdlib_dynamicCastToExistential1(object, Printable.self) {
    printableObject.description.writeTo(&target)
    return
  }

  if let debugPrintableObject =
      _stdlib_dynamicCastToExistential1(object, DebugPrintable.self) {
    debugPrintableObject.debugDescription.writeTo(&target)
    return
  }

  _adHocPrint(object, &target)
}

/// Writes the textual representation of `object` and a newline character into
/// the stream `target`.
///
/// The textual representation is obtained from the `object` using its protocol
/// conformances, in the following order of preference: `Streamable`,
/// `Printable`, `DebugPrintable`.
///
/// Do not overload this function for your type.  Instead, adopt one of the
/// protocols mentioned above.
public func println<T, TargetStream : OutputStreamType>(
    object: T, inout target: TargetStream
) {
  print(object, &target)
  target.write("\n")
}

/// Writes the textual representation of `object` into the standard output.
///
/// The textual representation is obtained from the `object` using its protocol
/// conformances, in the following order of preference: `Streamable`,
/// `Printable`, `DebugPrintable`.
///
/// Do not overload this function for your type.  Instead, adopt one of the
/// protocols mentioned above.
public func print<T>(object: T) {
  var stdoutStream = _Stdout()
  print(object, &stdoutStream)
}

/// Writes the textual representation of `object` and a newline character into
/// the standard output.
///
/// The textual representation is obtained from the `object` using its protocol
/// conformances, in the following order of preference: `Streamable`,
/// `Printable`, `DebugPrintable`.
///
/// Do not overload this function for your type.  Instead, adopt one of the
/// protocols mentioned above.
public func println<T>(object: T) {
  var stdoutStream = _Stdout()
  print(object, &stdoutStream)
  stdoutStream.write("\n")
}

/// Writes a single newline character into the standard output.
public func println() {
  var stdoutStream = _Stdout()
  stdoutStream.write("\n")
}

/// Returns the result of `print`\ 'ing `x` into a `String`
public func toString<T>(x: T) -> String {
  var result = ""
  print(x, &result)
  return result
}

/// Returns the result of `print`\ 'ing `x` into a `String`
///
/// Exactly the same as `toString`, but annotated 'readonly' to allow the optimizer
/// to remove calls where results are unused.
///
/// This function is forbidden from being inlined because when building the
/// standard library inlining makes us drop the special semantics.
@inline(never) @effects(readonly)
func _toStringReadOnlyStreamable<T : Streamable>(x: T) -> String {
  var result = ""
  x.writeTo(&result)
  return result
}

@inline(never) @effects(readonly)
func _toStringReadOnlyPrintable<T : Printable>(x: T) -> String {
  return x.description
}

/// Returns the result of `debugPrint`\ 'ing `x` into a `String`
public func toDebugString<T>(x: T) -> String {
  var result = ""
  debugPrint(x, &result)
  return result
}

//===----------------------------------------------------------------------===//
// `debugPrint`
//===----------------------------------------------------------------------===//

public func debugPrint<T, TargetStream : OutputStreamType>(
    object: T, inout target: TargetStream
) {
  if let debugPrintableObject =
      _stdlib_dynamicCastToExistential1(object, DebugPrintable.self) {
    debugPrintableObject.debugDescription.writeTo(&target)
    return
  }

  if var printableObject =
      _stdlib_dynamicCastToExistential1(object, Printable.self) {
    printableObject.description.writeTo(&target)
    return
  }

  if let streamableObject =
      _stdlib_dynamicCastToExistential1(object, Streamable.self) {
    streamableObject.writeTo(&target)
    return
  }

  _adHocPrint(object, &target)
}

public func debugPrintln<T, TargetStream : OutputStreamType>(
    object: T, inout target: TargetStream
) {
  debugPrint(object, &target)
  target.write("\n")
}

public func debugPrint<T>(object: T) {
  var stdoutStream = _Stdout()
  debugPrint(object, &stdoutStream)
}

public func debugPrintln<T>(object: T) {
  var stdoutStream = _Stdout()
  debugPrint(object, &stdoutStream)
  stdoutStream.write("\n")
}

//===----------------------------------------------------------------------===//
// OutputStreams
//===----------------------------------------------------------------------===//

internal struct _Stdout : OutputStreamType {
  mutating func write(string: String) {
    // FIXME: buffering?
    // It is important that we use stdio routines in order to correctly
    // interoperate with stdio buffering.
    for c in string.utf8 {
      putchar(Int32(c))
    }
  }
}

extension String : OutputStreamType {
  public mutating
  
  /// Append `other` to this stream.
  func write(other: String) {
    self += other
  }
}

//===----------------------------------------------------------------------===//
// Streamables
//===----------------------------------------------------------------------===//

extension String : Streamable {
  /// Write a textual representation of `self` into `target`
  public func writeTo<Target : OutputStreamType>(inout target: Target) {
    target.write(self)
  }
}

extension Character : Streamable {
  /// Write a textual representation of `self` into `target`
  public func writeTo<Target : OutputStreamType>(inout target: Target) {
    target.write(String(self))
  }
}

extension UnicodeScalar : Streamable {
  /// Write a textual representation of `self` into `target`
  public func writeTo<Target : OutputStreamType>(inout target: Target) {
    target.write(String(Character(self)))
  }
}
