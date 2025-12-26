// EmbedViews.swift
import SwiftUI
import WebKit

// MARK: - View Modifiers
@available(iOS 16.0, *)
extension View {
    fileprivate func interactiveDismissDisabledCompat(_ disabled: Bool) -> some View {
        // iOS 16+ 直接支援 interactiveDismissDisabled (iOS 15.0+)
        self.interactiveDismissDisabled(disabled)
    }
}

// MARK: - Bridge constants
enum EmbedBridge {
    static let resizeHandlerName = "tagnologyResize"
    static let eventHandlerName = "tagnologyEvent"
    static let eventTypeKey = "eventType"
    static let bridgeInjectionFlag = "__tagnologyNativeBridgeInjected"
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
	case FIXED_BOTTOM_LEFT = "FIXED_BOTTOM_LEFT"
	case FIXED_BOTTOM_RIGHT = "FIXED_BOTTOM_RIGHT"
	case FIXED_TOP_LEFT = "FIXED_TOP_LEFT"
	case FIXED_TOP_RIGHT = "FIXED_TOP_RIGHT"
	case FIXED_CENTER_LEFT = "FIXED_CENTER_LEFT"
	case FIXED_CENTER_RIGHT = "FIXED_CENTER_RIGHT"
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
	public static let FIXED_BOTTOM_LEFT = EmbedPosition.FIXED_BOTTOM_LEFT
	public static let FIXED_BOTTOM_RIGHT = EmbedPosition.FIXED_BOTTOM_RIGHT
	public static let FIXED_TOP_LEFT = EmbedPosition.FIXED_TOP_LEFT
	public static let FIXED_TOP_RIGHT = EmbedPosition.FIXED_TOP_RIGHT
	public static let FIXED_CENTER_LEFT = EmbedPosition.FIXED_CENTER_LEFT
	public static let FIXED_CENTER_RIGHT = EmbedPosition.FIXED_CENTER_RIGHT
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
     *              Note: When layout is "FloatingMedia", the response will include an additional
     *              floatingMediaPosition field with possible values:
     *              - "TopRight"
     *              - "CenterRight"
     *              - "BottomRight"
     *              - "TopLeft"
     *              - "CenterLeft"
     *              - "BottomLeft"
     *
     * @param {String} productId - The product ID to fetch information for.
     * @param {String} platform - The platform identifier (e.g., "91APP").
     * @param {String} pageUrl - The page URL where the widget is displayed.
     *
     * @returns {PageInfoResponse} The response containing page information and embed widgets.
     * @throws {URLError} If the URL is invalid or the request fails.
     */
    public static func fetchPageInfo(productId: String, platform: String, pageUrl: String) async throws -> PageInfoResponse {
        print("[EmbedAPI] fetchPageInfo called")
        print("[EmbedAPI]   - productId: \(productId)")
        print("[EmbedAPI]   - platform: \(platform)")
        print("[EmbedAPI]   - pageUrl: \(pageUrl)")
        
        guard let url = URL(string: "https://embed.tagnology.co/api/product/getPageInfo") else {
            print("[EmbedAPI] ERROR: Invalid URL")
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
        
        print("[EmbedAPI] Sending request to: \(url.absoluteString)")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            print("[EmbedAPI] ERROR: Invalid response type")
            throw URLError(.badServerResponse)
        }
        
        print("[EmbedAPI] Response status code: \(http.statusCode)")
        
        guard 200..<300 ~= http.statusCode else {
            print("[EmbedAPI] ERROR: Bad status code \(http.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("[EmbedAPI] Response body: \(responseString)")
            }
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
        let expectedFloatingMediaPosition: String? = {
            switch position {
            case .FIXED_BOTTOM_LEFT:
                return "BottomLeft"
            case .FIXED_BOTTOM_RIGHT:
                return "BottomRight"
            case .FIXED_TOP_LEFT:
                return "TopLeft"
            case .FIXED_TOP_RIGHT:
                return "TopRight"
            case .FIXED_CENTER_LEFT:
                return "CenterLeft"
            case .FIXED_CENTER_RIGHT:
                return "CenterRight"
            default:
                return nil
            }
        }()
        let isFixedPosition = expectedFloatingMediaPosition != nil
        
        let filteredWidgets = response.pageInfo.filter { folderInfo in
            let isFloatingMedia = folderInfo.layout?.lowercased() == "floatingmedia"
            
            // 如果是 FIXED_* 位置，需要匹配 FloatingMedia 的 floatingMediaPosition
            if isFixedPosition {
                if isFloatingMedia {
                    let widgetFloatingMediaPosition = folderInfo.floatingMediaPosition
                    return widgetFloatingMediaPosition == expectedFloatingMediaPosition
                } else {
                    // FIXED_* 位置只顯示 FloatingMedia widgets
                    return false
                }
            }
            
            // 非 FIXED 位置：不允許顯示 FloatingMedia widgets
            if isFloatingMedia {
                return false
            }
            
            // 正常過濾：根據 embedLocation 匹配（非 FIXED 位置，且非 FloatingMedia）
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
/**
 * @struct EmbedFolderInfo
 * @description Information about an embed widget folder.
 *              When layout is "FloatingMedia", floatingMediaPosition will be present with values:
 *              "TopRight", "CenterRight", "BottomRight", "TopLeft", "CenterLeft", "BottomLeft"
 */
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
    public let setting: Int?
    /// FloatingMedia position. Only present when layout is "FloatingMedia".
    /// Possible values: "TopRight", "CenterRight", "BottomRight", "TopLeft", "CenterLeft", "BottomLeft"
    public let floatingMediaPosition: String?

    public var id: String { folderId }
    
    public init(folderId: String, productId: String? = nil, platform: String? = nil, productName: String? = nil, productUrl: String? = nil, productImage: String? = nil, embedLocation: String? = nil, timestamp: Int? = nil, folderName: String? = nil, layout: String? = nil, setting: Int? = nil, floatingMediaPosition: String? = nil) {
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
        self.setting = setting
        self.floatingMediaPosition = floatingMediaPosition
    }
}

// MARK: - EmbedWidgetDataManager (Shared Data Manager)
/**
 * @class EmbedWidgetDataManager
 * @description Manages shared data for embed widgets to avoid multiple API calls for the same page URL.
 *              All EmbedWidgetView instances with the same pageUrl will share the same data source.
 */
@available(iOS 16.0, *)
@MainActor
public class EmbedWidgetDataManager: ObservableObject {
    public static let shared = EmbedWidgetDataManager()
    
    private var cache: [String: CacheEntry] = [:]
    private var loadingTasks: [String: Task<Void, Never>] = [:]
    
    private struct CacheEntry {
        let pageInfo: [EmbedFolderInfo]
        let timestamp: Date
    }
    
    private init() {}
    
    /**
     * @function getWidgetsForPosition
     * @description Gets widgets for a specific position from cached data or fetches from API if needed.
     *
     * @param {String} pageUrl - The page URL where the widget is displayed.
     * @param {EmbedPosition} position - The position where the widget should be displayed.
     * @param {String?} productId - Optional product ID. If not provided, will be extracted from pageUrl.
     * @param {String} platform - Platform identifier. Defaults to "91APP".
     *
     * @returns {[EmbedFolderInfo]} Array of embed folder information matching the specified position.
     */
    func getWidgetsForPosition(
        pageUrl: String,
        position: EmbedPosition,
        productId: String? = nil,
        platform: String = EmbedAPI.defaultPlatform
    ) async -> [EmbedFolderInfo] {
        let cacheKey = pageUrl
        let positionString = position.rawValue
        
        print("[EmbedWidgetDataManager] getWidgetsForPosition called - pageUrl: \(pageUrl), position: \(positionString)")
        
        // 檢查快取
        if let cached = cache[cacheKey] {
            print("[EmbedWidgetDataManager] Cache hit! Found \(cached.pageInfo.count) widgets in cache")
            let filtered = filterWidgetsByPosition(cached.pageInfo, position: position)
            print("[EmbedWidgetDataManager] After filtering by position \(positionString): \(filtered.count) widgets")
            return filtered
        }
        
        print("[EmbedWidgetDataManager] Cache miss")
        
        // 如果正在載入，等待載入完成
        if let loadingTask = loadingTasks[cacheKey] {
            print("[EmbedWidgetDataManager] Already loading, waiting for existing task...")
            // 使用 Task.value 等待任務完成（忽略返回值）
            let _: Void = await loadingTask.value
            if let cached = cache[cacheKey] {
                print("[EmbedWidgetDataManager] Load completed, found \(cached.pageInfo.count) widgets")
                let filtered = filterWidgetsByPosition(cached.pageInfo, position: position)
                print("[EmbedWidgetDataManager] After filtering by position \(positionString): \(filtered.count) widgets")
                return filtered
            } else {
                print("[EmbedWidgetDataManager] Load completed but cache is empty (possible error)")
            }
        }
        
        // 開始載入
        let finalProductId = productId ?? EmbedAPI.extractProductIdFromPageUrl(pageUrl) ?? ""
        print("[EmbedWidgetDataManager] Starting new load - productId: \(finalProductId), platform: \(platform)")
        
        guard !finalProductId.isEmpty else {
            print("[EmbedWidgetDataManager] ERROR: productId is empty, returning empty array")
            return []
        }
        
        // 創建載入任務
        let task = Task { @MainActor in
            do {
                print("[EmbedWidgetDataManager] Calling API fetchPageInfo...")
                let response = try await EmbedAPI.fetchPageInfo(
                    productId: finalProductId,
                    platform: platform,
                    pageUrl: pageUrl
                )
                
                print("[EmbedWidgetDataManager] API call successful! Received \(response.pageInfo.count) widgets")
                for (index, widget) in response.pageInfo.enumerated() {
                    print("[EmbedWidgetDataManager] Widget[\(index)]: folderId=\(widget.folderId), embedLocation=\(widget.embedLocation ?? "nil"), layout=\(widget.layout ?? "nil")")
                }
                
                self.cache[cacheKey] = CacheEntry(
                    pageInfo: response.pageInfo,
                    timestamp: Date()
                )
                self.loadingTasks.removeValue(forKey: cacheKey)
                print("[EmbedWidgetDataManager] Cache updated and loading task removed")
            } catch {
                print("[EmbedWidgetDataManager] ERROR in API call: \(error.localizedDescription)")
                self.loadingTasks.removeValue(forKey: cacheKey)
            }
        }
        
        loadingTasks[cacheKey] = task
        print("[EmbedWidgetDataManager] Waiting for task to complete...")
        // 使用 Task.value 等待任務完成（忽略返回值）
        let _: Void = await task.value
        print("[EmbedWidgetDataManager] Task completed")
        
        // 載入完成後再次檢查快取
        if let cached = cache[cacheKey] {
            print("[EmbedWidgetDataManager] After load, found \(cached.pageInfo.count) widgets in cache")
            let filtered = filterWidgetsByPosition(cached.pageInfo, position: position)
            print("[EmbedWidgetDataManager] After filtering by position \(positionString): \(filtered.count) widgets")
            return filtered
        }
        
        print("[EmbedWidgetDataManager] WARNING: Cache is still empty after load, returning empty array")
        return []
    }
    
    /**
     * @function getFloatingMediaPositionForEmbedPosition
     * @description Maps EmbedPosition to corresponding floatingMediaPosition value.
     *
     * @param {EmbedPosition} position - The EmbedPosition to map.
     *
     * @returns {String?} The corresponding floatingMediaPosition value, or nil if not a FIXED position.
     */
    private func getFloatingMediaPositionForEmbedPosition(_ position: EmbedPosition) -> String? {
        switch position {
        case .FIXED_BOTTOM_LEFT:
            return "BottomLeft"
        case .FIXED_BOTTOM_RIGHT:
            return "BottomRight"
        case .FIXED_TOP_LEFT:
            return "TopLeft"
        case .FIXED_TOP_RIGHT:
            return "TopRight"
        case .FIXED_CENTER_LEFT:
            return "CenterLeft"
        case .FIXED_CENTER_RIGHT:
            return "CenterRight"
        default:
            return nil
        }
    }
    
    /**
     * @function filterWidgetsByPosition
     * @description Filters widgets by position and sorts them by timestamp.
     *              For FIXED_* positions, matches FloatingMedia widgets by floatingMediaPosition.
     *
     * @param {[EmbedFolderInfo]} widgets - Array of widgets to filter.
     * @param {EmbedPosition} position - The position to filter by.
     *
     * @returns {[EmbedFolderInfo]} Filtered and sorted widgets.
     */
    private func filterWidgetsByPosition(_ widgets: [EmbedFolderInfo], position: EmbedPosition) -> [EmbedFolderInfo] {
        let positionString = position.rawValue
        let expectedFloatingMediaPosition = getFloatingMediaPositionForEmbedPosition(position)
        let isFixedPosition = expectedFloatingMediaPosition != nil
        print("[EmbedWidgetDataManager] filterWidgetsByPosition - input: \(widgets.count) widgets, position: \(positionString), isFixedPosition: \(isFixedPosition), expectedFloatingMediaPosition: \(expectedFloatingMediaPosition ?? "nil")")
        
        let filteredWidgets = widgets.filter { folderInfo in
            let isFloatingMedia = folderInfo.layout?.lowercased() == "floatingmedia"
            
            // 如果是 FIXED_* 位置，需要匹配 FloatingMedia 的 floatingMediaPosition
            if isFixedPosition {
                if isFloatingMedia {
                    let widgetFloatingMediaPosition = folderInfo.floatingMediaPosition
                    let matches = widgetFloatingMediaPosition == expectedFloatingMediaPosition
                    if matches {
                        print("[EmbedWidgetDataManager] Filter: Including FloatingMedia widget \(folderInfo.folderId) - floatingMediaPosition '\(widgetFloatingMediaPosition ?? "nil")' matches position \(positionString)")
                    } else {
                        print("[EmbedWidgetDataManager] Filter: Excluding FloatingMedia widget \(folderInfo.folderId) - floatingMediaPosition '\(widgetFloatingMediaPosition ?? "nil")' != expected '\(expectedFloatingMediaPosition ?? "nil")'")
                    }
                    return matches
                } else {
                    // FIXED_* 位置只顯示 FloatingMedia widgets
                    print("[EmbedWidgetDataManager] Filter: Excluding non-FloatingMedia widget \(folderInfo.folderId) for FIXED position \(positionString)")
                    return false
                }
            }
            
            // 非 FIXED 位置：不允許顯示 FloatingMedia widgets
            if isFloatingMedia {
                print("[EmbedWidgetDataManager] Filter: Excluding FloatingMedia widget \(folderInfo.folderId) - FloatingMedia can only be displayed in FIXED_* positions")
                return false
            }
            
            // 正常過濾：根據 embedLocation 匹配（非 FIXED 位置，且非 FloatingMedia）
            if let embedLocation = folderInfo.embedLocation {
                let embedLocationUpper = embedLocation.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let positionStringTrimmed = positionString.trimmingCharacters(in: .whitespacesAndNewlines)
                let matches = embedLocationUpper == positionStringTrimmed
                if !matches {
                    print("[EmbedWidgetDataManager] Filter: widget \(folderInfo.folderId) location '\(embedLocationUpper)' != '\(positionStringTrimmed)'")
                } else {
                    print("[EmbedWidgetDataManager] Filter: widget \(folderInfo.folderId) location '\(embedLocationUpper)' matches '\(positionStringTrimmed)'")
                }
                return matches
            }
            print("[EmbedWidgetDataManager] Filter: widget \(folderInfo.folderId) has no embedLocation")
            return false
        }
        
        print("[EmbedWidgetDataManager] filterWidgetsByPosition - after filter: \(filteredWidgets.count) widgets")
        
        // 對過濾後的 widgets 進行排序：按照 timestamp 降序（較新的先顯示）
        let sortedWidgets = filteredWidgets.sorted { folderInfo1, folderInfo2 in
            let timestamp1 = folderInfo1.timestamp ?? 0
            let timestamp2 = folderInfo2.timestamp ?? 0
            return timestamp1 > timestamp2
        }
        
        print("[EmbedWidgetDataManager] filterWidgetsByPosition - after sort: \(sortedWidgets.count) widgets")
        return sortedWidgets
    }
    
    /**
     * @function clearCache
     * @description Clears the cache for a specific page URL or all cache.
     *
     * @param {String?} pageUrl - Optional page URL to clear. If nil, clears all cache.
     */
    public func clearCache(for pageUrl: String? = nil) {
        if let pageUrl = pageUrl {
            cache.removeValue(forKey: pageUrl)
            loadingTasks.removeValue(forKey: pageUrl)
        } else {
            cache.removeAll()
            loadingTasks.removeAll()
        }
    }
}

// MARK: - EmbedWidgetView (SwiftUI - Auto-loading by position)
/**
 * @struct EmbedWidgetView
 * @description A SwiftUI view that automatically loads and displays embed widgets based on page URL and position.
 *              This view uses a shared data manager to avoid multiple API calls for the same page URL.
 */
@available(iOS 16.0, *)
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
    }
    
    public var body: some View {
        // 在 body 第一次計算時就開始載入（不等待 onAppear，確保即使不在可見區域也會載入）
        if !hasStartedLoading {
            DispatchQueue.main.async {
                if !self.hasStartedLoading {
                    self.hasStartedLoading = true
                    print("[EmbedWidgetView] body - First render, triggering load for position: \(self.position.rawValue)")
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
                    .onAppear {
                        print("[EmbedWidgetView] body - Rendering: isLoading=true")
                    }
            } else if errorMessage != nil {
                // 錯誤時不顯示任何內容（或可選擇顯示錯誤訊息）
                EmptyView()
                    .onAppear {
                        print("[EmbedWidgetView] body - Rendering: error=\(self.errorMessage ?? "unknown")")
                    }
            } else if folderInfos.isEmpty {
                // 沒有資料時不顯示
                EmptyView()
                    .onAppear {
                        print("[EmbedWidgetView] body - Rendering: folderInfos.isEmpty=true")
                    }
            } else {
                // 過濾 widgets：對於 FIXED_* 位置，需要匹配 FloatingMedia 的 floatingMediaPosition
                let expectedFloatingMediaPosition: String? = {
                    switch position {
                    case .FIXED_BOTTOM_LEFT:
                        return "BottomLeft"
                    case .FIXED_BOTTOM_RIGHT:
                        return "BottomRight"
                    case .FIXED_TOP_LEFT:
                        return "TopLeft"
                    case .FIXED_TOP_RIGHT:
                        return "TopRight"
                    case .FIXED_CENTER_LEFT:
                        return "CenterLeft"
                    case .FIXED_CENTER_RIGHT:
                        return "CenterRight"
                    default:
                        return nil
                    }
                }()
                let isFixedPosition = expectedFloatingMediaPosition != nil
                
                let filteredWidgets = folderInfos.filter { folderInfo in
                    let isFloatingMedia = folderInfo.layout?.lowercased() == "floatingmedia"
                    
                    print("[EmbedWidgetView] Filtering widget - folderId: \(folderInfo.folderId), layout: \(folderInfo.layout ?? "nil"), position: \(position.rawValue), isFloatingMedia: \(isFloatingMedia), isFixedPosition: \(isFixedPosition)")
                    
                    // 如果是 FIXED_* 位置，需要匹配 FloatingMedia 的 floatingMediaPosition
                    if isFixedPosition {
                        if isFloatingMedia {
                            let widgetFloatingMediaPosition = folderInfo.floatingMediaPosition
                            let shouldShow = widgetFloatingMediaPosition == expectedFloatingMediaPosition
                            print("[EmbedWidgetView] FloatingMedia widget - floatingMediaPosition: '\(widgetFloatingMediaPosition ?? "nil")', expected: '\(expectedFloatingMediaPosition ?? "nil")', shouldShow: \(shouldShow)")
                            return shouldShow
                        } else {
                            // FIXED_* 位置只顯示 FloatingMedia widgets
                            print("[EmbedWidgetView] Non-FloatingMedia widget for FIXED position - excluding")
                            return false
                        }
                    }
                    
                    // 非 FIXED 位置：不允許顯示 FloatingMedia widgets
                    if isFloatingMedia {
                        print("[EmbedWidgetView] Excluding FloatingMedia widget - FloatingMedia can only be displayed in FIXED_* positions")
                        return false
                    }
                    
                    // 如果不是 FIXED 位置，且不是 FloatingMedia，正常顯示
                    print("[EmbedWidgetView] Non-FIXED position widget (non-FloatingMedia) - showing")
                    return true
                }
                
                if filteredWidgets.isEmpty {
                    // 過濾後沒有資料時不顯示
                    EmptyView()
                        .onAppear {
                            print("[EmbedWidgetView] body - Rendering: All widgets filtered out for position \(self.position.rawValue)")
                        }
                } else {
                    // 有資料時顯示所有匹配的 widgets（依序垂直排列）
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredWidgets, id: \.folderId) { folderInfo in
                            EmbedView(folderInfo: folderInfo, pageUrl: pageUrl)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .onAppear {
                        print("[EmbedWidgetView] body - Rendering: \(filteredWidgets.count) widgets (filtered from \(self.folderInfos.count)) for position \(self.position.rawValue)")
                    }
                }
            }
        }
    }
    
    /**
     * @function loadWidgets
     * @description Loads widgets from the shared data manager based on the specified position.
     *              Uses cached data if available to avoid multiple API calls.
     */
    private func loadWidgets() async {
        print("[EmbedWidgetView] loadWidgets called - pageUrl: \(pageUrl), position: \(position.rawValue)")
        
        // 使用 MainActor 確保狀態檢查和設置是原子操作
        let shouldLoad = await MainActor.run {
            if self.isLoading {
                print("[EmbedWidgetView] Already loading, skipping...")
                return false
            }
            if self.hasStartedLoading && !self.folderInfos.isEmpty {
                print("[EmbedWidgetView] Already loaded with \(self.folderInfos.count) widgets, skipping...")
                return false
            }
            // 設置載入狀態
            print("[EmbedWidgetView] Setting loading state to true")
            self.isLoading = true
            self.errorMessage = nil
            return true
        }
        
        guard shouldLoad else {
            print("[EmbedWidgetView] Should not load, returning early")
            return
        }
        
        print("[EmbedWidgetView] Calling EmbedWidgetDataManager.shared.getWidgetsForPosition...")
        
        // 使用共享資料管理器，避免重複 API 呼叫
        let widgets = await EmbedWidgetDataManager.shared.getWidgetsForPosition(
            pageUrl: pageUrl,
            position: position,
            productId: productId,
            platform: platform
        )
        
        print("[EmbedWidgetView] Received \(widgets.count) widgets from data manager")
        
        // 載入完成後進行 log（僅在第一次載入時）
        if !widgets.isEmpty {
            let positionString = position.rawValue
            print("[EmbedWidgetView] === Widgets for position \(positionString) ===")
            for folderInfo in widgets {
                print("[EmbedWidgetView] position: \(positionString)")
                print("[EmbedWidgetView] folderId: \(folderInfo.folderId)")
                print("[EmbedWidgetView] folderName: \(folderInfo.folderName ?? "nil")")
                print("[EmbedWidgetView] layout: \(folderInfo.layout ?? "nil")")
                print("[EmbedWidgetView] embedLocation: \(folderInfo.embedLocation ?? "nil")")
                print("[EmbedWidgetView] ---")
            }
        } else {
            print("[EmbedWidgetView] WARNING: No widgets returned for position \(position.rawValue)")
        }
        
        await MainActor.run {
            print("[EmbedWidgetView] Updating folderInfos with \(widgets.count) widgets")
            self.folderInfos = widgets
            self.isLoading = false
            print("[EmbedWidgetView] Loading complete, isLoading set to false")
        }
    }
}

// MARK: - EmbedView (SwiftUI)
@available(iOS 16.0, *)
public struct EmbedView: View {
    private let folderInfo: EmbedFolderInfo
	private let pageUrl: String

    @State private var contentHeight: CGFloat = 0
    @State private var isLightboxPresented = false
    @State private var pendingLightboxMessageJSON: String?
    // 當 widget property position == fixed 時切換為 true，整個 WebView 會變成 fullscreen fixed
    @State private var isFullscreenFixed = false
    @State private var lightboxLoadFailed = false

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
            ZStack {
                EmbedWebView(
                    folderId: folderInfo.folderId,
                    pageUrl: pageUrl,
                    layout: folderInfo.layout,
                    contentHeight: $contentHeight,
                    onEvent: handleEmbedEvent
                )
                .frame(maxWidth: .infinity)
                .frame(height: {
                    let isFloatingMedia = folderInfo.layout?.lowercased() == "floatingmedia"
                    if isFloatingMedia {
                        // FloatingMedia 強制使用 224px 高度
                        return 224
                    } else if isFullscreenFixed {
                        return UIScreen.main.bounds.height
                    } else {
                        return max(contentHeight, 60)
                    }
                }())
                .background(Color.clear)
                .ignoresSafeArea(edges: isFullscreenFixed ? .all : .init())
                .interactiveDismissDisabledCompat(isFullscreenFixed)
                .zIndex(isFullscreenFixed ? 1 : 0)
            }
        }
        // Lightbox（fullscreen）
        .fullScreenCover(isPresented: $isLightboxPresented) {
            ZStack(alignment: .topTrailing) {
                // Lightbox 內容
                LightboxWebView(
                    url: lightboxURL,
                    messageJSON: $pendingLightboxMessageJSON,
                    onEvent: handleEmbedEvent,
                    loadFailed: $lightboxLoadFailed
                )
                .background(Color.black.opacity(0.95))
                .ignoresSafeArea()
                
                // 只在載入失敗時顯示關閉按鈕
                if lightboxLoadFailed {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                handleLightboxToggle(false)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.5))
                                            .frame(width: 36, height: 36)
                                    )
                            }
                            .padding(.top, 8)
                            .padding(.trailing, 16)
                        }
                        Spacer()
                    }
                }
            }
            .interactiveDismissDisabled(false) // 允許下拉關閉
            .onAppear {
                // 重置載入失敗狀態
                lightboxLoadFailed = false
            }
        }
    }


    // MARK: - Event handler
    private func handleEmbedEvent(_ event: EmbedWebView.EmbedEvent) {
        switch event.type {
        case "resize":
            handleResizeEventPayload(event.payload)
			break
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
        // 確保在主線程上執行
        DispatchQueue.main.async {
            self.isLightboxPresented = shouldOpen
            if !shouldOpen {
                self.pendingLightboxMessageJSON = nil
                self.lightboxLoadFailed = false // 重置載入失敗狀態
            }
        }
    }

    // MARK: - resize handling (保留原始邏輯，並加入 fixed detection)
    private func handleResizeEventPayload(_ payload: [String: Any]) {
        // 對於 FloatingMedia，忽略 resize 事件，強制使用 224px 高度
        let isFloatingMedia = folderInfo.layout?.lowercased() == "floatingmedia"
        if isFloatingMedia {
            contentHeight = 224
            return
        }
        
        let property = payload["property"] as? [String: Any]
        let rawHeightFromProperty = extractRawHeightString(from: property)
        let shouldDefer = shouldDeferHeightSync(rawHeightFromProperty, property: property)
        let resolvedHeight = extractNumericHeight(from: payload, property: property)

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
    let layout: String?
    @Binding var contentHeight: CGFloat
    let onEvent: (EmbedEvent) -> Void

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
        Coordinator(parent: self, onEvent: onEvent)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        // iOS 16+ 使用新的 API 替代已棄用的 javaScriptEnabled (iOS 14.0+)
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.allowsInlineMediaPlayback = true
        // iOS 16+ 直接支援 mediaTypesRequiringUserActionForPlayback (iOS 10.0+)
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.userContentController.add(context.coordinator, name: EmbedBridge.resizeHandlerName)
        configuration.userContentController.add(context.coordinator, name: EmbedBridge.eventHandlerName)

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
        let htmlString = EmbedHTMLBuilder.buildHTML(folderId: folderId, pageUrl: pageUrl, layout: layout)
        webView.loadHTMLString(htmlString, baseURL: EmbedHTMLBuilder.assetBaseURL)
    }

    // MARK: - Coordinator
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        private var parent: EmbedWebView
        private let onEvent: (EmbedEvent) -> Void
        weak var webView: WKWebView?

        init(parent: EmbedWebView, onEvent: @escaping (EmbedEvent) -> Void) {
            self.parent = parent
            self.onEvent = onEvent
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
            default: break
            }
        }

        private func handleEventMessage(_ body: Any) {
            guard let embedEvent = EmbedWebView.makeEvent(from: body) else { return }
            DispatchQueue.main.async { [weak self] in
                self?.onEvent(embedEvent)
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
        }
    }
}

