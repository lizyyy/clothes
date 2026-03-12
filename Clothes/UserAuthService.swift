// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  UserAuthService.swift
//  Clothes
//
//  Created by Codex on 2026/1/16.
//

import Foundation

struct UserProfilePayload: Codable {
    var nickname: String
    var username: String
    var password: String
    var gender: String?
    var height: String?
    var size: String?
    var zodiac: String?
    var mbti: String?
    var colorPreference: String?
    var weight: String?
}

struct UserProfile: Decodable {
    let id: Int64
    let uid: String
    let email: String
    let name: String
    let gender: String
    let height: String
    let weight: String
    let size: String
    let zodiac: String
    let mbti: String
    let colorPreference: String
    let avatarURL: String

    private enum CodingKeys: String, CodingKey {
        case id
        case uid
        case email
        case username
        case nickname
        case name
        case gender
        case height
        case weight
        case size
        case zodiac
        case mbti
        case colorPreference = "color_preference"
        case colorPreferenceLegacy = "colorPreference"
        case avatarURL = "avatar_url"
        case avatarURLLegacy = "avatarURL"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(Int64.self, forKey: .id)) ?? 0
        if let uidString = try? container.decode(String.self, forKey: .uid) {
            uid = uidString
        } else if let uidInt = try? container.decode(Int64.self, forKey: .uid) {
            uid = String(uidInt)
        } else {
            uid = ""
        }
        email = (try? container.decode(String.self, forKey: .email)) ?? ""
        name =
            (try? container.decode(String.self, forKey: .name))
            ?? (try? container.decode(String.self, forKey: .nickname))
            ?? (try? container.decode(String.self, forKey: .username))
            ?? ""
        if let genderText = try? container.decode(String.self, forKey: .gender) {
            gender = genderText
        } else if let genderInt = try? container.decode(Int.self, forKey: .gender) {
            gender = String(genderInt)
        } else {
            gender = ""
        }
        height = (try? container.decode(String.self, forKey: .height)) ?? ""
        weight = (try? container.decode(String.self, forKey: .weight)) ?? ""
        size = (try? container.decode(String.self, forKey: .size)) ?? ""
        zodiac = (try? container.decode(String.self, forKey: .zodiac)) ?? ""
        mbti = (try? container.decode(String.self, forKey: .mbti)) ?? ""
        colorPreference =
            (try? container.decode(String.self, forKey: .colorPreference))
            ?? (try? container.decode(String.self, forKey: .colorPreferenceLegacy))
            ?? ""
        avatarURL =
            (try? container.decode(String.self, forKey: .avatarURL))
            ?? (try? container.decode(String.self, forKey: .avatarURLLegacy))
            ?? ""
    }
}

struct SMSCodeSendResponse: Codable {
    let nextRetrySeconds: Int
    let dailyLimit: Int
    let debugCode: String?

    enum CodingKeys: String, CodingKey {
        case nextRetrySeconds = "next_retry_seconds"
        case dailyLimit = "daily_limit"
        case debugCode = "debug_code"
    }
}

struct PasswordResetVerifyResponse: Codable {
    let ok: Bool
    let resetToken: String

    enum CodingKeys: String, CodingKey {
        case ok
        case resetToken = "reset_token"
    }
}

private enum SMSClientIDStore {
    private static let key = "sms_client_id"

    static func value() -> String {
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: key)
        return generated
    }
}

@MainActor
struct UserAuthService {
    static let uiTestingSMSPendingToken = "__ui_testing_sms_pending__"

