import SwiftUI
import EmbedIOSSDK
import WebKit

struct ProductPageView: View {
    // 當前頁面的 URL
    @State private var pageUrl: String = "https://partnertest3.91app.com/SalePage/Index/8555569"
	@State private var productId: String = "8555569"

    // 固定位置 FloatingMedia widgets 的狀態
    @State private var showFixedBottomLeftWidget: Bool = true
    @State private var hasFixedBottomLeftContent: Bool = false
    @State private var showFixedBottomRightWidget: Bool = true
    @State private var hasFixedBottomRightContent: Bool = false
    @State private var showFixedTopLeftWidget: Bool = true
    @State private var hasFixedTopLeftContent: Bool = false
    @State private var showFixedTopRightWidget: Bool = true
    @State private var hasFixedTopRightContent: Bool = false
    @State private var showFixedCenterLeftWidget: Bool = true
    @State private var hasFixedCenterLeftContent: Bool = false
    @State private var showFixedCenterRightWidget: Bool = true
    @State private var hasFixedCenterRightContent: Bool = false

    private let tagItems: [String] = [
        "電子票券", "NFT", "限定地區活動", "獨享", "點數兌換商品", "APP獨享活動", "限定商品", "定期購商品", "買就送"
    ]

    private let categoryItems: [String] = [
        "依品牌 Crash Baggage BAGS",
        "依顏色 低調黑",
        "依顏色 清新綠",
        "依顏色 繽紛黃",
        "旅行｜戶外 行李箱｜包袋 隨行包",
        "旅行｜戶外 行李箱｜包袋 後背包",
        "旅行｜戶外 行李箱｜包袋 收納包"
    ]

    private let shippingMethods: [String] = [
        "宅配到府", "超商取貨", "門市自取", "國際運送"
    ]

    private let paymentOptions: [String] = [
        "信用卡一次付清", "信用卡分期0利率", "Apple Pay", "LINE Pay"
    ]

    private let recommendationDates: [String] = [
        "2025/03/18", "2025/03/28", "2025/04/02", "2025/04/15"
    ]

