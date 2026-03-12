// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  TryOnTabView.swift
//  Clothes
//
//  Created by Codex on 2026/2/12.
//

import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct TryOnTabView: View {
    let initialRecord: OutfitRecord?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("auth_token") private var authToken = ""
    @AppStorage("auth_username") private var authUsername = ""
    @State private var tryOnModelBase64 = ""
    @State private var tryOnHeight = ""
    @State private var tryOnWeight = ""
    @AppStorage("body_height") private var profileHeight = ""
    @AppStorage("body_weight") private var profileWeight = ""
    @AppStorage("profile_mbti") private var profileMbti = ""
    @AppStorage("profile_zodiac") private var profileZodiac = ""
    @AppStorage("profile_name") private var profileName = ""
    @AppStorage("profile_location") private var profileLocation = ""
    @AppStorage("body_shape") private var profileBodyShape = ""
    @AppStorage("daily_weather") private var dailyWeather = ""
    @AppStorage("daily_temperature") private var dailyTemperature = ""
    @AppStorage("preference_occasions") private var preferenceOccasions = ""
    @AppStorage("preference_colors") private var preferenceColors = ""
    @State private var outfitRecords: [OutfitRecord] = []
    @State private var clothingItems: [ClothingItem] = []
    @State private var isLoadingData = true

    @State private var showModelSheet = false
    @State private var showHistorySheet = false
    @State private var showOutfitBuilder = false
    @State private var selectedItemIDs: Set<UUID> = []
    @State private var newOutfitTitle = ""
    @State private var selectedSection = 0
    @State private var generatingRecordID: UUID?
    @State private var isGeneratingRecommendation = false
    @State private var aiRecommendationDrafts: [TryOnRecommendationDraft] = []
    @State private var previewImageData: Data?
    @State private var showPreview = false
    @State private var countdownRemaining = 60
    @State private var countdownTimer: Timer?
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var didFocusInitialRecord = false
    @State private var showScenePicker = false
    @State private var selectedScene = ""
    @State private var sharingRecordID: UUID?

    private let tryOnCost: Int64 = 10
    private let sceneOptions = ["日常", "学校", "工作", "旅行", "派对", "约会", "散步", "运动", "聚会", "面试"]

    init(initialRecord: OutfitRecord? = nil) {
        self.initialRecord = initialRecord
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("AI 试衣")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(AppTheme.titleText)

                        modelPreview

                        HStack(spacing: 10) {
                            Button {
                                showHistorySheet = true
                            } label: {
                                Label("试穿记录", systemImage: "doc.text.magnifyingglass")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.actionText)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(0.9))
                                    )
                            }

                            if previewImageData != nil, !tryOnModelBase64.isEmpty {
                                Button {
                                    previewImageData = nil
                                } label: {
                                    Label("查看模特", systemImage: "person")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(AppTheme.actionText)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(Color.white.opacity(0.9))
                                        )
                                }
                            }

                            Button {
                                showModelSheet = true
                            } label: {
                                Label("替换模特", systemImage: "person.crop.square")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.actionText)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(0.9))
                                    )
                            }
                        }

                        HStack(spacing: 12) {
                            Button {
                                selectedSection = 0
                            } label: {
                                Text("我的搭配")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(selectedSection == 0 ? Color.white : Color(red: 0.36, green: 0.30, blue: 0.24))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule()
                                            .fill(selectedSection == 0 ? Color(red: 0.22, green: 0.20, blue: 0.18) : Color.white.opacity(0.95))
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(Color(red: 0.84, green: 0.80, blue: 0.74), lineWidth: selectedSection == 0 ? 0 : 1)
                                    )
                            }
                            .buttonStyle(.appPlain)

                            Button {
                                selectedSection = 1
                            } label: {
                                Text("AI 推荐")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(selectedSection == 1 ? Color.white : Color(red: 0.36, green: 0.30, blue: 0.24))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule()
                                            .fill(selectedSection == 1 ? Color(red: 0.22, green: 0.20, blue: 0.18) : Color.white.opacity(0.95))
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(Color(red: 0.84, green: 0.80, blue: 0.74), lineWidth: selectedSection == 1 ? 0 : 1)
                                    )
                            }
                            .buttonStyle(.appPlain)
                        }

                        if selectedSection == 0 {
                            myOutfitsSection
                        } else {
                            aiRecommendationSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .adaptiveContentWidth(maxWidth: 760)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Text("完成")
                    .toolbarDoneButton()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.9))
                    )
            }
            .padding(.top, 12)
            .padding(.trailing, 16)
        }
        .sheet(isPresented: $showModelSheet) {
            TryOnModelSheet(
                initialHeight: tryOnHeight.isEmpty ? profileHeight : tryOnHeight,
                initialWeight: tryOnWeight.isEmpty ? profileWeight : tryOnWeight,
                onComplete: { base64, height, weight in
                    applyTryOnModel(base64: base64, height: height, weight: weight)
                }
            )
        }
        .sheet(isPresented: $showHistorySheet) {
            TryOnHistorySheet(records: outfitRecords) { record in
                previewImageData = record.aiTryOnImageData
            }
        }
        .sheet(isPresented: $showOutfitBuilder) {
            TryOnOutfitBuilderSheet(
                title: $newOutfitTitle,
                items: clothingItems,
                selectedItemIDs: $selectedItemIDs
            ) {
                saveCustomOutfit()
                showOutfitBuilder = false
            }
        }
        .alert("提示", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("分享成功", isPresented: Binding(get: { infoMessage != nil }, set: { _ in infoMessage = nil })) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(infoMessage ?? "")
        }
        .fullScreenCover(isPresented: $showPreview) {
            let modelData = Data(base64Encoded: tryOnModelBase64)
            FullScreenImageView(imageData: previewImageData ?? modelData, imageURL: nil) {
                showPreview = false
            }
        }
        .task {
            loadTryOnModelState()
            loadData()
        }
        .onChange(of: authUsername) { _, _ in
            loadTryOnModelState()
            previewImageData = nil
            loadData()
        }
        .onAppear {
            guard !didFocusInitialRecord, let record = initialRecord else { return }
            selectedSection = 1
            previewImageData = record.aiTryOnImageData
            didFocusInitialRecord = true
        }
    }

    private var modelPreview: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(Color(red: 0.95, green: 0.95, blue: 0.97))
            .frame(height: 420)
            .overlay(
                Group {
                    if let data = previewImageData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding(12)
                    } else if let modelData = Data(base64Encoded: tryOnModelBase64), let image = UIImage(data: modelData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding(12)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "person")
                                .font(.title2)
                                .foregroundStyle(Color(red: 0.60, green: 0.58, blue: 0.54))
                            Text(tryOnModelBase64.isEmpty ? "请替换模特生成试衣图" : "生成完成后在这里查看效果图")
                                .font(.subheadline)
                                .foregroundStyle(Color(red: 0.60, green: 0.58, blue: 0.54))
                        }
                    }
                }
            )
            .onTapGesture {
                if previewImageData != nil || !tryOnModelBase64.isEmpty {
                    showPreview = true
                }
            }
            .overlay {
                if generatingRecordID != nil {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22)
                            .fill(Color.black.opacity(0.12))
                        VStack(spacing: 10) {
                            AIGeneratingIconView()
                            Text("AI 生成中...")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.white)
                            Text("预计还需 \(countdownRemaining) 秒")
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.85))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black.opacity(0.35))
                        )
                    }
                }
            }
    }

    private var myOutfitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("我的搭配")
                    .font(.headline)
                    .foregroundStyle(AppTheme.bodyText)
                Spacer()
                Button {
                    newOutfitTitle = ""
                    selectedItemIDs = []
                    showOutfitBuilder = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("添加搭配")
                    }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.actionText)
            }
            if isLoadingData {
                ProgressView("加载中...")
                    .foregroundStyle(AppTheme.secondaryText)
            } else if manualOutfits.isEmpty {
                Text("暂无搭配记录")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(manualOutfits.sorted(by: { $0.createdAt > $1.createdAt })) { record in
                            TryOnOutfitCard(
                                record: record,
                                items: items(for: record),
                                isGenerating: generatingRecordID == record.id,
                                isSharing: sharingRecordID == record.id,
                                priceText: "10穿贝/次",
                                onView: { previewImageData = record.aiTryOnImageData },
                                onTryOn: { Task { await generateTryOn(for: record) } },
                                onShare: { Task { await shareOutfit(record) } }
                            )
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteOutfit(record)
                                } label: {
                                    Text("删除")
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var aiRecommendationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("基于 MBTI 与星座从衣橱生成搭配")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedText)
                Spacer()
                Button("更多需求") {
                    showScenePicker = true
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.actionText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.95))
                )
                if !selectedScene.isEmpty {
                    Text(selectedScene)
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtleText)
                }
                Button(isGeneratingRecommendation ? "生成中..." : "生成推荐") {
                    Task { await generateAIRecommendation() }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(AppTheme.primary)
                )
                .disabled(isGeneratingRecommendation || selectedScene.isEmpty)
            }

            if selectedScene.isEmpty {
                Text("请选择需求后生成推荐。")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            } else if isGeneratingRecommendation {
                ProgressView("正在筛选衣橱搭配...")
                    .foregroundStyle(AppTheme.secondaryText)
            }

            if selectedScene.isEmpty {
                EmptyView()
            } else if aiRecommendationDrafts.isEmpty {
                Text("暂无推荐搭配，点击“生成推荐”。")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(aiRecommendationDrafts) { draft in
                            let savedRecord = savedRecord(for: draft)
                            TryOnRecommendationCard(
                                draft: draft,
                                items: items(for: draft),
                                savedRecord: savedRecord,
                                isGenerating: generatingRecordID == savedRecord?.id,
                                onSave: { saveAIRecommendation(draft) },
                                onGenerate: {
                                    if let savedRecord {
                                        Task { await generateTryOn(for: savedRecord) }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            let aiOutfits = aiRecommendedOutfits
            if !aiOutfits.isEmpty {
                Text("最近保存的 AI 推荐")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedText)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        let visible = Array(aiOutfits.prefix(3))
                        ForEach(visible) { record in
                            TryOnOutfitCard(
                                record: record,
                                items: items(for: record),
                                isGenerating: generatingRecordID == record.id,
                                isSharing: sharingRecordID == record.id,
                                priceText: "10穿贝/次",
                                onView: { previewImageData = record.aiTryOnImageData },
                                onTryOn: { Task { await generateTryOn(for: record) } },
                                onShare: { Task { await shareOutfit(record) } }
                            )
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteOutfit(record)
                                } label: {
                                    Text("删除")
                                }
                            }
                        }
                        if aiOutfits.count > 3 {
                            MoreSavedOutfitsCard()
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .confirmationDialog("选择需求", isPresented: $showScenePicker, titleVisibility: .visible) {
            ForEach(sceneOptions, id: \.self) { scene in
                Button(scene) { selectedScene = scene }
            }
            Button("取消", role: .cancel) {}
        }
    }

    private func items(for record: OutfitRecord) -> [ClothingItem] {
        guard !record.itemIDs.isEmpty else { return [] }
        return clothingItems.filter { record.itemIDs.contains($0.id) }
    }

    private func items(for draft: TryOnRecommendationDraft) -> [ClothingItem] {
        guard !draft.itemIDs.isEmpty else { return [] }
        let lookup = Dictionary(uniqueKeysWithValues: clothingItems.map { ($0.id, $0) })
        return draft.itemIDs.compactMap { lookup[$0] }
    }

    private func loadData() {
        isLoadingData = true
        defer { isLoadingData = false }
        let isGuest = currentOwnerKey == SharedConstants.guestOwnerKey
        do {
            outfitRecords = try modelContext.fetch(FetchDescriptor<OutfitRecord>()).filter {
                $0.deletedAt == nil && ($0.ownerUsername == currentOwnerKey || (isGuest && $0.ownerUsername.isEmpty))
            }
            let items = try modelContext.fetch(FetchDescriptor<ClothingItem>())
            clothingItems = items.filter {
                $0.deletedAt == nil && ($0.ownerUsername == currentOwnerKey || (isGuest && $0.ownerUsername.isEmpty))
            }
        } catch {
            outfitRecords = []
            clothingItems = []
        }
    }

    private func deleteOutfit(_ record: OutfitRecord) {
        record.deletedAt = Date()
        outfitRecords.removeAll { $0.id == record.id }
    }

    private func shareOutfit(_ record: OutfitRecord) async {
        guard !record.isShared else {
            infoMessage = "这套搭配已分享，可在探索页查看。"
            return
        }
        guard !authToken.isEmpty else {
            errorMessage = "请先登录后再分享搭配。"
            return
        }

        sharingRecordID = record.id
        defer { sharingRecordID = nil }

        do {
            let api = ClothesAPIService.shared
            api.setAuthToken(authToken)

            if record.serverOutfitID == nil || record.syncStatus != .synced {
                WardrobeSyncService.shared.markOutfitPending(record)
                try await WardrobeSyncService.shared.syncOutfitNow(record, modelContext: modelContext)
            }

            guard let serverID = record.serverOutfitID else {
                errorMessage = "分享失败，请稍后重试。"
                return
            }
            try await api.shareOutfit(id: serverID)
            record.isShared = true
            WardrobeSyncService.shared.markOutfitPending(record)
            Task { @MainActor in
                await WardrobeSyncService.shared.syncNow(modelContext: modelContext)
            }
            infoMessage = "分享成功，其他用户现在可以在探索页看到这套搭配。"
        } catch {
            errorMessage = "分享失败：\(error.localizedDescription)"
        }
    }

    private func generateTryOn(for record: OutfitRecord) async {
        guard generatingRecordID == nil else { return }
        guard !authToken.isEmpty else {
            errorMessage = "请先登录后再试穿。"
            return
        }
        guard let modelData = Data(base64Encoded: tryOnModelBase64) else {
            errorMessage = "请先替换模特并生成试衣模特。"
            return
        }
        let items = items(for: record)
        let clothingImages = items.compactMap { $0.imageData }
        guard !clothingImages.isEmpty else {
            errorMessage = "该搭配缺少衣物图片，无法试穿。"
            return
        }

        // 先检查余额是否足够
        do {
            let wallet = try await WalletService().fetchWallet(token: authToken)
            guard wallet.balance >= tryOnCost else {
                errorMessage = "穿贝不足，无法试穿。当前余额：\(wallet.balance)，需要：\(tryOnCost)"
                return
            }
        } catch {
            errorMessage = "无法获取穿贝余额，请检查网络连接。"
            return
        }

        generatingRecordID = record.id
        startCountdown()
        defer {
            generatingRecordID = nil
            stopCountdown()
        }

        do {
            _ = try await WalletService().consumeCoins(
                token: authToken,
                amount: tryOnCost,
                reason: "虚拟试穿"
            )
            let service = AIVirtualTryOnService()
            let prompt = buildPrompt(items: items)
            let url = try await service.generateTryOn(prompt: prompt, images: [modelData] + clothingImages)
            let (data, _) = try await URLSession.shared.data(from: url)
            if record.personImageData == nil {
                record.personImageData = modelData
            }
            record.aiTryOnImageData = data
            record.imageData = data
            record.remoteImageURL = ""
            WardrobeSyncService.shared.markOutfitPending(record)
            Task { @MainActor in
                await WardrobeSyncService.shared.syncNow(modelContext: modelContext)
            }
            previewImageData = data
        } catch {
            if let serviceError = error as? ServiceError, serviceError.errno == 1201 {
                errorMessage = "穿贝不足，无法试穿。"
            } else {
                errorMessage = TryOnErrorReporting.handleTryOnGenerationFailure(error: error, recordID: record.id, itemCount: items.count, clothingImageCount: clothingImages.count, hasModelImage: !tryOnModelBase64.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, promptLength: buildPrompt(items: items).count)
            }
        }
    }

    private func startCountdown(duration: Int = 60) {
        countdownTimer?.invalidate()
        countdownRemaining = duration
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if countdownRemaining > 0 {
                countdownRemaining -= 1
            } else {
                stopCountdown()
            }
        }
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    private func buildPrompt(items: [ClothingItem]) -> String {
        AIPrompts.virtualTryOn(itemNames: items.map { $0.name })
    }

    private var currentOwnerKey: String {
        let trimmed = authUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? SharedConstants.guestOwnerKey : trimmed
    }

    private func loadTryOnModelState() {
        let defaults = UserDefaults.standard
        let owner = currentOwnerKey
        tryOnModelBase64 = defaults.string(forKey: tryOnModelKey("base64", owner: owner)) ?? ""
        tryOnHeight = defaults.string(forKey: tryOnModelKey("height", owner: owner)) ?? ""
        tryOnWeight = defaults.string(forKey: tryOnModelKey("weight", owner: owner)) ?? ""
    }

    private func applyTryOnModel(base64: String, height: String, weight: String) {
        let defaults = UserDefaults.standard
        let owner = currentOwnerKey
        tryOnModelBase64 = base64
        tryOnHeight = height
        tryOnWeight = weight
        defaults.set(base64, forKey: tryOnModelKey("base64", owner: owner))
        defaults.set(height, forKey: tryOnModelKey("height", owner: owner))
        defaults.set(weight, forKey: tryOnModelKey("weight", owner: owner))
    }

    private func tryOnModelKey(_ field: String, owner: String) -> String {
        "tryon_model_\(field)_\(owner)"
    }

    private var manualOutfits: [OutfitRecord] {
        outfitRecords.filter { !$0.title.hasPrefix("AI推荐") }
    }

    private var aiRecommendedOutfits: [OutfitRecord] {
        outfitRecords.filter { $0.title.hasPrefix("AI推荐") }
    }

    private func saveCustomOutfit() {
        let pickedItems = clothingItems.filter { selectedItemIDs.contains($0.id) }
        guard !pickedItems.isEmpty else {
            errorMessage = "请至少选择一件衣物。"
            return
        }
        let title = newOutfitTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "我的搭配"
            : newOutfitTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let names = pickedItems.map { $0.name }.joined(separator: "、")
        let ids = pickedItems.map { $0.id }
        let record = OutfitRecord(ownerUsername: currentOwnerKey, title: title, itemNames: names, itemIDs: ids)
        modelContext.insert(record)
        outfitRecords.insert(record, at: 0)
    }

    private func generateAIRecommendation() async {
        guard !isGeneratingRecommendation else { return }
        isGeneratingRecommendation = true
        defer { isGeneratingRecommendation = false }

        guard !selectedScene.isEmpty else {
            return
        }
        guard !clothingItems.isEmpty else {
            errorMessage = "衣橱里没有可推荐的衣物。"
            return
        }

        let drafts = buildRecommendationDrafts()
        guard !drafts.isEmpty else {
            errorMessage = "没有匹配到可用的衣物。"
            return
        }
        let savedKeys = Set(aiRecommendedOutfits.map { draftKey($0.itemIDs) })
        aiRecommendationDrafts = drafts.filter { !savedKeys.contains(draftKey($0.itemIDs)) }
    }

    private func saveAIRecommendation(_ draft: TryOnRecommendationDraft) {
        let pickedItems = items(for: draft)
        guard !pickedItems.isEmpty else { return }
        let ids = pickedItems.map { $0.id }
        let idSet = Set(ids)
        if outfitRecords.contains(where: { $0.title.hasPrefix("AI推荐") && Set($0.itemIDs) == idSet }) {
            return
        }
        let names = pickedItems.map { $0.name }.joined(separator: "、")
        let title = buildAIRecommendationTitle()
        let record = OutfitRecord(ownerUsername: currentOwnerKey, title: title, itemNames: names, itemIDs: ids)
        modelContext.insert(record)
        outfitRecords.insert(record, at: 0)
        aiRecommendationDrafts.removeAll { Set($0.itemIDs) == idSet }
    }

    private func savedRecord(for draft: TryOnRecommendationDraft) -> OutfitRecord? {
        let idSet = Set(draft.itemIDs)
        return outfitRecords.first { $0.title.hasPrefix("AI推荐") && Set($0.itemIDs) == idSet }
    }

    private func buildRecommendationDrafts() -> [TryOnRecommendationDraft] {
        let preferredColors = preferredColorTokens()
        let preferredStyles = preferredStyleTags()
        let preferredOccasions = preferredOccasionTokens()
        let preferredFits = preferredFitTokens()
        let currentSeason = currentSeasonTag()
        let temperatureValue = parseTemperature(dailyTemperature)
        let weatherText = dailyWeather

        var scoreCache: [UUID: Int] = [:]
        func score(_ item: ClothingItem) -> Int {
            if let cached = scoreCache[item.id] { return cached }
            var total = 0
            if !preferredColors.isEmpty, colorMatch(item.color, preferredColors) {
                total += 3
            }
            if !preferredStyles.isEmpty, !item.styleTags.isEmpty, item.styleTags.contains(where: { preferredStyles.contains($0) }) {
                total += 2
            }
            if !preferredOccasions.isEmpty, !item.occasions.isEmpty, item.occasions.contains(where: { preferredOccasions.contains($0) }) {
                total += 2
            }
            if !preferredFits.isEmpty, !item.fit.isEmpty, preferredFits.contains(where: { item.fit.contains($0) }) {
                total += 1
            }
            if item.seasons.contains(currentSeason) {
                total += 1
            }
            scoreCache[item.id] = total
            return total
        }

        func sortedItems(categories: [String]) -> [ClothingItem] {
            clothingItems
                .filter { categories.contains($0.category) }
                .sorted { score($0) > score($1) }
        }

        let tops = sortedItems(categories: ["上衣"])
        let bottoms = sortedItems(categories: ["长裤", "短裤"])
        let outers = sortedItems(categories: ["外套"])
        let shoes = sortedItems(categories: ["鞋子"])
        let accessories = sortedItems(categories: ["饰品"])
        let hats = sortedItems(categories: ["帽子"])
        let bags = sortedItems(categories: ["箱包"])
        let socks = sortedItems(categories: ["袜子"])
        let categoryPools: [String: [ClothingItem]] = [
            "外套": outers,
            "鞋子": shoes,
            "饰品": accessories,
            "帽子": hats,
            "箱包": bags,
            "袜子": socks
        ]

        var seenKeys = Set<String>()
        var combos: [(ids: [UUID], score: Int)] = []

        func addCombo(_ items: [ClothingItem]) {
            let ids = items.map { $0.id }
            let key = ids.map { $0.uuidString }.sorted().joined(separator: "-")
            guard !ids.isEmpty, !seenKeys.contains(key) else { return }
            seenKeys.insert(key)
            let totalScore = items.reduce(0) { $0 + score($1) }
            combos.append((ids: ids, score: totalScore))
        }

        func bestItem(from items: [ClothingItem], excluding ids: Set<UUID>) -> ClothingItem? {
            items.first { !ids.contains($0.id) }
        }

        let topCandidates = shuffled(tops).prefix(4)
        let bottomCandidates = shuffled(bottoms).prefix(4)

        for top in topCandidates {
            for bottom in bottomCandidates {
                var picked: [ClothingItem] = [top, bottom]
                var usedIDs = Set(picked.map { $0.id })

                let extraCategories = chooseExtraCategories(
                    currentSeason: currentSeason,
                    temperature: temperatureValue,
                    weatherText: weatherText
                )
                for category in extraCategories {
                    guard let pool = categoryPools[category] else { continue }
                    if let item = bestItem(from: shuffled(pool), excluding: usedIDs) {
                        picked.append(item)
                        usedIDs.insert(item.id)
                    }
                }
                addCombo(picked)
            }
        }

        if combos.isEmpty {
            let fallback = clothingItems.sorted { score($0) > score($1) }
            for item in fallback.prefix(3) {
                addCombo([item])
            }
        }

        return combos
            .sorted { $0.score > $1.score }
            .prefix(2)
            .enumerated()
            .map { index, combo in
                TryOnRecommendationDraft(
                    id: UUID(),
                    title: "推荐方案 \(index + 1)",
                    itemIDs: combo.ids,
                    score: combo.score
                )
            }
    }

    private func colorMatch(_ color: String, _ preferred: [String]) -> Bool {
        preferred.isEmpty || preferred.contains(where: { color.contains($0) || $0.contains(color) })
    }

    private func preferredFitTokens() -> [String] {
        switch profileBodyShape {
        case "偏瘦": return ["修身", "slim"]
        case "健身": return ["修身", "regular"]
        case "微胖", "丰满": return ["宽松", "loose", "regular"]
        default: return []
        }
    }

    private func chooseExtraCategories(currentSeason: String, temperature: Int?, weatherText: String) -> [String] {
        var preferred: [String] = []
        let isCold = (temperature ?? 100) <= 12 || currentSeason == "冬"
        let isVeryCold = (temperature ?? 100) <= 5
        let isRainy = weatherText.contains("雨")
        let isSunny = weatherText.contains("晴")

        if isCold { preferred.append("外套") }
        if isVeryCold { preferred.append("袜子") }
        if isRainy || isSunny { preferred.append("帽子") }
        preferred.append("鞋子")

        let mbti = profileMbti.uppercased()
        if mbti.contains("E") { preferred.append("饰品") }
        if mbti.contains("I") && !preferred.contains("饰品") && Bool.random() { preferred.append("饰品") }

        let randomExtras = ["饰品", "帽子", "袜子", "外套", "鞋子", "箱包"]
        let count = Int.random(in: 2...4)
        while preferred.count < count {
            if let pick = randomExtras.randomElement(), !preferred.contains(pick) {
                preferred.append(pick)
            }
        }

        return Array(Set(preferred))
    }

    private func shuffled<T>(_ items: [T]) -> [T] {
        var copy = items
        copy.shuffle()
        return copy
    }

    private func parseTemperature(_ raw: String) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let digits = trimmed.split { !("-0123456789".contains($0)) }
        guard let first = digits.first, let value = Int(first) else { return nil }
        return value
    }

    private func preferredColorTokens() -> [String] {
        var tokens = parseTokens(preferenceColors)
        let zodiacColors: [String: [String]] = [
            "白羊座": ["红", "橙"],
            "金牛座": ["棕", "米", "卡其"],
            "双子座": ["黄", "浅蓝"],
            "巨蟹座": ["白", "银", "浅灰"],
            "狮子座": ["金", "橙", "红"],
            "处女座": ["米", "卡其", "灰"],
            "天秤座": ["蓝", "白", "灰"],
            "天蝎座": ["黑", "深蓝"],
            "射手座": ["蓝", "棕"],
            "摩羯座": ["黑", "灰", "深棕"],
            "水瓶座": ["蓝", "银", "灰"],
            "双鱼座": ["浅蓝", "白"]
        ]
        if let extras = zodiacColors[profileZodiac] {
            tokens.append(contentsOf: extras)
        }
        return uniqueTokens(tokens)
    }

    private func preferredStyleTags() -> [String] {
        let mbti = profileMbti.uppercased()
        var tags: [String] = []
        if mbti.contains("I") { tags.append(contentsOf: ["极简", "文艺"]) }
        if mbti.contains("E") { tags.append(contentsOf: ["街头", "活力"]) }
        if mbti.contains("N") { tags.append(contentsOf: ["前卫", "设计感"]) }
        if mbti.contains("S") { tags.append(contentsOf: ["通勤", "基础"]) }
        if mbti.contains("T") { tags.append(contentsOf: ["利落", "中性"]) }
        if mbti.contains("F") { tags.append(contentsOf: ["柔和", "优雅"]) }
        if mbti.contains("J") { tags.append(contentsOf: ["经典", "通勤"]) }
        if mbti.contains("P") { tags.append(contentsOf: ["休闲", "随性"]) }
        return uniqueTokens(tags)
    }

    private func preferredOccasionTokens() -> [String] {
        let base = parseTokens(preferenceOccasions)
        if selectedScene.isEmpty { return base }
        return uniqueTokens(base + [selectedScene])
    }

    private func parseTokens(_ raw: String) -> [String] {
        raw
            .split { $0 == "," || $0 == "、" || $0 == "/" || $0 == " " }
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func uniqueTokens(_ tokens: [String]) -> [String] {
        Array(Set(tokens)).sorted()
    }

    private func currentSeasonTag() -> String {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 3...5: return "春"
        case 6...8: return "夏"
        case 9...11: return "秋"
        default: return "冬"
        }
    }

    private func draftKey(_ ids: [UUID]) -> String {
        ids.map { $0.uuidString }.sorted().joined(separator: "-")
    }

    private func buildAIRecommendationTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日HHmm"
        let datePart = formatter.string(from: Date())
        let randomPart = Int.random(in: 100...999)
        return "AI推荐\(datePart)\(randomPart)"
    }

}

private struct TryOnOutfitBuilderSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: Binding<String>
    let items: [ClothingItem]
    @Binding var selectedItemIDs: Set<UUID>
    let onSave: () -> Void

    private let categories = CategoryConfig.categories
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        TextField("", text: title, prompt: Text("搭配名称（可选）").foregroundStyle(AppTheme.placeholder))
                            .appInputStyle()

                        ForEach(categories, id: \.self) { category in
                            let filtered = items.filter { $0.category == category }
                            if !filtered.isEmpty {
                                Text(category)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.bodyText)
                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(filtered) { item in
                                        TryOnSelectCard(item: item, isSelected: selectedItemIDs.contains(item.id)) {
                                            toggle(item.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .adaptiveContentWidth(maxWidth: 760)
                }
            }
            .navigationTitle("选择衣物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                        .toolbarDoneButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        onSave()
                    }
                    .contentShape(Rectangle())
                }
            }
        }
    }

    private func toggle(_ id: UUID) {
        if selectedItemIDs.contains(id) {
            selectedItemIDs.remove(id)
        } else if selectedItemIDs.count < 10 {
            selectedItemIDs.insert(id)
        }
    }
}

private struct TryOnSelectCard: View {
    let item: ClothingItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .frame(height: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(red: 0.90, green: 0.88, blue: 0.84), lineWidth: 1)
                        )

                    if let image = cachedThumbnail(id: item.id, data: item.imageData, maxPixel: 240) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 110)
                    }

                    Circle()
                        .fill(isSelected ? Color(red: 0.58, green: 0.47, blue: 0.37) : Color.white)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.caption2)
                                .foregroundStyle(isSelected ? Color.white : Color.clear)
                        )
                        .padding(6)
                }
                Text(item.name.isEmpty ? "未命名单品" : item.name)
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.19))
                Text(item.category)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.subtleText)
            }
        }
        .buttonStyle(.appPlain)
    }
}

