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

-   iOS 16.0+
-   Swift 5.0+
-   Xcode 14.0+

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
2. Ensure your project targets iOS 16.0 or higher

## Usage

### Basic Usage

`EmbedWidgetView` automatically loads and displays widgets based on the page URL and position. The SDK will automatically extract the product ID from the page URL.

```swift
import SwiftUI
import EmbedIOSSDK

struct ContentView: View {
    @State private var pageUrl: String = "https://your-domain.com/product/12345"

    var body: some View {
        ScrollView {
            VStack {
                // Display widget below buy button
                EmbedWidgetView(
                    pageUrl: pageUrl,
                    position: EmbedIOSSDK.BELOW_BUY_BUTTON
                )

                // Display widget below main product info
                EmbedWidgetView(
                    pageUrl: pageUrl,
                    position: EmbedIOSSDK.BELOW_MAIN_PRODUCT_INFO
                )
            }
        }
    }
}
```

### Position Enum

The `position` parameter accepts the following values from `EmbedIOSSDK.Position`:

**Standard Positions:**

-   `EmbedIOSSDK.BELOW_BUY_BUTTON` - Display below the buy button
-   `EmbedIOSSDK.BELOW_MAIN_PRODUCT_INFO` - Display below main product information
-   `EmbedIOSSDK.ABOVE_RECOMMENDATION` - Display above recommendation section
-   `EmbedIOSSDK.ABOVE_FILTER` - Display above filter section

**Fixed FloatingMedia Positions:**

-   `EmbedIOSSDK.FIXED_BOTTOM_LEFT` - Fixed at bottom left corner
-   `EmbedIOSSDK.FIXED_BOTTOM_RIGHT` - Fixed at bottom right corner
-   `EmbedIOSSDK.FIXED_TOP_LEFT` - Fixed at top left corner
-   `EmbedIOSSDK.FIXED_TOP_RIGHT` - Fixed at top right corner
-   `EmbedIOSSDK.FIXED_CENTER_LEFT` - Fixed at center left
-   `EmbedIOSSDK.FIXED_CENTER_RIGHT` - Fixed at center right

**Note:** Fixed positions are only for FloatingMedia widgets. The SDK automatically filters widgets based on the `floatingMediaPosition` field when using fixed positions.

### Fixed Position Widgets Example

For fixed position widgets (FloatingMedia), you can overlay them on your content:

```swift
struct ProductPageView: View {
    @State private var pageUrl: String = "https://your-domain.com/product/12345"
    @State private var showFixedWidget: Bool = true
    @State private var hasContent: Bool = false

    var body: some View {
        ZStack {
            // Your main content
            ScrollView {
                // ... your content
            }

            // Fixed position widget overlay
            if showFixedWidget {
                VStack {
                    Spacer()
                    HStack {
                        FixedFloatingMediaWidgetView(
                            pageUrl: pageUrl,
                            position: EmbedIOSSDK.FIXED_BOTTOM_LEFT,
                            hasContent: $hasContent
                        )
                        Spacer()
                    }
                    .padding(.leading, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }
}
```

### Parameters

-   **`pageUrl`** (String, required): The URL of the page where the widget is displayed. The SDK will automatically extract the product ID from this URL.
-   **`position`** (EmbedIOSSDK.Position, required): The position where the widget should be displayed. See Position Enum above for available values.

### Advanced Usage

The SDK uses a shared data manager to cache widget data and avoid multiple API calls for the same page URL. All `EmbedWidgetView` instances with the same `pageUrl` will share the same cached data.

To clear the cache manually:

```swift
EmbedWidgetDataManager.shared.clearCache(for: pageUrl) // Clear specific page
EmbedWidgetDataManager.shared.clearCache() // Clear all cache
```

## License

MIT License - see LICENSE file for details

## Support

For support, please contact: wayne.zhang@tagnology.co
