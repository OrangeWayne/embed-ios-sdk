// EmbedViews.swift
import SwiftUI
import WebKit

// MARK: - View Modifiers
private struct InteractiveDismissModifierCompat: ViewModifier {
    let isDisabled: Bool
    
    func body(content: Content) -> some View {
        if #available(iOS 15.0, *) {
            content.interactiveDismissDisabled(isDisabled)
        } else {
            content
        }
    }
}

extension View {
    fileprivate func interactiveDismissDisabledCompat(_ disabled: Bool) -> some View {
        self.modifier(InteractiveDismissModifierCompat(isDisabled: disabled))
    }
}

// MARK: - Bridge constants
enum EmbedBridge {
    static let resizeHandlerName = "tagnologyResize"
    static let eventHandlerName = "tagnologyEvent"
    static let eventTypeKey = "eventType"
    static let bridgeInjectionFlag = "__tagnologyNativeBridgeInjected"
    static let hitTestHandlerName = "tagnologyHitTest"
}

// MARK: - Overlay Window (click-through with smart detection)
final class PassthroughWindow: UIWindow {
    var clickableRects: [CGRect] = []
    var hasClickableContent: Bool = false
    
    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // 如果有可點擊內容，檢查是否在區域內
        if hasClickableContent && !clickableRects.isEmpty {
            for rect in clickableRects {
                if rect.contains(point) {
                    return super.hitTest(point, with: event)
                }
            }
        }
        
        // 不在可點擊區域內，穿透到下層
        return nil
    }
}

final class FloatingOverlayManager {
    static let shared = FloatingOverlayManager()
    private var window: PassthroughWindow?
    private var hostingController: UIHostingController<AnyView>?
    private var currentOwnerId: String?
    weak var webView: WKWebView?  // 保存 WebView 引用用於座標轉換
    private var lastRects: [CGRect] = []  // 緩存上次的 rects，避免重複更新

