//
//  BlockList.swift
//  AzureBlobStorage
//
//  Created by Ionut Andrei COSTIN on 27.09.2023.
//

import Foundation

struct BlockList: Codable {
   let committed: [String]
   let uncommitted: [String]
   let latest: [String]

   private enum CodingKeys: String, CodingKey {
      case committed = "Committed"
      case uncommitted = "Uncommitted"
      case latest = "Latest"
   }

   init(committed: [String] = [], uncommitted: [String] = [], latest: [String] = []) {
      self.committed = committed
      self.uncommitted = uncommitted
      self.latest = latest
   }
}
