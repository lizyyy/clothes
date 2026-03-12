// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  ExploreTabView.swift
//  Clothes
//
//  Created by Codex on 2026/1/6.
//  Updated by Codex on 2026/3/5: 探索流改为大图穿搭卡片，新增"他人主页 + 分享详情（评论占位）"跳转，并补充 UITest 定位标识。
//  Updated by Codex on 2026/3/12: 新增个人主页入口、关注/粉丝列表功能。
//

import SwiftUI

struct ExploreTabView: View {
    @AppStorage("auth_token") private var authToken = ""
    @State private var exploreFilter: ExploreFilter = .following
    @State private var searchText = ""
    @State private var creators: [ExploreCreatorDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedCreatorUserID: Int64?
    @State private var selectedSharedOutfit: ExploreSharedOutfitRoute?
    @State private var showMyProfile = false

    private let service = ExploreService()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        ExploreTopBar(selection: $exploreFilter)

                        ExploreSearchBar(text: $searchText)
                            .padding(.horizontal, 20)

                        if isLoading {
                            ProgressView("加载中...")
                                .padding(.top, 10)
                        }

                        VStack(spacing: 18) {
                            ForEach(creators) { creator in
                                ExploreCreatorRow(
                                    creator: creator,
                                    onOpenCreator: {
                                        guard !creator.isSelf else { return }
                                        selectedCreatorUserID = creator.userID
                                    },
                                    onToggleFollow: { Task { await toggleFollow(userID: creator.userID) } },
                                    onOpenOutfit: { outfit in
                                        selectedSharedOutfit = ExploreSharedOutfitRoute(
                                            creatorUserID: creator.userID,
                                            outfitID: outfit.id
                                        )
                                    },
                                    onToggleLike: { outfitID in Task { await toggleLike(outfitID: outfitID, in: creator.userID) } }
                                )
                            }
                        }
                        .padding(.horizontal, 16)

                        if !isLoading, creators.isEmpty {
                            emptyGuideView
                        }
                    }
                    .padding(.bottom, 32)
                    .adaptiveContentWidth(maxWidth: 760)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showMyProfile = true
                    } label: {
                        Text("个人主页")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color(red: 0.28, green: 0.24, blue: 0.20))
                    }
                    .buttonStyle(.appPlain)
                    .accessibilityIdentifier("explore.my_profile.button")
                }
            }
            .task(id: exploreFilter.rawValue + "|" + searchText + "|" + authToken) {
                await loadFeed()
            }
            .alert("探索", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .navigationDestination(item: $selectedCreatorUserID) { creatorUserID in
                if let creator = creators.first(where: { $0.userID == creatorUserID }) {
                    ExploreUserHomeView(
                        creator: creator,
                        onOpenOutfit: { outfit in
                            selectedSharedOutfit = ExploreSharedOutfitRoute(
                                creatorUserID: creator.userID,
                                outfitID: outfit.id
                            )
                        }
                    )
                } else {
                    Text("用户主页暂时不可用")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .navigationDestination(item: $selectedSharedOutfit) { route in
                if let creator = creators.first(where: { $0.userID == route.creatorUserID }),
                   let outfit = creator.outfits.first(where: { $0.id == route.outfitID }) {
                    ExploreSharedOutfitDetailView(creator: creator, outfit: outfit)
                } else {
                    Text("分享穿搭暂时不可用")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .navigationDestination(isPresented: $showMyProfile) {
                ExploreMyProfileView(service: service)
            }
        }
    }

    private func loadFeed() async {
        guard !authToken.isEmpty else {
            creators = []
            errorMessage = "请先登录后再查看探索页。"
            return
        }
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await service.fetchFeed(
                token: authToken,
                mode: exploreFilter.rawValue,
                keyword: searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            creators = response.creators
        } catch {
            if handleInvalidTokenIfNeeded(error) {
                creators = []
                return
            }
            // Silent handling - show empty state instead of error alert
            creators = []
            let loweredMessage = error.localizedDescription.lowercased()
            if loweredMessage.contains("explore feed not implemented yet") {
                return
            }
            // Report error with code for tracking
            ErrorReporter.report(
                message: "Explore data load failed: \(error.localizedDescription)",
                errorCode: ErrorReporter.ERROR_EXPLORE_DATA_LOAD_FAILED,
                screen: "ExploreTabView",
                context: ["filter": exploreFilter.rawValue, "search": searchText]
            )
        }
    }

    private func toggleFollow(userID: Int64) async {
        guard let idx = creators.firstIndex(where: { $0.userID == userID }) else { return }
        let nextState = !creators[idx].isFollowing

        creators[idx].isFollowing = nextState
        creators[idx].followersCount = max(0, creators[idx].followersCount + (nextState ? 1 : -1))

        do {
            try await service.follow(token: authToken, userID: userID, isFollowing: nextState)
        } catch {
            creators[idx].isFollowing.toggle()
            creators[idx].followersCount += nextState ? -1 : 1
            if handleInvalidTokenIfNeeded(error) { return }
            errorMessage = "更新关注状态失败：\(error.localizedDescription)"
        }
    }

    private func toggleLike(outfitID: Int64, in creatorUserID: Int64) async {
        guard let creatorIndex = creators.firstIndex(where: { $0.userID == creatorUserID }) else { return }
        guard let outfitIndex = creators[creatorIndex].outfits.firstIndex(where: { $0.id == outfitID }) else { return }

        let nextState = !creators[creatorIndex].outfits[outfitIndex].isLiked
        creators[creatorIndex].outfits[outfitIndex].isLiked = nextState
        creators[creatorIndex].outfits[outfitIndex].likeCount = max(
            0,
            creators[creatorIndex].outfits[outfitIndex].likeCount + (nextState ? 1 : -1)
        )

        do {
            try await service.like(token: authToken, outfitID: outfitID, isLiked: nextState)
        } catch {
            creators[creatorIndex].outfits[outfitIndex].isLiked.toggle()
            creators[creatorIndex].outfits[outfitIndex].likeCount += nextState ? -1 : 1
            if handleInvalidTokenIfNeeded(error) { return }
            errorMessage = "更新点赞状态失败：\(error.localizedDescription)"
        }
    }

    private func handleInvalidTokenIfNeeded(_ error: Error) -> Bool {
        guard let serviceError = error as? ServiceError, serviceError.errno == 1002 else {
            return false
        }
        authToken = ""
        errorMessage = "登录已失效，请重新登录。"
        return true
    }

    @ViewBuilder
    private var emptyGuideView: some View {
        if exploreFilter == .following {
            VStack(spacing: 10) {
                Image(systemName: "person.2.slash")
                    .font(.title2)
                    .foregroundStyle(Color(red: 0.70, green: 0.66, blue: 0.60))
                Text("你还没有关注任何用户")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.26, green: 0.22, blue: 0.18))
                Text("去「探索更多」关注你喜欢的穿搭创作者吧。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                Button("去探索更多") {
                    exploreFilter = .trending
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.black))
                .foregroundStyle(Color.white)
            }
            .padding(.top, 8)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(Color(red: 0.70, green: 0.66, blue: 0.60))
                Text("暂时没有可探索内容")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.26, green: 0.22, blue: 0.18))
            }
            .padding(.top, 8)
        }
    }

}

