//
//  AZBlobClient.swift
//  AzureBlobStorage
//
//  Created by Ionut Andrei COSTIN on 22.09.2023.
//

import Foundation
import Alamofire
import CryptoKit

public class AZBlobClient {
   public typealias Result<Value> = Swift.Result<Value, Error>

   private let hostSuffix = ".blob.core.windows.net"
   private let headerDateFormatter: DateFormatter = {
      let dateFormatter = DateFormatter()
      dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
      dateFormatter.locale = Locale(identifier: "en_US_POSIX")
      dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

      return dateFormatter
   }()

   private let credentials: AZCredentials
   private let baseURL: URL

   // MARK: - Init
   public init(`protocol`: AZEndpointsProtocol, credentials: AZCredentials) {
      self.credentials = credentials

      switch credentials {
      case let .sharedKey(accountName, _, _):
         self.baseURL = URL(string: "\(`protocol`.rawValue)://\(accountName)\(hostSuffix)")!
      }
   }

   // MARK: - Getters
   private var defaultHeaders: HTTPHeaders {
      HTTPHeaders(arrayLiteral: .init(name: "x-ms-client-request-id", value: UUID().uuidString),
                  .init(name: "x-ms-date", value: headerDateFormatter.string(from: Date())),
                  .init(name: "x-ms-version", value: "2023-05-03"))
   }

   // MARK: - Request
   func request(path: String,
                method: HTTPMethod,
                queryItems: [URLQueryItem]? = nil,
                parameters: Parameters? = nil,
                encoding: ParameterEncoding = URLEncoding.default,
                headers: HTTPHeaders? = nil) -> DataRequest {
      var allHeaders = defaultHeaders
      headers?.forEach { allHeaders.update($0) }

      let request = createAndSignRequest(path: path, method: method,
                                         queryItems: queryItems, parameters: parameters,
                                         encoding: encoding, headers: allHeaders)
      return AF.request(request).validate()
   }

   func upload(_ data: Data,
               to path: String,
               method: HTTPMethod,
               queryItems: [URLQueryItem]? = nil,
               parameters: Parameters? = nil,
               encoding: ParameterEncoding = URLEncoding.default,
               headers: HTTPHeaders? = nil) -> UploadRequest {
      var allHeaders = defaultHeaders
      allHeaders.add(name: "Content-Length", value: String(data.count))
      headers?.forEach { allHeaders.update($0) }

      let request = createAndSignRequest(path: path, method: method,
                                         queryItems: queryItems, parameters: parameters,
                                         encoding: encoding, headers: allHeaders)
      return AF.upload(data, with: request).validate()
   }

   // MARK: - Helpers
   private func createAndSignRequest(path: String,
                                     method: HTTPMethod,
                                     queryItems: [URLQueryItem]? = nil,
                                     parameters: Parameters? = nil,
                                     encoding: ParameterEncoding = URLEncoding.default,
                                     headers: HTTPHeaders? = nil) -> URLRequest {
      var urlComponents = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
      urlComponents.queryItems = queryItems

      var request = URLRequest(url: urlComponents.url!)
      request.method = method
      request.headers = headers ?? HTTPHeaders()

      // swiftlint:disable:next force_try
      request = try! encoding.encode(request, with: parameters)
      signRequest(&request)

      return request
   }

   private func signRequest(_ request: inout URLRequest) {
      let requestHeaders = request.headers

      var stringToSign = ""

      // Method
      stringToSign.append(request.httpMethod ?? "")

      // Standard headers
      stringToSign.appendOnNewLine(requestHeaders.value(for: "Content-Encoding") ?? "")
      stringToSign.appendOnNewLine(requestHeaders.value(for: "Content-Language") ?? "")

      let contentLength = requestHeaders.value(for: "Content-Length") ?? ""
      stringToSign.appendOnNewLine(contentLength != "0" ? contentLength : "")

      stringToSign.appendOnNewLine(requestHeaders.value(for: "Content-MD5") ?? "")
      stringToSign.appendOnNewLine(requestHeaders.value(for: "Content-Type") ?? "")
      stringToSign.appendOnNewLine(requestHeaders.value(for: "Date") ?? "")
      stringToSign.appendOnNewLine(requestHeaders.value(for: "If-Modified-Since") ?? "")
      stringToSign.appendOnNewLine(requestHeaders.value(for: "If-Match") ?? "")
      stringToSign.appendOnNewLine(requestHeaders.value(for: "If-None-Match") ?? "")
      stringToSign.appendOnNewLine(requestHeaders.value(for: "If-Unmodified-Since") ?? "")
      stringToSign.appendOnNewLine(requestHeaders.value(for: "Range") ?? "")

      // x-ms-* headers (Canonicalized headers)
      requestHeaders
         .filter { $0.name.hasPrefix("x-ms-") }
         .sorted(by: { $0.name < $1.name })
         .forEach { header in
            let name = header.name
               .cleaningWhitespacesAndNewLines()
               .lowercased()
            let value = header.value
               .cleaningWhitespacesAndNewLines()

            stringToSign.appendOnNewLine(name + ":" + value)
         }

      // Canonicalized resource string
      let urlComponents = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!

      let host = urlComponents.host!.replacingOccurrences(of: hostSuffix, with: "")
      stringToSign.appendOnNewLine("/" + host + urlComponents.percentEncodedPath)

      urlComponents.queryItems?
         .sorted(by: { $0.name < $1.name })
         .forEach { stringToSign.appendOnNewLine($0.name + ":" + ($0.value ?? "")) }

      // String Signing
      switch credentials {
      case let .sharedKey(accountName, key, isLite):
         guard let keyData = Data(base64Encoded: key) else {
            assert(false, "Invalid key")
            return
         }
         let signatureKey = SymmetricKey(data: keyData)
         let signature = HMAC<SHA256>.authenticationCode(for: stringToSign.data(using: .utf8)!, using: signatureKey)
         let signatureString = Data(signature).base64EncodedString()

         let prefix = "SharedKey" + (isLite ? "Lite " : " ")
         request.headers.add(.authorization(prefix + accountName + ":" + signatureString))
      }
   }
}

extension DataTask {
   public var azResponse: DataResponse<Value, AZBlobClient.Error> {
       get async {
          let response = await self.response

          let result: Result<Value, AZBlobClient.Error>
          switch response.result {
          case .success(let value):
             result = .success(value)
          case .failure(let error):
             result = .failure(.init(error: error, response: response.response, data: response.data))
          }

          return DataResponse(request: response.request,
                              response: response.response,
                              data: response.data,
                              metrics: response.metrics,
                              serializationDuration: response.serializationDuration,
                              result: result)
       }
   }

   /// `Result` of any response serialization performed for the `response`.
   public var azResult: Result<Value, AZBlobClient.Error> {
       get async { await azResponse.result }
   }
}

extension String {
   mutating func appendOnNewLine(_ other: String) {
      self += "\n" + other
   }

   /// Returns a new string made by removing from both ends of the `String` whitespaces and new lines
   /// and by replacing duplicated whitespaces and new lines from between the end of the `String` with one whitespace
   fileprivate func cleaningWhitespacesAndNewLines() -> String {
      self.trimmingCharacters(in: .whitespacesAndNewlines)
         .replacingOccurrences(of: "[ \n]+", with: " ", options: .regularExpression)
   }
}

public extension Result {
   var value: Success? {
      try? get()
   }

   var error: Failure? {
      if case .failure(let error) = self {
         return error
      }
      return nil
   }
}