    var body: some View {
        NavigationStack {
        ZStack {
            ScrollView {
                    VStack(spacing: 32) {
                        HeaderSection()
                        HeroBannerSection()

                        VStack(spacing: 20) {
                            ProductHeadlineSection()
                            PromoBadgeSection()
                            PurchaseCTASection()
                            
                            // 在購買按鈕下方顯示 widget
                            EmbedWidgetView(
                                pageUrl: pageUrl,
                                position: EmbedIOSSDK.BELOW_BUY_BUTTON
                            )
                        }
                        .padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 24) {
                            InfoCardSection(title: "本商品適用活動", subtitle: "付款完成後將發送電子票券至「會員專區 > 我的票券」，需至門市出示憑證掃碼兌換。", badges: tagItems)

                            NoticeCardSection()

                            ProductDetailsSection()
                            
                            // 在商品特色區塊下方顯示 widget
                            EmbedWidgetView(
                                pageUrl: pageUrl,
                                position: EmbedIOSSDK.BELOW_MAIN_PRODUCT_INFO
                            )

                            PaymentShippingSection(paymentOptions: paymentOptions, shippingMethods: shippingMethods)

							  // 在購買按鈕下方顯示 widget
                            EmbedWidgetView(
                                pageUrl: pageUrl,
                                position: EmbedIOSSDK.ABOVE_RECOMMENDATION
                            )

                            RecommendationSection(dates: recommendationDates)

                            CategorySection(categories: categoryItems)

                            CommentSection()
                        }
                        .padding(.horizontal, 20)

                        FooterSection()
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                    }
                }
                .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            
            // 固定位置的 FloatingMedia widgets
            ZStack {
                // 左下角
                if showFixedBottomLeftWidget {
                    VStack {
                        Spacer()
                        HStack {
                            FixedFloatingMediaWidgetView(
                                pageUrl: pageUrl,
                                position: EmbedIOSSDK.FIXED_BOTTOM_LEFT,
                                hasContent: $hasFixedBottomLeftContent
                            )
                            Spacer()
                        }
                        .padding(.leading, 20)
                        .padding(.bottom, 20)
                    }
                }
                
                // 右下角
                if showFixedBottomRightWidget {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            FixedFloatingMediaWidgetView(
                                pageUrl: pageUrl,
                                position: EmbedIOSSDK.FIXED_BOTTOM_RIGHT,
                                hasContent: $hasFixedBottomRightContent
                            )
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
                
                // 左上角
                if showFixedTopLeftWidget {
                    VStack {
                        HStack {
                            FixedFloatingMediaWidgetView(
                                pageUrl: pageUrl,
                                position: EmbedIOSSDK.FIXED_TOP_LEFT,
                                hasContent: $hasFixedTopLeftContent
                            )
                            Spacer()
                        }
                        .padding(.leading, 20)
                        .padding(.top, 20)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                
                // 右上角
                if showFixedTopRightWidget {
                    VStack {
                        HStack {
                            Spacer()
                            FixedFloatingMediaWidgetView(
                                pageUrl: pageUrl,
                                position: EmbedIOSSDK.FIXED_TOP_RIGHT,
                                hasContent: $hasFixedTopRightContent
                            )
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 20)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
                
                // 左側中央
                if showFixedCenterLeftWidget {
                    VStack {
                        Spacer()
                        HStack {
                            FixedFloatingMediaWidgetView(
                                pageUrl: pageUrl,
                                position: EmbedIOSSDK.FIXED_CENTER_LEFT,
                                hasContent: $hasFixedCenterLeftContent
                            )
                            Spacer()
                        }
                        .padding(.leading, 20)
                        Spacer()
                    }
                }
                
                // 右側中央
                if showFixedCenterRightWidget {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            FixedFloatingMediaWidgetView(
                                pageUrl: pageUrl,
                                position: EmbedIOSSDK.FIXED_CENTER_RIGHT,
                                hasContent: $hasFixedCenterRightContent
                            )
                        }
                        .padding(.trailing, 20)
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(edges: [.bottom, .leading, .trailing])
            .allowsHitTesting(true)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            clearWebViewCache()
            
            // 5 秒後檢查所有固定位置的 widgets，沒有內容則隱藏
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                checkAndHideWidgetIfNoContent(show: $showFixedBottomLeftWidget, hasContent: hasFixedBottomLeftContent)
                checkAndHideWidgetIfNoContent(show: $showFixedBottomRightWidget, hasContent: hasFixedBottomRightContent)
                checkAndHideWidgetIfNoContent(show: $showFixedTopLeftWidget, hasContent: hasFixedTopLeftContent)
                checkAndHideWidgetIfNoContent(show: $showFixedTopRightWidget, hasContent: hasFixedTopRightContent)
                checkAndHideWidgetIfNoContent(show: $showFixedCenterLeftWidget, hasContent: hasFixedCenterLeftContent)
                checkAndHideWidgetIfNoContent(show: $showFixedCenterRightWidget, hasContent: hasFixedCenterRightContent)
            }
        }
        }
    }
    
    private func checkAndHideWidgetIfNoContent(show: Binding<Bool>, hasContent: Bool) {
        if !hasContent {
            withAnimation {
                show.wrappedValue = false
            }
        }
    }
    
    /**
     * @function clearWebViewCache
     * @description 清除 WKWebsiteDataStore 的 cache、cookies 和其他網站數據
     */
    private func clearWebViewCache() {
        let _ = WKWebsiteDataStore.default()
        let websiteDataTypes: Set<String> = [
            WKWebsiteDataTypeDiskCache,
            WKWebsiteDataTypeMemoryCache,
            WKWebsiteDataTypeOfflineWebApplicationCache,
            WKWebsiteDataTypeCookies,
            WKWebsiteDataTypeSessionStorage,
            WKWebsiteDataTypeLocalStorage,
            WKWebsiteDataTypeWebSQLDatabases,
            WKWebsiteDataTypeIndexedDBDatabases
        ]
        
        let date = Date(timeIntervalSince1970: 0)
        WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes, modifiedSince: date) {
            print("[ProductPageView] WebView cache cleared successfully")
        }
    }
}

struct HeaderSection: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                HStack(spacing: 12) {
                    Label("訂單查詢", systemImage: "doc.text.magnifyingglass")
                    Label("會員專區", systemImage: "person.circle")
                    Label("我的優惠券", systemImage: "ticket")
                    Label("購物車0", systemImage: "cart")
                }
                .font(.subheadline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.95))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(["首頁", "依品牌", "Crash Baggage", "BAGS"], id: \.self) { item in
                        Text(item)
                            .font(.footnote)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.white.opacity(0.9))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .secondarySystemBackground))
        }
        .shadow(color: Color.black.opacity(0.05), radius: 4, y: 4)
    }
}