private struct ExploreTopBar: View {
    @Binding var selection: ExploreFilter

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                tabButton(title: "我的关注", value: .following)
                tabButton(title: "探索更多", value: .trending)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    private func tabButton(title: String, value: ExploreFilter) -> some View {
        Button(title) { selection = value }
            .font(.title2.weight(selection == value ? .semibold : .regular))
            .foregroundStyle(selection == value ? Color.black : Color(red: 0.70, green: 0.70, blue: 0.72))
            .buttonStyle(.appPlain)
            .accessibilityIdentifier("explore.filter.\(value.rawValue)")
    }
}

private struct ExploreSearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color(red: 0.62, green: 0.62, blue: 0.66))
            TextField("", text: $text, prompt: Text("搜索用户昵称或邮箱").foregroundStyle(AppTheme.placeholder))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("explore.search.field")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.95, green: 0.95, blue: 0.97))
        )
    }
}

private struct ExploreCreatorRow: View {
    let creator: ExploreCreatorDTO
    let onOpenCreator: () -> Void
    let onToggleFollow: () -> Void
    let onOpenOutfit: (ExploreOutfitDTO) -> Void
    let onToggleLike: (Int64) -> Void

    private var sharedOutfits: [ExploreOutfitDTO] {
        creator.outfits.filter { $0.shared }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button(action: onOpenCreator) {
                    HStack(spacing: 12) {
                        ExploreAvatar(
                            initials: ExploreVisualStyle.initials(from: creator.name),
                            color: ExploreVisualStyle.avatarColor(from: creator.userID)
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(creator.name)
                                .font(.headline)
                                .foregroundStyle(Color(red: 0.16, green: 0.14, blue: 0.12))
                            Text("@\(creator.handle) · \(creator.followersCount) 粉丝")
                                .font(.caption)
                                .foregroundStyle(Color(red: 0.60, green: 0.60, blue: 0.62))
                        }
                    }
                }
                .buttonStyle(.appPlain)
                .accessibilityIdentifier("explore.creator.open.\(creator.userID)")

                Spacer()

                if creator.isSelf {
                    Text("我")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color(red: 0.93, green: 0.93, blue: 0.95)))
                        .foregroundStyle(Color(red: 0.22, green: 0.18, blue: 0.14))
                } else {
                    Button(creator.isFollowing ? "已关注" : "关注") {
                        onToggleFollow()
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(creator.isFollowing ? Color(red: 0.86, green: 0.86, blue: 0.89) : Color(red: 0.14, green: 0.14, blue: 0.14))
                    )
                    .foregroundStyle(creator.isFollowing ? Color.black : Color.white)
                    .accessibilityIdentifier("explore.follow.\(creator.userID)")
                }
            }

            if sharedOutfits.isEmpty {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.97, green: 0.97, blue: 0.98))
                    .frame(height: 78)
                    .overlay(
                        Text("这个用户还没有公开穿搭")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    )
            } else {
                VStack(spacing: 12) {
                    ForEach(sharedOutfits) { outfit in
                        ExploreOutfitFeedCard(
                            outfit: outfit,
                            onOpen: { onOpenOutfit(outfit) },
                            onToggleLike: { onToggleLike(outfit.id) }
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.white))
    }
}

