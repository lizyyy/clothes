// 文件input：系统框架、项目内模型/服务、用户输入
// 文件output：短信验证码登录卡片视图、状态更新与登录回调
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
// 最近更新：2026-03-12，补齐短信登录卡片内缺失的错误处理/设置跳转辅助方法，修复编译错误。
import Foundation
import SwiftUI
import UIKit

struct SMSLoginInlineCard: View {
    let onAuthSuccess: (AuthResponse, String) -> Void

    @Environment(\.openURL) private var openURL
    @State private var phone = ""
    @State private var code = ""
    @State private var agreedToPolicies = false
    @State private var isSending = false
    @State private var isSubmitting = false
    @State private var remainingSeconds = 0
    @State private var timer: Timer?
    @State private var errorMessage: String?
    @State private var showOpenSettingsAlert = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case phone
        case code
    }

    private var canSendCode: Bool {
        agreedToPolicies && !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSubmit: Bool {
        !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && code.count == 6
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("手机号验证码登录")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.titleText)

            Text("未注册手机号登录成功后将自动注册")
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedText)

            TextField("", text: $phone, prompt: Text("请输入手机号").foregroundStyle(Color.gray))
                .keyboardType(.phonePad)
                .appInputStyle()
                .focused($focusedField, equals: .phone)
                .accessibilityIdentifier("sms.inline.phone.field")

            HStack(spacing: 10) {
                TextField("", text: codeBinding, prompt: Text("请输入6位验证码").foregroundStyle(Color.gray))
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .appInputStyle()
                    .focused($focusedField, equals: .code)
                    .accessibilityIdentifier("sms.inline.code.field")

                Button {
                    Task { await sendCode() }
                } label: {
                    Text(remainingSeconds > 0 ? "\(remainingSeconds)s" : (isSending ? "发送中..." : "发送验证码"))
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Capsule().fill((remainingSeconds > 0 || isSending) ? Color.gray.opacity(0.22) : AppTheme.primary))
                        .foregroundStyle((remainingSeconds > 0 || isSending) ? Color.gray : Color.white)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.appPlain)
                .disabled(remainingSeconds > 0 || isSending || !canSendCode)
                .accessibilityIdentifier("sms.inline.send.button")
            }

            Button {
                agreedToPolicies.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: agreedToPolicies ? "largecircle.fill.circle" : "circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(agreedToPolicies ? AppTheme.primary : AppTheme.mutedText)
                    Text("我已阅读并同意《服务协议》《隐私政策》")
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedText)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            Button {
                Task { await submit() }
            } label: {
                Text(isSubmitting ? "登录中..." : "验证码登录")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.primary)
                    .foregroundStyle(Color.white)
                    .clipShape(Capsule())
                    .contentShape(Rectangle())
            }
            .buttonStyle(.appPlain)
            .disabled(isSubmitting || !canSubmit || !agreedToPolicies)
            .opacity((canSubmit && agreedToPolicies) ? 1 : 0.45)
            .accessibilityIdentifier("sms.inline.submit.button")

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.78, green: 0.20, blue: 0.20))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.94)))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { focusedField = nil }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
            }
        }
        .onDisappear { stopTimer() }
        .alert("网络不可用", isPresented: $showOpenSettingsAlert) {
            Button("去设置") {
                openAppSettings(with: openURL)
            }
            Button("知道了", role: .cancel) {}
        } message: {
            Text("请在系统设置中为 Clothes 开启“无线局域网与蜂窝网络”。")
        }
    }

    private var codeBinding: Binding<String> {
        Binding(
            get: { code },
            set: { newValue in
                code = String(newValue.filter(\.isNumber).prefix(6))
            }
        )
    }

    private func sendCode() async {
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPhone.isEmpty else {
            errorMessage = "请先输入手机号。"
            return
        }
        guard agreedToPolicies else {
            errorMessage = "请先同意服务协议与隐私政策。"
            return
        }
        isSending = true
        defer { isSending = false }
        do {
            let response = try await UserAuthService().sendSMSCode(phone: trimmedPhone, purpose: "login")
            errorMessage = nil
            showOpenSettingsAlert = false
            startTimer(seconds: max(60, response.nextRetrySeconds))
        } catch {
            errorMessage = resolvedSMSErrorMessage(error)
            showOpenSettingsAlert = shouldSuggestOpenSettings(for: error)
        }
    }

    private func submit() async {
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPhone.isEmpty, trimmedCode.count == 6 else {
            errorMessage = "请输入手机号和6位验证码。"
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let response = try await UserAuthService().loginBySMS(phone: trimmedPhone, code: trimmedCode)
            errorMessage = nil
            onAuthSuccess(response, trimmedPhone)
        } catch {
            if shouldFallbackToSMSRegister(error) {
                do {
                    let response = try await UserAuthService().registerBySMS(phone: trimmedPhone, code: trimmedCode)
                    errorMessage = nil
                    showOpenSettingsAlert = false
                    onAuthSuccess(response, trimmedPhone)
                    return
                } catch {
                    errorMessage = resolvedSMSErrorMessage(error)
                    showOpenSettingsAlert = shouldSuggestOpenSettings(for: error)
                    return
                }
            }
            errorMessage = resolvedSMSErrorMessage(error)
            showOpenSettingsAlert = shouldSuggestOpenSettings(for: error)
        }
    }

    private func shouldSuggestOpenSettings(for error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorDataNotAllowed,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorCannotFindHost,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorTimedOut:
                return true
            default:
                break
            }
        }

        let text = error.localizedDescription.lowercased()
        return text.contains("the internet connection appears to be offline")
            || text.contains("offline")
            || text.contains("网络")
    }

    private func resolvedSMSErrorMessage(_ error: Error) -> String {
        if shouldSuggestOpenSettings(for: error) {
            return "网络不可用，请检查系统设置中 Clothes 的“无线局域网与蜂窝网络”权限。"
        }
        return error.localizedDescription
    }

    private func openAppSettings(with openURL: OpenURLAction) {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(settingsURL)
    }

    private func shouldFallbackToSMSRegister(_ error: Error) -> Bool {
        let text = error.localizedDescription.lowercased()
        return text.contains("未注册")
            || text.contains("手机号未注册")
            || text.contains("user not found")
            || text.contains("not registered")
    }

    private func startTimer(seconds: Int) {
        stopTimer()
        remainingSeconds = max(0, seconds)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                stopTimer()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
