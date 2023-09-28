//
//  AZCredentials.swift
//  AzureBlobStorage
//
//  Created by Ionut Andrei COSTIN on 22.09.2023.
//

import Foundation

public enum AZCredentials {
   case sharedKey(accountName: String, key: String, isLite: Bool)
}