private struct ExploreOutfitFeedCard: View {
    let outfit: ExploreOutfitDTO
    let onOpen: () -> Void
    let onToggleLike: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onOpen) {
                GeometryReader { proxy in
                    AuthedCachedRemoteImage(
                        rawPath: outfit.imageURL,
                        ttl: SharedConstants.remoteImageCacheTTLSeconds,
                        width: max(proxy.size.width, 1),
                        height: max(proxy.size.height, 1),
                        cornerRadius: 18,
                        contentMode: .fit
                    )
                }
                .frame(height: 238)
                .overlay(alignment: .bottomTrailing) {
                    Text(outfit.shared ? "已分享" : "私密")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.58))
                        )
                        .foregroundStyle(Color.white)
                        .padding(10)
                }
            }
            .buttonStyle(.appPlain)
            .accessibilityIdentifier("explore.outfit.open.\(outfit.id)")

            if !ExploreVisualStyle.itemImages(from: outfit).isEmpty {
                ExploreOutfitItemsStrip(
                    itemImages: ExploreVisualStyle.itemImages(from: outfit),
                    accessibilityID: "explore.feed.items.strip.\(outfit.id)"
                )
            }

            Text(outfit.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未命名穿搭" : outfit.title)
                .font(.headline)
                .foregroundStyle(AppTheme.bodyText)
                .lineLimit(1)

            HStack(spacing: 8) {
                Button(action: onToggleLike) {
                    Image(systemName: outfit.isLiked ? "heart.fill" : "heart")
                        .font(.callout)
                        .foregroundStyle(outfit.isLiked ? Color.red : Color(red: 0.60, green: 0.60, blue: 0.62))
                }
                .buttonStyle(.appPlain)

                Text("\(outfit.likeCount)")
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.60, green: 0.60, blue: 0.62))

                Spacer()

                Text(ExploreVisualStyle.dateText(from: outfit.createdAt))
                    .font(.caption2)
                    .foregroundStyle(Color(red: 0.66, green: 0.60, blue: 0.54))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(red: 0.90, green: 0.88, blue: 0.84), lineWidth: 1)
        )
    }
}

