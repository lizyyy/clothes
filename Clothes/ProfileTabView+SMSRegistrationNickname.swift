// 文件input：项目内模型、资料补全用户信息
// 文件output：短信注册默认昵称
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
// 最近更新：2026-03-10，拆分短信注册默认昵称逻辑，控制 ProfileTabView 动作文件规模。
import Foundation

extension ProfileTabView {
    func resolvedSMSRegistrationNickname(from user: UserInfo?) -> String {
        let trimmed = user?.nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            return trimmed
        }
        if let uid = user?.uid {
            return "穿起来\(uid)"
        }
        return "穿起来用户"
    }
}