private struct TryOnOutfitCard: View {
    let record: OutfitRecord
    let items: [ClothingItem]
    let isGenerating: Bool
    let isSharing: Bool
    let priceText: String
    let onView: () -> Void
    let onTryOn: () -> Void
    let onShare: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white)
                .frame(width: 150, height: 180)
                .overlay(
                    VStack(spacing: 6) {
                        let previewItems = Array(items.prefix(4))
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                            ForEach(previewItems) { item in
                                if let image = cachedThumbnail(id: item.id, data: item.imageData, maxPixel: 120) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 60)
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(red: 0.95, green: 0.95, blue: 0.97))
                                        .frame(height: 60)
                                }
                            }
                        }
                    }
                    .padding(10)
                )
                .onTapGesture {
                    if record.aiTryOnImageData != nil {
                        onView()
                    }
                }

            Text(record.title.isEmpty ? "未命名搭配" : record.title)
                .font(.caption)
                .foregroundStyle(AppTheme.mutedText)

            HStack(spacing: 6) {
                Text(priceText)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.subtleText)
                Text(record.isShared ? "已分享" : "私密")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(record.isShared ? Color.green : AppTheme.subtleText)
            }

            Button(record.aiTryOnImageData != nil ? (isGenerating ? "生成中..." : "重新生成") : (isGenerating ? "生成中..." : "生成")) {
                onTryOn()
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.white)
            .frame(width: 120)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(AppTheme.primary)
            )
            .disabled(isGenerating)

            // 分享功能暂不开放，下一期再做
            // Button(record.isShared ? "已分享" : (isSharing ? "分享中..." : "分享到探索")) {
            //     onShare()
            // }
            // .font(.caption.weight(.semibold))
            // .foregroundStyle(record.isShared ? Color(red: 0.30, green: 0.54, blue: 0.33) : AppTheme.actionText)
            // .frame(width: 120)
            // .padding(.vertical, 7)
            // .background(
            //     Capsule()
            //         .fill(record.isShared ? Color(red: 0.92, green: 0.98, blue: 0.92) : Color.white)
            //         .overlay(
            //             Capsule()
            //                 .stroke(record.isShared ? Color(red: 0.63, green: 0.83, blue: 0.64) : Color(red: 0.84, green: 0.80, blue: 0.74), lineWidth: 1)
            //         )
            // )
            // .disabled(record.isShared || isSharing)
        }
    }
}

