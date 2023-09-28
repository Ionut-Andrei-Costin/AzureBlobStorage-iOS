// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(name: "AzureBlobStorage",
                      platforms: [.iOS(.v13)],
                      products: [.library(name: "AzureBlobStorage",
                                          targets: ["AzureBlobStorage"])],
                      dependencies: [.package(url: "https://github.com/Alamofire/Alamofire", exact: .init(5, 8, 0)),
                                     .package(url: "https://github.com/CoreOffice/XMLCoder", exact: .init(0, 17, 1))],
                      targets: [.target(name: "AzureBlobStorage",
                                        dependencies: [.byName(name: "Alamofire"),
                                                       .byName(name: "XMLCoder")],
                                        path: "AzureBlobStorage")],
                      swiftLanguageVersions: [.v5]
)