private struct ExploreOutfitItemsStrip: View {
    let itemImages: [String]
    var accessibilityID: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(itemImages.prefix(8).enumerated()), id: \.offset) { _, imagePath in
                    AuthedCachedRemoteImage(
                        rawPath: imagePath,
                        ttl: SharedConstants.remoteImageCacheTTLSeconds,
                        width: 44,
                        height: 44,
                        cornerRadius: 10,
                        contentMode: .fit
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(red: 0.88, green: 0.86, blue: 0.84), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 2)
        }
        .accessibilityIdentifier(accessibilityID ?? "explore.outfit.items.strip")
    }
}

private struct ExploreSharedOutfitRoute: Hashable, Identifiable {
    let creatorUserID: Int64
    let outfitID: Int64

    var id: String {
        "\(creatorUserID)-\(outfitID)"
    }
}

private struct ExploreUserHomeView: View {
    let creator: ExploreCreatorDTO
    let onOpenOutfit: (ExploreOutfitDTO) -> Void

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var sharedOutfits: [ExploreOutfitDTO] {
        creator.outfits.filter { $0.shared }
    }

    private var totalLikes: Int64 {
        sharedOutfits.reduce(0) { $0 + $1.likeCount }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard

                if sharedOutfits.isEmpty {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .frame(height: 120)
                        .overlay(
                            Text("这个用户还没有分享穿搭")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                        )
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(sharedOutfits) { outfit in
                            ExploreUserHomeOutfitTile(
                                outfit: outfit,
                                onTap: { onOpenOutfit(outfit) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
            .adaptiveContentWidth(maxWidth: 760)
        }
        .background(Color(red: 0.97, green: 0.97, blue: 0.98).ignoresSafeArea())
        .navigationTitle("主页")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ExploreAvatar(
                    initials: ExploreVisualStyle.initials(from: creator.name),
                    color: ExploreVisualStyle.avatarColor(from: creator.userID),
                    size: 68
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text(creator.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.titleText)
                    HStack(spacing: 18) {
                        statItem(value: creator.followersCount, title: "粉丝")
                        statItem(value: creator.followingCount, title: "关注")
                        statItem(value: totalLikes, title: "获赞")
                    }
                }

                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
        )
        .accessibilityIdentifier("explore.user.home.header")
    }

    private func statItem(value: Int64, title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.titleText)
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }
}

private struct ExploreUserHomeOutfitTile: View {
    let outfit: ExploreOutfitDTO
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { proxy in
                    AuthedCachedRemoteImage(
                        rawPath: outfit.imageURL,
                        ttl: SharedConstants.remoteImageCacheTTLSeconds,
                        width: max(proxy.size.width, 1),
                        height: max(proxy.size.height, 1),
                        cornerRadius: 14,
                        contentMode: .fit
                    )
                }
                .frame(height: 220)

                if !ExploreVisualStyle.itemImages(from: outfit).isEmpty {
                    ExploreOutfitItemsStrip(
                        itemImages: ExploreVisualStyle.itemImages(from: outfit),
                        accessibilityID: "explore.user.home.items.strip.\(outfit.id)"
                    )
                }

