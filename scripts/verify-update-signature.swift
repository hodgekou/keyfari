// SPDX-License-Identifier: GPL-3.0-only
// Checks that an update's EdDSA signature matches the public key the app ships with,
// so a feed entry that installed copies would reject is never published.
//
// Usage: swift scripts/verify-update-signature.swift <file> <base64 signature> <base64 public key>

import CryptoKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 4,
    let file = FileManager.default.contents(atPath: arguments[1]),
    let signature = Data(base64Encoded: arguments[2]),
    let keyData = Data(base64Encoded: arguments[3]),
    let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData)
else {
    FileHandle.standardError.write(Data("usage: verify-update-signature.swift <file> <base64 signature> <base64 public key>\n".utf8))
    exit(64)
}

if key.isValidSignature(signature, for: file) {
    print("The signature matches the public key")
} else {
    FileHandle.standardError.write(Data("The signature does not match the public key\n".utf8))
    exit(1)
}
