//
//  XMLDecoder+KeyPath.swift
//  AzureBlobStorage
//
//  Created by Ionut Andrei COSTIN on 26.09.2023.
//

import Foundation
import XMLCoder

extension CodingUserInfoKey {
   static let keyPaths = CodingUserInfoKey(rawValue: "KeyPaths")!
}

private struct Key: CodingKey {
   var stringValue: String
   var intValue: Int?

   init?(stringValue: String) {
      self.stringValue = stringValue
   }

   init?(intValue: Int) {
      self.intValue = intValue
      stringValue = String(intValue)
   }
}

extension XMLDecoder {
   func decode<T: Decodable>(_ type: T.Type, from data: Data,
                             keyPath: String? = nil, keyPathSeparator separator: String = ".") throws -> T {
      let components = keyPath?.components(separatedBy: separator) ?? []
      self.userInfo = [.keyPaths: components]

      return try decode(DecodingProxy<T>.self, from: data).object
   }
}

private struct DecodingProxy<T: Decodable>: Decodable {
   let object: T

   init(from decoder: Decoder) throws {
      if var keyPaths = decoder.userInfo[.keyPaths] as? [String],
         !keyPaths.isEmpty {
         var container = try decoder.container(keyedBy: Key.self)
         let lastKey = Key(stringValue: keyPaths.removeLast())!

         for keyPath in keyPaths {
            let key = Key(stringValue: keyPath)!
            container = try container.nestedContainer(keyedBy: Key.self, forKey: key)
         }

         object = try container.decode(T.self, forKey: lastKey)
      } else {
         object = try decoder.singleValueContainer().decode(T.self)
      }
   }
}