struct HeroBannerSection: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.98, green: 0.88, blue: 0.76), Color(red: 0.96, green: 0.76, blue: 0.62)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 160)
                    .overlay(
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Crash Baggage 限定活動")
                                .font(.title3).bold()
                                .foregroundColor(.black.opacity(0.8))
                            Text("門市限定 · 預購滿額贈好禮")
                                .font(.subheadline)
                                .foregroundColor(.black.opacity(0.6))
                        }
                            .padding(20),
                        alignment: .topLeading
                    )

                VStack(alignment: .trailing, spacing: 4) {
                    Text("即將開賣")
                        .font(.caption)
                        .bold()
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(Color.orange.opacity(0.9))
                        .clipShape(Capsule())
                        .foregroundColor(.white)
                    Text("2025/04/20 12:00 開賣")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(14)
            }

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.27, green: 0.32, blue: 0.44), Color(red: 0.12, green: 0.16, blue: 0.24)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 260)
                .overlay {
                    VStack(spacing: 12) {
                        Image(systemName: "bag.fill")
                    .resizable()
                    .scaledToFit()
                            .frame(width: 90, height: 90)
                            .foregroundColor(.white.opacity(0.9))
                        Text("商品示意圖")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.85))
                        Text("ICONIC 經典撞擊後背包")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .shadow(color: Color.black.opacity(0.12), radius: 16, y: 8)
        }
        .padding(.horizontal, 20)
    }
}

struct ProductHeadlineSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Crash Baggage ICONIC 經典撞擊後背包")
                    .font(.title2)
                    .bold()

            HStack(spacing: 12) {
                Label("4.9", systemImage: "star.fill")
                    .foregroundColor(.yellow)
                Text("( 243 則評價 )")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("已售出 5,268 件")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text("頂部快取口袋設計，硬殼材質提高防護力，側邊水壺空間，背部獨立隱形拉鍊可放置貴重物品；織帶與掛環設計，可掛耳機、太陽眼鏡；行李帶設計，旅遊與日常都適用。")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PromoBadgeSection: View {
    private let badges: [String] = [
        "滿 NT$3,000 免運", "贈杯套", "加購保護殼", "預購加碼 10% 點數回饋"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(badges, id: \.self) { badge in
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text(badge)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 6, y: 3)
                )
            }
        }
    }
}

struct PurchaseCTASection: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .lastTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                        Text("$12,999")
                            .font(.title2)
                        .foregroundColor(.secondary)
                        .strikethrough()
                    Text("優惠價 $9,999")
                        .font(.largeTitle.bold())
                        .foregroundStyle(LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing))
                    Text("活動截至 2025/04/30，限量 1,000 組")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    }
                    Spacer()
                VStack(spacing: 12) {
                    Button {
                        print("立即購買 tapped")
                    } label: {
                        Text("立即購買")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 32)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }

                    Button {
                        print("加入購物車 tapped")
                    } label: {
                        Text("加入購物車")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.blue)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 28)
                            .background(Color.blue.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 12, y: 8)
            )

            HStack(spacing: 16) {
                Label("購物滿 NT$2,000 加購 $199 行李束帶", systemImage: "gift.fill")
                Spacer()
                Text("查看贈品")
                    .foregroundColor(.blue)
                    .font(.subheadline)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 6, y: 4)
            )
        }
    }
}

struct InfoCardSection: View {
    let title: String
    let subtitle: String
    let badges: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.footnote)
                .foregroundColor(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(badges, id: \.self) { badge in
                    Text(badge)
                        .font(.footnote)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 10, y: 8)
        )
    }
}

struct NoticeCardSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("購買須知")
                .font(.headline)
            ForEach([
                "購物滿 NT$5,000 才可購買本商品。",
                "本商品不適用折價券及點數折抵。",
                "付款完成後將發送 NFT 至「會員專區 > 我的 NFT 收藏」。"
            ], id: \.self) { message in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                        .padding(.top, 2)
                    Text(message)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct ProductDetailsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("商品特色")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                DetailRow(title: "商品編號", description: "CB-ICONIC-BK")
                DetailRow(title: "適用族群", description: "旅行、通勤、學生")
                DetailRow(title: "內含配件", description: "防塵袋、保固卡")
            }
                
                Divider()
                
                    Text("規格說明")
                        .font(.headline)

            Text("‧ 尺寸：45 cm × 30 cm × 20 cm\n‧ 重量：1.2 kg\n‧ 材質：硬殼聚碳酸酯 + 高密度尼龍內襯\n‧ 容量：30 L\n‧ 保固：原廠保固一年")
                        .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 6)
        )
    }
}