private struct MoreSavedOutfitsCard: View {
    var body: some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.9))
                .frame(width: 150, height: 180)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "ellipsis")
                            .font(.title2)
                            .foregroundStyle(AppTheme.secondaryText)
                        Text("更多请到")
                            .font(.caption)
                            .foregroundStyle(AppTheme.mutedText)
                        Text("搭配列表")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(red: 0.36, green: 0.30, blue: 0.24))
                    }
                )
        }
    }
}

private struct TryOnRecommendationDraft: Identifiable {
    let id: UUID
    let title: String
    let itemIDs: [UUID]
    let score: Int
}

private struct TryOnRecommendationCard: View {
    let draft: TryOnRecommendationDraft
    let items: [ClothingItem]
    let savedRecord: OutfitRecord?
    let isGenerating: Bool
    let onSave: () -> Void
    let onGenerate: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white)
                .frame(width: 150, height: 180)
                .overlay(
                    VStack(spacing: 6) {
                        let previewItems = Array(items.prefix(4))
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                            ForEach(previewItems) { item in
                                if let image = cachedThumbnail(id: item.id, data: item.imageData, maxPixel: 120) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 60)
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(red: 0.95, green: 0.95, blue: 0.97))
                                        .frame(height: 60)
                                }
                            }
                        }
                    }
                    .padding(10)
                )

            Text(draft.title)
                .font(.caption)
                .foregroundStyle(AppTheme.mutedText)

            Text("10穿贝/次")
                .font(.caption2)
                .foregroundStyle(AppTheme.subtleText)

            Button(buttonTitle) {
                if savedRecord == nil {
                    onSave()
                } else {
                    onGenerate()
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.white)
            .frame(width: 120)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(AppTheme.primary)
            )
            .disabled(isGenerating && savedRecord != nil)
        }
    }

    private var buttonTitle: String {
        if savedRecord != nil {
            return isGenerating ? "生成中..." : "生成"
        }
        return "保存搭配"
    }
}