                Text(timeCode)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.titleText)
                    .lineLimit(1)

                Text(outfit.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未命名穿搭" : outfit.title)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(red: 0.90, green: 0.88, blue: 0.84), lineWidth: 1)
            )
        }
        .buttonStyle(.appPlain)
        .accessibilityIdentifier("explore.user.home.outfit.\(outfit.id)")
    }

    private var timeCode: String {
        ExploreVisualStyle.compactDateCode(from: outfit.createdAt)
    }
}

private struct ExploreSharedOutfitDetailView: View {
    let creator: ExploreCreatorDTO
    let outfit: ExploreOutfitDTO

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    ExploreAvatar(
                        initials: ExploreVisualStyle.initials(from: creator.name),
                        color: ExploreVisualStyle.avatarColor(from: creator.userID),
                        size: 42
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(creator.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.titleText)
                    }
                    Spacer()
                }

                GeometryReader { proxy in
                    AuthedCachedRemoteImage(
                        rawPath: outfit.imageURL,
                        ttl: SharedConstants.remoteImageCacheTTLSeconds,
                        width: max(proxy.size.width, 1),
                        height: max(proxy.size.height, 1),
                        cornerRadius: 20,
                        contentMode: .fit
                    )
                }
                .frame(height: 420)

                if !ExploreVisualStyle.itemImages(from: outfit).isEmpty {
                    ExploreOutfitItemsStrip(
                        itemImages: ExploreVisualStyle.itemImages(from: outfit),
                        accessibilityID: "explore.detail.items.strip.\(outfit.id)"
                    )
                }

                Text(ExploreVisualStyle.compactDateCode(from: outfit.createdAt))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.titleText)

                Text(outfit.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未命名穿搭" : outfit.title)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)

                HStack(spacing: 8) {
                    Image(systemName: outfit.isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(outfit.isLiked ? Color.red : AppTheme.secondaryText)
                    Text("\(outfit.likeCount)")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                    Spacer()
                    Text(ExploreVisualStyle.dateText(from: outfit.createdAt))
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("评论区")
                        .font(.headline)
                        .foregroundStyle(AppTheme.titleText)
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white)
                        .frame(height: 120)
                        .overlay(
                            Text("评论功能下期上线，先预留展示空间")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(red: 0.90, green: 0.88, blue: 0.84), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .adaptiveContentWidth(maxWidth: 760)
        }
        .background(Color(red: 0.97, green: 0.97, blue: 0.98).ignoresSafeArea())
        .navigationTitle("穿搭详情")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("explore.outfit.detail.root")
    }
}

private enum ExploreVisualStyle {
    static func initials(from name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "?" }
        return String(trimmed.prefix(2)).uppercased()
    }

    static func avatarColor(from userID: Int64) -> Color {
        let colors: [Color] = [
            Color(red: 0.52, green: 0.42, blue: 0.36),
            Color(red: 0.42, green: 0.35, blue: 0.54),
            Color(red: 0.63, green: 0.47, blue: 0.37),
            Color(red: 0.35, green: 0.50, blue: 0.45)
        ]
        return colors[Int(userID % Int64(colors.count))]
    }

    static func dateText(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "刚刚" }
        if let date = iso8601WithFractional.date(from: trimmed) ?? iso8601Basic.date(from: trimmed) {
            return dayFormatter.string(from: date)
        }
        return trimmed
    }

    static func compactDateCode(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "-- --" }
        if let date = iso8601WithFractional.date(from: trimmed) ?? iso8601Basic.date(from: trimmed) {
            return compactDayFormatter.string(from: date)
        }
        return String(trimmed.prefix(4))
    }

    static func itemImages(from outfit: ExploreOutfitDTO) -> [String] {
        (outfit.itemImages ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601Basic: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()

    private static let compactDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMdd"
        return formatter
    }()
}

private struct ExploreAvatar: View {
    let initials: String
    let color: Color
    let size: CGFloat

