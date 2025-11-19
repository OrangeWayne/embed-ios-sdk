Pod::Spec.new do |spec|
	spec.name         = "EmbedIOSSDK"
	spec.version      = "1.0.1"
	spec.summary      = "Tagnology Embed SDK for iOS - Embed web content into iOS apps with SwiftUI support"
	spec.description  = <<-DESC
	  EmbedIOSSDK is a powerful iOS SDK developed by Tagnology that allows you to embed 
	  web content into your iOS applications. It provides:
	  - SwiftUI integration
	  - Floating media support with click-through overlay
	  - Lightbox functionality
	  - Smart hit-testing for interactive elements
	  - Support for fixed position widgets
	  - Fullscreen mode support
	DESC
  
	spec.homepage     = "https://embed.tagnology.co"
	spec.license      = { :type => "MIT", :file => "LICENSE" }
	spec.author       = { "Tagnology" => "wayne.zhang@tagnology.co" }
	
	spec.platform     = :ios, "14.0"
	spec.swift_version = "5.0"
	
	spec.source       = { :git => "https://github.com/OrangeWayne/embed-ios-sdk.git", :tag => "#{spec.version}" }
	
	spec.source_files = "embed.swift"
	
	spec.frameworks   = "SwiftUI", "WebKit", "UIKit"
	spec.requires_arc = true
	
	spec.pod_target_xcconfig = {
	  'SWIFT_VERSION' => '5.0',
	  'IPHONEOS_DEPLOYMENT_TARGET' => '14.0'
	}
	
	spec.user_target_xcconfig = {
	  'SWIFT_VERSION' => '5.0'
	}
  end
  
  