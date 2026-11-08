#!/usr/bin/swift
// Offline bootstrap tool. Keep the private key outside the project and source distributions.
import Foundation
import CryptoKit
import Darwin

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}
func b64url(_ data: Data) -> String {
    data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
}
struct Claims: Encodable {
    let version = 1
    let product = "NotchFlow"
    let id: String
    let kind: String
    let expiresAt: Int64?
}
let args = CommandLine.arguments
do {
    if args.count == 3 && args[1] == "generate" {
        let url = URL(fileURLWithPath: args[2])
        let key = Curve25519.Signing.PrivateKey()
        // Create atomically with owner-only permissions; never overwrite an existing key.
        let fd = open(url.path, O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { fail("Cannot create private key file (it may already exist).") }
        let file = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        try file.write(contentsOf: key.rawRepresentation)
        try file.close()
        print("Public key (base64): \(key.publicKey.rawRepresentation.base64EncodedString())")
        print("Private key saved to \(url.path). Keep it secret and back it up securely.")
    } else if (args.count == 5 || args.count == 6) && args[1] == "issue" {
        guard ["pro", "developer"].contains(args[3]), !args[4].isEmpty, args[4].utf8.count <= 128 else {
            fail("Kind must be pro or developer; id must be 1–128 bytes.")
        }
        let expiry: Int64?
        if args.count == 6 {
            guard let value = Int64(args[5]), value > 0 else { fail("Expiry must be a positive Unix timestamp.") }
            expiry = value
        } else { expiry = nil }
        let key = try Curve25519.Signing.PrivateKey(rawRepresentation: Data(contentsOf: URL(fileURLWithPath: args[2])))
        let payload = try JSONEncoder().encode(Claims(id: args[4], kind: args[3], expiresAt: expiry))
        let message = "NF1.\(b64url(payload))"
        print("\(message).\(b64url(try key.signature(for: Data(message.utf8))))")
    } else {
        fail("Usage: swift scripts/license-tool.swift generate PRIVATE_KEY_FILE\n       swift scripts/license-tool.swift issue PRIVATE_KEY_FILE pro|developer LICENSE_ID [EXPIRY_UNIX_SECONDS]")
    }
} catch {
    fail("License tool failed: \(error.localizedDescription)")
}
