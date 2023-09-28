//
//  AZBlobClient+Endpoints.swift
//  AzureBlobStorage
//
//  Created by Ionut Andrei COSTIN on 22.09.2023.
//

import Foundation
import Alamofire
import XMLCoder

extension AZBlobClient {
   public func existsContainer(named name: String) async -> Error? {
      let queryItems = [URLQueryItem(name: "restype", value: "container")]
      let response = await request(path: name, method: .head, queryItems: queryItems)
         .serializingData()
         .azResponse
      return response.error
   }

   /// Returns `true` if the container was created
   public func createContainerIfNotExisting(named name: String) async -> Result<Bool> {
      if await existsContainer(named: name) == nil {
         return .success(false)
      } else {
         if let error = await createContainer(named: name) {
            return .failure(error)
         } else {
            return .success(true)
         }
      }
   }

   public func createContainer(named name: String) async -> Error? {
      let queryItems = [URLQueryItem(name: "restype", value: "container")]
      let response = await request(path: name, method: .put, queryItems: queryItems)
         .serializingData(emptyResponseCodes: [201])
         .azResponse

      return response.error
   }
}

extension AZBlobClient {
   public func uploadLocalBlob(atURL url: URL, toContainer container: String) async -> Error? {
      guard let data = FileManager.default.contents(atPath: url.path) else {
         return Error(code: .noSuchFile)
      }
      return await uploadBlob(data, named: url.lastPathComponent, toContainer: container)
   }

   public func uploadBlob(_ data: Data, named name: String, toContainer container: String) async -> Error? {
      // Upload blob in batches
      let stream = InputStream(data: data)
      stream.open()
      defer { stream.close() }

      let bufferSize = 1024 * 1024 * 5 // 5 MB
      let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
      defer { buffer.deallocate() }

      let path = "\(container)/\(name)"
      var uploadedBlockIDs: [String] = []

      while stream.hasBytesAvailable {
         let read = stream.read(buffer, maxLength: bufferSize)
         let bufferData = Data(bytes: buffer, count: read)

         let blockID = UUID().uuidString.data(using: .utf8)!.base64EncodedString()
         let queryItems: [URLQueryItem] = [.init(name: "comp", value: "block"),
                                           .init(name: "blockid", value: blockID)]

         let bufferUploadResponse = await self.upload(bufferData, to: path, method: .put, queryItems: queryItems)
            .serializingData(emptyResponseCodes: [201])
            .azResponse

         if let error = bufferUploadResponse.error {
            return error
         }

         uploadedBlockIDs.append(blockID)
      }

      // Commit blocks
      let blockListData: Data
      do {
         let blockList = BlockList(latest: uploadedBlockIDs)
         blockListData = try XMLEncoder().encode(blockList)
      } catch {
         return Error(error: error)
      }

      let queryItems = [URLQueryItem(name: "comp", value: "blocklist")]
      let blockListResponse = await upload(blockListData, to: path, method: .put, queryItems: queryItems)
         .serializingData(emptyResponseCodes: [201])
         .azResponse

      return blockListResponse.error
   }
}
