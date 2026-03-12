// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
// 最近更新：2026-03-06，注册补全页默认昵称文案与兜底值改为隐私安全形式，不再回退手机号。
import SwiftUI

struct RegistrationFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var phone: String
    @Binding var code: String
    @Binding var isVerified: Bool
    @Binding var nickname: String
    @Binding var username: String
    @Binding var password: String
    @Binding var confirmPassword: String
    @Binding var gender: String
    @Binding var height: String
    @Binding var weight: String
    @Binding var size: String
    @Binding var zodiac: String
    @Binding var mbti: String
    @Binding var colorPreference: String
    let onVerifyRegistration: (String, String) async throws -> Void
    let onComplete: () -> Void

    @State private var step: RegistrationStep = .smsVerify
    @State private var isSendingCode = false
    @State private var isVerifying = false
    @State private var remainingSeconds = 0
    @State private var timer: Timer?
    @State private var localMessage: String?
    @State private var localError: String?
    @State private var activeWheelField: RegistrationWheelField?
    @FocusState private var focusField: Field?

    private enum Field {
        case phone
        case code
        case username
        case nickname
        case password
        case confirmPassword
    }

    private enum RegistrationStep {
        case smsVerify
        case accountInfo
        case profileComplete
    }

    private enum RegistrationWheelField: String, Identifiable {
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

    private var isUITestMode: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTesting")
    }

    private var canVerify: Bool {
        !phone.trimmed.isEmpty && !code.trimmed.isEmpty
    }

    private var canProceedAccountInfo: Bool {
        !username.trimmed.isEmpty
            && !nickname.trimmed.isEmpty
            && password.count >= 6
            && password == confirmPassword
    }

    private var canSubmit: Bool {
        step == .profileComplete
            && isVerified
            && canProceedAccountInfo
            && !gender.trimmed.isEmpty
            && !size.trimmed.isEmpty
            && !zodiac.trimmed.isEmpty
            && !mbti.trimmed.isEmpty
            && !colorPreference.trimmed.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if step == .smsVerify {
                            smsVerifySection
                        } else if step == .accountInfo {
                            accountInfoSection
                        } else {
                            profileCompleteSection
                        }

                        if let localMessage {
                            Text(localMessage)
                                .font(.caption)
                                .foregroundStyle(Color(red: 0.32, green: 0.54, blue: 0.34))
                        }
                        if let localError {
                            Text(localError)
                                .font(.caption)
                                .foregroundStyle(Color(red: 0.78, green: 0.20, blue: 0.20))
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("注册")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(step == .smsVerify ? "关闭" : "返回") {
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
            .onDisappear { stopTimer() }
            .sheet(item: $activeWheelField) { field in
                NavigationStack {
                    SettingsEditWheelPickerView(
                        title: field.title,
                        options: options(for: field),
                        selection: selectionBinding(for: field)
                    )
                }
            }
        }
    }

    private var smsVerifySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("1/3 手机号校验")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.mutedText)

            Text("手机号短信注册")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.titleText)

            TextField("", text: $phone, prompt: Text("手机号").foregroundStyle(Color.gray))
                .keyboardType(.phonePad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .appInputStyle()
                .focused($focusField, equals: .phone)
                .accessibilityIdentifier("register.phone.field")

            HStack(spacing: 10) {
                TextField("", text: $code, prompt: Text("验证码").foregroundStyle(Color.gray))
                    .keyboardType(.numberPad)
                    .appInputStyle()
                    .focused($focusField, equals: .code)
                    .accessibilityIdentifier("register.smsCode.field")

                Button {
                    Task { await sendCode() }
                } label: {
                    Text(remainingSeconds > 0 ? "\(remainingSeconds)s" : "发送验证码")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(remainingSeconds > 0 ? Color.gray.opacity(0.22) : AppTheme.primary))
                        .foregroundStyle(remainingSeconds > 0 ? Color.gray : Color.white)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.appPlain)
                .disabled(remainingSeconds > 0 || isSendingCode)
                .accessibilityIdentifier("register.sms.send.button")
            }

            Button {
                focusField = nil
                Task { await verifyAndRegister() }
            } label: {
                Text(isVerifying ? "校验中..." : "下一步")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.primary)
                    .foregroundStyle(Color.white)
                    .clipShape(Capsule())
                    .contentShape(Rectangle())
            }
            .buttonStyle(.appPlain)
            .disabled(!canVerify || isVerifying)
            .opacity(canVerify ? 1 : 0.45)
            .accessibilityIdentifier("register.verify.button")
        }
    }

    private var accountInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("2/3 填写账号信息")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.mutedText)

            Text("验证码验证成功，请先完成账号信息")
                .font(.caption)
                .foregroundStyle(Color(red: 0.32, green: 0.54, blue: 0.34))

            TextField("", text: $username, prompt: Text("登录账号（默认手机号）").foregroundStyle(Color.gray))
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .appInputStyle()
                .focused($focusField, equals: .username)
                .accessibilityIdentifier("register.username.field")

            TextField("", text: $nickname, prompt: Text("昵称（默认穿起来+UID）").foregroundStyle(Color.gray))
                .appInputStyle()
                .focused($focusField, equals: .nickname)
                .accessibilityIdentifier("register.nickname.field")

            passwordField
            confirmPasswordField

            Button {
                focusField = nil
                guard canProceedAccountInfo else {
                    localError = "请填写完整账号信息，并确认密码一致。"
                    return
                }
                localError = nil
                step = .profileComplete
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
            .disabled(!canProceedAccountInfo)
            .opacity(canProceedAccountInfo ? 1 : 0.45)
            .accessibilityIdentifier("register.account.next.button")
        }
    }

    private var profileCompleteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("3/3 完善资料")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.mutedText)

            wheelPickerRow(title: "性别", value: gender, placeholder: "请选择性别", field: .gender)
            TextField("", text: $height, prompt: Text("身高（cm）").foregroundStyle(Color.gray))
                .keyboardType(.numberPad)
                .appInputStyle()
            TextField("", text: $weight, prompt: Text("体重（kg）").foregroundStyle(Color.gray))
                .keyboardType(.numberPad)
                .appInputStyle()
            wheelPickerRow(title: "尺码", value: size, placeholder: "请选择尺码", field: .size)
            wheelPickerRow(title: "星座", value: zodiac, placeholder: "请选择星座", field: .zodiac)
            wheelPickerRow(title: "MBTI", value: mbti, placeholder: "请选择MBTI", field: .mbti)
            wheelPickerRow(title: "色系", value: colorPreference, placeholder: "请选择色系", field: .color)

            Button {
                focusField = nil
                if canSubmit {
                    localError = nil
                    onComplete()
                } else {
                    localError = "请填写完整信息，并确认密码一致。"
                }
            } label: {
                Text("完成注册")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.primary)
                    .foregroundStyle(Color.white)
                    .clipShape(Capsule())
                    .contentShape(Rectangle())
            }
            .buttonStyle(.appPlain)
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : 0.45)
            .accessibilityIdentifier("register.complete.button")
        }
    }

    @ViewBuilder
    private var passwordField: some View {
        if isUITestMode {
            TextField("", text: $password, prompt: Text("密码（至少6位）").foregroundStyle(Color.gray))
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .appInputStyle()
                .foregroundStyle(password.isEmpty ? AppTheme.placeholder : AppTheme.bodyText)
                .focused($focusField, equals: .password)
                .accessibilityIdentifier("register.password.field")
        } else {
            SecureField("", text: $password, prompt: Text("密码（至少6位）").foregroundStyle(Color.gray))
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .appInputStyle()
                .foregroundStyle(password.isEmpty ? AppTheme.placeholder : AppTheme.bodyText)
                .focused($focusField, equals: .password)
                .accessibilityIdentifier("register.password.field")
        }
    }

    @ViewBuilder
    private var confirmPasswordField: some View {
        if isUITestMode {
            TextField("", text: $confirmPassword, prompt: Text("确认密码").foregroundStyle(Color.gray))
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .appInputStyle()
                .foregroundStyle(confirmPassword.isEmpty ? AppTheme.placeholder : AppTheme.bodyText)
                .focused($focusField, equals: .confirmPassword)
                .accessibilityIdentifier("register.confirmPassword.field")
        } else {
            SecureField("", text: $confirmPassword, prompt: Text("确认密码").foregroundStyle(Color.gray))
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .appInputStyle()
                .foregroundStyle(confirmPassword.isEmpty ? AppTheme.placeholder : AppTheme.bodyText)
                .focused($focusField, equals: .confirmPassword)
                .accessibilityIdentifier("register.confirmPassword.field")
        }
    }

    private func sendCode() async {
        let trimmedPhone = phone.trimmed
        guard !trimmedPhone.isEmpty else {
            localError = "请先输入手机号。"
            return
        }
        isSendingCode = true
        defer { isSendingCode = false }
        do {
            let response = try await UserAuthService().sendSMSCode(phone: trimmedPhone, purpose: "register")
            localError = nil
            _ = response
            localMessage = "验证码已发送，请注意查收。"
            startTimer(seconds: max(60, response.nextRetrySeconds))
        } catch {
            localError = error.localizedDescription
        }
    }

    private func verifyAndRegister() async {
        let trimmedPhone = phone.trimmed
        let trimmedCode = code.trimmed
        guard !trimmedPhone.isEmpty, !trimmedCode.isEmpty else {
            localError = "请填写手机号和验证码。"
            return
        }
        isVerifying = true
        defer { isVerifying = false }
        do {
            try await onVerifyRegistration(trimmedPhone, trimmedCode)
            isVerified = true
            if username.trimmed.isEmpty { username = trimmedPhone }
            if nickname.trimmed.isEmpty { nickname = "穿起来用户" }
            if size.trimmed.isEmpty { size = "M" }
            if zodiac.trimmed.isEmpty { zodiac = zodiacOptions[0] }
            if mbti.trimmed.isEmpty { mbti = "不知道" }
            if colorPreference.trimmed.isEmpty { colorPreference = colorOptions[0] }
            localError = nil
            localMessage = nil
            step = .accountInfo
        } catch {
            localError = error.localizedDescription
        }
    }

    private func handleBack() {
        focusField = nil
        switch step {
        case .smsVerify:
            dismiss()
        case .accountInfo:
            step = .smsVerify
        case .profileComplete:
            step = .accountInfo
        }
    }

    private func wheelPickerRow(title: String, value: String, placeholder: String, field: RegistrationWheelField) -> some View {
        Button {
            activeWheelField = field
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(AppTheme.bodyText)
                Spacer()
                Text(value.trimmed.isEmpty ? placeholder : value)
                    .foregroundStyle(value.trimmed.isEmpty ? AppTheme.placeholder : AppTheme.mutedText)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.95)))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 0.86, green: 0.80, blue: 0.74), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func options(for field: RegistrationWheelField) -> [String] {
        switch field {
        case .gender: return genderOptions
        case .size: return sizeOptions
        case .zodiac: return zodiacOptions
        case .mbti: return mbtiOptions
        case .color: return colorOptions
        }
    }

    private func selectionBinding(for field: RegistrationWheelField) -> Binding<String> {
        switch field {
        case .gender: return $gender
        case .size: return $size
        case .zodiac: return $zodiac
        case .mbti: return $mbti
        case .color: return $colorPreference
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

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
