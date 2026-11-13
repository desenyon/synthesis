import Foundation
import Security

public enum ProviderKeychain {
  private static var query: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "dev.desenyon.synthesis",
      kSecAttrAccount as String: "openai-api-key",
    ]
  }
  public static func read() -> String? {
    var q = query
    q[kSecReturnData as String] = true
    q[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data
    else { return nil }
    return String(data: data, encoding: .utf8)
  }
  public static var configured: Bool {
    var q = query
    q[kSecReturnAttributes as String] = true
    return SecItemCopyMatching(q as CFDictionary, nil) == errSecSuccess
  }
  public static func save(_ value: String) throws {
    let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !key.isEmpty else { throw SynthesisError.invalid("Enter an API key.") }
    let data = Data(key.utf8)
    let result = SecItemUpdate(
      query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
    if result == errSecItemNotFound {
      var q = query
      q[kSecValueData as String] = data
      q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
      guard SecItemAdd(q as CFDictionary, nil) == errSecSuccess else {
        throw SynthesisError.invalid("The key could not be saved in macOS Keychain.")
      }
    } else if result != errSecSuccess {
      throw SynthesisError.invalid("Keychain refused the update.")
    }
  }
  public static func remove() throws {
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw SynthesisError.invalid("Could not remove the key from Keychain.")
    }
  }
}
public struct OpenAITransport: ModelTransport {
  public let model: @Sendable () -> String
  public init(model: @escaping @Sendable () -> String) { self.model = model }
  public func generate(_ request: ModelRequest, onDelta: @escaping @Sendable (String) async -> Void)
    async throws -> String
  {
    guard let key = ProviderKeychain.read(), !model().isEmpty else {
      throw SynthesisError.unavailable
    }
    try Task.checkCancellation()
    var url = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
    url.httpMethod = "POST"
    url.timeoutInterval = 120
    url.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
    url.setValue("application/json", forHTTPHeaderField: "Content-Type")
    url.httpBody = try JSONSerialization.data(withJSONObject: [
      "model": model(), "instructions": request.instructions, "input": request.messages,
      "stream": true, "store": false,
    ])
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 120
    config.timeoutIntervalForResource = 180
    let session = URLSession(configuration: config)
    defer { session.invalidateAndCancel() }
    let (bytes, response) = try await session.bytes(for: url)
    guard let http = response as? HTTPURLResponse else {
      throw SynthesisError.invalid("The model provider returned an invalid response.")
    }
    guard http.statusCode == 200 else {
      throw SynthesisError.invalid(
        "The model provider returned HTTP \(http.statusCode). Check your key, model access, and quota in Settings."
      )
    }
    var output = ""
    var completed = false
    for try await line in bytes.lines {
      try Task.checkCancellation()
      guard line.hasPrefix("data: "), let data = String(line.dropFirst(6)).data(using: .utf8),
        let event = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
      else { continue }
      let type = event["type"] as? String ?? ""
      if type == "response.output_text.delta", let delta = event["delta"] as? String {
        output += delta
        await onDelta(output)
      }
      if type == "response.completed" { completed = true }
      if ["error", "response.failed", "response.incomplete"].contains(type) {
        throw SynthesisError.invalid(
          "The provider could not finish this response. Your message is saved. Try again or use a different model."
        )
      }
      guard output.utf8.count < 1_000_000 else {
        throw SynthesisError.invalid("The response exceeded the local size limit.")
      }
    }
    guard completed else {
      throw SynthesisError.invalid(
        "The connection ended before the response finished. No incomplete answer was saved.")
    }
    return output
  }
}
