// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
// 最近更新：2026-03-07，充值页改为读取共享商品目录并优先展示 StoreKit 正式价格，online 禁止 DEBUG 直充兜底。
import StoreKit
import SwiftUI

struct WalletRechargeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var envManager = EnvironmentManager.shared
    let token: String
    let currentBalance: Int64
    let onSuccess: (WalletSummary, CoinRechargePackage) -> Void

    @State private var selectedPackageID = "popular"
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @StateObject private var iapManager = IAPManager.shared

    private var packages: [CoinRechargePackage] {
        RechargeProductCatalog.packages(for: envManager.currentEnvironment)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("充值穿贝")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppTheme.bodyText)
                            Text("当前余额 \(currentBalance) 穿贝")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.mutedText)
                            Text("固定汇率：10 穿贝 = 1 元")
                                .font(.caption)
                                .foregroundStyle(AppTheme.mutedText)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.white.opacity(0.92))
                        )

                        ForEach(packages) { package in
                            Button {
                                selectedPackageID = package.id
                            } label: {
                                HStack(alignment: .center, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 8) {
                                            Text(package.title)
                                                .font(.headline)
                                                .foregroundStyle(AppTheme.bodyText)
                                            if let badge = package.badge {
                                                Text(badge)
                                                    .font(.caption2.weight(.semibold))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(
                                                        Capsule()
                                                            .fill(Color(red: 0.95, green: 0.90, blue: 0.84))
                                                    )
                                                    .foregroundStyle(Color(red: 0.44, green: 0.36, blue: 0.28))
                                            }
                                        }
                                        Text(package.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.mutedText)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 3) {
                                        Text("\(package.coins) 穿贝")
                                            .font(.headline.weight(.semibold))
                                            .foregroundStyle(AppTheme.bodyText)
                                        Text(iapManager.displayPrice(for: package))
                                            .font(.subheadline)
                                            .foregroundStyle(AppTheme.actionText)
                                    }
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(selectedPackageID == package.id ? Color(red: 0.98, green: 0.93, blue: 0.87) : Color.white.opacity(0.92))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(selectedPackageID == package.id ? Color(red: 0.64, green: 0.45, blue: 0.28) : Color(red: 0.86, green: 0.80, blue: 0.74), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.appPlain)
                            .accessibilityIdentifier("wallet.package.\(package.id)")
                        }

                        Button {
                            Task { await recharge() }
                        } label: {
                            Text(isSubmitting ? "处理中..." : "立即充值 \(iapManager.displayPrice(for: selectedPackage))")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(Color.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(AppTheme.primary)
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.appPlain)
                        .disabled(isSubmitting)
                        .accessibilityIdentifier("wallet.recharge.confirm")
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .adaptiveContentWidth(maxWidth: 760)
                }
            }
            .navigationTitle("充值穿贝")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                        .toolbarDoneButton()
                }
            }
        }
        .alert("充值失败", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .task(id: envManager.currentEnvironment?.rawValue ?? "online") {
            await iapManager.requestProducts()
        }
    }

    private var selectedPackage: CoinRechargePackage {
        packages.first(where: { $0.id == selectedPackageID }) ?? packages[0]
    }

    private func recharge() async {
        guard !token.isEmpty else {
            errorMessage = "请先登录后再充值。"
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }

        let productID = selectedPackage.productID

        // 查找StoreKit产品
        guard let product = iapManager.product(for: selectedPackage) else {
            #if DEBUG
            if RechargeProductCatalog.allowsDebugDirectRechargeFallback(for: envManager.currentEnvironment) {
                print("[DEBUG] IAP产品未加载，使用 dev 测试模式直接充值")
                do {
                    let wallet = try await WalletService().rechargeCoins(
                        token: token,
                        amount: selectedPackage.coins,
                        packageName: selectedPackage.title
                    )
                    await MainActor.run {
                        onSuccess(wallet, selectedPackage)
                        dismiss()
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = "充值失败: \(error.localizedDescription)"
                    }
                }
                return
            }
            #endif

            errorMessage = iapManager.products.isEmpty
                ? "商品加载中，请稍后重试"
                : "未找到正式商品，请检查 App Store Connect 配置"
            await iapManager.requestProducts()
            return
        }

        do {
            // 执行IAP购买
            let transaction = try await iapManager.purchase(product)

            // 获取收据
            guard let receiptData = iapManager.getReceiptData() else {
                errorMessage = "无法获取购买收据"
                return
            }

            // 调用后端验证收据并充值
            let wallet = try await WalletService().rechargeWithAppleReceipt(
                token: token,
                receiptData: receiptData,
                productID: productID,
                transactionID: String(transaction.id)
            )

            await MainActor.run {
                onSuccess(wallet, selectedPackage)
                dismiss()
            }
        } catch let error as IAPError {
            await MainActor.run {
                errorMessage = error.localizedDescription
                ErrorReporter.report(
                    message: "IAP purchase failed: \(error.localizedDescription)",
                    errorCode: ErrorReporter.ERROR_IAP_TRANSACTION_FAILED,
                    screen: "WalletRecharge",
                    context: ["error": "\(error)"]
                )
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct WalletRecordsView: View {
    let records: [CoinTransaction]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                List {
                    if records.isEmpty {
                        Text("暂无收支记录")
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.white)
                    } else {
                        ForEach(records) { record in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.reason.isEmpty ? "收支变动" : record.reason)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.black)
                                    Text(record.createdAt)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text(record.change > 0 ? "+\(record.change)" : "\(record.change)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(record.change >= 0 ? Color.green : Color.red)
                                    Text("余额 \(record.balanceAfter)")
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.mutedText)
                                }
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(Color.white)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("收支记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.white, for: .navigationBar)
        }
        .preferredColorScheme(.light)
    }
}
