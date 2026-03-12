// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import Foundation

struct APIEnvelope<T: Decodable>: Decodable {
    let errno: Int
    let errmsg: String
    let data: T?
}

struct APIErrorEnvelope: Decodable {
    let errno: Int
    let errmsg: String
}

struct ServiceError: LocalizedError {
    let errno: Int
    let message: String

    var errorDescription: String? { message }
}

struct WalletSummary: Decodable {
    let userID: Int64
    let balance: Int64
    let level: Int
    let updatedAt: String
    let totalEarned: Int64?
    let totalSpent: Int64

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case uid
        case id
        case balance
        case level
        case updatedAt = "updated_at"
        case totalEarned = "total_earned"
        case totalSpent = "total_spent"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = Self.decodeInt64(in: container, keys: [.userID, .uid, .id]) ?? 0
        balance = Self.decodeInt64(in: container, keys: [.balance]) ?? 0
        level = (try? container.decode(Int.self, forKey: .level)) ?? 0
        updatedAt = (try? container.decode(String.self, forKey: .updatedAt)) ?? ""
        totalEarned = Self.decodeInt64(in: container, keys: [.totalEarned])
        totalSpent = Self.decodeInt64(in: container, keys: [.totalSpent]) ?? 0
    }

    private static func decodeInt64(
        in container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> Int64? {
        for key in keys {
            if let value = try? container.decode(Int64.self, forKey: key) {
                return value
            }
            if let value = try? container.decode(Int.self, forKey: key) {
                return Int64(value)
            }
            if let value = try? container.decode(String.self, forKey: key) {
                let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if let intValue = Int64(normalized) {
                    return intValue
                }
                let digits = normalized.filter(\.isNumber)
                if let intValue = Int64(digits) {
                    return intValue
                }
            }
        }
        return nil
    }
}

struct CoinTransaction: Decodable, Identifiable {
    let id: Int64
    let userID: Int64
    let change: Int64
    let balanceAfter: Int64
    let reason: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case uid
        case amount
        case delta
        case change
        case balanceAfter = "balance_after"
        case balance
        case reason
        case type
        case remark
        case createdAt = "created_at"
        case createdAtLegacy = "createdAt"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = Self.decodeInt64(in: container, keys: [.id]) ?? 0
        userID = Self.decodeInt64(in: container, keys: [.userID, .uid]) ?? 0
        change = Self.decodeInt64(in: container, keys: [.change, .amount, .delta]) ?? 0
        balanceAfter = Self.decodeInt64(in: container, keys: [.balanceAfter, .balance]) ?? 0
        reason =
            (try? container.decode(String.self, forKey: .reason))
            ?? (try? container.decode(String.self, forKey: .type))
            ?? (try? container.decode(String.self, forKey: .remark))
            ?? ""
        createdAt =
            (try? container.decode(String.self, forKey: .createdAt))
            ?? (try? container.decode(String.self, forKey: .createdAtLegacy))
            ?? ""
    }

    private static func decodeInt64(
        in container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> Int64? {
        for key in keys {
            if let value = try? container.decode(Int64.self, forKey: key) {
                return value
            }
            if let value = try? container.decode(Int.self, forKey: key) {
                return Int64(value)
            }
            if let value = try? container.decode(String.self, forKey: key) {
                let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if let intValue = Int64(normalized) {
                    return intValue
                }
                let digits = normalized.filter(\.isNumber)
                if let intValue = Int64(digits) {
                    return intValue
                }
            }
        }
        return nil
    }
}

struct WalletTransactionList: Decodable {
    let list: [CoinTransaction]
}

@MainActor
struct WalletService {
    /// 动态获取 baseURL，支持环境切换
    private var baseURL: URL {
        URL(string: APIConfig.baseURL)!
    }

