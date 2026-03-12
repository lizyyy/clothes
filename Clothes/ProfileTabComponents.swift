// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
// 最近更新：2026-03-05，切换账号列表去除行间分隔线，并固定展示昵称与登录用户名（手机号）字段值。
import Foundation
import SwiftUI

struct StoredAccount: Codable, Identifiable {
    let username: String
    let token: String
    let profileName: String
    let profileNickname: String
    let profileUID: String
    let profileGender: String
    let bodyHeight: String
    let bodyWeight: String
    let bodySize: String
    let profileZodiac: String
    let profileMBTI: String
    let preferenceColors: String
    let profileAvatar: Data

    var id: String { username }

    enum CodingKeys: String, CodingKey {
        case username
        case token
        case profileName
        case profileNickname
        case profileUID
        case profileGender
        case bodyHeight
        case bodyWeight
        case bodySize
        case profileZodiac
        case profileMBTI
        case preferenceColors
        case profileAvatar
    }

    init(
        username: String,
        token: String,
        profileName: String,
        profileNickname: String,
        profileUID: String,
        profileGender: String,
        bodyHeight: String,
        bodyWeight: String,
        bodySize: String,
        profileZodiac: String,
        profileMBTI: String,
        preferenceColors: String,
        profileAvatar: Data
    ) {
        self.username = username
        self.token = token
        self.profileName = profileName
        self.profileNickname = profileNickname
        self.profileUID = profileUID
        self.profileGender = profileGender
        self.bodyHeight = bodyHeight
        self.bodyWeight = bodyWeight
        self.bodySize = bodySize
        self.profileZodiac = profileZodiac
        self.profileMBTI = profileMBTI
        self.preferenceColors = preferenceColors
        self.profileAvatar = profileAvatar
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        username = (try? container.decode(String.self, forKey: .username)) ?? ""
        token = (try? container.decode(String.self, forKey: .token)) ?? ""
        profileName = (try? container.decode(String.self, forKey: .profileName)) ?? ""
        profileNickname = (try? container.decode(String.self, forKey: .profileNickname)) ?? ""
        profileUID = (try? container.decode(String.self, forKey: .profileUID)) ?? ""
        profileGender = (try? container.decode(String.self, forKey: .profileGender)) ?? ""
        bodyHeight = (try? container.decode(String.self, forKey: .bodyHeight)) ?? ""
        bodyWeight = (try? container.decode(String.self, forKey: .bodyWeight)) ?? ""
        bodySize = (try? container.decode(String.self, forKey: .bodySize)) ?? ""
        profileZodiac = (try? container.decode(String.self, forKey: .profileZodiac)) ?? ""
        profileMBTI = (try? container.decode(String.self, forKey: .profileMBTI)) ?? ""
        preferenceColors = (try? container.decode(String.self, forKey: .preferenceColors)) ?? ""
        profileAvatar = (try? container.decode(Data.self, forKey: .profileAvatar)) ?? Data()
    }
}

