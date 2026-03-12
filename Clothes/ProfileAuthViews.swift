// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import Foundation
import SwiftUI
import UIKit

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

struct RegistrationPrompt: View {
    let onRegister: () -> Void
    let onLogin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("请先登录")
                .font(.headline)
                .foregroundStyle(AppTheme.bodyText)
            Text("登录后可同步个人偏好与推荐配置。")
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedText)
            HStack(spacing: 12) {
                Button("注册", action: onRegister)
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(AppTheme.primary))
                    .foregroundStyle(Color.white)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("profile.register.button")

                Button("已有账号登录", action: onLogin)
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.white))
                    .overlay(Capsule().stroke(Color(red: 0.18, green: 0.18, blue: 0.20), lineWidth: 1))
                    .foregroundStyle(Color(red: 0.18, green: 0.18, blue: 0.20))
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("profile.login.button")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.94)))
    }
}

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var username: String
    @Binding var password: String
    let onLogin: () -> Void
    let onOpenSMS: () -> Void
    var showsCloseButton: Bool = true
    @FocusState private var focusField: Field?

    private enum Field {
        case username
        case password
    }

    private var isUITestMode: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTesting")
    }

    var body: some View {
        if showsCloseButton {
            NavigationStack {
                loginContent
                    .navigationTitle("登录账号")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("关闭") { dismiss() }
                                .toolbarDoneButton()
                        }
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("完成") { focusField = nil }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                        }
                    }
            }
        } else {
            loginContent
        }
    }

    private var loginContent: some View {
        ZStack {
            WarmBackdrop()
            VStack(alignment: .leading, spacing: 18) {
                Text("欢迎回来")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppTheme.titleText)
                Text("使用账号密码登录")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedText)
                TextField("", text: $username, prompt: Text("用户名或手机号").foregroundStyle(Color.gray))
                    .appInputStyle()
                    .focused($focusField, equals: .username)
                    .accessibilityIdentifier("login.username.field")
                passwordField
                Button {
                    focusField = nil
                    onLogin()
                } label: {
                    Text("登录")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.primary)
                        .foregroundStyle(Color.white)
                        .clipShape(Capsule())
                        .contentShape(Rectangle())
                }
                .buttonStyle(.appPlain)
                .accessibilityIdentifier("login.submit.button")

                HStack(spacing: 14) {
                    iconActionButton(
                        icon: "message.fill",
                        title: "验证码登录",
                        accessibilityID: "login.sms.button"
                    ) {
                        focusField = nil
                        onOpenSMS()
                    }
                }

                Spacer()
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private var passwordField: some View {
        if isUITestMode {
            TextField("", text: $password, prompt: Text("密码").foregroundStyle(Color.gray))
                .appInputStyle()
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .focused($focusField, equals: .password)
                .accessibilityIdentifier("login.password.field")
        } else {
            SecureField("", text: $password, prompt: Text("密码").foregroundStyle(Color.gray))
                .appInputStyle()
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .focused($focusField, equals: .password)
                .accessibilityIdentifier("login.password.field")
        }
    }

    private func iconActionButton(icon: String, title: String, accessibilityID: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.primary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.9)))
                    .overlay(Circle().stroke(Color.gray.opacity(0.25), lineWidth: 1))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(AppTheme.bodyText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID)
    }

}