private struct TryOnModelSheet: View {
    @Environment(\.dismiss) private var dismiss
    let initialHeight: String
    let initialWeight: String
    let onComplete: (String, String, String) -> Void

    @AppStorage("auth_token") private var authToken = ""
    @AppStorage("body_size") private var bodySize = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var height: String
    @State private var weight: String
    @State private var isLoading = false
    @State private var countdownRemaining = 60
    @State private var countdownProgress: Double = 0
    @State private var countdownTimer: Timer?
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private let tryOnCost: Int64 = 10

    private enum Field {
        case height
        case weight
    }

    init(initialHeight: String, initialWeight: String, onComplete: @escaping (String, String, String) -> Void) {
        self.initialHeight = initialHeight
        self.initialWeight = initialWeight
        self.onComplete = onComplete
        _height = State(initialValue: initialHeight)
        _weight = State(initialValue: initialWeight)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("替换模特")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.bodyText)

                        PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                            VStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.white)
                                    .frame(height: 220)
                                    .overlay(
                                        Group {
                                            if let data = photoData, let image = UIImage(data: data) {
                                                Image(uiImage: image)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .padding(10)
                                            } else {
                                                VStack(spacing: 6) {
                                                    Image(systemName: "plus")
                                                        .font(.title2)
                                                        .foregroundStyle(Color(red: 0.60, green: 0.58, blue: 0.54))
                                                    Text("上传正面全身照")
                                                        .font(.subheadline)
                                                        .foregroundStyle(Color(red: 0.60, green: 0.58, blue: 0.54))
                                                }
                                            }
                                        }
                                    )
                            }
                        }

                        TextField("", text: $height, prompt: Text("身高（cm）").foregroundStyle(AppTheme.placeholder))
                            .keyboardType(.numberPad)
                            .appInputStyle()
                            .focused($focusedField, equals: .height)

                        TextField("", text: $weight, prompt: Text("体重（kg）").foregroundStyle(AppTheme.placeholder))
                            .keyboardType(.numberPad)
                            .appInputStyle()
                            .focused($focusedField, equals: .weight)

                        if isLoading {
                            VStack(spacing: 10) {
                                AIGeneratingIconView()
                                Text("AI 正在生成试衣模特...")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.bodyText)
                                Text("预计还需 \(countdownRemaining) 秒")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondaryText)
                                ProgressView(value: countdownProgress)
                                    .tint(AppTheme.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.92))
                            )
                        }

                        Button {
                            Task { await generateModel() }
                        } label: {
                            Text(isLoading ? "生成中..." : "生成试衣模特")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(AppTheme.primary)
                                )
                        }
                        .disabled(isLoading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .adaptiveContentWidth(maxWidth: 680)
                }
            }
            .navigationTitle("替换模特")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                        .toolbarDoneButton()
                }
            }
        }
        .onChange(of: photoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    photoData = data
                }
            }
        }
        .alert("提示", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onDisappear {
            stopCountdown()
        }
    }

    private func generateModel() async {
        guard !isLoading else { return }
        guard !authToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "请先登录后再生成试衣模特。"
            return
        }
        guard let photoData else {
            errorMessage = "请上传正面全身照。"
            return
        }
        let trimmedHeight = height.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedWeight = weight.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHeight.isEmpty, !trimmedWeight.isEmpty else {
            errorMessage = "请填写身高和体重。"
            return
        }

        // 先检查余额是否足够
        do {
            let wallet = try await WalletService().fetchWallet(token: authToken)
            guard wallet.balance >= tryOnCost else {
                errorMessage = "穿贝不足，无法生成模特。当前余额：\(wallet.balance)，需要：\(tryOnCost)"
                return
            }
        } catch {
            errorMessage = "无法获取穿贝余额，请检查网络连接。"
            return
        }

        isLoading = true
        startCountdown()
        defer {
            isLoading = false
            stopCountdown()
        }

        do {
            // 先扣费
            _ = try await WalletService().consumeCoins(
                token: authToken,
                amount: tryOnCost,
                reason: "生成试衣模特"
            )
            let service = AIVirtualTryOnService()
            let url = try await service.generateBaseModel(
                personImage: photoData,
                height: trimmedHeight,
                weight: trimmedWeight,
                size: bodySize.isEmpty ? "未填写" : bodySize
            )
            let (data, _) = try await URLSession.shared.data(from: url)
            let base64 = data.base64EncodedString()
            onComplete(base64, trimmedHeight, trimmedWeight)
            dismiss()
        } catch {
            if let serviceError = error as? ServiceError, serviceError.errno == 1201 {
                errorMessage = "穿贝不足，无法生成模特。"
            } else {
                errorMessage = TryOnErrorReporting.handleModelGenerationFailure(error: error, height: trimmedHeight, weight: trimmedWeight, hasPhoto: photoData != nil, size: bodySize)
            }
        }
    }

    private func startCountdown(duration: Int = 60) {
        countdownTimer?.invalidate()
        countdownRemaining = duration
        countdownProgress = 0
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if countdownRemaining > 0 {
                countdownRemaining -= 1
                countdownProgress = 1 - (Double(countdownRemaining) / Double(duration))
            } else {
                countdownProgress = 1
                stopCountdown()
            }
        }
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
}

private struct TryOnHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    let records: [OutfitRecord]
    let onSelect: (OutfitRecord) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                List {
                    let generated = records.filter { $0.aiTryOnImageData != nil }
                    if generated.isEmpty {
                        Text("暂无试穿记录")
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(generated.sorted(by: { $0.createdAt > $1.createdAt })) { record in
                            Button {
                                onSelect(record)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    if let data = record.aiTryOnImageData,
                                       let image = cachedThumbnail(id: record.id, data: data, maxPixel: 120) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 72, height: 72)
                                            .clipped()
                                            .cornerRadius(12)
                                    } else {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(red: 0.93, green: 0.91, blue: 0.87))
                                            .frame(width: 72, height: 72)
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(record.title)
                                            .font(.subheadline.weight(.medium))
                                        Text(record.itemNames)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                            .buttonStyle(.appPlain)
                            .listRowBackground(Color.clear)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("试穿记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                        .toolbarDoneButton()
                }
            }
        }
    }
}
