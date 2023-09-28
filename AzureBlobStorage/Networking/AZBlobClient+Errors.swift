//
//  AZBlobClient+Errors.swift
//  AzureBlobStorage
//
//  Created by Ionut Andrei COSTIN on 22.09.2023.
//

import Foundation
import XMLCoder

extension AZBlobClient {
   public struct Error: Swift.Error {
      private let customMessage: String?

      public let code: Code

      init(error: Swift.Error, response: HTTPURLResponse? = nil, data: Data? = nil) {
         code = Code(rawValue: response?.statusCode ?? Int.min) ?? .custom

         if let data = data {
            do {
               customMessage = try XMLDecoder().decode(String.self, from: data, keyPath: "Message")
            } catch {
               customMessage = error.localizedDescription
            }
         } else {
            switch code {
            case .resourceNotFound:
               customMessage = "Resource not found."
            default:
               customMessage = error.localizedDescription
            }
         }
      }

      init(code: Code, message: String? = nil) {
         self.code = code
         self.customMessage = message
      }

      public var message: String {
         if let customMessage = customMessage {
            return customMessage
         }

         switch code {
         case .noSuchFile: return "No file found"
         case .invalidAuthenticationInfo: return "The key is missing or is invalid"
         case .resourceNotFound: return "The specific resource is not found"
         case .resourceAlreadyExists: return "Resource already exists"
         case .custom: return "Unknown error"
         }
      }
   }
}

extension AZBlobClient.Error {
   public enum Code: Int {
      case noSuchFile = 4
      case invalidAuthenticationInfo = 401
      case resourceNotFound = 404
      case resourceAlreadyExists = 409
      case custom = 9999
   }
}