struct DetailRow: View {
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.subheadline)
                .frame(width: 88, alignment: .leading)
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct PaymentShippingSection: View {
    let paymentOptions: [String]
    let shippingMethods: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("付款與運送方式")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                Text("付款方式")
                    .font(.subheadline.bold())
                ForEach(paymentOptions, id: \.self) { option in
                    Label(option, systemImage: "creditcard")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("運送方式")
                    .font(.subheadline.bold())
                ForEach(shippingMethods, id: \.self) { method in
                    Label(method, systemImage: "shippingbox.fill")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Label("使用運費券可享有更多運費優惠", systemImage: "ticket.fill")
                    .font(.footnote)
                    .foregroundColor(.orange)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 6)
        )
    }
}

struct RecommendationSection: View {
    let dates: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("更多推薦")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(dates, id: \.self) { date in
                        RecommendationCard(date: date)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 6)
        )
    }
}

struct RecommendationCard: View {
    let date: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 180, height: 120)
                .overlay(
                    Text("門市限定\n{點數加價購}")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(12),
                    alignment: .bottomLeading
                )
            Text("\(date) 開賣")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(width: 180)
    }
}

struct CategorySection: View {
    let categories: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("商品相關分類")
                        .font(.headline)
            ForEach(categories, id: \.self) { category in
                HStack {
                    Image(systemName: "square.grid.2x2")
                        .foregroundColor(.blue)
                    Text(category)
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                Divider()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 6)
        )
    }
}

struct CommentSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("商品評價")
                .font(.headline)

            CommentCard(
                name: "王小明",
                sku: "ICONIC-BK-L",
                title: "行李箱愛好者必買",
                content: "質感很好，行李帶設計很方便，後背時肩帶有透氣設計不會悶熱，推薦購買。"
            )

            CommentCard(
                name: "林小雅",
                sku: "ICONIC-BK-M",
                title: "顏色很亮眼",
                content: "收到的實品顏色非常亮眼，搭配服裝也好看。外層硬殼有撞擊感但不怕刮傷。"
            )

            Button {
                print("查看更多評價")
            } label: {
                Text("查看更多評價")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 24)
                    .background(Color.blue.opacity(0.08))
                    .clipShape(Capsule())
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 6)
        )
    }
}

struct CommentCard: View {
    let name: String
    let sku: String
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.subheadline.bold())
                Spacer()
                Text(sku)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(title)
                .font(.subheadline)
            Text(content)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.blue.opacity(0.04))
        )
    }
}

struct FooterSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("關於我們")
                .font(.headline)
            Text("品牌故事 · 商店簡介 · 門市資訊 · 隱私權及網站使用條款")
                .font(.footnote)
                .foregroundColor(.secondary)

            Divider()

            Text("客服資訊")
                .font(.headline)
            Text("購物說明 · 客服留言 · 線上購物問與答 · 會員權益聲明 · 聯絡我們")
                .font(.footnote)
                .foregroundColor(.secondary)

            Divider()

            Text("© 2025 by demo股份有限公司 · 建議使用 Chrome、Firefox 或 Edge 最新版本")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ContentView: View {
    var body: some View {
            ProductPageView()
    }
}

// MARK: - FixedFloatingMediaWidgetView
/**
 * @struct FixedFloatingMediaWidgetView
 * @description 通用的固定位置 FloatingMedia widget view，用於顯示所有 FIXED_* 位置的 widgets
 */
struct FixedFloatingMediaWidgetView: View {
    let pageUrl: String
    let position: EmbedIOSSDK.Position
    @Binding var hasContent: Bool
    
    @State private var widgetHasRendered: Bool = false
    
    private let widgetSize = CGSize(width: 126, height: 224)
    
    var body: some View {
        EmbedWidgetView(pageUrl: pageUrl, position: position)
            .frame(width: widgetSize.width, height: widgetSize.height)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: WidgetHeightPreferenceKey.self, value: geometry.size.height)
                        .onAppear {
                            widgetHasRendered = true
                            checkForContent(height: geometry.size.height)
                        }
                        .onChange(of: geometry.size.height) { newHeight in
                            checkForContent(height: newHeight)
                        }
                }
            )
            .onPreferenceChange(WidgetHeightPreferenceKey.self) { height in
                checkForContent(height: height)
            }
            .contentShape(Rectangle())
            .allowsHitTesting(true)
    }
    
    private func checkForContent(height: CGFloat) {
        if height > 0 && !hasContent {
            hasContent = true
        }
    }
}

// MARK: - WidgetHeightPreferenceKey
/**
 * @struct WidgetHeightPreferenceKey
 * @description PreferenceKey 用於檢測 widget 的高度（判斷是否有內容）
 */
struct WidgetHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
