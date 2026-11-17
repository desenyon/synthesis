import Foundation

/// Small arithmetic grammar: numbers, field keys, + - * / %, parentheses and six pure functions.
/// No Foundation expression interpreter, filesystem, network, JavaScript or executable payloads.
public enum EntityFormula {
  public static func references(_ expression: String) throws -> Set<String> {
    let tokens = try tokenize(expression)
    return Set(
      tokens.enumerated().compactMap { index, token in
        guard case .name(let name) = token else { return nil }
        if index + 1 < tokens.count, tokens[index + 1] == .symbol("(") { return nil }
        return name
      })
  }
  public static func evaluate(_ expression: String, value: @escaping (String) throws -> Double)
    throws -> Double
  {
    var parser = Parser(tokens: try tokenize(expression), value: value)
    let result = try parser.expression()
    guard parser.index == parser.tokens.count, result.isFinite else {
      throw SynthesisError.invalid("The formula must produce a finite number.")
    }
    return result
  }
  public static func validateSyntax(_ expression: String) throws {
    var parser = Parser(tokens: try tokenize(expression), value: { _ in 1 }, validating: true)
    _ = try parser.expression()
    guard parser.index == parser.tokens.count else {
      throw SynthesisError.invalid("The formula contains an unexpected term.")
    }
  }
  private enum Token: Equatable {
    case number(Double)
    case name(String)
    case symbol(Character)
  }
  private static func tokenize(_ text: String) throws -> [Token] {
    guard !text.isEmpty, text.count <= 1000 else {
      throw SynthesisError.invalid("Use a formula of 1–1000 characters.")
    }
    let chars = Array(text)
    var result: [Token] = []
    var i = 0
    while i < chars.count {
      let c = chars[i]
      if c.isWhitespace {
        i += 1
        continue
      }
      if c.isASCII && (c.isNumber || c == ".") {
        let start = i
        i += 1
        while i < chars.count && (chars[i].isASCII && chars[i].isNumber || chars[i] == ".") {
          i += 1
        }
        guard let value = Double(String(chars[start..<i])), value.isFinite else {
          throw SynthesisError.invalid("The formula contains an invalid number.")
        }
        result.append(.number(value))
      } else if c.isASCII && (c.isLetter || c == "_") {
        let start = i
        i += 1
        while i < chars.count && chars[i].isASCII
          && (chars[i].isLetter || chars[i].isNumber || chars[i] == "_")
        { i += 1 }
        result.append(.name(String(chars[start..<i])))
      } else if "+-*/%(),".contains(c) {
        result.append(.symbol(c))
        i += 1
      } else {
        throw SynthesisError.invalid("Formulas accept arithmetic and field keys only.")
      }
      guard result.count <= 256 else {
        throw SynthesisError.invalid("This formula has too many terms.")
      }
    }
    return result
  }
  private struct Parser {
    let tokens: [Token]
    let value: (String) throws -> Double
    var validating = false
    var index = 0
    var depth = 0
    mutating func consume(_ char: Character) -> Bool {
      guard index < tokens.count, tokens[index] == .symbol(char) else { return false }
      index += 1
      return true
    }
    mutating func expression() throws -> Double {
      depth += 1
      defer { depth -= 1 }
      guard depth <= 32 else { throw SynthesisError.invalid("The formula is nested too deeply.") }
      var result = try term()
      while index < tokens.count {
        if consume("+") {
          result += try term()
        } else if consume("-") {
          result -= try term()
        } else {
          break
        }
      }
      return result
    }
    mutating func term() throws -> Double {
      var result = try atom()
      while index < tokens.count {
        if consume("*") {
          result *= try atom()
        } else if consume("/") {
          let divisor = try atom()
          guard validating || divisor != 0 else {
            throw SynthesisError.invalid("A formula cannot divide by zero.")
          }
          result = validating && divisor == 0 ? 0 : result / divisor
        } else if consume("%") {
          let divisor = try atom()
          guard validating || divisor != 0 else {
            throw SynthesisError.invalid("A formula cannot divide by zero.")
          }
          result = validating && divisor == 0 ? 0 : result.truncatingRemainder(dividingBy: divisor)
        } else {
          break
        }
      }
      return result
    }
    mutating func atom() throws -> Double {
      depth += 1
      defer { depth -= 1 }
      guard depth <= 32 else { throw SynthesisError.invalid("The formula is nested too deeply.") }
      if consume("-") { return try -atom() }
      if consume("+") { return try atom() }
      if consume("(") {
        let result = try expression()
        guard consume(")") else { throw SynthesisError.invalid("Close each formula parenthesis.") }
        return result
      }
      guard index < tokens.count else { throw SynthesisError.invalid("The formula is incomplete.") }
      let token = tokens[index]
      index += 1
      switch token {
      case .number(let number): return number
      case .name(let name):
        if !consume("(") { return try value(name) }
        var args: [Double] = [try expression()]
        while consume(",") { args.append(try expression()) }
        guard consume(")") else {
          throw SynthesisError.invalid("Close the function's parentheses.")
        }
        switch (name, args.count) {
        case ("min", 2): return min(args[0], args[1])
        case ("max", 2): return max(args[0], args[1])
        case ("abs", 1): return abs(args[0])
        case ("round", 1): return args[0].rounded()
        case ("floor", 1): return floor(args[0])
        case ("ceil", 1): return ceil(args[0])
        default:
          throw SynthesisError.invalid(
            "Use min(a,b), max(a,b), abs(x), round(x), floor(x) or ceil(x).")
        }
      case .symbol: throw SynthesisError.invalid("A formula term is missing.")
      }
    }
  }
}

/// Shared memoization makes a densely connected formula graph linear in its dependencies.
final class EntityFormulaValues {
  let fields: [String: EntityField]
  let values: [String: EntityValue]
  private var cache: [String: Double] = [:]
  private var active = Set<String>()
  private var unavailable = Set<String>()
  init(fields: [EntityField], values: [String: EntityValue]) {
    self.fields = Dictionary(uniqueKeysWithValues: fields.map { ($0.key, $0) })
    self.values = values
  }
  func resolve(_ key: String) throws -> Double {
    if let value = cache[key] { return value }
    guard !active.contains(key), !unavailable.contains(key), let field = fields[key] else {
      throw SynthesisError.invalid("A computed input is unavailable.")
    }
    active.insert(key)
    defer { active.remove(key) }
    do {
      let value: Double
      if field.kind == .formula {
        value = try EntityFormula.evaluate(field.formula) { try self.resolve($0) }
      } else {
        guard case .number(let number) = values[key] else {
          throw SynthesisError.invalid("\(field.label) is unknown.")
        }
        value = number
      }
      cache[key] = value
      return value
    } catch {
      unavailable.insert(key)
      throw error
    }
  }
}