    func fetchWallet(token: String) async throws -> WalletSummary {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/v1/wallet"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        let responseText = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(http.statusCode) else {
            ErrorReporter.report(
                message: "wallet fetch failed",
                errorCode: ErrorReporter.ERROR_BALANCE_CHECK_FAILED,
                screen: "Wallet",
                context: ["status": http.statusCode, "body": responseText]
            )
            if let error = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                throw ServiceError(errno: error.errno, message: error.errmsg)
            }
            throw ServiceError(errno: http.statusCode, message: "获取穿贝失败")
        }
        let envelope = try JSONDecoder().decode(APIEnvelope<WalletSummary>.self, from: data)
        guard envelope.errno == 0, let payload = envelope.data else {
            throw ServiceError(errno: envelope.errno, message: envelope.errmsg)
        }
        return payload
    }

    func consumeCoins(token: String, amount: Int64, reason: String) async throws -> WalletSummary {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/v1/wallet/consume"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "amount": amount,
            "reason": reason
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        let responseText = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(http.statusCode) else {
            ErrorReporter.report(
                message: "wallet consume failed",
                errorCode: ErrorReporter.ERROR_BALANCE_CHECK_FAILED,
                screen: "Wallet",
                context: ["status": http.statusCode, "body": responseText]
            )
            if let error = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                throw ServiceError(errno: error.errno, message: error.errmsg)
            }
            throw ServiceError(errno: http.statusCode, message: "扣减穿贝失败")
        }
        let envelope = try JSONDecoder().decode(APIEnvelope<WalletSummary>.self, from: data)
        guard envelope.errno == 0, let payload = envelope.data else {
            throw ServiceError(errno: envelope.errno, message: envelope.errmsg)
        }
        return payload
    }

    func rechargeCoins(token: String, amount: Int64, packageName: String) async throws -> WalletSummary {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/v1/wallet/recharge"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "amount": amount,
            "package": packageName
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        let responseText = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(http.statusCode) else {
            ErrorReporter.report(
                message: "wallet recharge failed",
                screen: "Wallet",
                context: ["status": http.statusCode, "body": responseText]
            )
            if let error = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                throw ServiceError(errno: error.errno, message: error.errmsg)
            }
            throw ServiceError(errno: http.statusCode, message: "充值失败")
        }
        let envelope = try JSONDecoder().decode(APIEnvelope<WalletSummary>.self, from: data)
        guard envelope.errno == 0, let payload = envelope.data else {
            throw ServiceError(errno: envelope.errno, message: envelope.errmsg)
        }
        return payload
    }

    func fetchTransactions(token: String) async throws -> [CoinTransaction] {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/v1/wallet/transactions"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        let responseText = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(http.statusCode) else {
            ErrorReporter.report(
                message: "wallet transactions failed",
                screen: "Wallet",
                context: ["status": http.statusCode, "body": responseText]
            )
            if let error = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                throw ServiceError(errno: error.errno, message: error.errmsg)
            }
            throw ServiceError(errno: http.statusCode, message: "获取消费记录失败")
        }
        if let arrayEnvelope = try? JSONDecoder().decode(APIEnvelope<[CoinTransaction]>.self, from: data) {
            guard arrayEnvelope.errno == 0 else {
                throw ServiceError(errno: arrayEnvelope.errno, message: arrayEnvelope.errmsg)
            }
            return arrayEnvelope.data ?? []
        }
        let listEnvelope = try JSONDecoder().decode(APIEnvelope<WalletTransactionList>.self, from: data)
        guard listEnvelope.errno == 0 else {
            throw ServiceError(errno: listEnvelope.errno, message: listEnvelope.errmsg)
        }
        return listEnvelope.data?.list ?? []
    }

    func rechargeWithAppleReceipt(token: String, receiptData: String, productID: String, transactionID: String) async throws -> WalletSummary {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/v1/wallet/recharge/apple"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "receipt_data": receiptData,
            "product_id": productID,
            "transaction_id": transactionID
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        let responseText = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(http.statusCode) else {
            ErrorReporter.report(
                message: "wallet apple recharge failed",
                screen: "Wallet",
                context: ["status": http.statusCode, "body": responseText]
            )
            if let error = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                throw ServiceError(errno: error.errno, message: error.errmsg)
            }
            throw ServiceError(errno: http.statusCode, message: "苹果支付验证失败")
        }
        let envelope = try JSONDecoder().decode(APIEnvelope<WalletSummary>.self, from: data)
        guard envelope.errno == 0, let payload = envelope.data else {
            throw ServiceError(errno: envelope.errno, message: envelope.errmsg)
        }
        return payload
    }
}