    func showOverlay<V: View>(ownerId: String, view: V) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) else { return }

        if window == nil {
            let newWindow = PassthroughWindow(windowScene: windowScene)
            newWindow.backgroundColor = .clear
            newWindow.windowLevel = .statusBar + 1
            window = newWindow
        }
        let controller = UIHostingController(rootView: AnyView(view))
        controller.view.backgroundColor = .clear
        hostingController = controller
        window?.rootViewController = controller
        window?.isHidden = false
        currentOwnerId = ownerId
    }

    func hideOverlay(ownerId: String) {
        guard currentOwnerId == ownerId else { return }
        window?.isHidden = true
        window?.rootViewController = nil
        hostingController = nil
        currentOwnerId = nil
        webView = nil
    }
    
    func updateClickableRectFromResizeEvent(property: [String: Any]?) {
        guard let window = window else {
            return
        }
        
        guard let property = property else {
            return
        }
        
        // 使用完整的 window bounds，不包含安全區域
        let windowBounds = window.bounds
        
        // 提取所有相關屬性
        let widthRaw = property["width"]
        let heightRaw = property["height"]
        let rightRaw = property["right"]
        let bottomRaw = property["bottom"]
        let leftRaw = property["left"]
        let topRaw = property["top"]
        
        // 檢查是否為全螢幕狀態：width = 100dvw, height = 100dvh, top = 0, left = 0
        let isFullscreen = checkIfFullscreen(
            width: widthRaw,
            height: heightRaw,
            left: leftRaw,
            top: topRaw,
            windowBounds: windowBounds
        )
        
        if isFullscreen {
            // 全螢幕狀態：將整個 window 設為可點擊區域
            let rect = windowBounds
            
            // 只有當 rect 真正改變時才更新
            let hasChanged: Bool
            if lastRects.count != 1 {
                hasChanged = true
            } else if let lastRect = lastRects.first {
                let dx = abs(lastRect.origin.x - rect.origin.x)
                let dy = abs(lastRect.origin.y - rect.origin.y)
                let dw = abs(lastRect.width - rect.width)
                let dh = abs(lastRect.height - rect.height)
                hasChanged = dx > 1 || dy > 1 || dw > 1 || dh > 1
            } else {
                hasChanged = true
            }
            
            if hasChanged {
                window.clickableRects = [rect]
                window.hasClickableContent = true
                lastRects = [rect]
            }
            return
        }
        
        // 非全螢幕狀態：正常計算位置
        // 提取尺寸
        let width = extractPixelValue(from: widthRaw, windowBounds: windowBounds)
        let height = extractPixelValue(from: heightRaw, windowBounds: windowBounds)
        
        guard width > 0, height > 0 else {
            return
        }
        
        var x: CGFloat = 0
        var y: CGFloat = 0
        
        // 調整參數
        let horizontalPadding: CGFloat = 24.0  // left/right 各減少 24px（總共減少 48px）
        let verticalPadding: CGFloat = 18.0    // top/bottom 各增加 18px（總共增加 36px）
        
        // 計算 x 座標和調整寬度
        var adjustedX: CGFloat = 0
        var adjustedWidth: CGFloat = width
        
        if let right = rightRaw as? String, right != "auto" {
            let rightValue = extractPixelValue(from: right, windowBounds: windowBounds)
            x = windowBounds.width - width - rightValue
            // 使用 right 定位時：向右移動 12px，寬度減少 24px
            adjustedX = x + horizontalPadding
            adjustedWidth = max(0, width - horizontalPadding * 2)
        } else if let right = rightRaw as? NSNumber {
            let rightValue = CGFloat(truncating: right)
            x = windowBounds.width - width - rightValue
            // 使用 right 定位時：向右移動 12px，寬度減少 24px
            adjustedX = x + horizontalPadding
            adjustedWidth = max(0, width - horizontalPadding * 2)
        } else if let left = leftRaw as? String, left != "auto" {
            x = extractPixelValue(from: left, windowBounds: windowBounds)
            // 使用 left 定位時：向右移動 12px，寬度減少 24px
            adjustedX = x + horizontalPadding
            adjustedWidth = max(0, width - horizontalPadding * 2)
        } else if let left = leftRaw as? NSNumber {
            x = CGFloat(truncating: left)
            // 使用 left 定位時：向右移動 12px，寬度減少 24px
            adjustedX = x + horizontalPadding
            adjustedWidth = max(0, width - horizontalPadding * 2)
        } else {
            // 預設居中：左右各減少 12px
            x = (windowBounds.width - width) / 2
            adjustedX = x + horizontalPadding
            adjustedWidth = max(0, width - horizontalPadding * 2)
        }
        
        // 計算 y 座標和調整高度
        var adjustedY: CGFloat = 0
        var adjustedHeight: CGFloat = height
        
        if let bottom = bottomRaw as? String, bottom != "auto" {
            let bottomValue = extractPixelValue(from: bottom, windowBounds: windowBounds)
            y = windowBounds.height - height - bottomValue
            // 使用 bottom 定位時：向上移動 12px，高度增加 24px
            adjustedY = max(0, y - verticalPadding)
            adjustedHeight = height + verticalPadding * 2
        } else if let bottom = bottomRaw as? NSNumber {
            let bottomValue = CGFloat(truncating: bottom)
            y = windowBounds.height - height - bottomValue
            // 使用 bottom 定位時：向上移動 12px，高度增加 24px
            adjustedY = max(0, y - verticalPadding)
            adjustedHeight = height + verticalPadding * 2
        } else if let top = topRaw as? String, top != "auto" {
            y = extractPixelValue(from: top, windowBounds: windowBounds)
            // 使用 top 定位時：向上移動 12px，高度增加 24px
            adjustedY = max(0, y - verticalPadding)
            adjustedHeight = height + verticalPadding * 2
        } else if let top = topRaw as? NSNumber {
            y = CGFloat(truncating: top)
            // 使用 top 定位時：向上移動 12px，高度增加 24px
            adjustedY = max(0, y - verticalPadding)
            adjustedHeight = height + verticalPadding * 2
        } else {
            // 預設居中：上下各增加 12px
            y = (windowBounds.height - height) / 2
            adjustedY = max(0, y - verticalPadding)
            adjustedHeight = height + verticalPadding * 2
        }
        
        // 確保不會超出 window 邊界
        if adjustedX < 0 {
            adjustedX = 0
        }
        if adjustedX + adjustedWidth > windowBounds.width {
            adjustedWidth = windowBounds.width - adjustedX
        }
        if adjustedY + adjustedHeight > windowBounds.height {
            adjustedHeight = windowBounds.height - adjustedY
        }
        
        let rect = CGRect(x: adjustedX, y: adjustedY, width: adjustedWidth, height: adjustedHeight)
        
        // 只有當 rect 真正改變時才更新
        let hasChanged: Bool
        if lastRects.count != 1 {
            hasChanged = true
        } else if let lastRect = lastRects.first {
            // 允許 1 像素的誤差（避免浮點數精度問題）
            let dx = abs(lastRect.origin.x - rect.origin.x)
            let dy = abs(lastRect.origin.y - rect.origin.y)
            let dw = abs(lastRect.width - rect.width)
            let dh = abs(lastRect.height - rect.height)
            hasChanged = dx > 1 || dy > 1 || dw > 1 || dh > 1
        } else {
            hasChanged = true
        }
        
        if hasChanged {
            window.clickableRects = [rect]
            window.hasClickableContent = true
            lastRects = [rect]
        }
    }
    
    private func checkIfFullscreen(width: Any?, height: Any?, left: Any?, top: Any?, windowBounds: CGRect) -> Bool {
        // 檢查是否為全螢幕：width = 100dvw, height = 100dvh, top = 0, left = 0
        let widthStr = (width as? String)?.lowercased() ?? ""
        let heightStr = (height as? String)?.lowercased() ?? ""
        let leftStr = (left as? String)?.lowercased() ?? ""
        let topStr = (top as? String)?.lowercased() ?? ""
        
        let isFullscreenWidth = widthStr == "100dvw" || widthStr == "100vw" || 
                               (widthStr.contains("100") && (widthStr.contains("vw") || widthStr.contains("dvw")))
        let isFullscreenHeight = heightStr == "100dvh" || heightStr == "100vh" ||
                                (heightStr.contains("100") && (heightStr.contains("vh") || heightStr.contains("dvh")))
        let isLeftZero = leftStr == "0" || leftStr == "0px" || (left as? NSNumber)?.doubleValue == 0
        let isTopZero = topStr == "0" || topStr == "0px" || (top as? NSNumber)?.doubleValue == 0
        
        return isFullscreenWidth && isFullscreenHeight && isLeftZero && isTopZero
    }
    
    private func extractPixelValue(from value: Any?, windowBounds: CGRect? = nil) -> CGFloat {
        guard let value = value else {
            return 0
        }
        
        if let number = value as? NSNumber {
            return CGFloat(truncating: number)
        }
        
        if let string = value as? String {
            let lowercased = string.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 處理視口單位：100dvw, 100vw, 100dvh, 100vh
            if lowercased.contains("dvw") || lowercased.contains("vw") {
                let cleaned = lowercased.replacingOccurrences(of: "dvw", with: "")
                    .replacingOccurrences(of: "vw", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let percent = Double(cleaned), let bounds = windowBounds {
                    return bounds.width * CGFloat(percent) / 100.0
                }
            }
            
            if lowercased.contains("dvh") || lowercased.contains("vh") {
                let cleaned = lowercased.replacingOccurrences(of: "dvh", with: "")
                    .replacingOccurrences(of: "vh", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let percent = Double(cleaned), let bounds = windowBounds {
                    return bounds.height * CGFloat(percent) / 100.0
                }
            }
            
            // 移除 "px" 後綴並轉換為數字
            let cleaned = string.replacingOccurrences(of: "px", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let doubleValue = Double(cleaned) {
                return CGFloat(doubleValue)
            }
        }
        
        return 0
    }
    
    func updateClickableRects(_ rects: [CGRect], webView: WKWebView?) {
        // 在 floating mode 下，我們使用 resize event 來更新位置，忽略 JavaScript 的自動更新
        // 因為 JavaScript 的 getBoundingClientRect() 對於 fixed 元素可能不準確
        // 此函數僅用於記錄，實際位置更新由 updateClickableRectFromResizeEvent 處理
    }
}

// MARK: - Position Enum
/**
 * @enum EmbedPosition
 * @description Defines the position where the embed widget should be displayed on the page.
 */
public enum EmbedPosition: String, Codable {
    case BELOW_BUY_BUTTON = "BELOW_BUY_BUTTON"
    case BELOW_MAIN_PRODUCT_INFO = "BELOW_MAIN_PRODUCT_INFO"
    case ABOVE_RECOMMENDATION = "ABOVE_RECOMMENDATION"
    case ABOVE_FILTER = "ABOVE_FILTER"
}

// MARK: - SDK Namespace
/**
 * @enum EmbedIOSSDK
 * @description Main namespace for EmbedIOSSDK, providing convenient access to SDK types and constants.
 */
public enum EmbedIOSSDK {
    /// Position enum for embed widget placement
    public typealias Position = EmbedPosition
    
    /// Convenience access to position values
    public static let BELOW_BUY_BUTTON = EmbedPosition.BELOW_BUY_BUTTON
    public static let BELOW_MAIN_PRODUCT_INFO = EmbedPosition.BELOW_MAIN_PRODUCT_INFO
    public static let ABOVE_RECOMMENDATION = EmbedPosition.ABOVE_RECOMMENDATION
    public static let ABOVE_FILTER = EmbedPosition.ABOVE_FILTER
}

// MARK: - API
/**
 * @class EmbedAPI
 * @description Handles API calls to fetch embed widget information from the server.
 */
public enum EmbedAPI {
    /// 預設平台識別碼
    public static let defaultPlatform = "91APP"
    
    /**
     * @function extractProductIdFromPageUrl
     * @description Extracts product ID from page URL based on the URL path pattern.
     *              Matches the logic from JavaScript getProductId() function.
     *
     * @param {String} pageUrl - The page URL to extract product ID from.
     *
     * @returns {String?} The extracted product ID, or nil if not found.
     */
    public static func extractProductIdFromPageUrl(_ pageUrl: String) -> String? {
        guard let url = URL(string: pageUrl) else {
            return nil
        }
        
        let pathname = url.path.lowercased()
        let pathComponents = pathname.components(separatedBy: "/").filter { !$0.isEmpty }
        
        if pathname.contains("/salepage/") {
            // 對於 SalePage，返回最後一個路徑組件
            // 注意：在 Swift 中無法從 DOM 獲取，所以直接使用路徑的最後部分
            return pathComponents.last
        } else if pathname.contains("/salepagecategory/") {
            // 對於 SalePageCategory，返回 category_${最後一個部分}
            if let lastComponent = pathComponents.last {
                return "category_\(lastComponent)"
            }
        } else if pathname.contains("/detail/") {
            // 對於 Detail，返回 detail_${最後一個部分}
            if let lastComponent = pathComponents.last {
                return "detail_\(lastComponent)"
            }
        }
        
        return nil
    }
    /**
     * @struct PageInfoResponse
     * @description Response structure from the getPageInfo API endpoint.
     */
    public struct PageInfoResponse: Codable {
        public let message: String
        public let pageInfo: [EmbedFolderInfo]
        
        public init(message: String, pageInfo: [EmbedFolderInfo]) {
            self.message = message
            self.pageInfo = pageInfo
        }
    }
    
    /**
     * @function fetchPageInfo
     * @description Fetches page information including embed widgets from the server.
     *
     * @param {String} productId - The product ID to fetch information for.
     * @param {String} platform - The platform identifier (e.g., "91APP").
     * @param {String} pageUrl - The page URL where the widget is displayed.
     *
     * @returns {PageInfoResponse} The response containing page information and embed widgets.
     * @throws {URLError} If the URL is invalid or the request fails.
     */
    public static func fetchPageInfo(productId: String, platform: String, pageUrl: String) async throws -> PageInfoResponse {
        guard let url = URL(string: "https://embed.tagnology.co/api/product/getPageInfo") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "productId": productId,
            "platform": platform,
            "page": pageUrl
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(PageInfoResponse.self, from: data)
        return decoded
    }
    
    /**
     * @function fetchPageInfoForPosition
     * @description Fetches page information and filters widgets by the specified position.
     *
     * @param {String} pageUrl - The page URL where the widget is displayed.
     * @param {EmbedPosition} position - The position where the widget should be displayed.
     * @param {String} productId - Optional product ID. If not provided, will be extracted from pageUrl if possible.
     * @param {String} platform - Optional platform identifier. Defaults to "91APP" if not provided.
     *
     * @returns {[EmbedFolderInfo]} Array of embed folder information matching the specified position, or empty array if none found.
     * @throws {URLError} If the URL is invalid or the request fails.
     */
    public static func fetchPageInfoForPosition(
        pageUrl: String,
        position: EmbedPosition,
        productId: String? = nil,
        platform: String = EmbedAPI.defaultPlatform
    ) async throws -> [EmbedFolderInfo] {
        // 嘗試從 pageUrl 提取 productId（如果未提供）
        let finalProductId: String
        if let productId = productId {
            finalProductId = productId
        } else {
            // 使用 extractProductIdFromPageUrl 函數提取 productId
            finalProductId = EmbedAPI.extractProductIdFromPageUrl(pageUrl) ?? ""
        }
        
        let response = try await fetchPageInfo(
            productId: finalProductId,
            platform: platform,
            pageUrl: pageUrl
        )
        
        // 根據 position 過濾 widgets
        let positionString = position.rawValue
        let filteredWidgets = response.pageInfo.filter { folderInfo in
            // 檢查 embedLocation 是否匹配 position
            if let embedLocation = folderInfo.embedLocation {
                let embedLocationUpper = embedLocation.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let positionStringTrimmed = positionString.trimmingCharacters(in: .whitespacesAndNewlines)
                return embedLocationUpper == positionStringTrimmed
            }
            return false
        }
        
        // 對過濾後的 widgets 進行排序：按照 timestamp 降序（較新的先顯示）
        // 如果沒有 timestamp，則保持原順序（放在最後）
        let sortedWidgets = filteredWidgets.sorted { folderInfo1, folderInfo2 in
            let timestamp1 = folderInfo1.timestamp ?? 0
            let timestamp2 = folderInfo2.timestamp ?? 0
            // 降序排序：timestamp 較大的（較新的）先顯示
            return timestamp1 > timestamp2
        }
        
        return sortedWidgets
    }
}

// MARK: - Models
public struct EmbedFolderInfo: Identifiable, Codable, Hashable {
    public let folderId: String
    public let productId: String?
    public let platform: String?
    public let productName: String?
    public let productUrl: String?
    public let productImage: String?
    public let embedLocation: String?
    public let timestamp: Int?
    public let folderName: String?
    public let layout: String?

    public var id: String { folderId }
    
    public init(folderId: String, productId: String? = nil, platform: String? = nil, productName: String? = nil, productUrl: String? = nil, productImage: String? = nil, embedLocation: String? = nil, timestamp: Int? = nil, folderName: String? = nil, layout: String? = nil) {
        self.folderId = folderId
        self.productId = productId
        self.platform = platform
        self.productName = productName
        self.productUrl = productUrl
        self.productImage = productImage
        self.embedLocation = embedLocation
        self.timestamp = timestamp
        self.folderName = folderName
        self.layout = layout
    }
}

// MARK: - EmbedWidgetView (SwiftUI - Auto-loading by position)
/**
 * @struct EmbedWidgetView
 * @description A SwiftUI view that automatically loads and displays embed widgets based on page URL and position.
 *              This view handles API calls internally and only displays widgets when data is available.
 */
public struct EmbedWidgetView: View {
    private let pageUrl: String
    private let position: EmbedPosition
    private let productId: String?
    private let platform: String
    
    @State private var folderInfos: [EmbedFolderInfo] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var hasStartedLoading: Bool = false
    
    /**
     * @function init
     * @description Initializes EmbedWidgetView with page URL and position.
     *              Product ID will be automatically extracted from pageUrl, and platform defaults to "91APP".
     *
     * @param {String} pageUrl - The page URL where the widget is displayed.
     * @param {EmbedPosition} position - The position where the widget should be displayed.
     *
     * @returns {EmbedWidgetView} A new EmbedWidgetView instance.
     */
    public init(
        pageUrl: String,
        position: EmbedPosition
    ) {
        self.pageUrl = pageUrl
        self.position = position
        // 自動從 pageUrl 提取 productId（使用與 JavaScript getProductId() 相同的邏輯）
        self.productId = EmbedAPI.extractProductIdFromPageUrl(pageUrl)
        // 使用預設平台
        self.platform = EmbedAPI.defaultPlatform
        
        // 在 init 完成後立即開始載入 widgets（不等待 onAppear）
        let productIdToLoad = self.productId
        let platformToLoad = self.platform
        let pageUrlToLoad = self.pageUrl
        let positionToLoad = self.position
        
        // 同時進行 log 和載入
        Task {
            // 先進行 log
            await EmbedWidgetView.fetchAndLogPageInfo(
                productId: productIdToLoad,
                platform: platformToLoad,
                pageUrl: pageUrlToLoad,
                position: positionToLoad
            )
        }
        
        // 立即開始載入 widgets（使用延遲執行來避免在 init 中直接修改 @State）
        // 注意：在 init 中無法直接修改 @State，所以我們在 body 第一次計算時觸發載入
    }
    
    /**
     * @function fetchAndLogPageInfo
     * @description 呼叫 getPageInfo API 並將相關資訊 log 出來，並標註哪些 widget 會根據 embedLocation 被顯示
     *
     * @param {String?} productId - 產品 ID
     * @param {String} platform - 平台識別碼
     * @param {String} pageUrl - 頁面 URL
     * @param {EmbedPosition} position - 要顯示的 widget 位置
     */
    private static func fetchAndLogPageInfo(
        productId: String?,
        platform: String,
        pageUrl: String,
        position: EmbedPosition
    ) async {
        guard let productId = productId else {
            return
        }
        
        do {
            let response = try await EmbedAPI.fetchPageInfo(
                productId: productId,
                platform: platform,
                pageUrl: pageUrl
            )
            
            // 根據 position 過濾 widgets
            let positionString = position.rawValue
            let filteredWidgets = response.pageInfo.filter { folderInfo in
                if let embedLocation = folderInfo.embedLocation {
                    let embedLocationUpper = embedLocation.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    let positionStringTrimmed = positionString.trimmingCharacters(in: .whitespacesAndNewlines)
                    return embedLocationUpper == positionStringTrimmed
                }
                return false
            }
            
            // 只顯示需要顯示的 widgets 資訊
            if !filteredWidgets.isEmpty {
                for folderInfo in filteredWidgets {
                    print("position: \(positionString)")
                    print("folderId: \(folderInfo.folderId)")
                    print("folderName: \(folderInfo.folderName ?? "nil")")
                    print("layout: \(folderInfo.layout ?? "nil")")
                    print("---")
                }
            }
        } catch {
            // 錯誤時不輸出 log
        }
    }
    
    public var body: some View {
        // 在 body 第一次計算時就開始載入（不等待 onAppear，確保即使不在可見區域也會載入）
        if !hasStartedLoading {
            DispatchQueue.main.async {
                if !self.hasStartedLoading {
                    self.hasStartedLoading = true
                    Task {
                        await self.loadWidgets()
                    }
                }
            }
        }
        
        return Group {
            if isLoading {
                // 載入中時不顯示任何內容（或可選擇顯示載入指示器）
                EmptyView()
            } else if errorMessage != nil {
                // 錯誤時不顯示任何內容（或可選擇顯示錯誤訊息）
                EmptyView()
            } else if folderInfos.isEmpty {
                // 沒有資料時不顯示
                EmptyView()
            } else {
                // 有資料時顯示所有匹配的 widgets（依序垂直排列）
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(folderInfos, id: \.folderId) { folderInfo in
                        EmbedView(folderInfo: folderInfo, pageUrl: pageUrl)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    /**
     * @function loadWidgets
     * @description Loads widgets from the API based on the specified position.
     */
    private func loadWidgets() async {
        // 使用 MainActor 確保狀態檢查和設置是原子操作
        let shouldLoad = await MainActor.run {
            if self.isLoading {
                return false
            }
            if self.hasStartedLoading && !self.folderInfos.isEmpty {
                return false
            }
            // 設置載入狀態
            self.isLoading = true
            self.errorMessage = nil
            return true
        }
        
        guard shouldLoad else {
            return
        }
        
        do {
            let widgets = try await EmbedAPI.fetchPageInfoForPosition(
                pageUrl: pageUrl,
                position: position,
                productId: productId,
                platform: platform
            )
            
            await MainActor.run {
                self.folderInfos = widgets
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

// MARK: - EmbedView (SwiftUI)
public struct EmbedView: View {
    private let folderInfo: EmbedFolderInfo
	private let pageUrl: String

    @State private var contentHeight: CGFloat = 0
    @State private var isLightboxPresented = false
    @State private var pendingLightboxMessageJSON: String?
    // 當 widget property position == fixed 時切換為 true，整個 WebView 會變成 fullscreen fixed
    @State private var isFullscreenFixed = false
    @State private var hasInstalledFloatingOverlay = false

    private var lightboxURL: URL {
        EmbedHTMLBuilder.lightBoxURL(pageUrl: pageUrl)
    }

    /**
     * @function init
     * @description Initializes EmbedView with folder information and page URL.
     *
     * @param {EmbedFolderInfo} folderInfo - The folder information for the embed widget.
     * @param {String} pageUrl - The page URL where the widget is displayed.
     *
     * @returns {EmbedView} A new EmbedView instance.
     */
    public init(folderInfo: EmbedFolderInfo, pageUrl: String) {
        self.folderInfo = folderInfo
        self.pageUrl = pageUrl
    }

    public var body: some View {
        Group {
            if (folderInfo.layout?.lowercased() == "floatingmedia") {
                Color.clear
                    .frame(height: 0.1)
                    .onAppear { 
                        installFloatingOverlay() 
                    }
                    .onDisappear { 
                        uninstallFloatingOverlay() 
                    }
            } else {
                ZStack {
                    EmbedWebView(
                        folderId: folderInfo.folderId,
                        pageUrl: pageUrl,
                        contentHeight: $contentHeight,
                        onEvent: handleEmbedEvent,
                        isFloatingMode: false
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: isFullscreenFixed ? UIScreen.main.bounds.height : max(contentHeight, 60))
                    .background(Color.clear)
                    .ignoresSafeArea(edges: isFullscreenFixed ? .all : .init())
                    .interactiveDismissDisabledCompat(isFullscreenFixed)
                    .zIndex(isFullscreenFixed ? 1 : 0)
                }
            }
        }
        // Lightbox（fullscreen）
        .fullScreenCover(isPresented: $isLightboxPresented) {
            LightboxWebView(
                url: lightboxURL,
                messageJSON: $pendingLightboxMessageJSON,
                onEvent: handleEmbedEvent
            )
            .background(Color.black.opacity(0.85))
            .ignoresSafeArea()
        }
    }

    private func installFloatingOverlay() {
        guard !hasInstalledFloatingOverlay else { return }
        let overlay = ZStack {
            Color.clear
                .ignoresSafeArea()
                .allowsHitTesting(false)
            // 右下角定位的浮動媒體 iframe（實際固定由內部 CSS: position: fixed; bottom/right）
            EmbedWebView(
                folderId: folderInfo.folderId,
                pageUrl: pageUrl,
                contentHeight: $contentHeight,
                onEvent: handleEmbedEvent,
                isFloatingMode: true
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear)
            .ignoresSafeArea()
            .allowsHitTesting(true)  // 改為 true，讓 WebView 可以接收點擊
        }
        FloatingOverlayManager.shared.showOverlay(ownerId: folderInfo.folderId, view: overlay)
        hasInstalledFloatingOverlay = true
    }

    private func uninstallFloatingOverlay() {
        if hasInstalledFloatingOverlay {
            FloatingOverlayManager.shared.hideOverlay(ownerId: folderInfo.folderId)
            hasInstalledFloatingOverlay = false
        }
    }

    // MARK: - Event handler
    private func handleEmbedEvent(_ event: EmbedWebView.EmbedEvent) {
        switch event.type {
        case "resize":
            handleResizeEventPayload(event.payload)
        case "click":
            guard let item = event.payload["data"] as? [String: Any] else {
                return
            }
            let disabled = (item["disabledLightBox"] as? Bool) ?? false
            if disabled {
                return
            }
            let messagePayload: [String: Any] = [
                "eventType": "click",
                "item": item
            ]
            guard JSONSerialization.isValidJSONObject(messagePayload),
                  let jsonData = try? JSONSerialization.data(withJSONObject: messagePayload),
                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                return
            }
            pendingLightboxMessageJSON = jsonString
            handleLightboxToggle(true)
        case "toggleLB":
            let openValue = event.payload["open"]
            let shouldOpen: Bool? = {
                switch openValue {
                case let bool as Bool:
                    return bool
                case let number as NSNumber:
                    return number.boolValue
                case let string as String:
                    let lowered = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if ["true", "1", "yes"].contains(lowered) { return true }
                    if ["false", "0", "no"].contains(lowered) { return false }
                    return nil
                default:
                    return nil
                }
            }()

            guard let open = shouldOpen else {
                return
            }
            handleLightboxToggle(open)
            if !open {
                pendingLightboxMessageJSON = nil
            }
        default:
            break
        }
    }

    // MARK: - lightbox
    private func handleLightboxToggle(_ shouldOpen: Bool) {
        isLightboxPresented = shouldOpen
        if !shouldOpen {
            pendingLightboxMessageJSON = nil
        }
    }

    // MARK: - resize handling (保留原始邏輯，並加入 fixed detection)
    private func handleResizeEventPayload(_ payload: [String: Any]) {
        let property = payload["property"] as? [String: Any]
        let rawHeightFromProperty = extractRawHeightString(from: property)
        let shouldDefer = shouldDeferHeightSync(rawHeightFromProperty, property: property)
        let resolvedHeight = extractNumericHeight(from: payload, property: property)

        if hasInstalledFloatingOverlay {
            // 在 floating overlay 模式下，使用 property 來更新可點擊區域
            // 如果 property 為 nil，這是正常的（例如某些 resize event 可能不包含 property）
            // 我們只在有 property 時才更新，避免不必要的警告
            if let property = property {
                FloatingOverlayManager.shared.updateClickableRectFromResizeEvent(property: property)
            }
            // 注意：property 為 nil 時不更新是正常的，不需要警告
        } 

        // 如果 widget 指定 position: fixed，切換為 fullscreen fixed（避免被外層壓扁）
        if let position = property?["position"] as? String, position.lowercased() == "fixed" {
            // 切到 fullscreen
            isFullscreenFixed = true
        } else {
            // 如果沒有 fixed，並且目前是 fullscreen（先前某個元素是 fixed），我們可以選擇自動關閉 fullscreen
            // 視需求決定是否要自動還原；這裡採用：若 property 沒有 position=fixed，維持原狀（不自動還原）
            // 若你想自動還原，將下面註解打開：
            // isFullscreenFixed = false
        }

        if shouldDefer {
            let fallbackHeight = resolvedHeight ?? UIScreen.main.bounds.height
            if fallbackHeight > 0 {
                contentHeight = max(contentHeight, fallbackHeight)
            }
            return
        }

        if let height = resolvedHeight {
            contentHeight = height
        }
    }

    // MARK: - helpers (same as original)
    private func extractNumericHeight(from payload: [String: Any], property: [String: Any]?) -> CGFloat? {
        var candidates: [Any?] = []
        candidates.append(payload["height"])
        if let size = payload["size"] as? [String: Any] {
            candidates.append(size["height"])
        }
        if let data = payload["data"] as? [String: Any] {
            candidates.append(data["height"])
        }
        if let property {
            let propertyKeys = ["height", "minHeight", "maxHeight", "--height", "--tagnology-height"]
            for key in propertyKeys {
                candidates.append(property[key])
            }
        }

        for candidate in candidates {
            if let height = normalizeHeightValue(candidate) {
                return height
            }
        }
        return nil
    }

    private func extractRawHeightString(from property: [String: Any]?) -> String? {
        guard let property else { return nil }
        let keys = ["height", "minHeight", "maxHeight", "--height", "--tagnology-height"]
        for key in keys {
            if let stringValue = property[key] as? String {
                return stringValue
            }
        }
        return nil
    }

    private func shouldDeferHeightSync(_ rawHeight: String?, property: [String: Any]?) -> Bool {
        if let position = property?["position"] as? String, position.lowercased() == "fixed" {
            return true
        }
        guard let rawHeight else {
            return false
        }
        let unitCharacterSet = CharacterSet.letters.union(CharacterSet(charactersIn: "%"))
        return rawHeight.rangeOfCharacter(from: unitCharacterSet) != nil
    }

    private func normalizeHeightValue(_ value: Any?) -> CGFloat? {
        switch value {
        case let number as NSNumber:
            return CGFloat(truncating: number)
        case let string as String:
            let allowedCharacters = CharacterSet(charactersIn: "0123456789.-")
            let sanitized = string.unicodeScalars.filter { allowedCharacters.contains($0) }
            guard let numericValue = Double(String(String.UnicodeScalarView(sanitized))) else {
                return nil
            }
            return CGFloat(numericValue)
        default:
            return nil
        }
    }
}

// MARK: - EmbedWebView (UIViewRepresentable)
struct EmbedWebView: UIViewRepresentable {
    let folderId: String
    let pageUrl: String
    @Binding var contentHeight: CGFloat
    let onEvent: (EmbedEvent) -> Void
    let isFloatingMode: Bool

    struct EmbedEvent {
        let type: String
        let payload: [String: Any]
        let jsonString: String
    }

    static func makeEvent(from body: Any) -> EmbedEvent? {
        guard let payload = body as? [String: Any],
              let eventType = payload[EmbedBridge.eventTypeKey] as? String,
              JSONSerialization.isValidJSONObject(payload),
              let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }
        return EmbedEvent(type: eventType, payload: payload, jsonString: jsonString)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self, onEvent: onEvent, isFloatingMode: isFloatingMode)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.preferences.javaScriptEnabled = true
        configuration.allowsInlineMediaPlayback = true
        if #available(iOS 10.0, *) {
            configuration.mediaTypesRequiringUserActionForPlayback = []
        } else {
            configuration.requiresUserActionForMediaPlayback = false
        }
        configuration.userContentController.add(context.coordinator, name: EmbedBridge.resizeHandlerName)
        configuration.userContentController.add(context.coordinator, name: EmbedBridge.eventHandlerName)
        
        // 如果是 floating 模式，添加 hitTest handler 和注入腳本
        if isFloatingMode {
            configuration.userContentController.add(context.coordinator, name: EmbedBridge.hitTestHandlerName)
            
            let hitTestScript = """
            (function() {
                let lastRectsString = '';
                let updateTimer = null;
                
                function rectsToString(rects) {
                    return JSON.stringify(rects.map(r => [r.x, r.y, r.width, r.height]));
                }
                
                function updateClickableRegions() {
                    const rects = [];
                    const viewportWidth = window.innerWidth || document.documentElement.clientWidth;
                    const viewportHeight = window.innerHeight || document.documentElement.clientHeight;
                    
                    // 方案 1: 偵測所有 iframe（主要目標）
                    const iframes = document.querySelectorAll('iframe');
                    iframes.forEach(iframe => {
                        const rect = iframe.getBoundingClientRect();
                        if (rect.width > 0 && rect.height > 0) {
                            // 對於 fixed 元素，getBoundingClientRect() 直接返回視口座標
                            // 不需要額外計算，直接使用即可
                            const x = Math.round(rect.left);
                            const y = Math.round(rect.top);
                            
                            rects.push({
                                x: x,
                                y: y,
                                width: Math.round(rect.width),
                                height: Math.round(rect.height)
                            });
                            
                            console.log('[Embed][updateClickableRegions] iframe rect:', {
                                getBoundingClientRect: { left: rect.left, top: rect.top, width: rect.width, height: rect.height },
                                final: { x, y, width: rect.width, height: rect.height },
                                viewport: { width: viewportWidth, height: viewportHeight }
                            });
                        }
                    });
                    
                    // 方案 2: 偵測外層的可點擊元素（作為補充）
                    const clickableElements = document.querySelectorAll('a, button, [onclick], [role="button"], [role="link"], input, select, textarea, video, audio, [style*="cursor: pointer"], [style*="cursor:pointer"]');
                    clickableElements.forEach(element => {
                        const rect = element.getBoundingClientRect();
                        if (rect.width > 0 && rect.height > 0) {
                            rects.push({
                                x: Math.round(rect.left),
                                y: Math.round(rect.top),
                                width: Math.round(rect.width),
                                height: Math.round(rect.height)
                            });
                        }
                    });
                    
                    // 只有當 rects 真正改變時才發送
                    const currentRectsString = rectsToString(rects);
                    if (currentRectsString !== lastRectsString) {
                        lastRectsString = currentRectsString;
                        if (window.webkit?.messageHandlers?.tagnologyHitTest) {
                            window.webkit.messageHandlers.tagnologyHitTest.postMessage({ rects: rects });
                        }
                    }
                }
                
                // 防抖版本的更新函數
                function debouncedUpdate() {
                    if (updateTimer) {
                        clearTimeout(updateTimer);
                    }
                    updateTimer = setTimeout(updateClickableRegions, 200);
                }
                
                // 注意：在 floating mode 下，我們不使用 JavaScript 的自動更新
                // 因為 getBoundingClientRect() 對於 fixed 元素可能不準確
                // 位置更新由 resize event 的 property 來處理
                // 所以這裡不啟動初始更新、定期更新和 DOM 監聽
                
                // 導出函數供外部調用（但不會自動執行）
                window.updateClickableRegions = updateClickableRegions;
            })();
            """
            
            let userScript = WKUserScript(source: hitTestScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
            configuration.userContentController.addUserScript(userScript)
        }

        let webView = WKWebView(frame: .zero, configuration: configuration)
        // 若不允許 scroll，fixed 內部元素仍會相對於 viewport 定位（我們已 inject CSS workaround）
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        
        // 確保 WebView 可以接收用戶交互
        webView.isUserInteractionEnabled = true
        webView.allowsBackForwardNavigationGestures = false
        
        context.coordinator.webView = webView

        loadWidget(into: webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // no-op for now
    }

    private func loadWidget(into webView: WKWebView) {
        let htmlString = EmbedHTMLBuilder.buildHTML(folderId: folderId, pageUrl: pageUrl)
        webView.loadHTMLString(htmlString, baseURL: EmbedHTMLBuilder.assetBaseURL)
    }

    // MARK: - Coordinator
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        private var parent: EmbedWebView
        private let onEvent: (EmbedEvent) -> Void
        private let isFloatingMode: Bool
        weak var webView: WKWebView?

        init(parent: EmbedWebView, onEvent: @escaping (EmbedEvent) -> Void, isFloatingMode: Bool) {
            self.parent = parent
            self.onEvent = onEvent
            self.isFloatingMode = isFloatingMode
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case EmbedBridge.resizeHandlerName:
                guard var payload = message.body as? [String: Any] else { 
                    return 
                }
                let reportedHeight: CGFloat? = {
                    if let numericValue = payload["height"] as? NSNumber {
                        return CGFloat(truncating: numericValue)
                    }
                    return nil
                }()
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if let height = reportedHeight {
                        self.parent.contentHeight = height
                    }
                    payload[EmbedBridge.eventTypeKey] = payload[EmbedBridge.eventTypeKey] ?? "resize"
                    if let embedEvent = EmbedWebView.makeEvent(from: payload) {
                        self.onEvent(embedEvent)
                    }
                }
            case EmbedBridge.eventHandlerName:
                handleEventMessage(message.body)
            case EmbedBridge.hitTestHandlerName:
                handleHitTestMessage(message.body)
            default: break
            }
        }

        private func handleEventMessage(_ body: Any) {
            guard let embedEvent = EmbedWebView.makeEvent(from: body) else { return }
            DispatchQueue.main.async { [weak self] in
                self?.onEvent(embedEvent)
            }
        }
        
        private func handleHitTestMessage(_ body: Any) {
            guard isFloatingMode else {
                return
            }
            
            guard let payload = body as? [String: Any],
                  let rectsArray = payload["rects"] as? [[String: Any]] else {
                return
            }
            
            var clickableRects: [CGRect] = []
            for rectDict in rectsArray {
                if let x = rectDict["x"] as? Double,
                   let y = rectDict["y"] as? Double,
                   let width = rectDict["width"] as? Double,
                   let height = rectDict["height"] as? Double {
                    let rect = CGRect(x: x, y: y, width: width, height: height)
                    clickableRects.append(rect)
                }
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let webView = self?.webView else {
                    return
                }
                FloatingOverlayManager.shared.updateClickableRects(clickableRects, webView: webView)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // 初次載入時回報高度
            webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, _ in
                guard let self = self else { return }
                if let number = result as? NSNumber {
                    let height = CGFloat(truncating: number)
                    DispatchQueue.main.async {
                        self.parent.contentHeight = max(height, self.parent.contentHeight)
                    }
                }
            }
            
            // 注意：在 floating 模式，我們不使用 JavaScript 的 updateClickableRegions
            // 位置更新由 resize event 的 property 來處理
            // 所以這裡不需要主動觸發
        }
    }
}

// MARK: - LightboxWebView (UIViewRepresentable)
struct LightboxWebView: UIViewRepresentable {
    let url: URL
    @Binding var messageJSON: String?
    let onEvent: (EmbedWebView.EmbedEvent) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onEvent: onEvent) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptEnabled = true
        configuration.allowsInlineMediaPlayback = true
        if #available(iOS 10.0, *) {
            configuration.mediaTypesRequiringUserActionForPlayback = []
        } else {
            configuration.requiresUserActionForMediaPlayback = false
        }
        configuration.userContentController.add(context.coordinator, name: EmbedBridge.eventHandlerName)

        // 注入 bridge helper 至 Lightbox（同時支援 postMessage）
        let scriptSource = """
        (function() {
            if (window.\(EmbedBridge.bridgeInjectionFlag)) { return; }
            window.\(EmbedBridge.bridgeInjectionFlag) = true;

            const handlerName = '\(EmbedBridge.eventHandlerName)';
            const notifyNative = function(payload) {
                try {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[handlerName]) {
                        window.webkit.messageHandlers[handlerName].postMessage(payload);
                    }
                } catch (error) {
                    console.log('[LightboxBridge] notify native error', error);
                }
            };

            const originalPostMessage = window.postMessage;
            window.postMessage = function(message, targetOrigin, transfer) {
                notifyNative(message);
                if (typeof originalPostMessage === 'function') {
                    return originalPostMessage.call(this, message, targetOrigin, transfer);
                }
            };

            window.addEventListener('message', function(event) {
                if (event && event.data) {
                    notifyNative(event.data);
                }
            });
        })();
        """
        let userScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        configuration.userContentController.addUserScript(userScript)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear

        context.coordinator.webView = webView
        context.coordinator.pendingMessageJSON = messageJSON

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.pendingMessageJSON = messageJSON
        context.coordinator.flushPendingMessage()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        var pendingMessageJSON: String?
        private var isContentLoaded = false
        private let onEvent: (EmbedWebView.EmbedEvent) -> Void

        init(onEvent: @escaping (EmbedWebView.EmbedEvent) -> Void) {
            self.onEvent = onEvent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isContentLoaded = true
            flushPendingMessage()
        }

        func flushPendingMessage() {
            guard isContentLoaded,
                  let jsonString = pendingMessageJSON,
                  let webView else { return }

            // Dispatch MessageEvent into the lightbox page
            let script = """
            window.dispatchEvent(new MessageEvent('message', { data: \(jsonString), origin: '\(EmbedHTMLBuilder.origin)' }));
            """
            webView.evaluateJavaScript(script, completionHandler: nil)
            pendingMessageJSON = nil
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == EmbedBridge.eventHandlerName,
                  let embedEvent = EmbedWebView.makeEvent(from: message.body) else {
                return
            }
            DispatchQueue.main.async { [weak self] in
                self?.onEvent(embedEvent)
            }
        }
    }
}

// MARK: - EmbedHTMLBuilder (HTML + Safari 14 workaround)
enum EmbedHTMLBuilder {
    static let assetBaseURL = URL(string: "https://embed.tagnology.co")!
    
    /**
     * @function lightBoxURL
     * @description Generates the lightbox URL with the specified page URL.
     *
     * @param {String} pageUrl - The page URL to include in the lightbox query parameter.
     *
     * @returns {URL} The lightbox URL with the page parameter.
     */
    static func lightBoxURL(pageUrl: String) -> URL {
        return URL(string: "https://embed.tagnology.co/lightBox?page=\(pageUrl)")!
    }
    
    static let origin = "https://embed.tagnology.co"

    /**
     * @function buildHTML
     * @description Builds the HTML string for embedding the widget.
     *
     * @param {String} folderId - The folder ID for the embed widget.
     * @param {String} pageUrl - The page URL where the widget is displayed.
     *
     * @returns {String} The HTML string containing the embed iframe.
     */
    static func buildHTML(folderId: String, pageUrl: String) -> String {
        // 這裡注入 CSS 的重點是：解 Safari 14 iframe + position:fixed 的 bug
        // 並仍保留 JS 來解析 widget 傳來的 property，並把 property 套到 iframe.style
        return """
        <!DOCTYPE html>
        <html lang="zh-Hant">
        <head>
            <meta charset="utf-8" />
            <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1" />
            <style>
                /* 基本 reset */
                html, body {
                    margin: 0;
                    padding: 0;
                    background: transparent;
                    height: 100%;
                    width: 100%;
                    overflow: hidden;
                }

                /* SAFARI 14 WORKAROUND:
                   為了讓 iframe 內的 position: fixed 元素在 iOS14/Safari14 正常生效，
                   可以讓 iframe 自身在載入端以 fixed 方式呈現（或在需要時由 JS 設定）。
                   這裡使用 safe defaults：讓 iframe 可以被 JS 覆寫高度與 position。
                 */
                iframe {
                    border: 0;
                    width: 100vw !important;
                    height: 100vh !important;
                    position: fixed !important;
                    top: 0;
                    left: 0;
                    overflow: hidden;
                    -webkit-overflow-scrolling: touch; /* 若需要滾動，可改為 touch */
                    background: transparent;
                }
            </style>
        </head>
        <body>
            <iframe id="embed-frame" src="https://embed.tagnology.co/display?folderId=\(folderId)&page=\(pageUrl)" scrolling="no" frameborder="0" allow="fullscreen; autoplay; picture-in-picture" playsinline></iframe>
            <script>
            const frame = document.getElementById('embed-frame');

            function notifyNativeResize(height) {
                if (!height || Number.isNaN(Number(height))) {
                    return;
                }
                if (window.webkit?.messageHandlers?.tagnologyResize) {
                    window.webkit.messageHandlers.tagnologyResize.postMessage({ height: Number(height) });
                }
            }

            function applyFrameHeight(rawHeight) {
                if (!frame) { return null; }
                const parsedHeight = normalizeHeightValue(rawHeight);
                if (!parsedHeight) { return null; }
                frame.style.height = parsedHeight + 'px';
                return parsedHeight;
            }

            function normalizeHeightValue(value) {
                if (typeof value === 'number' && Number.isFinite(value)) {
                    return value;
                }
                if (typeof value === 'string') {
                    const sanitized = value.replace(/[^0-9.\\-]/g, '');
                    const numericValue = parseFloat(sanitized);
                    return Number.isNaN(numericValue) ? null : numericValue;
                }
                return null;
            }

            function extractHeightFromPayload(data) {
                if (!data) return null;
                const directCandidates = [
                    data.height,
                    data.size?.height,
                    data.data?.height
                ];
                const property = data.property || {};
                const propertyCandidates = [
                    property.height,
                    property.minHeight,
                    property.maxHeight,
                    property['--height'],
                    property['--tagnology-height']
                ];
                const candidate = [...directCandidates, ...propertyCandidates].find((item) => item !== undefined && item !== null);
                return normalizeHeightValue(candidate);
            }

            function getRawHeightFromProperty(property) {
                if (!property || typeof property !== 'object') return null;
                const propertyCandidates = [
                    property.height,
                    property.minHeight,
                    property.maxHeight,
                    property['--height'],
                    property['--tagnology-height']
                ];
                const candidate = propertyCandidates.find((v) => v !== undefined && v !== null);
                return typeof candidate === 'string' ? candidate : null;
            }

            function shouldDeferHeightSync(rawHeight, property) {
                if (property && String(property.position).toLowerCase() === 'fixed') return true;
                if (!rawHeight) return false;
                return /[a-z%]/i.test(rawHeight);
            }

            function notifyNativeEvent(payload) {
                if (!payload) return;
                if (window.webkit?.messageHandlers?.tagnologyEvent) {
                    window.webkit.messageHandlers.tagnologyEvent.postMessage(payload);
                }
            }

            function handleResizeEvent(data) {
                console.log('[Embed][handleResizeEvent]', data);
                const property = (data && typeof data === 'object') ? data.property : null;
                if (property && frame) {
                    Object.keys(property).forEach((key) => {
                        if (!Object.prototype.hasOwnProperty.call(property, key)) return;
                        const value = property[key];
                        if (value === undefined || value === null) return;
                        // 套用到 iframe 上（frame.style）
                        frame.style.setProperty(String(key), String(value), 'important');
                    });
                }

                const rawPropertyHeight = getRawHeightFromProperty(property);
                const shouldSkipAutoHeight = shouldDeferHeightSync(rawPropertyHeight, property);
                const reportedHeight = frame?.getBoundingClientRect().height ?? 0;
                if (shouldSkipAutoHeight) {
                    if (reportedHeight) {
                        notifyNativeResize(reportedHeight);
                    }
                    // 同時通知完整 payload 給 native（包含 property）
                    const payloadForNative = (data && typeof data === 'object') ? { ...data } : {};
                    payloadForNative.eventType = payloadForNative.eventType || 'resize';
                    payloadForNative.property = property;
                    payloadForNative.height = payloadForNative.height ?? reportedHeight;
                    notifyNativeEvent(payloadForNative);
                    return;
                }

                const height = extractHeightFromPayload(data) ?? reportedHeight;
                if (height) {
                    const appliedHeight = applyFrameHeight(height);
                    notifyNativeResize(appliedHeight ?? height);
                }

                const payloadForNative = (data && typeof data === 'object') ? { ...data } : {};
                payloadForNative.eventType = payloadForNative.eventType || 'resize';
                payloadForNative.property = property;
                payloadForNative.height = payloadForNative.height ?? height ?? reportedHeight ?? null;
                notifyNativeEvent(payloadForNative);
            }

            // 接收來自 widget 的 message
            window.addEventListener('message', (event) => {
                const origin = event?.origin || '';
                if (origin && !origin.includes('tagnology.co')) {
                    return;
                }
                const data = event?.data || {};
                if (!data) return;
                if (data.eventType === 'resize') {
                    handleResizeEvent(data);
                    return;
                }
                notifyNativeEvent(data);
            });

            // load event: report initial height
            window.addEventListener('load', () => {
                const initialHeight = frame?.getBoundingClientRect().height || 400;
                applyFrameHeight(initialHeight);
                notifyNativeResize(initialHeight);
                console.log('[Embed][load] initialHeight', initialHeight);
            });
            </script>
        </body>
        </html>
        """
    }
}