struct AccountSwitcherSheet: View {
    @Environment(\.dismiss) private var dismiss
    let accounts: [StoredAccount]
    let currentUsername: String
    let onSelect: (StoredAccount) -> Void
    let onDelete: (StoredAccount) -> Void
    let onAddLogin: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if accounts.isEmpty {
                    Text("暂无可切换账号")
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.white)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(accounts) { account in
                        Button {
                            onSelect(account)
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 0.73, green: 0.65, blue: 0.56),
                                                    Color(red: 0.60, green: 0.53, blue: 0.45)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                    if let image = UIImage(data: account.profileAvatar), !account.profileAvatar.isEmpty {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .clipShape(Circle())
                                    } else {
                                        Text(String(resolvedAvatarInitial(for: account)))
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.white)
                                    }
                                }
                                .frame(width: 44, height: 44)
                                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(resolvedNickname(for: account))
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color(red: 0.14, green: 0.13, blue: 0.12))
                                    HStack(spacing: 6) {
                                        Image(systemName: "person.text.rectangle")
                                            .font(.caption2)
                                            .foregroundStyle(Color(red: 0.49, green: 0.46, blue: 0.42))
                                        Text("登录用户名（手机号）")
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(Color(red: 0.49, green: 0.46, blue: 0.42))
                                    }
                                    Text(resolvedLoginAccount(for: account))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color(red: 0.20, green: 0.19, blue: 0.17))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                                if account.username == currentUsername {
                                    Text("当前账号")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(Color(red: 0.14, green: 0.44, blue: 0.25))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(
                                            Capsule()
                                                .fill(Color(red: 0.89, green: 0.97, blue: 0.91))
                                        )
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white, Color(red: 0.99, green: 0.98, blue: 0.97)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color(red: 0.89, green: 0.86, blue: 0.82), lineWidth: 1)
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 2)
                        }
                        .buttonStyle(.appPlain)
                        .accessibilityIdentifier("account.switch.\(account.username)")
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                onDelete(account)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("切换账号")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.98, green: 0.98, blue: 0.99))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                        .toolbarDoneButton()
                }
            }
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.white, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    Button {
                        onAddLogin()
                    } label: {
                        Text("添加账号")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(red: 0.82, green: 0.80, blue: 0.76), lineWidth: 1)
                            )
                            .foregroundStyle(Color(red: 0.22, green: 0.20, blue: 0.18))
                            .contentShape(Rectangle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(Color.white)
            }
        }
    }

    private func resolvedNickname(for account: StoredAccount) -> String {
        let nickname = account.profileNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if !nickname.isEmpty { return nickname }
        let profileName = account.profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !profileName.isEmpty { return profileName }
        return "未设置昵称"
    }

    private func resolvedLoginAccount(for account: StoredAccount) -> String {
        let username = account.username.trimmingCharacters(in: .whitespacesAndNewlines)
        if !username.isEmpty { return username }
        return "未填写"
    }

    private func resolvedAvatarInitial(for account: StoredAccount) -> Character {
        let nickname = resolvedNickname(for: account).trimmingCharacters(in: .whitespacesAndNewlines)
        if !nickname.isEmpty, nickname != "未设置昵称" {
            return nickname.first ?? "?"
        }
        let username = account.username.trimmingCharacters(in: .whitespacesAndNewlines)
        return username.isEmpty ? "?" : (username.first ?? "?")
    }
}

struct ProfileHero<Trailing: View>: View {
    let name: String
    let style: String
    let avatarData: Data?
    let onAvatarTap: (() -> Void)?
    let trailing: Trailing

    init(name: String, style: String, avatarData: Data?, onAvatarTap: (() -> Void)? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.name = name
        self.style = style
        self.avatarData = avatarData
        self.onAvatarTap = onAvatarTap
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Button(action: { onAvatarTap?() }) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.73, green: 0.64, blue: 0.54))
                        if let data = avatarData, let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .clipShape(Circle())
                        } else {
                            Text(initials(from: name))
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(Color.white)
                        }
                    }
                }
                .buttonStyle(.appPlain)
                .accessibilityIdentifier("profile.avatar.button")
            }
            .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.26, green: 0.21, blue: 0.17))
                if !style.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(style)
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 0.53, green: 0.45, blue: 0.38))
                }
            }
            Spacer()
            trailing
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(red: 0.50, green: 0.40, blue: 0.32))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.9))
        )
    }

    private func initials(from name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "?" }
        return String(trimmed.prefix(2))
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color(red: 0.27, green: 0.22, blue: 0.18))
            content
        }
    }
}

struct SettingsActionRow: View {
    let title: String
    let value: String
    let accessibilityId: String?
    let onTap: () -> Void

    init(title: String, value: String, accessibilityId: String? = nil, onTap: @escaping () -> Void) {
        self.title = title
        self.value = value
        self.accessibilityId = accessibilityId
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.19))
                Spacer()
                Text(value)
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedText)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.70, green: 0.66, blue: 0.60))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.9))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.appPlain)
        .accessibilityIdentifier(accessibilityId ?? "profile.row.\(title)")
    }
}