// MARK: - LightboxWebView (UIViewRepresentable)
struct LightboxWebView: UIViewRepresentable {
    let url: URL
    @Binding var messageJSON: String?
    let onEvent: (EmbedWebView.EmbedEvent) -> Void
    @Binding var loadFailed: Bool

    func makeCoordinator() -> Coordinator { Coordinator(onEvent: onEvent, loadFailed: $loadFailed) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // iOS 16+ 使用新的 API 替代已棄用的 javaScriptEnabled (iOS 14.0+)
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.allowsInlineMediaPlayback = true
        // iOS 16+ 直接支援 mediaTypesRequiringUserActionForPlayback (iOS 10.0+)
        configuration.mediaTypesRequiringUserActionForPlayback = []
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
        @Binding var loadFailed: Bool

        init(onEvent: @escaping (EmbedWebView.EmbedEvent) -> Void, loadFailed: Binding<Bool>) {
            self.onEvent = onEvent
            self._loadFailed = loadFailed
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isContentLoaded = true
            flushPendingMessage()
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("[LightboxWebView] Navigation failed: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.loadFailed = true
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("[LightboxWebView] Provisional navigation failed: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.loadFailed = true
            }
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
     * @param {String?} layout - Optional layout type (e.g., "FloatingMedia").
     *
     * @returns {String} The HTML string containing the embed iframe.
     */
    static func buildHTML(folderId: String, pageUrl: String, layout: String? = nil) -> String {
        // 構建 iframe src URL
        var iframeSrc = "https://embed.tagnology.co/display?folderId=\(folderId)&page=\(pageUrl)"
        
        // 如果 layout 為 FloatingMedia，添加 fullScreen=true 參數
        let isFloatingMedia = layout?.lowercased() == "floatingmedia"
        if isFloatingMedia {
            iframeSrc += "&fullScreen=true"
        }

        // 根據 layout 決定 iframe 的 CSS 樣式
        // FloatingMedia 需要適應容器大小，其他 layout 使用全螢幕 fixed（Safari 14 workaround）
        let iframeCSS: String
        let containerCSS: String
        if isFloatingMedia {
            // FloatingMedia：使用容器 div 限制大小，iframe 適應容器（參考 test.html 結構）
            containerCSS = """
                #embed-container {
                    width: 100%;
                    height: 100%;
                    max-width: 126px !important;
                    max-height: 224px !important;
                    position: relative;
                    overflow: hidden !important;
                    background: transparent;
                    top: 0 !important;
                    left: 0 !important;
                    margin: 0 !important;
                    padding: 0 !important;
                    visibility: visible !important;
                    opacity: 1 !important;
                    z-index: 1 !important;
                    display: block !important;
                }
            """
            iframeCSS = """
                iframe {
                    border: none !important;
                    width: 126px !important;
                    height: 224px !important;
                    max-width: 126px !important;
                    max-height: 224px !important;
                    position: relative !important;
                    display: block !important;
                    overflow: hidden !important;
                    background: transparent;
                    box-sizing: border-box !important;
                    visibility: visible !important;
                    opacity: 1 !important;
                    z-index: 1 !important;
                }
            """
        } else {
            // 其他 layout：使用全螢幕 fixed（Safari 14 workaround）
            containerCSS = ""
            iframeCSS = """
                iframe {
                    border: 0;
                    width: 100vw !important;
                    height: 100vh !important;
                    position: fixed !important;
                    top: 0;
                    left: 0;
                    overflow: hidden;
                    -webkit-overflow-scrolling: touch;
                    background: transparent;
                }
            """
        }

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
                
                /* FloatingMedia 專用：限制 body/html 高度並確保正確定位 */
                \(isFloatingMedia ? """
                html, body {
                    max-height: 224px !important;
                    display: flex !important;
                    align-items: flex-start !important;
                    justify-content: flex-start !important;
                }
                """ : "")

                /* 容器樣式（僅 FloatingMedia 使用） */
                \(containerCSS)
                /* Iframe 樣式（根據 layout 類型動態設定） */
                \(iframeCSS)
            </style>
        </head>
        <body>
            \(isFloatingMedia ? """
            <div id="embed-container">
                <iframe id="embed-frame" src="\(iframeSrc)" scrolling="no" frameborder="0" allow="fullscreen; autoplay; picture-in-picture" playsinline></iframe>
            </div>
            """ : """
            <iframe id="embed-frame" src="\(iframeSrc)" scrolling="no" frameborder="0" allow="fullscreen; autoplay; picture-in-picture" playsinline></iframe>
            """)
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
                const property = (data && typeof data === 'object') ? data.property : null;
                const container = document.getElementById('embed-container');
                const isFloatingMedia = container !== null; // 如果有容器，就是 FloatingMedia
                
                if (property && frame) {
                    Object.keys(property).forEach((key) => {
                        if (!Object.prototype.hasOwnProperty.call(property, key)) return;
                        const value = property[key];
                        if (value === undefined || value === null) return;
                        
                        // 對於 FloatingMedia，忽略 position 屬性（保持 relative）
                        if (isFloatingMedia && key.toLowerCase() === 'position') {
                            return;
                        }
                        
                        // 套用到 iframe 上（frame.style）
                        frame.style.setProperty(String(key), String(value), 'important');
                    });
                    
                    // 對於 FloatingMedia，強制確保 position 是 relative
                    if (isFloatingMedia) {
                        frame.style.setProperty('position', 'relative', 'important');
                    }
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
            });
            </script>
        </body>
        </html>
        """
    }
}
