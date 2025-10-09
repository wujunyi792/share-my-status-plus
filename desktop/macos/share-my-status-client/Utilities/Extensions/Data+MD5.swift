//
//  Data+MD5.swift
//  share-my-status-client
//


import Foundation
import CommonCrypto

extension Data {
    /// Compute MD5 hash of data
    nonisolated var md5Hash: String {
        let digest = self.withUnsafeBytes { bytes in
            var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            CC_MD5(bytes.bindMemory(to: UInt8.self).baseAddress, CC_LONG(self.count), &digest)
            return digest
        }
        
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    /// Compute MD5 hash as hex string (uppercase)
    nonisolated var md5HexString: String {
        return md5Hash.uppercased()
    }
}

