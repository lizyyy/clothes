// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import AuthenticationServices
import CryptoKit
import UIKit

@MainActor
class AppleSignInManager: NSObject {
    static let shared = AppleSignInManager()

    private var completionHandler: ((Result<AppleSignInResponse, Error>) -> Void)?
    private var currentNonce: String?

    private override init() {
        super.init()
    }

    // 开始苹果登录流程
    func signIn(presentingViewController: UIViewController, completion: @escaping (Result<AppleSignInResponse, Error>) -> Void) {
        self.completionHandler = completion

        // 生成随机 nonce
        let nonce = randomNonceString()
        currentNonce = nonce

        // 创建授权请求
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        // 创建授权控制器
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }

    // 生成随机字符串
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    // SHA256 哈希
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AppleSignInManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            completionHandler?(.failure(AppleSignInError.invalidCredential))
            return
        }

        guard let nonce = currentNonce else {
            completionHandler?(.failure(AppleSignInError.invalidState))
            return
        }

        // 获取用户标识
        let appleID = appleIDCredential.user

        // 获取身份令牌
        guard let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            completionHandler?(.failure(AppleSignInError.invalidToken))
            return
        }

        // 获取用户全名
        var fullName = ""
        if let givenName = appleIDCredential.fullName?.givenName,
           let familyName = appleIDCredential.fullName?.familyName {
            fullName = givenName + " " + familyName
        }

        // 获取邮箱
        let email = appleIDCredential.email ?? ""

        let response = AppleSignInResponse(
            appleID: appleID,
            email: email,
            fullName: fullName,
            identityToken: identityToken,
            nonce: nonce
        )

        completionHandler?(.success(response))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completionHandler?(.failure(error))
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AppleSignInManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // 获取当前窗口
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window
        }
        return UIWindow()
    }
}

// MARK: - Types
struct AppleSignInResponse {
    let appleID: String
    let email: String
    let fullName: String
    let identityToken: String
    let nonce: String
}

enum AppleSignInError: Error {
    case invalidCredential
    case invalidState
    case invalidToken

    var localizedDescription: String {
        switch self {
        case .invalidCredential:
            return "无效的登录凭证"
        case .invalidState:
            return "登录状态异常"
        case .invalidToken:
            return "身份令牌无效"
        }
    }
}
