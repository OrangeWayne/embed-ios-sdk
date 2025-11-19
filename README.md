# EmbedIOSSDK

Developed by Tagnology, an SDK that can be embedded into iOS apps.

## Features

-   ✅ SwiftUI integration
-   ✅ Floating media support with click-through overlay
-   ✅ Lightbox functionality
-   ✅ Smart hit-testing for interactive elements
-   ✅ Support for fixed position widgets
-   ✅ Fullscreen mode support
-   ✅ Automatic resize handling

## Requirements

-   iOS 14.0+
-   Swift 5.0+
-   Xcode 12.0+

## Installation

### CocoaPods

Add the following to your `Podfile`:

```ruby
pod 'EmbedIOSSDK', '~> 1.0.0'
```

Then run:

```bash
pod install
```

### Manual Installation

1. Copy the `embed.swift` file to your project
2. Ensure your project targets iOS 14.0 or higher

## Usage

### Basic Usage

```swift
import SwiftUI
import EmbedIOSSDK

struct ContentView: View {
    var body: some View {
        EmbedView(folderInfo: EmbedFolderInfo(
            folderId: "your-folder-id",
            productId: nil,
            platform: nil,
            productName: nil,
            productUrl: nil,
            productImage: nil,
            embedLocation: nil,
            timestamp: nil,
            folderName: nil,
            layout: nil
        ))
    }
}
```

### Handling Events

```swift
EmbedView(folderInfo: folderInfo)
    .onEvent { event in
        switch event.type {
        case "click":
            // Handle click event
            break
        case "resize":
            // Handle resize event
            break
        case "toggleLB":
            // Handle lightbox toggle
            break
        default:
            break
        }
    }
```

## License

MIT License - see LICENSE file for details

## Support

For support, please contact: support@tagnology.co