struct SettingsNavigationRow<Destination: View>: View {
    let title: String
    let value: String
    let destination: Destination

    init(title: String, value: String, @ViewBuilder destination: () -> Destination) {
        self.title = title
        self.value = value
        self.destination = destination()
    }

    var body: some View {
        NavigationLink(destination: destination) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.19))
                Spacer()
                Text(value)
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedText)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.70, green: 0.66, blue: 0.60))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.9))
            )
            .contentShape(Rectangle())
        }
    }
}

enum ProfileEditSheet: String, Identifiable {
    case nickname
    case gender
    case height
    case weight
    case size
    case zodiac
    case mbti
    case color

    var id: String { rawValue }
}

struct SettingsStaticRow: View {
    let title: String
    let value: String
    let accessibilityId: String?

    init(title: String, value: String, accessibilityId: String? = nil) {
        self.title = title
        self.value = value
        self.accessibilityId = accessibilityId
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.19))
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundStyle(AppTheme.mutedText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.9))
        )
        .accessibilityIdentifier(accessibilityId ?? "profile.row.\(title)")
    }
}

struct SettingsEditTextView: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            WarmBackdrop()
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.bodyText)
                TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(AppTheme.placeholder))
                    .appInputStyle()
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit { isFocused = false }
                    .accessibilityIdentifier("profile.edit.\(title).field")
                Spacer()
            }
            .padding(20)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.white, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") { dismiss() }
                    .toolbarDoneButton()
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { isFocused = false }
                    .toolbarDoneButton()
            }
        }
    }
}


struct SettingsEditPickerView: View {
    let title: String
    @Binding var selection: String
    let options: [String]

    var body: some View {
        ZStack {
            WarmBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.bodyText)
                    ForEach(options, id: \.self) { option in
                        Button {
                            selection = option
                        } label: {
                            HStack {
                                Text(option)
                                    .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.19))
                                Spacer()
                                if selection == option {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color(red: 0.44, green: 0.36, blue: 0.28))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.9))
                            )
                        }
                        .buttonStyle(.appPlain)
                    }
                    Spacer()
                }
                .padding(20)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.white, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}

struct SettingsEditWheelPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let options: [String]
    @Binding var selection: String
    @State private var draftSelection = ""

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.bodyText)
                .padding(.top, 28)
                .padding(.bottom, 18)

            Picker(title, selection: $draftSelection) {
                ForEach(options, id: \.self) { option in
                    Text(option)
                        .tag(option)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(height: 270)
            .clipped()
            .environment(\.colorScheme, .light)
            .padding(.bottom, 24)

            Spacer(minLength: 0)

            Button {
                if !draftSelection.isEmpty {
                    selection = draftSelection
                }
                dismiss()
            } label: {
                Text("保存")
                    .font(.system(size: 21, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background(Color.black)
                    .foregroundStyle(Color.white)
                    .clipShape(Capsule())
                    .contentShape(Rectangle())
            }
            .buttonStyle(.appPlain)
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .presentationDetents([.height(430)])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.light)
        .onAppear {
            draftSelection = selection.isEmpty ? (options.first ?? "") : selection
        }
    }
}

struct RegistrationWheelPickerString: View {
    let title: String
    let options: [String]
    @Binding var selection: String

    var body: some View {
        VStack(spacing: 12) {
            Text(selection.isEmpty ? (options.first ?? "") : selection)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.titleText)
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 180)
            .background(Color.white.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

struct SettingsEditToggleView: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        ZStack {
            WarmBackdrop()
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.bodyText)
                Toggle("启用提醒", isOn: $isOn)
                    .tint(Color(red: 0.58, green: 0.47, blue: 0.37))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.9))
                    )
                Spacer()
            }
            .padding(20)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.white, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}