struct SMSAuthSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let onAuthSuccess: (AuthResponse, String) -> Void

    @State private var phone = ""
    @State private var code = ""
    @State private var agreedToPolicies = false
    @State private var step: SMSAuthStep = .phoneInput
    @State private var sentPhone = ""
    @State private var isSending = false
    @State private var isSubmitting = false
    @State private var remainingSeconds = 0
    @State private var timer: Timer?
    @State private var errorMessage: String?
    @State private var suggestOpenSettingsForError = false
    @FocusState private var focusedField: Field?
    @FocusState private var isCodeInputFocused: Bool

    private enum SMSAuthStep {
        case phoneInput
        case codeInput
    }

    private enum Field {
        case phone
    }

    private var maskedSentPhone: String {
        let trimmed = sentPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 11 else { return trimmed }
        let prefix = trimmed.prefix(3)
        let suffix = trimmed.suffix(2)
        return "\(prefix)******\(suffix)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackdrop()
                Group {
                    switch step {
                    case .phoneInput:
                        phoneInputStep
                    case .codeInput:
                        codeInputStep
                    }
                }
                .padding(20)
            }
            .navigationTitle(step == .phoneInput ? "手机号验证码登录" : "输入验证码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(step == .codeInput ? "返回" : "关闭") {
                        if step == .codeInput {
                            step = .phoneInput
                            code = ""
                            isCodeInputFocused = false
                        } else {
                            stopTimer()
                            dismiss()
                        }
                    }
                    .toolbarDoneButton()
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        focusedField = nil
                        isCodeInputFocused = false
                    }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                }
            }
        }
        .onDisappear { stopTimer() }
        .alert(
            "提示",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { _ in
                    errorMessage = nil
                    suggestOpenSettingsForError = false
                }
            )
        ) {
            if suggestOpenSettingsForError {
                Button("去设置") {
                    suggestOpenSettingsForError = false
                    openAppSettings(with: openURL)
                }
            }
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var phoneInputStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("", text: $phone, prompt: Text("请输入手机号").foregroundStyle(Color.gray))
                .keyboardType(.phonePad)
                .appInputStyle()
                .focused($focusedField, equals: .phone)
                .accessibilityIdentifier("sms.login.phone.field")

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
                Task { await sendCodeAndContinue() }
            } label: {
                Text(isSending ? "发送中..." : "发送验证码")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.primary)
                    .foregroundStyle(Color.white)
                    .clipShape(Capsule())
                    .contentShape(Rectangle())
            }
            .buttonStyle(.appPlain)
            .disabled(isSending || !agreedToPolicies || phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity((agreedToPolicies && !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 1 : 0.45)
            .accessibilityIdentifier("sms.login.send.button")

            Spacer()
        }
    }

    private var codeInputStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("验证码已发送到：\(maskedSentPhone)")
                .font(.subheadline)
                .foregroundStyle(AppTheme.bodyText)

            codeBoxes
                .onTapGesture { isCodeInputFocused = true }

            TextField("", text: codeBinding)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .frame(maxWidth: .infinity)
                .frame(height: 2)
                .opacity(0.02)
                .focused($isCodeInputFocused)
                .accessibilityIdentifier("sms.login.code.field")

            HStack(spacing: 8) {
                Text(remainingSeconds > 0 ? "还有 \(remainingSeconds)s 可重新发送验证码" : "可重新发送验证码")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedText)
                Spacer()
                Button(remainingSeconds > 0 ? "\(remainingSeconds)s" : "重新发送") {
                    Task { await resendCode() }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(remainingSeconds > 0 ? Color.gray : AppTheme.primary)
                .disabled(remainingSeconds > 0 || isSending)
            }

            Button {
                Task { await submit() }
            } label: {
                Text(isSubmitting ? "登录中..." : "登录")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.primary)
                    .foregroundStyle(Color.white)
                    .clipShape(Capsule())
                    .contentShape(Rectangle())
            }
            .buttonStyle(.appPlain)
            .disabled(isSubmitting || code.count != 6)
            .opacity(code.count == 6 ? 1 : 0.45)
            .accessibilityIdentifier("sms.login.submit.button")

            Spacer()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isCodeInputFocused = true
            }
        }
    }

    private var codeBoxes: some View {
        HStack(spacing: 10) {
            ForEach(0..<6, id: \.self) { idx in
                let value = idx < code.count ? String(code[code.index(code.startIndex, offsetBy: idx)]) : ""
                Text(value)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.95))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.35), lineWidth: 1)
                    )
            }
        }
    }

    private var codeBinding: Binding<String> {
        Binding(
            get: { code },
            set: { newValue in
                let digits = newValue.filter(\.isNumber)
                code = String(digits.prefix(6))
            }
        )
    }

    private func sendCodeAndContinue() async {
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
            sentPhone = trimmedPhone
            code = ""
            errorMessage = nil
            suggestOpenSettingsForError = false
            step = .codeInput
            startTimer(seconds: max(60, response.nextRetrySeconds))
        } catch {
            errorMessage = resolvedSMSErrorMessage(error)
            suggestOpenSettingsForError = shouldSuggestOpenSettings(for: error)
        }
    }

    private func resendCode() async {
        guard !sentPhone.isEmpty else { return }
        isSending = true
        defer { isSending = false }
        do {
            let response = try await UserAuthService().sendSMSCode(phone: sentPhone, purpose: "login")
            errorMessage = nil
            suggestOpenSettingsForError = false
            startTimer(seconds: max(60, response.nextRetrySeconds))
        } catch {
            errorMessage = resolvedSMSErrorMessage(error)
            suggestOpenSettingsForError = shouldSuggestOpenSettings(for: error)
        }
    }

    private func submit() async {
        let trimmedPhone = sentPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPhone.isEmpty, !trimmedCode.isEmpty else {
            errorMessage = "请输入手机号和验证码。"
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let response = try await UserAuthService().loginBySMS(phone: trimmedPhone, code: trimmedCode)
            onAuthSuccess(response, trimmedPhone)
            dismiss()
        } catch {
            if shouldFallbackToSMSRegister(error) {
                do {
                    let response = try await UserAuthService().registerBySMS(phone: trimmedPhone, code: trimmedCode)
                    onAuthSuccess(response, trimmedPhone)
                    dismiss()
                    return
                } catch {
                    errorMessage = resolvedSMSErrorMessage(error)
                    suggestOpenSettingsForError = shouldSuggestOpenSettings(for: error)
                    return
                }
            }
            errorMessage = resolvedSMSErrorMessage(error)
            suggestOpenSettingsForError = shouldSuggestOpenSettings(for: error)
        }
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

struct SMSProfileCompletionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var gender: String
    @Binding var height: String
    @Binding var weight: String
    @Binding var size: String
    @Binding var zodiac: String
    @Binding var mbti: String
    @Binding var colorPreference: String
    let onSubmit: () async throws -> Void

    @State private var step: ProfileCompletionStep = .body
    @State private var activeWheelField: SMSProfileWheelField?
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private enum ProfileCompletionStep {
        case body
        case preference
    }

    private enum SMSProfileWheelField: String, Identifiable {
        case gender
        case size
        case zodiac
        case mbti
        case color

        var id: String { rawValue }

        var title: String {
            switch self {
            case .gender: return "性别"
            case .size: return "尺码"
            case .zodiac: return "星座"
            case .mbti: return "MBTI"
            case .color: return "色系"
            }
        }
    }

    private let genderOptions = ["女", "男", "中性"]
    private let sizeOptions = ["XS", "S", "M", "L", "XL", "XXL"]
    private let zodiacOptions = [
        "白羊座", "金牛座", "双子座", "巨蟹座", "狮子座", "处女座",
        "天秤座", "天蝎座", "射手座", "摩羯座", "水瓶座", "双鱼座"
    ]
    private let mbtiOptions = [
        "不知道",
        "INTJ", "INTP", "ENTJ", "ENTP",
        "INFJ", "INFP", "ENFJ", "ENFP",
        "ISTJ", "ISFJ", "ESTJ", "ESFJ",
        "ISTP", "ISFP", "ESTP", "ESFP"
    ]
    private let colorOptions = ["白色系", "杏色系", "黄色系", "橙色系", "红色系", "粉色系", "紫色系", "蓝色系", "绿色系", "棕色系", "咖色系", "灰色系", "黑色系"]
    
    private var canProceedBodyStep: Bool {
        !gender.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !size.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackdrop()
                ScrollView {
                    VStack(spacing: 12) {
                        Text(step == .body ? "1/2 完善基础体型信息" : "2/2 完善偏好信息")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.mutedText)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("欢迎使用，先完善基础信息")
                            .font(.headline)
                            .foregroundStyle(AppTheme.bodyText)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if step == .body {
                            wheelPickerRow(title: "性别", value: gender, placeholder: "请选择性别", field: .gender)
                            TextField("", text: $height, prompt: Text("身高（cm）").foregroundStyle(Color.gray))
                                .keyboardType(.numberPad)
                                .appInputStyle()
                            TextField("", text: $weight, prompt: Text("体重（kg）").foregroundStyle(Color.gray))
                                .keyboardType(.numberPad)
                                .appInputStyle()
                            wheelPickerRow(title: "尺码", value: size, placeholder: "请选择尺码", field: .size)

                            Button {
                                guard canProceedBodyStep else {
                                    errorMessage = "请先选择性别和尺码。"
                                    return
                                }
                                errorMessage = nil
                                step = .preference
                            } label: {
                                Text("下一步")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(AppTheme.primary)
                                    .foregroundStyle(Color.white)
                                    .clipShape(Capsule())
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.appPlain)
                            .disabled(!canProceedBodyStep)
                            .opacity(canProceedBodyStep ? 1 : 0.45)
                        } else {
                            wheelPickerRow(title: "星座", value: zodiac, placeholder: "请选择星座", field: .zodiac)
                            wheelPickerRow(title: "MBTI", value: mbti, placeholder: "请选择MBTI", field: .mbti)
                            wheelPickerRow(title: "色系", value: colorPreference, placeholder: "请选择色系", field: .color)

                            Button {
                                Task { await submit() }
                            } label: {
                                Text(isSubmitting ? "保存中..." : "保存并进入")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(AppTheme.primary)
                                    .foregroundStyle(Color.white)
                                    .clipShape(Capsule())
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.appPlain)
                            .disabled(isSubmitting)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("完善资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(step == .body ? "稍后完善" : "返回") {
                        if step == .preference {
                            step = .body
                            return
                        }
                        dismiss()
                    }
                        .toolbarDoneButton()
                }
            }
            .alert("提示", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(item: $activeWheelField) { field in
                NavigationStack {
                    SettingsEditWheelPickerView(
                        title: field.title,
                        options: options(for: field),
                        selection: selectionBinding(for: field)
                    )
                }
            }
            .onAppear {
                if size.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { size = "M" }
                if zodiac.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { zodiac = zodiacOptions[0] }
                if mbti.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { mbti = "不知道" }
                if colorPreference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { colorPreference = colorOptions[0] }
            }
        }
    }

    private func wheelPickerRow(title: String, value: String, placeholder: String, field: SMSProfileWheelField) -> some View {
        Button {
            activeWheelField = field
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(AppTheme.bodyText)
                Spacer()
                Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? placeholder : value)
                    .foregroundStyle(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppTheme.placeholder : AppTheme.mutedText)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func options(for field: SMSProfileWheelField) -> [String] {
        switch field {
        case .gender: return genderOptions
        case .size: return sizeOptions
        case .zodiac: return zodiacOptions
        case .mbti: return mbtiOptions
        case .color: return colorOptions
        }
    }

    private func selectionBinding(for field: SMSProfileWheelField) -> Binding<String> {
        switch field {
        case .gender: return $gender
        case .size: return $size
        case .zodiac: return $zodiac
        case .mbti: return $mbti
        case .color: return $colorPreference
        }
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await onSubmit()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

enum PasswordResetValidator {
    static func normalizedPhone(_ value: String) -> String {
        String(value.filter(\.isNumber).prefix(11))
    }

    static func normalizedCode(_ value: String) -> String {
        String(value.filter(\.isNumber).prefix(6))
    }

    static func passwordRuleError(_ password: String) -> String? {
        if password.count < 6 {
            return "密码长度至少 6 位"
        }
        let hasLetter = password.range(of: "[A-Za-z]", options: .regularExpression) != nil
        let hasNumber = password.range(of: "[0-9]", options: .regularExpression) != nil
        if !hasLetter || !hasNumber {
            return "密码需同时包含字母和数字"
        }
        return nil
    }

    static func confirmError(password: String, confirm: String) -> String? {
        guard !confirm.isEmpty else { return nil }
        guard password == confirm else { return "两次输入的密码不一致" }
        return nil
    }
}

struct ChangePasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSubmit: (_ newPassword: String, _ confirmPassword: String) async throws -> Void

    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @FocusState private var focusField: FocusField?

    private enum FocusField {
        case password
        case confirmPassword
    }

    private var passwordRuleError: String? {
        PasswordResetValidator.passwordRuleError(password)
    }

    private var passwordConfirmError: String? {
        PasswordResetValidator.confirmError(password: password, confirm: confirmPassword)
    }

    private var canSubmit: Bool {
        passwordRuleError == nil && passwordConfirmError == nil && !confirmPassword.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackdrop()
                VStack(alignment: .leading, spacing: 12) {
                    passwordFieldView
                    if let message = passwordRuleError {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(Color(red: 0.78, green: 0.20, blue: 0.20))
                    }
                    confirmPasswordFieldView
                    if let message = passwordConfirmError {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(Color(red: 0.78, green: 0.20, blue: 0.20))
                    }
                    Button {
                        Task { await submit() }
                    } label: {
                        Text(isSubmitting ? "提交中..." : "确认修改")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppTheme.primary)
                            .foregroundStyle(Color.white)
                            .clipShape(Capsule())
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.appPlain)
                    .disabled(!canSubmit || isSubmitting)
                    .opacity(canSubmit ? 1 : 0.45)
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("修改密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                        .toolbarDoneButton()
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { focusField = nil }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                }
            }
            .alert("提示", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("修改成功", isPresented: Binding(get: { successMessage != nil }, set: { _ in successMessage = nil })) {
                Button("确定") { dismiss() }
            } message: {
                Text(successMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var passwordFieldView: some View {
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            TextField("", text: $password, prompt: Text("请输入新密码").foregroundStyle(Color.gray))
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .appInputStyle()
                .focused($focusField, equals: .password)
                .accessibilityIdentifier("change.password.field")
        } else {
            SecureField("", text: $password, prompt: Text("请输入新密码").foregroundStyle(Color.gray))
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .appInputStyle()
                .focused($focusField, equals: .password)
                .accessibilityIdentifier("change.password.field")
        }
    }

    @ViewBuilder
    private var confirmPasswordFieldView: some View {
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            TextField("", text: $confirmPassword, prompt: Text("请再次输入新密码").foregroundStyle(Color.gray))
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .appInputStyle()
                .focused($focusField, equals: .confirmPassword)
                .accessibilityIdentifier("change.password.confirm.field")
        } else {
            SecureField("", text: $confirmPassword, prompt: Text("请再次输入新密码").foregroundStyle(Color.gray))
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .appInputStyle()
                .focused($focusField, equals: .confirmPassword)
                .accessibilityIdentifier("change.password.confirm.field")
        }
    }

    private func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await onSubmit(password, confirmPassword)
            successMessage = "密码已更新"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct PasswordResetSheet: View {
    private enum Step {
        case phone
        case code
        case password
    }

    private enum FocusField {
        case phone
        case code
        case password
        case confirmPassword
    }

    @Environment(\.dismiss) private var dismiss
    let onResetSuccess: (String) -> Void

    @State private var step: Step = .phone
    @State private var phone = ""
    @State private var code = ""
    @State private var resetToken = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var remainingSeconds = 0
    @State private var timer: Timer?
    @State private var isSending = false
    @State private var isVerifyingCode = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @FocusState private var focusField: FocusField?

    private var maskedPhone: String {
        guard phone.count == 11 else { return phone }
        return "+86 \(phone.prefix(3))****\(phone.suffix(4))"
    }

    private var isPhoneValid: Bool {
        phone.count == 11
    }

    private var isCodeValid: Bool {
        code.count == 6
    }

    private var passwordRuleError: String? {
        PasswordResetValidator.passwordRuleError(password)
    }

    private var passwordConfirmError: String? {
        PasswordResetValidator.confirmError(password: password, confirm: confirmPassword)
    }

    private var canSubmitPasswordStep: Bool {
        passwordRuleError == nil && passwordConfirmError == nil && !confirmPassword.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackdrop()
                VStack(alignment: .leading, spacing: 14) {
                    stepView
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("短信找回密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(step == .phone ? "关闭" : "返回") {
                        handleBack()
                    }
                    .toolbarDoneButton()
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { focusField = nil }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                }
            }
            .alert("提示", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("重置成功", isPresented: Binding(get: { successMessage != nil }, set: { _ in successMessage = nil })) {
                Button("确定") {
                    onResetSuccess(phone)
                    dismiss()
                }
            } message: {
                Text(successMessage ?? "")
            }
        }
        .onDisappear { stopTimer() }
    }

    @ViewBuilder
    private var stepView: some View {
        switch step {
        case .phone:
            phoneStep
        case .code:
            codeStep
        case .password:
            passwordStep
        }
    }

    private var phoneStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("1/3 输入手机号")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.mutedText)

            TextField("", text: Binding(
                get: { phone },
                set: { phone = PasswordResetValidator.normalizedPhone($0) }
            ), prompt: Text("请输入 11 位手机号").foregroundStyle(Color.gray))
                .keyboardType(.numberPad)
                .appInputStyle()
                .focused($focusField, equals: .phone)
                .accessibilityIdentifier("reset.phone.field")

            Button {
                Task { await sendCode() }
            } label: {
                Text(isSending ? "发送中..." : "发送验证码")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.primary)
                    .foregroundStyle(Color.white)
                    .clipShape(Capsule())
                    .contentShape(Rectangle())
            }
            .buttonStyle(.appPlain)
            .disabled(!isPhoneValid || isSending)
            .opacity(isPhoneValid ? 1 : 0.45)
            .accessibilityIdentifier("reset.send.button")
        }
    }

    private var codeStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("2/3 校验验证码")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.mutedText)

            Text("验证码已发送至 \(maskedPhone)")
                .font(.subheadline)
                .foregroundStyle(AppTheme.bodyText)

            TextField("", text: Binding(
                get: { code },
                set: { code = PasswordResetValidator.normalizedCode($0) }
            ), prompt: Text("请输入 6 位验证码").foregroundStyle(Color.gray))
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .appInputStyle()
                .focused($focusField, equals: .code)
                .accessibilityIdentifier("reset.code.field")

            HStack {
                Text(remainingSeconds > 0 ? "\(remainingSeconds)s 后可重发" : "未收到验证码？")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedText)
                Spacer()
                Button(remainingSeconds > 0 ? "\(remainingSeconds)s" : "重新发送") {
                    Task { await sendCode() }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(remainingSeconds > 0 ? Color.gray : AppTheme.primary)
                .disabled(remainingSeconds > 0 || isSending)
                .accessibilityIdentifier("reset.resend.button")
            }

            Button {
                Task { await verifyCode() }
            } label: {
                Text(isVerifyingCode ? "校验中..." : "下一步")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.primary)
                    .foregroundStyle(Color.white)
                    .clipShape(Capsule())
                    .contentShape(Rectangle())
            }
            .buttonStyle(.appPlain)
            .disabled(!isCodeValid || isVerifyingCode)
            .opacity(isCodeValid ? 1 : 0.45)
            .accessibilityIdentifier("reset.verify.button")
        }
    }

    @ViewBuilder
    private var passwordFieldView: some View {
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            TextField("", text: $password, prompt: Text("请输入新密码").foregroundStyle(Color.gray))
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .appInputStyle()
                .focused($focusField, equals: .password)
                .accessibilityIdentifier("reset.password.field")
        } else {
            SecureField("", text: $password, prompt: Text("请输入新密码").foregroundStyle(Color.gray))
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .appInputStyle()
                .focused($focusField, equals: .password)
                .accessibilityIdentifier("reset.password.field")
        }
    }

    @ViewBuilder
    private var confirmPasswordFieldView: some View {
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            TextField("", text: $confirmPassword, prompt: Text("请再次输入新密码").foregroundStyle(Color.gray))
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .appInputStyle()
                .focused($focusField, equals: .confirmPassword)
                .accessibilityIdentifier("reset.confirm.field")
        } else {
            SecureField("", text: $confirmPassword, prompt: Text("请再次输入新密码").foregroundStyle(Color.gray))
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .appInputStyle()
                .focused($focusField, equals: .confirmPassword)
                .accessibilityIdentifier("reset.confirm.field")
        }
    }

    private var passwordStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("3/3 设置新密码")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.mutedText)

            passwordFieldView
            if let message = passwordRuleError {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.78, green: 0.20, blue: 0.20))
                    .accessibilityIdentifier("reset.password.error")
            }

            confirmPasswordFieldView
            if let message = passwordConfirmError {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.78, green: 0.20, blue: 0.20))
                    .accessibilityIdentifier("reset.confirm.error")
            }

            Button {
                Task { await submitReset() }
            } label: {
                Text(isSubmitting ? "提交中..." : "确认重置")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.primary)
                    .foregroundStyle(Color.white)
                    .clipShape(Capsule())
                    .contentShape(Rectangle())
            }
            .buttonStyle(.appPlain)
            .disabled(!canSubmitPasswordStep || isSubmitting)
            .opacity(canSubmitPasswordStep ? 1 : 0.45)
            .accessibilityIdentifier("reset.submit.button")
        }
    }

    private func handleBack() {
        focusField = nil
        switch step {
        case .phone:
            stopTimer()
            dismiss()
        case .code:
            step = .phone
            code = ""
            stopTimer()
        case .password:
            step = .code
            password = ""
            confirmPassword = ""
        }
    }

    private func sendCode() async {
        guard isPhoneValid else {
            errorMessage = "请输入正确的 11 位手机号"
            return
        }
        isSending = true
        defer { isSending = false }
        do {
            try await UserAuthService().sendPasswordResetSMS(phone: phone)
            errorMessage = nil
            step = .code
            code = ""
            startTimer(seconds: 60)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func verifyCode() async {
        guard isCodeValid else {
            errorMessage = "请输入 6 位验证码"
            return
        }
        isVerifyingCode = true
        defer { isVerifyingCode = false }
        do {
            let result = try await UserAuthService().verifyPasswordResetSMS(phone: phone, code: code)
            guard result.ok, !result.resetToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                errorMessage = "验证码校验失败，请重试"
                return
            }
            resetToken = result.resetToken
            errorMessage = nil
            step = .password
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submitReset() async {
        guard canSubmitPasswordStep else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await UserAuthService().confirmPasswordReset(resetToken: resetToken, newPassword: password)
            errorMessage = nil
            successMessage = "密码已重置，请重新登录"
        } catch {
            errorMessage = error.localizedDescription
        }
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
