// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import Foundation
import UIKit

struct ErrorReporter {
    // Error codes: F0001 - F9999 (5 digits, F prefix)
    static let ERROR_AVATAR_UPLOAD_FAILED = "F0001"
    static let ERROR_EXPLORE_DATA_LOAD_FAILED = "F0002"
    static let ERROR_PROFILE_UPDATE_FAILED = "F0003"
    static let ERROR_TRYON_IMAGE_UPLOAD_FAILED = "F0004"
    static let ERROR_TRYON_GENERATION_FAILED = "F0005"
    static let ERROR_BALANCE_CHECK_FAILED = "F0006"
    static let ERROR_NETWORK_REQUEST_FAILED = "F0007"
    static let ERROR_AUTH_FAILED = "F0008"
    static let ERROR_DATA_PARSE_FAILED = "F0009"
    static let ERROR_FILE_UPLOAD_FAILED = "F0010"
    static let ERROR_APPLE_SIGNIN_FAILED = "F0011"
    static let ERROR_IAP_INIT_FAILED = "F0012"
    static let ERROR_IAP_TRANSACTION_FAILED = "F0013"
    static let ERROR_INVALID_CREDENTIALS = "F0014"
    static let ERROR_SERVER_UNAVAILABLE = "F0015"
    static let ERROR_UNKNOWN_ERROR = "F9999"

    static func report(
        message: String,
        errorCode: String? = nil,
        stack: String? = nil,
        screen: String? = nil,
        severity: String = "error",
        context: [String: Any]? = nil
    ) {
        Task.detached(priority: .background) {
            let snapshot = await MainActor.run {
                (
                    baseURL: APIConfig.baseURL,
                    appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
                    osVersion: UIDevice.current.systemVersion,
                    device: UIDevice.current.model
                )
            }

            guard let url = URL(string: snapshot.baseURL)?.appendingPathComponent("api/v1/client-errors") else {
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            if let token = UserDefaults.standard.string(forKey: "auth_token"), !token.isEmpty {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            var payload: [String: Any] = [
                "message": message,
                "stack": stack ?? "",
                "screen": screen ?? "",
                "severity": severity,
                "app_version": snapshot.appVersion,
                "os_version": snapshot.osVersion,
                "device": snapshot.device,
                "context": context ?? [:]
            ]
            if let errorCode = errorCode {
                payload["error_code"] = errorCode
            }
            guard let body = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
                return
            }
            request.httpBody = body
            _ = try? await URLSession.shared.data(for: request)
        }
    }
}