    init(initials: String, color: Color, size: CGFloat = 50) {
        self.initials = initials
        self.color = color
        self.size = size
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.headline)
                    .foregroundStyle(Color.white)
            )
    }
}

private enum ExploreFilter: String {
    case following
    case trending
}

struct ExploreMyProfileView: View {
    @AppStorage("auth_token") private var authToken = ""
    @State private var profile: ExploreMyProfileDTO?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showFollowing = false
    @State private var showFollowers = false
    @State private var followingUsers: [ExploreFollowUserDTO] = []
    @State private var followersUsers: [ExploreFollowUserDTO] = []

    let service: ExploreService

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var sharedOutfits: [ExploreOutfitDTO] {
        profile?.outfits.filter { $0.shared } ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if isLoading {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 100)
                } else if let profile = profile {
                    headerCard(profile: profile)

                    if sharedOutfits.isEmpty {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .frame(height: 120)
                            .overlay(
                                Text("你还没有分享穿搭")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.secondaryText)
                            )
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(sharedOutfits) { outfit in
                                ExploreMyProfileOutfitTile(outfit: outfit)
                            }
                        }
                    }
                } else {
                    emptyStateView
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
            .adaptiveContentWidth(maxWidth: 760)
        }
        .background(Color(red: 0.97, green: 0.97, blue: 0.98).ignoresSafeArea())
        .navigationTitle("个人主页")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadProfile()
        }
        .sheet(isPresented: $showFollowing) {
            if let profile = profile {
                ExploreFollowListView(
                    title: "关注",
                    users: followingUsers,
                    isLoading: followingUsers.isEmpty,
                    onLoad: { await loadFollowing(userID: profile.userID) },
                    onToggleFollow: { userID in await toggleFollowInList(userID: userID, users: &followingUsers) }
                )
            }
        }
        .sheet(isPresented: $showFollowers) {
            if let profile = profile {
                ExploreFollowListView(
                    title: "粉丝",
                    users: followersUsers,
                    isLoading: followersUsers.isEmpty,
                    onLoad: { await loadFollowers(userID: profile.userID) },
                    onToggleFollow: { userID in await toggleFollowInList(userID: userID, users: &followersUsers) }
                )
            }
        }
    }

    private func headerCard(profile: ExploreMyProfileDTO) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ExploreAvatar(
                    initials: ExploreVisualStyle.initials(from: profile.name),
                    color: ExploreVisualStyle.avatarColor(from: profile.userID),
                    size: 68
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text(profile.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.titleText)
                    HStack(spacing: 18) {
                        Button {
                            showFollowers = true
                        } label: {
                            statItem(value: profile.followersCount, title: "粉丝")
                        }
                        .buttonStyle(.appPlain)

                        Button {
                            showFollowing = true
                        } label: {
                            statItem(value: profile.followingCount, title: "关注")
                        }
                        .buttonStyle(.appPlain)

                        statItem(value: profile.likeCount, title: "获赞")
                    }
                }

                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
        )
        .accessibilityIdentifier("explore.my_profile.header")
    }

    private func statItem(value: Int64, title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.titleText)
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.title)
                .foregroundStyle(AppTheme.secondaryText)
            Text("无法加载个人主页")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }

    private func loadProfile() async {
        guard !authToken.isEmpty else {
            isLoading = false
            errorMessage = "请先登录"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            profile = try await service.fetchMyProfile(token: authToken)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadFollowing(userID: Int64) async {
        do {
            followingUsers = try await service.fetchFollowing(token: authToken, userID: userID)
        } catch {
            print("Failed to load following: \(error)")
        }
    }

    private func loadFollowers(userID: Int64) async {
        do {
            followersUsers = try await service.fetchFollowers(token: authToken, userID: userID)
        } catch {
            print("Failed to load followers: \(error)")
        }
    }

    private func toggleFollowInList(userID: Int64, users: inout [ExploreFollowUserDTO]) async {
        guard let idx = users.firstIndex(where: { $0.userID == userID }) else { return }
        let nextState = !users[idx].isFollowing

        users[idx].isFollowing = nextState

        do {
            try await service.follow(token: authToken, userID: userID, isFollowing: nextState)
        } catch {
            users[idx].isFollowing.toggle()
        }
    }
}

private struct ExploreMyProfileOutfitTile: View {
    let outfit: ExploreOutfitDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                AuthedCachedRemoteImage(
                    rawPath: outfit.imageURL,
                    ttl: SharedConstants.remoteImageCacheTTLSeconds,
                    width: max(proxy.size.width, 1),
                    height: max(proxy.size.height, 1),
                    cornerRadius: 14,
                    contentMode: .fit
                )
            }
            .frame(height: 220)

            if !ExploreVisualStyle.itemImages(from: outfit).isEmpty {
                ExploreOutfitItemsStrip(
                    itemImages: ExploreVisualStyle.itemImages(from: outfit),
                    accessibilityID: "explore.my_profile.items.strip.\(outfit.id)"
                )
            }

            Text(ExploreVisualStyle.compactDateCode(from: outfit.createdAt))
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.titleText)
                .lineLimit(1)

            Text(outfit.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未命名穿搭" : outfit.title)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(red: 0.90, green: 0.88, blue: 0.84), lineWidth: 1)
        )
        .accessibilityIdentifier("explore.my_profile.outfit.\(outfit.id)")
    }
}

