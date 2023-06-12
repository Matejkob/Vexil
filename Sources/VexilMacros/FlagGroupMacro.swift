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

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public enum FlagGroupMacro {}

extension FlagGroupMacro: AccessorMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard let argument = node.argument else {
            return []
        }

        guard
            let property = declaration.as(VariableDeclSyntax.self),
            let binding = property.bindings.first,
            let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
            let type = binding.typeAnnotation?.type,
            binding.accessor == nil
        else {
            return []
        }

        let strategy = KeyStrategy(exprSyntax: argument[label: "keyStrategy"]?.expression) ?? .default

        return [
            """
            get {
                \(type)(_flagKeyPath: \(strategy.createKey(identifier.text)), _flagLookup: _flagLookup)
            }
            """,
        ]
    }

}

// MARK: - Coding Key Strategy

private extension FlagGroupMacro {

    /// This is a mirror of `VexilConfiguration.FlagKeyStrategy` so that we can work with it ourselves
    enum KeyStrategy {
        case `default`
        case kebabcase
        case snakecase
        case skip
        case customKey(String)

        init?(exprSyntax: ExprSyntax?) {
            if let memberAccess = exprSyntax?.as(MemberAccessExprSyntax.self) {
                switch memberAccess.name.text {
                case "default":             self = .default
                case "kebabcase":           self = .kebabcase
                case "snakecase":           self = .snakecase
                case "skip":                self = .skip
                default:                    return nil
                }

            } else if
                let functionCall = exprSyntax?.as(FunctionCallExprSyntax.self),
                let memberAccess = functionCall.calledExpression.as(MemberAccessExprSyntax.self),
                let stringLiteral = functionCall.argumentList.first?.expression.as(StringLiteralExprSyntax.self),
                let string = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
            {
                switch memberAccess.name.text {
                case "customKey":           self = .customKey(string.content.text)
                default:                    return nil
                }

            } else {
                return nil
            }
        }

        func createKey(_ propertyName: String) -> ExprSyntax {
            switch self {
            case .default, .kebabcase:
                return "_flagKeyPath.append(\"\(raw: propertyName.convertedToSnakeCase(separator: "-"))\")"
            case .snakecase:
                return "_flagKeyPath.append(\"\(raw: propertyName.convertedToSnakeCase())\")"
            case .skip:
                return "_flagKeyPath"
            case let .customKey(key):
                return "_flagKeyPath.append(\"\(raw: key)\")"
            }
        }

    }

}
