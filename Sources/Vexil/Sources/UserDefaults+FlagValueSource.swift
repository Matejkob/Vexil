//===----------------------------------------------------------------------===//
//
// This source file is part of the Vexil open source project
//
// Copyright (c) 2023 Unsigned Apps and the open source contributors.
// Licensed under the MIT license
//
// See LICENSE for license information
//
// SPDX-License-Identifier: MIT
//
//===----------------------------------------------------------------------===//

#if !os(Linux)
import Combine
#endif

import Foundation

/// Provides support for using `UserDefaults` as a `FlagValueSource`
///
extension UserDefaults: FlagValueSource {

    /// The name of the Flag Value Source
    public var name: String {
        return "UserDefaults\(self == UserDefaults.standard ? ".standard" : "")"
    }

    /// Fetch values for the specified key
    public func flagValue<Value>(key: String) -> Value? where Value: FlagValue {

        guard
            let object = object(forKey: key),
            let boxed = BoxedFlagValue(object: object, typeHint: Value.self)
        else {
            return nil
        }

        return Value(boxedFlagValue: boxed)
    }

    /// Sets the value for the specified key
    public func setFlagValue<Value>(_ value: Value?, key: String) throws where Value: FlagValue {
        guard let value = value else {
            removeObject(forKey: key)
            return
        }

        if value.boxedFlagValue.object == NSNull() {
            set(Data(), forKey: key)
        } else {
            set(value.boxedFlagValue.object, forKey: key)
        }

    }

#if os(watchOS)

    /// A Publisher that emits events when the flag values it manages changes
    public func valuesDidChange(keys: Set<String>) -> AnyPublisher<Set<String>, Never>? {
        return NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .filter { ($0.object as AnyObject) === self }
            .map { _ in [] }
            .eraseToAnyPublisher()
    }

#elseif !os(Linux)

    public func valuesDidChange(keys: Set<String>) -> AnyPublisher<Set<String>, Never>? {
        return Publishers.Merge(
            NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
                .filter { ($0.object as AnyObject) === self }
                .map { _ in () },
            NotificationCenter.default.publisher(for: ApplicationDidBecomeActive).map { _ in () }
        )
        .map { _ in [] }
        .eraseToAnyPublisher()
    }

#endif
}


// MARK: - Application Active Notifications

#if canImport(UIKit) && !os(watchOS)

import UIKit

private let ApplicationDidBecomeActive = UIApplication.didBecomeActiveNotification

#elseif canImport(Cocoa)

import Cocoa

private let ApplicationDidBecomeActive = NSApplication.didBecomeActiveNotification

#endif