struct ExploreFollowListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var users: [ExploreFollowUserDTO]
    let title: String
    let isLoading: Bool
    let onLoad: () async -> Void
    let onToggleFollow: (Int64) async -> Void

    init(
        title: String,
        users: [ExploreFollowUserDTO],
        isLoading: Bool,
        onLoad: @escaping () async -> Void,
        onToggleFollow: @escaping (Int64) async -> Void
    ) {
        self.title = title
        self._users = State(initialValue: users)
        self.isLoading = isLoading
        self.onLoad = onLoad
        self.onToggleFollow = onToggleFollow
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.97, green: 0.97, blue: 0.98).ignoresSafeArea()

                if users.isEmpty {
                    if isLoading {
                        ProgressView("加载中...")
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "person.2.slash")
                                .font(.title)
                                .foregroundStyle(AppTheme.secondaryText)
                            Text("暂无\(title)")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(users) { user in
                                ExploreFollowUserRow(
                                    user: user,
                                    onToggleFollow: { Task { await toggleFollow(userID: user.userID) } }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                        .toolbarDoneButton()
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.white, for: .navigationBar)
            .task {
                if users.isEmpty {
                    await onLoad()
                }
            }
        }
    }

    private func toggleFollow(userID: Int64) async {
        guard let idx = users.firstIndex(where: { $0.userID == userID }) else { return }
        let nextState = !users[idx].isFollowing

        users[idx].isFollowing = nextState

        await onToggleFollow(userID)

        if !nextState {
            users[idx].isFollowing = false
        }
    }
}

private struct ExploreFollowUserRow: View {
    let user: ExploreFollowUserDTO
    let onToggleFollow: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ExploreAvatar(
                initials: ExploreVisualStyle.initials(from: user.name),
                color: ExploreVisualStyle.avatarColor(from: user.userID),
                size: 48
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.titleText)
                HStack(spacing: 8) {
                    Text("\(user.followingCount) 关注")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                    Text("\(user.followersCount) 粉丝")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            Spacer()

            Button(user.isFollowing ? "已关注" : "关注") {
                onToggleFollow()
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(user.isFollowing ? Color(red: 0.86, green: 0.86, blue: 0.89) : Color(red: 0.14, green: 0.14, blue: 0.14))
            )
            .foregroundStyle(user.isFollowing ? Color.black : Color.white)
            .accessibilityIdentifier("explore.follow_list.follow.\(user.userID)")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )
        .accessibilityIdentifier("explore.follow_list.user.\(user.userID)")
    }
}
