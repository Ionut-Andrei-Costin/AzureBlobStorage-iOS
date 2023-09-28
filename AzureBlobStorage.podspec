Pod::Spec.new do |spec|
   spec.name = "AzureBlobStorage"
   spec.version = "0.1.0"
   spec.summary = "Client for AzureBlobStorage"
   spec.homepage = "https://github.com/Ionut-Andrei-Costin/AzureBlobStorage-iOS"
   spec.license = "MIT"
   spec.author = { "Siteflow" => "" }
   spec.source = { :git => "https://github.com/Ionut-Andrei-Costin/AzureBlobStorage-iOS", :tag => spec.version }

   spec.ios.deployment_target = "13.0"

   spec.swift_version = ['5']

   spec.source_files = ["AzureBlobStorage/**/*.swift"]

   spec.dependency "Alamofire", "5.8.0"
   spec.dependency "XMLCoder", "0.14.0"
end