    /// 动态获取 baseURL，支持环境切换
    private var baseURL: URL {
        URL(string: APIConfig.baseURL)!
    }

    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTesting")
    }

    // MARK: - Apple Receipt Recharge
    func rechargeWithAppleReceipt(token: String, receiptData: String, productID: String, transactionID: UInt64) async throws -> WalletSummary {
        let url = baseURL.appendingPathComponent("api/v1/wallet/recharge/apple")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "receipt_data": receiptData,
            "product_id": productID,
            "transaction_id": String(transactionID)
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            if let error = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                throw ServiceError(errno: error.errno, message: error.errmsg)
            }
            throw ServiceError(errno: http.statusCode, message: "充值验证失败")
        }
        let envelope = try JSONDecoder().decode(APIEnvelope<WalletSummary>.self, from: data)
        guard envelope.errno == 0, let payload = envelope.data else {
            throw ServiceError(errno: envelope.errno, message: envelope.errmsg)
        }
        return payload
    }

    func register(payload: UserProfilePayload) async throws -> AuthResponse {
        let url = self.baseURL.appendingPathComponent("api/v1/auth/register")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 转换 gender 为 int8 (0未知 1男 2女 3中性)
        let genderInt = genderValue(from: payload.gender ?? "")

        let body: [String: Any] = [
            "username": payload.username,
            "password": payload.password,
            "nickname": payload.nickname,
            "gender": genderInt,
            "height": payload.height ?? "",
            "weight": payload.weight ?? "",
            "size": payload.size ?? "",
            "zodiac": payload.zodiac ?? "",
            "mbti": payload.mbti ?? "",
            "colorPreference": payload.colorPreference ?? ""
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        let responseText = String(data: data, encoding: .utf8) ?? ""
#if DEBUG
        let redactedBody = body.merging(["password": "***"]) { current, _ in current }
        print("Auth register request:", url.absoluteString, redactedBody)
        print("Auth register response status:", http.statusCode)
#endif
        guard (200..<300).contains(http.statusCode) else {
            ErrorReporter.report(
                message: "auth register failed",
                errorCode: ErrorReporter.ERROR_AUTH_FAILED,
                screen: "Register",
                context: ["status": http.statusCode, "body": responseText, "email": payload.username]
            )
            if let error = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                throw ServiceError(errno: error.errno, message: error.errmsg)
            }
            let message = String(data: data, encoding: .utf8) ?? "注册失败"
            throw NSError(domain: "Auth", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }
        let envelope = try JSONDecoder().decode(APIEnvelope<AuthResponse>.self, from: data)
        guard envelope.errno == 0, let payload = envelope.data else {
            throw ServiceError(errno: envelope.errno, message: envelope.errmsg)
        }
        return payload
    }

    func login(username: String, password: String) async throws -> AuthResponse {
        let url = self.baseURL.appendingPathComponent("api/v1/auth/login")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "username": username,
            "password": password
        ]
        request.httpBody = try JSONEncoder().encode(body)

        // 详细日志记录
        let debugInfo = [
            "url": url.absoluteString,
            "username": username,
            "baseURL": self.baseURL.absoluteString
        ]
        print("🔐 [Login] Request:", debugInfo)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            print("🔐 [Login] Error: Invalid response")
            throw URLError(.badServerResponse)
        }
        let responseText = String(data: data, encoding: .utf8) ?? ""
        print("🔐 [Login] Response status:", http.statusCode)
        print("🔐 [Login] Response body:", responseText)

        guard (200..<300).contains(http.statusCode) else {
            ErrorReporter.report(
                message: "auth login failed",
                errorCode: ErrorReporter.ERROR_AUTH_FAILED,
                screen: "Login",
                context: [
                    "status": http.statusCode,
                    "body": responseText,
                    "username": username,
                    "baseURL": self.baseURL.absoluteString,
                    "requestURL": url.absoluteString
                ]
            )
            if let error = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                print("🔐 [Login] API Error:", error.errmsg)
                throw ServiceError(errno: error.errno, message: error.errmsg)
            }
            let message = String(data: data, encoding: .utf8) ?? "登录失败"
            throw NSError(domain: "Auth", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }
        let envelope = try JSONDecoder().decode(APIEnvelope<AuthResponse>.self, from: data)
        guard envelope.errno == 0, let payload = envelope.data else {
            print("🔐 [Login] Business Error:", envelope.errmsg)
            throw ServiceError(errno: envelope.errno, message: envelope.errmsg)
        }
        print("🔐 [Login] Success! Token received")
        return payload
    }

    func sendSMSCode(phone: String, purpose: String) async throws -> SMSCodeSendResponse {
        let url = self.baseURL.appendingPathComponent("api/v1/auth/sms/send")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SMSClientIDStore.value(), forHTTPHeaderField: "X-Client-ID")
        request.httpBody = try JSONEncoder().encode([
            "phone": phone.trimmingCharacters(in: .whitespacesAndNewlines),
            "purpose": purpose
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            // Backward compatibility for dev environments where sms routes are not deployed yet.
            if isUITesting, http.statusCode == 404 {
                return SMSCodeSendResponse(nextRetrySeconds: 0, dailyLimit: 3, debugCode: "123456")
            }
            if let error = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                throw ServiceError(errno: error.errno, message: error.errmsg)
            }
            throw ServiceError(errno: http.statusCode, message: "发送验证码失败")
        }
        let envelope = try JSONDecoder().decode(APIEnvelope<SMSCodeSendResponse>.self, from: data)
        guard envelope.errno == 0, let payload = envelope.data else {
            throw ServiceError(errno: envelope.errno, message: envelope.errmsg)
        }
        return payload
    }

    func loginBySMS(phone: String, code: String) async throws -> AuthResponse {
        let url = self.baseURL.appendingPathComponent("api/v1/auth/sms/login")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode([
            "phone": phone.trimmingCharacters(in: .whitespacesAndNewlines),
            "code": code.trimmingCharacters(in: .whitespacesAndNewlines)
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            if let error = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                throw ServiceError(errno: error.errno, message: error.errmsg)
            }
            throw ServiceError(errno: http.statusCode, message: "短信登录失败")
        }
        let envelope = try JSONDecoder().decode(APIEnvelope<AuthResponse>.self, from: data)
        guard envelope.errno == 0, let payload = envelope.data else {
            throw ServiceError(errno: envelope.errno, message: envelope.errmsg)
        }
        return payload
    }

    func registerBySMS(
        phone: String,
        code: String,
        username: String = "",
        nickname: String = "",
        password: String = ""
    ) async throws -> AuthResponse {
        let url = self.baseURL.appendingPathComponent("api/v1/auth/sms/register")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: String] = [
            "phone": phone.trimmingCharacters(in: .whitespacesAndNewlines),
            "code": code.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedUsername.isEmpty { body["username"] = trimmedUsername }
        if !trimmedNickname.isEmpty { body["nickname"] = trimmedNickname }
        if !trimmedPassword.isEmpty { body["password"] = trimmedPassword }
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            // UITest fallback when backend does not expose sms register route.
            if isUITesting, http.statusCode == 404 {
                return AuthResponse(
                    token: Self.uiTestingSMSPendingToken,
                    user: UserInfo(uid: nil, username: phone.trimmingCharacters(in: .whitespacesAndNewlines), email: nil, nickname: nil),
                    is_new_user: true
                )
            }
            if let error = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                throw ServiceError(errno: error.errno, message: error.errmsg)
            }
            throw ServiceError(errno: http.statusCode, message: "短信注册失败")
        }
        let envelope = try JSONDecoder().decode(APIEnvelope<AuthResponse>.self, from: data)
        guard envelope.errno == 0, let result = envelope.data else {
            throw ServiceError(errno: envelope.errno, message: envelope.errmsg)
        }
        return result
    }

    func completeSMSRegistration(token: String, username: String, nickname: String, password: String) async throws -> UserProfile {
        let url = self.baseURL.appendingPathComponent("api/v1/auth/sms/complete-registration")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode([
            "username": username.trimmingCharacters(in: .whitespacesAndNewlines),
            "nickname": nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            "password": password
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            if let error = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                throw ServiceError(errno: error.errno, message: error.errmsg)
            }
            throw ServiceError(errno: http.statusCode, message: "补全注册信息失败")
        }
        let envelope = try JSONDecoder().decode(APIEnvelope<UserProfile>.self, from: data)
        guard envelope.errno == 0, let payload = envelope.data else {
            throw ServiceError(errno: envelope.errno, message: envelope.errmsg)
        }
        return payload
    }

    func registerBySMS(payload: UserProfilePayload, phone: String, code: String) async throws -> AuthResponse {
        try await registerBySMS(
            phone: phone,
            code: code,
            username: payload.username,
            nickname: payload.nickname,
            password: payload.password
        )
    }

    func fetchProfile(token: String) async throws -> UserProfile {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/v1/auth/profile"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            let responseText = String(data: data, encoding: .utf8) ?? ""
            ErrorReporter.report(
                message: "profile fetch failed",
                errorCode: ErrorReporter.ERROR_PROFILE_UPDATE_FAILED,
                screen: "Profile",
                context: ["status": http.statusCode, "body": responseText]
            )
            if let error = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                throw ServiceError(errno: error.errno, message: error.errmsg)
            }
            throw ServiceError(errno: http.statusCode, message: "获取用户信息失败")
        }
        let envelope = try JSONDecoder().decode(APIEnvelope<UserProfile>.self, from: data)
        guard envelope.errno == 0, let payload = envelope.data else {
            throw ServiceError(errno: envelope.errno, message: envelope.errmsg)
        }
        return payload
    }

    func updateProfile(
        token: String,
        nickname: String,
        genderText: String,
        height: String,
        weight: String,
        size: String,
        zodiac: String,
        mbti: String,
        colorPreference: String
    ) async throws -> UserProfile {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/v1/auth/profile"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let genderCode = genderValue(from: genderText)

        let body: [String: Any] = [
            "nickname": nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            "gender": genderCode,
            "height": height.trimmingCharacters(in: .whitespacesAndNewlines),
            "weight": weight.trimmingCharacters(in: .whitespacesAndNewlines),
            "size": size.trimmingCharacters(in: .whitespacesAndNewlines),
            "zodiac": zodiac.trimmingCharacters(in: .whitespacesAndNewlines),
            "mbti": mbti.trimmingCharacters(in: .whitespacesAndNewlines),
            "color_preference": colorPreference.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            if let error = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                throw ServiceError(errno: error.errno, message: error.errmsg)
            }
            throw ServiceError(errno: http.statusCode, message: "更新用户资料失败")
        }
        let envelope = try JSONDecoder().decode(APIEnvelope<UserProfile>.self, from: data)
        guard envelope.errno == 0, let payload = envelope.data else {
            throw ServiceError(errno: envelope.errno, message: envelope.errmsg)
        }
        return payload
    }

    func updateAvatar(token: String, avatarURL: String) async throws {
        let url = baseURL.appendingPathComponent("api/v1/auth/profile/avatar")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(["avatar_url": avatarURL])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            let responseText = String(data: data, encoding: .utf8) ?? ""
            ErrorReporter.report(
                message: "avatar update failed",
                errorCode: ErrorReporter.ERROR_AVATAR_UPLOAD_FAILED,
                screen: "Profile",
                context: ["status": http.statusCode, "body": responseText]
            )
            if let error = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                throw ServiceError(errno: error.errno, message: error.errmsg)
            }
            throw ServiceError(errno: http.statusCode, message: "更新头像失败")
        }
        let envelope = try JSONDecoder().decode(APIEnvelope<[String: String]>.self, from: data)
        guard envelope.errno == 0 else {
            throw ServiceError(errno: envelope.errno, message: envelope.errmsg)
        }
    }

    private func genderValue(from raw: String) -> Int {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "1", "男", "male", "m":
            return 1
        case "2", "女", "female", "f":
            return 2
        case "3", "中性", "neutral", "non-binary", "nonbinary":
            return 3
        default:
            return 0
        }
    }
    
    // 忘记密码重置
    func resetPassword(phone: String, code: String, username: String, password: String) async throws {
        let url = baseURL.appendingPathComponent("api/v1/auth/sms/reset-password")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "phone": phone.trimmingCharacters(in: .whitespacesAndNewlines),
            "code": code.trimmingCharacters(in: .whitespacesAndNewlines),
            "username": username.trimmingCharacters(in: .whitespacesAndNewlines),
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            if let error = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                throw ServiceError(errno: error.errno, message: error.errmsg)
            }
            throw ServiceError(errno: http.statusCode, message: "密码重置失败")
        }
    }

    func sendPasswordResetSMS(phone: String) async throws {
        let url = baseURL.appendingPathComponent("api/v1/auth/password-reset/sms/send")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SMSClientIDStore.value(), forHTTPHeaderField: "X-Client-ID")

        let body: [String: String] = [
            "country_code": "86",
            "phone": phone.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            if let error = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                throw ServiceError(errno: error.errno, message: error.errmsg)
            }
            throw ServiceError(errno: http.statusCode, message: "发送验证码失败")
        }
        let envelope = try JSONDecoder().decode(APIEnvelope<[String: Bool]>.self, from: data)
        guard envelope.errno == 0 else {
            throw ServiceError(errno: envelope.errno, message: envelope.errmsg)
        }
    }

    func verifyPasswordResetSMS(phone: String, code: String) async throws -> PasswordResetVerifyResponse {
        let url = baseURL.appendingPathComponent("api/v1/auth/password-reset/sms/verify")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SMSClientIDStore.value(), forHTTPHeaderField: "X-Client-ID")

        let body: [String: String] = [
            "country_code": "86",
            "phone": phone.trimmingCharacters(in: .whitespacesAndNewlines),
            "code": code.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            if let error = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                throw ServiceError(errno: error.errno, message: error.errmsg)
            }
            throw ServiceError(errno: http.statusCode, message: "验证码校验失败")
        }
        let envelope = try JSONDecoder().decode(APIEnvelope<PasswordResetVerifyResponse>.self, from: data)
        guard envelope.errno == 0, let payload = envelope.data else {
            throw ServiceError(errno: envelope.errno, message: envelope.errmsg)
        }
        return payload
    }

    func confirmPasswordReset(resetToken: String, newPassword: String) async throws {
        let url = baseURL.appendingPathComponent("api/v1/auth/password-reset/confirm")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "reset_token": resetToken.trimmingCharacters(in: .whitespacesAndNewlines),
            "new_password": newPassword
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            if let error = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                throw ServiceError(errno: error.errno, message: error.errmsg)
            }
            throw ServiceError(errno: http.statusCode, message: "重置密码失败")
        }
        let envelope = try JSONDecoder().decode(APIEnvelope<[String: Bool]>.self, from: data)
        guard envelope.errno == 0 else {
            throw ServiceError(errno: envelope.errno, message: envelope.errmsg)
        }
    }

    func changePassword(token: String, newPassword: String, confirmPassword: String) async throws {
        let url = baseURL.appendingPathComponent("api/v1/auth/password")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: String] = [
            "new_password": newPassword,
            "confirm_password": confirmPassword
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            if let error = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                throw ServiceError(errno: error.errno, message: error.errmsg)
            }
            throw ServiceError(errno: http.statusCode, message: "修改密码失败")
        }
        let envelope = try JSONDecoder().decode(APIEnvelope<[String: Bool]>.self, from: data)
        guard envelope.errno == 0 else {
            throw ServiceError(errno: envelope.errno, message: envelope.errmsg)
        }
    }

    func registerWithPassword(payload: UserProfilePayload, phone: String, code: String, password: String) async throws -> AuthResponse {
        try await registerBySMS(
            phone: phone,
            code: code,
            username: payload.username,
            nickname: payload.nickname,
            password: password
        )
    }

    // 苹果登录
    func appleSignIn(appleID: String, email: String, fullName: String, identityToken: String) async throws -> AuthResponse {
        let url = baseURL.appendingPathComponent("api/v1/auth/apple")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "apple_id": appleID,
            "email": email,
            "full_name": fullName,
            "identity_token": identityToken
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            ErrorReporter.report(
                message: "apple sign in failed",
                errorCode: ErrorReporter.ERROR_APPLE_SIGNIN_FAILED,
                screen: "Login",
                context: ["status": http.statusCode]
            )
            if let error = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                throw ServiceError(errno: error.errno, message: error.errmsg)
            }
            throw ServiceError(errno: http.statusCode, message: "苹果登录失败")
        }
        let envelope = try JSONDecoder().decode(APIEnvelope<AuthResponse>.self, from: data)
        guard envelope.errno == 0, let payload = envelope.data else {
            throw ServiceError(errno: envelope.errno, message: envelope.errmsg)
        }
        return payload
    }
}
