// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
// 最近更新：2026-03-07，充值商品目录改为共享配置，online 依赖正式商品并优先显示 StoreKit 实际价格。
import StoreKit
import Foundation
import Combine

struct CoinRechargePackage: Identifiable, Equatable {
    let id: String
    let productID: String
    let title: String
    let subtitle: String
    let coins: Int64
    let fallbackPriceYuan: Int
    let badge: String?

    var fallbackDisplayPrice: String {
        "¥\(fallbackPriceYuan)"
    }
}

enum RechargeProductCatalog {
    private static let onlinePackages: [CoinRechargePackage] = [
        CoinRechargePackage(id: "starter", productID: "com.clothes.coin.starter", title: "新手包", subtitle: "轻量体验", coins: 100, fallbackPriceYuan: 12, badge: nil),
        CoinRechargePackage(id: "daily", productID: "com.clothes.coin.daily", title: "日常包", subtitle: "常用推荐", coins: 300, fallbackPriceYuan: 28, badge: "推荐"),
        CoinRechargePackage(id: "popular", productID: "com.clothes.coin.popular", title: "人气包", subtitle: "高频试穿", coins: 680, fallbackPriceYuan: 68, badge: "热门"),
        CoinRechargePackage(id: "vip", productID: "com.clothes.coin.vip", title: "尊享包", subtitle: "进阶玩家", coins: 1280, fallbackPriceYuan: 128, badge: "超值"),
        CoinRechargePackage(id: "pro", productID: "com.clothes.coin.pro", title: "臻选包", subtitle: "重度用户", coins: 3000, fallbackPriceYuan: 298, badge: nil)
    ]

    // 目前 dev 与 online 共用一组 product_id；保留独立分支，后续如需拆分测试商品无需再改调用点。
    private static let devPackages = onlinePackages

    static func packages(for environment: EnvironmentType?) -> [CoinRechargePackage] {
        switch environment ?? .online {
        case .dev:
            return devPackages
        case .online:
            return onlinePackages
        }
    }

    static func productIDs(for environment: EnvironmentType?) -> [String] {
        packages(for: environment).map(\.productID)
    }

    static func allowsDebugDirectRechargeFallback(for environment: EnvironmentType?) -> Bool {
        #if DEBUG
        return environment == .dev
        #else
        return false
        #endif
    }
}

@MainActor
class IAPManager: NSObject, ObservableObject {
    static let shared = IAPManager()

    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var updateListenerTask: Task<Void, Error>?

    private override init() {
        super.init()
        updateListenerTask = listenForTransactions()
        Task {
            await requestProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // 请求产品信息
    func requestProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let productIDs = RechargeProductCatalog.productIDs(for: EnvironmentManager.shared.currentEnvironment)
            let products = try await Product.products(for: productIDs)
            self.products = products.sorted { $0.price < $1.price }
            print("[IAP] Loaded \(products.count) products")
        } catch {
            print("[IAP] Failed to load products: \(error)")
            errorMessage = "加载商品失败: \(error.localizedDescription)"
            ErrorReporter.report(
                message: "IAP load products failed",
                errorCode: ErrorReporter.ERROR_IAP_INIT_FAILED,
                screen: "WalletRecharge",
                context: ["error": "\(error)"]
            )
        }
    }

    // 购买产品
    func purchase(_ product: Product) async throws -> Transaction {
        print("[IAP] Starting purchase for \(product.id)")

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            print("[IAP] Purchase success, verifying transaction...")
            let transaction = try checkVerified(verification)
            await transactionFinish(transaction)
            return transaction

        case .userCancelled:
            print("[IAP] User cancelled purchase")
            throw IAPError.userCancelled

        case .pending:
            print("[IAP] Purchase pending approval")
            throw IAPError.pendingApproval

        @unknown default:
            print("[IAP] Unknown purchase result")
            throw IAPError.unknown
        }
    }

    // 验证交易
    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            print("[IAP] Verification failed: \(error)")
            throw IAPError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    // 完成交易
    private func transactionFinish(_ transaction: Transaction) async {
        purchasedProductIDs.insert(transaction.productID)
        await transaction.finish()
        print("[IAP] Transaction finished: \(transaction.productID)")
    }

    // 监听交易更新
    private func listenForTransactions() -> Task<Void, Error> {
        return Task { [weak self] in
            guard let self = self else { return }
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.transactionFinish(transaction)
                } catch {
                    print("[IAP] Transaction update error: \(error)")
                }
            }
        }
    }

    // 恢复购买
    func restorePurchases() async throws {
        print("[IAP] Restoring purchases...")
        try await AppStore.sync()
    }

    // 获取收据数据
    func getReceiptData() -> String? {
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              FileManager.default.fileExists(atPath: receiptURL.path),
              let receiptData = try? Data(contentsOf: receiptURL) else {
            return nil
        }
        return receiptData.base64EncodedString()
    }

    func product(for package: CoinRechargePackage) -> Product? {
        products.first(where: { $0.id == package.productID })
    }

    func displayPrice(for package: CoinRechargePackage) -> String {
        // 统一显示人民币价格
        return package.fallbackDisplayPrice
    }
}

// MARK: - IAP Error
enum IAPError: Error, LocalizedError {
    case userCancelled
    case pendingApproval
    case verificationFailed
    case unknown
    case productNotFound
    case receiptNotFound

    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "用户取消购买"
        case .pendingApproval:
            return "等待购买确认"
        case .verificationFailed:
            return "交易验证失败"
        case .unknown:
            return "未知错误"
        case .productNotFound:
            return "商品不存在"
        case .receiptNotFound:
            return "收据不存在"
        }
    }
}
