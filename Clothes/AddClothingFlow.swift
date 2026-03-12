// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  AddClothingFlow.swift
//  Clothes
//
//  Created by lzy on 2026/1/6.
//

import CoreImage
import CoreML
import CryptoKit
import ImageIO
import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Vision

struct AddClothingFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("auth_username") private var authUsername = ""

    @State private var drafts: [ClothingDraft] = []
    @State private var selectedIndex = 0
    @State private var applyToAll = false
    @State private var showCamera = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var splitPhotoItem: PhotosPickerItem?
    @State private var isLoading = false
    @State private var isFlattening = false
    @State private var loadError: String?
    @State private var showManualErase = false
    @State private var activePicker: AddClothingWheelPicker?

    private let categories = CategoryConfig.categories
    private let seasons = ["春", "夏", "秋", "冬", "四季"]
    private let occasions = ["工作", "休闲", "运动", "校园", "约会", "居家", "度假", "宴会"]
    private let colors: [ColorOption] = [
        ColorOption(name: "白色系", color: Color(red: 0.96, green: 0.96, blue: 0.96), rgb: (0.96, 0.96, 0.96)),
        ColorOption(name: "杏色系", color: Color(red: 0.86, green: 0.78, blue: 0.66), rgb: (0.86, 0.78, 0.66)),
        ColorOption(name: "黄色系", color: Color(red: 0.98, green: 0.83, blue: 0.32), rgb: (0.98, 0.83, 0.32)),
        ColorOption(name: "橙色系", color: Color(red: 0.98, green: 0.57, blue: 0.22), rgb: (0.98, 0.57, 0.22)),
        ColorOption(name: "红色系", color: Color(red: 0.92, green: 0.28, blue: 0.26), rgb: (0.92, 0.28, 0.26)),
        ColorOption(name: "粉色系", color: Color(red: 0.96, green: 0.70, blue: 0.74), rgb: (0.96, 0.70, 0.74)),
        ColorOption(name: "紫色系", color: Color(red: 0.55, green: 0.39, blue: 0.85), rgb: (0.55, 0.39, 0.85)),
        ColorOption(name: "蓝色系", color: Color(red: 0.28, green: 0.50, blue: 0.91), rgb: (0.28, 0.50, 0.91)),
        ColorOption(name: "绿色系", color: Color(red: 0.40, green: 0.72, blue: 0.26), rgb: (0.40, 0.72, 0.26)),
        ColorOption(name: "棕色系", color: Color(red: 0.46, green: 0.30, blue: 0.16), rgb: (0.46, 0.30, 0.16)),
        ColorOption(name: "咖色系", color: Color(red: 0.60, green: 0.46, blue: 0.36), rgb: (0.60, 0.46, 0.36)),
        ColorOption(name: "灰色系", color: Color(red: 0.58, green: 0.58, blue: 0.58), rgb: (0.58, 0.58, 0.58)),
        ColorOption(name: "黑色系", color: Color(red: 0.12, green: 0.12, blue: 0.12), rgb: (0.12, 0.12, 0.12))
    ]

    private var currentOwnerKey: String {
        let trimmed = authUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? SharedConstants.guestOwnerKey : trimmed
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackdrop()
                contentView
            }
            .navigationTitle("上传衣物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera) { image in
                if let data = image.jpegData(compressionQuality: 0.9) {
                    Task {
                        await addDraftAndProcess(from: downsampledImageData(data) ?? data)
                    }
                }
            }
        }
        .sheet(isPresented: $showManualErase) {
            ManualEraseView(imageData: bindingForDraftImage())
        }
        .sheet(item: $activePicker) { picker in
            AddClothingWheelPickerSheet(picker: picker)
        }
        .alert("导入失败", isPresented: Binding(get: { loadError != nil }, set: { _ in loadError = nil })) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(loadError ?? "未知错误")
        }
        .onChange(of: photoItems) { _, newItems in
            Task {
                await loadPhotos(from: newItems)
            }
        }
        .onChange(of: splitPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await splitOutfitPhoto(from: newItem)
                splitPhotoItem = nil
            }
        }
    }

    private var contentView: AnyView {
        if drafts.isEmpty {
            return AnyView(sourceSelection)
        }
        return AnyView(editorView)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("取消") {
                dismiss()
            }
            .foregroundStyle(AppTheme.actionText)
        }
        ToolbarItem(placement: .topBarTrailing) {
            if !drafts.isEmpty {
                Button("保存") {
                    saveDrafts()
                }
                .foregroundStyle(AppTheme.actionText)
                .contentShape(Rectangle())
            }
        }
    }

    private var sourceSelection: some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                Text("添加到衣橱")
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .foregroundStyle(AppTheme.titleText)
                Text("支持拍照、相册与批量导入")
                    .font(.callout)
                    .foregroundStyle(Color(red: 0.53, green: 0.45, blue: 0.38))
            }

            VStack(spacing: 12) {
                PrimaryActionButton(title: "拍照添加", systemImage: "camera") {
                    showCamera = true
                }

                PhotosPicker(selection: $splitPhotoItem, matching: .images, photoLibrary: .shared()) {
                    ActionCard(title: "整图拆解", systemImage: "scissors")
                }

                PhotosPicker(selection: $photoItems, maxSelectionCount: 1, matching: .images, photoLibrary: .shared()) {
                    ActionCard(title: "相册选择", systemImage: "photo.on.rectangle")
                }

                PhotosPicker(selection: $photoItems, maxSelectionCount: 20, matching: .images, photoLibrary: .shared()) {
                    ActionCard(title: "批量导入", systemImage: "square.grid.2x2")
                }
            }
            .padding(.horizontal, 24)

            if isLoading {
                ProgressView("导入中...")
                    .tint(Color(red: 0.45, green: 0.38, blue: 0.32))
            }

            Spacer()
        }
        .padding(.top, 32)
    }

    private var editorView: some View {
        ScrollView {
            VStack(spacing: 20) {
                thumbnailStrip
                selectionHint

                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        Toggle("", isOn: $applyToAll)
                            .labelsHidden()
                            .tint(Color(red: 0.58, green: 0.47, blue: 0.37))
                        Text("开启后，修改当前单品的信息会同步到全部已选图片。")
                            .font(.caption)
                            .foregroundStyle(Color(red: 0.46, green: 0.46, blue: 0.46))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                    }

                    EditSection(title: "图片处理") {
                        HStack(spacing: 12) {
                            SecondaryActionButton(title: "手动抹除", systemImage: "pencil.tip") {
                                showManualErase = true
                            }
                            SecondaryActionButton(title: "旋转左", systemImage: "arrow.counterclockwise") {
                                rotateCurrent(clockwise: false)
                            }
                            SecondaryActionButton(title: "旋转右", systemImage: "arrow.clockwise") {
                                rotateCurrent(clockwise: true)
                            }
                            SecondaryActionButton(title: isFlattening ? "处理中" : "整理美化", systemImage: "square.stack.3d.up") {
                                generateFlatLayForCurrentDraft()
                            }
                            .disabled(isFlattening)
                        }
                        Text("默认已进行本地去背景与自动矫正，识别不准可手动旋转或抹除。")
                            .font(.caption)
                            .foregroundStyle(AppTheme.mutedText)
                    }

                    EditSection(title: "基础信息") {
                        AddClothingListRow(title: "品类", showDivider: true, onTap: {
                            showWheelPicker(title: "选择品类", options: categories, current: currentDraft?.category ?? "") { selected in
                                updateDraft(\.category, to: selected)
                            }
                        }) {
                            AddClothingValueCapsule(text: currentDraft?.category.isEmpty == false ? (currentDraft?.category ?? "") : "未选择")
                        }
                        AddClothingListRow(title: "季节", showDivider: true, onTap: {
                            showWheelPicker(title: "选择季节", options: seasons, current: currentDraft?.seasons.first ?? "") { selected in
                                updateDraft(\.seasons, to: [selected])
                            }
                        }) {
                            AddClothingValueCapsule(text: currentDraft?.seasons.first ?? "未选择")
                        }
                        AddClothingListRow(title: "适用场景", showDivider: true, onTap: {
                            showWheelPicker(title: "选择适用场景", options: occasions, current: currentDraft?.occasions.first ?? "") { selected in
                                updateDraft(\.occasions, to: [selected])
                            }
                        }) {
                            AddClothingValueCapsule(text: currentDraft?.occasions.first ?? "未选择")
                        }
                        AddClothingListRow(title: "色系", showDivider: false) {
                            AddClothingColorPicker(options: colors, selection: binding(for: \ClothingDraft.color))
                        }
                    }

                    VStack(spacing: 12) {
                        PrimaryActionButton(title: "保存到衣橱", systemImage: "checkmark") {
                            saveDrafts()
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var thumbnailStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(drafts.indices, id: \.self) { index in
                    let draft = drafts[index]
                    VStack(spacing: 6) {
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(red: 0.90, green: 0.86, blue: 0.80))
                                .frame(width: 90, height: 120)
                            if let image = UIImage(data: draft.imageData) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 90, height: 120)
                                    .clipped()
                                    .cornerRadius(12)
                                    .opacity(draft.isProcessing ? 0.65 : 1)
                                    .onTapGesture {
                                        selectedIndex = index
                                    }
                            }
                            if draft.isProcessing {
                                ProgressView()
                                    .tint(Color.white)
                            }
                            Button {
                                toggleSelection(for: index)
                            } label: {
                                Image(systemName: draft.isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.caption)
                                    .foregroundStyle(draft.isSelected ? Color.green : Color.white)
                                    .padding(6)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.35))
                                    )
                            }
                            .padding(6)
                        }

                        Text(draft.category)
                            .font(.caption)
                            .foregroundStyle(Color(red: 0.53, green: 0.45, blue: 0.38))
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedIndex == index ? Color(red: 0.58, green: 0.47, blue: 0.37) : Color.clear, lineWidth: 2)
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var selectionHint: some View {
        let selectedCount = drafts.filter { $0.isSelected }.count
        return HStack {
            Text("已选 \(selectedCount) 件")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.actionText)
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var currentDraft: ClothingDraft? {
        guard drafts.indices.contains(selectedIndex) else { return nil }
        return drafts[selectedIndex]
    }

    private func binding<T>(for keyPath: WritableKeyPath<ClothingDraft, T>) -> Binding<T> {
        Binding(
            get: {
                guard drafts.indices.contains(selectedIndex) else { return ClothingDraft.placeholder()[keyPath: keyPath] }
                return drafts[selectedIndex][keyPath: keyPath]
            },
            set: { newValue in
                guard drafts.indices.contains(selectedIndex) else { return }
                if applyToAll {
                    for index in drafts.indices {
                        drafts[index][keyPath: keyPath] = newValue
                    }
                } else {
                    drafts[selectedIndex][keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func updateDraft<T>(_ keyPath: WritableKeyPath<ClothingDraft, T>, to newValue: T) {
        guard drafts.indices.contains(selectedIndex) else { return }
        if applyToAll {
            for index in drafts.indices {
                drafts[index][keyPath: keyPath] = newValue
            }
        } else {
            drafts[selectedIndex][keyPath: keyPath] = newValue
        }
    }

    private func generateFlatLayForCurrentDraft() {
        guard !isFlattening else { return }
        guard drafts.indices.contains(selectedIndex) else {
            loadError = "请先选择要处理的衣物。"
            return
        }
        let data = drafts[selectedIndex].imageData
        guard !data.isEmpty else {
            loadError = "请先添加衣物照片。"
            return
        }

        isFlattening = true
        Task {
            do {
                let service = AIVirtualTryOnService()
                let url = try await service.generateFlatLay(imageData: data, prompt: AIPrompts.flatLay)
                let (fileURL, _) = try await URLSession.shared.download(from: url)
                let compressedData = try await Task.detached(priority: .userInitiated) {
                    let data: Data? = autoreleasepool {
                        downsampledImageData(fileURL: fileURL, maxPixel: 2048, quality: 0.85)
                    }
                    guard let data else {
                        throw FlatLayProcessingError.imageProcessingFailed
                    }
                    return data
                }.value

                let refinedData = await Task.detached(priority: .userInitiated) {
                    guard #available(iOS 17.0, *),
                          let image = UIImage(data: compressedData),
                          let cleaned = BackgroundRemoval.removeBackground(image: image),
                          let output = cleaned.pngData() else {
                        return compressedData
                    }
                    return output
                }.value

                try? FileManager.default.removeItem(at: fileURL)

                await MainActor.run {
                    guard drafts.indices.contains(selectedIndex) else {
                        isFlattening = false
                        return
                    }
                    drafts[selectedIndex].imageData = refinedData
                    drafts[selectedIndex].originalImageData = refinedData
                    isFlattening = false
                }
            } catch {
                await MainActor.run {
                    if error is FlatLayProcessingError {
                        loadError = "整理美化失败：图片处理失败，请稍后再试。"
                    } else {
                        loadError = "整理美化失败：\(error.localizedDescription)"
                    }
                    isFlattening = false
                }
            }
        }
    }

    private func showWheelPicker(title: String, options: [String], current: String, onSelect: @escaping (String) -> Void) {
        let initial = current.isEmpty ? (options.first ?? "") : current
        activePicker = AddClothingWheelPicker(
            title: title,
            options: options.isEmpty ? ["未提供"] : options,
            selection: initial,
            onSelect: onSelect
        )
    }

    private func bindingForDraftImage() -> Binding<Data?> {
        Binding(
            get: {
                guard drafts.indices.contains(selectedIndex) else { return nil }
                return drafts[selectedIndex].imageData
            },
            set: { newValue in
                guard drafts.indices.contains(selectedIndex) else { return }
                drafts[selectedIndex].imageData = newValue ?? drafts[selectedIndex].imageData
                drafts[selectedIndex].originalImageData = newValue ?? drafts[selectedIndex].originalImageData
            }
        )
    }

    private func loadPhotos(from items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        for item in items.prefix(20) {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    let normalized = downsampledImageData(data) ?? data
                    await addDraftAndProcess(from: normalized)
                }
            } catch {
                loadError = "无法读取照片，请重试。"
            }
        }

        if drafts.isEmpty {
            loadError = "没有导入到可用的照片。"
        }
        photoItems = []
    }

    private func saveDrafts() {
        let selectedDrafts = drafts.filter { $0.isSelected }
        guard !selectedDrafts.isEmpty else {
            loadError = "请先选择要录入的衣物。"
            return
        }

        var existingFingerprints = fetchExistingWardrobeImageFingerprints()
        var insertedCount = 0
        var duplicateCount = 0

        for draft in selectedDrafts {
            if let fingerprint = imageFingerprint(from: draft.imageData),
               existingFingerprints.contains(fingerprint) {
                duplicateCount += 1
                continue
            }
            let price = Double(draft.priceText.replacingOccurrences(of: ",", with: "."))
            let item = ClothingItem(
                ownerUsername: currentOwnerKey,
                name: draft.name.isEmpty ? "未命名单品" : draft.name,
                category: draft.category,
                subCategory: draft.subCategory,
                color: draft.color,
                material: draft.material,
                pattern: draft.pattern,
                fit: draft.fit,
                formality: draft.formality,
                seasons: draft.seasons.isEmpty ? ["四季"] : draft.seasons,
                occasions: draft.occasions.isEmpty ? ["休闲"] : draft.occasions,
                styleTags: draft.styleTags,
                brand: draft.brand,
                price: price,
                purchaseDate: draft.hasPurchaseDate ? draft.purchaseDate : nil,
                imageData: draft.imageData
            )
            item.syncStatus = .pending
            item.syncRetryCount = 0
            item.syncErrorMessage = ""
            item.updatedAt = Date()
            modelContext.insert(item)
            insertedCount += 1
            if let fingerprint = imageFingerprint(from: draft.imageData) {
                existingFingerprints.insert(fingerprint)
            }
        }

        guard insertedCount > 0 else {
            if duplicateCount > 0 {
                loadError = "检测到 \(duplicateCount) 件重复衣物，未重复保存。"
            } else {
                loadError = "没有可保存的衣物。"
            }
            return
        }

        Task { @MainActor in
            await WardrobeSyncService.shared.syncNow(modelContext: modelContext)
        }
        dismiss()
    }

    private func fetchExistingWardrobeImageFingerprints() -> Set<String> {
        let owner = currentOwnerKey
        let descriptor = FetchDescriptor<ClothingItem>(
            predicate: #Predicate<ClothingItem> { item in
                item.ownerUsername == owner && item.deletedAt == nil
            }
        )
        guard let items = try? modelContext.fetch(descriptor) else {
            return []
        }
        return Set(items.compactMap { imageFingerprint(from: $0.imageData) })
    }

    private func imageFingerprint(from data: Data?) -> String? {
        guard let data, !data.isEmpty else { return nil }
        let normalized = downsampledImageData(data, maxPixel: 512) ?? data
        let digest = SHA256.hash(data: normalized)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func addDraftAndProcess(from data: Data) async {
        let draft = ClothingDraft(imageData: data, originalImageData: data, isProcessing: true)
        drafts.append(draft)
        selectedIndex = drafts.count - 1
        let index = selectedIndex
        await processDraft(at: index)
    }

    private func processDraft(at index: Int) async {
        await processDraft(at: index, preferredCategory: nil)
    }

    private func processDraft(at index: Int, preferredCategory: String?) async {
        guard drafts.indices.contains(index) else { return }
        let original = drafts[index].originalImageData
        let processed = await Task(priority: .userInitiated) {
            autoreleasepool {
                processImageData(original)
            }
        }.value
        let refinedCategory = await refineCategoryIfNeeded(processed: processed, preferredCategory: preferredCategory)
        await MainActor.run {
            guard drafts.indices.contains(index) else { return }
            if let processed {
                drafts[index].imageData = processed.imageData
                drafts[index].category = refinedCategory
                drafts[index].color = processed.color
            }
            drafts[index].isProcessing = false
        }
    }

    private func refineCategoryIfNeeded(processed: ProcessedImageResult?, preferredCategory: String?) async -> String {
        guard let processed else {
            return preferredCategory ?? "上衣"
        }
        guard preferredCategory == nil else {
            return preferredCategory ?? processed.category
        }

        let localCategory = processed.category
        let highConflict = Set(["上衣", "外套", "长裤", "短裤"])
        let needsRemoteCheck = processed.localConfidence < 0.8 || highConflict.contains(localCategory)
        guard needsRemoteCheck else {
            return localCategory
        }

        do {
            let service = AIVirtualTryOnService()
            if let remote = try await service.classifyGarmentViaBackend(imageData: processed.imageData),
               CategoryConfig.categories.contains(remote) {
                return remote
            }
        } catch {
            return localCategory
        }
        return localCategory
    }

    private func rotateCurrent(clockwise: Bool) {
        guard drafts.indices.contains(selectedIndex) else { return }
        let original = drafts[selectedIndex].originalImageData
        guard let rotated = rotateImageData(original, clockwise: clockwise) else { return }
        drafts[selectedIndex].originalImageData = rotated
        drafts[selectedIndex].imageData = rotated
        drafts[selectedIndex].isProcessing = true
        let index = selectedIndex
        Task {
            await processDraft(at: index)
        }
    }

    @MainActor
    private func splitOutfitPhoto(from item: PhotosPickerItem) async {
        isLoading = true
        defer { isLoading = false }
        var fallbackImageData: Data?
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                loadError = "无法读取照片，请重试。"
                return
            }
            let normalized = image.normalizedOrientation()
            guard let normalizedData = normalized.jpegData(compressionQuality: 0.9) else {
                loadError = "无法处理照片，请重试。"
                return
            }
            fallbackImageData = normalizedData

            let service = AIVirtualTryOnService()
            let parsed = try await service.parseOutfitViaBackend(imageData: normalizedData)
            let orderedKeys = [
                "top", "long_pants", "shorts", "skirt", "one_piece", "outerwear",
                "hat", "shoes", "socks", "bag", "accessories"
            ]
            let categoryMap: [String: String] = [
                "top": "上衣",
                "long_pants": "长裤",
                "shorts": "短裤",
                "skirt": "长裤",
                "one_piece": "上衣",
                "outerwear": "外套",
                "hat": "帽子",
                "shoes": "鞋子",
                "socks": "袜子",
                "bag": "箱包",
                "accessories": "饰品"
            ]

            var hasResults = false
            var emittedCategories = Set<String>()
            for key in orderedKeys {
                guard let partData = parsed[key], let category = categoryMap[key] else { continue }
                if emittedCategories.contains(category) { continue }
                emittedCategories.insert(category)
                hasResults = true
                let draft = ClothingDraft(
                    imageData: partData,
                    originalImageData: partData,
                    category: category,
                    isProcessing: true,
                    isSelected: true
                )
                drafts.append(draft)
                let index = drafts.count - 1
                selectedIndex = index
                await processDraft(at: index, preferredCategory: category)
            }
            if !hasResults {
                // 后端返回为空时，退回本地拆解兜底，避免整图导入中断。
                let localResults: [ProcessedImageResult] = await Task(priority: .userInitiated) {
                    autoreleasepool {
                        guard let fallbackImageData,
                              let fallbackImage = UIImage(data: fallbackImageData) else {
                            return []
                        }
                        return localSplitOutfitResults(from: fallbackImage)
                    }
                }.value
                if localResults.isEmpty {
                    loadError = "未能识别到可拆解的衣物，请换一张更清晰的整身照片。"
                    return
                }
                appendSplitDrafts(from: localResults)
            }
        } catch {
            // 后端失败时回退到本地拆解，避免整图拆解直接失败。
            let localResults: [ProcessedImageResult] = await Task(priority: .userInitiated) {
                autoreleasepool {
                    guard let fallbackImageData,
                          let fallbackImage = UIImage(data: fallbackImageData) else {
                        return []
                    }
                    return localSplitOutfitResults(from: fallbackImage)
                }
            }.value
            if !localResults.isEmpty {
                appendSplitDrafts(from: localResults)
                return
            }
            loadError = error.localizedDescription
        }
    }

    private func appendSplitDrafts(from results: [ProcessedImageResult]) {
        for result in results {
            let draft = ClothingDraft(
                imageData: result.imageData,
                originalImageData: result.imageData,
                category: result.category,
                color: result.color,
                isProcessing: false,
                isSelected: true
            )
            drafts.append(draft)
            selectedIndex = drafts.count - 1
        }
    }

    private func toggleSelection(for index: Int) {
        guard drafts.indices.contains(index) else { return }
        drafts[index].isSelected.toggle()
    }

}

private struct EditSection<Content: View>: View {
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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.9))
        )
    }
}

private struct AddClothingListRow<Content: View>: View {
    let title: String
    let showDivider: Bool
    let content: Content
    let onTap: (() -> Void)?

    init(title: String, showDivider: Bool, onTap: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.showDivider = showDivider
        self.onTap = onTap
        self.content = content()
    }

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) {
                    rowContent
                }
                .buttonStyle(.appPlain)
            } else {
                rowContent
            }
        }
        .overlay(alignment: .bottom) {
            if showDivider {
                Rectangle()
                    .fill(Color(red: 0.92, green: 0.90, blue: 0.88))
                    .frame(height: 1)
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.actionText)
            Spacer()
            content
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color(red: 0.70, green: 0.66, blue: 0.60))
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

private struct AddClothingValueCapsule: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color(red: 0.96, green: 0.96, blue: 0.96))
            )
            .foregroundStyle(AppTheme.bodyText)
    }
}

private struct ActionCard: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack {
            Image(systemName: systemImage)
            Text(title)
                .font(.subheadline.weight(.medium))
            Spacer()
        }
        .foregroundStyle(AppTheme.actionText)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(red: 0.86, green: 0.80, blue: 0.74), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
    }
}

private struct ChipGroup: View {
    let title: String
    let options: [String]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.actionText)
            WrapStack(items: options) { option in
                Button {
                    selection = option
                } label: {
                    Text(option)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selection == option ? Color(red: 0.84, green: 0.76, blue: 0.66) : Color(red: 0.95, green: 0.92, blue: 0.88))
                        )
                        .foregroundStyle(Color(red: 0.30, green: 0.24, blue: 0.19))
                }
                .buttonStyle(.appPlain)
            }
        }
    }
}

private struct ColorChipGroup: View {
    let title: String
    let options: [ColorOption]
    @Binding var selection: String
    @State private var fineTuneColor: Color = .black
    @State private var hasInitialized = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.actionText)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                ForEach(options, id: \.name) { option in
                    Button {
                        selection = option.name
                    } label: {
                        Circle()
                            .fill(option.color)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(baseColorName(from: selection) == option.name ? AppTheme.bodyText : Color.black.opacity(0.1), lineWidth: baseColorName(from: selection) == option.name ? 2 : 1)
                            )
                    }
                    .buttonStyle(.appPlain)
                }
            }
            ColorPicker("细节色盘", selection: $fineTuneColor, supportsOpacity: false)
                .onChange(of: fineTuneColor) { _, newValue in
                    let base = baseColorName(from: selection)
                    if let hex = hexString(from: newValue) {
                        selection = "\(base.isEmpty ? "自定义" : base) · \(hex)"
                    }
                }
            Text(selection)
                .font(.caption)
                .foregroundStyle(AppTheme.mutedText)
        }
        .onAppear {
            guard !hasInitialized else { return }
            hasInitialized = true
            if let hex = selectionHex(from: selection), let parsed = colorFromHexString(hex) {
                fineTuneColor = parsed
            } else if let match = options.first(where: { $0.name == baseColorName(from: selection) }) {
                fineTuneColor = match.color
            }
        }
        .onChange(of: selection) { _, newValue in
            if let hex = selectionHex(from: newValue), let parsed = colorFromHexString(hex) {
                fineTuneColor = parsed
            } else if let match = options.first(where: { $0.name == baseColorName(from: newValue) }) {
                fineTuneColor = match.color
            }
        }
    }
}

private struct MultiChipGroup: View {
    let title: String
    let options: [String]
    @Binding var selection: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.actionText)
            WrapStack(items: options) { option in
                Button {
                    toggle(option)
                } label: {
                    Text(option)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selection.contains(option) ? Color(red: 0.84, green: 0.76, blue: 0.66) : Color(red: 0.95, green: 0.92, blue: 0.88))
                        )
                        .foregroundStyle(Color(red: 0.30, green: 0.24, blue: 0.19))
                }
                .buttonStyle(.appPlain)
            }
        }
    }

    private func toggle(_ option: String) {
        if selection.contains(option) {
            selection.removeAll { $0 == option }
        } else {
            selection.append(option)
        }
    }
}

private struct WrapStack<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let rows = wrapRows(for: items)
            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(spacing: 8) {
                    ForEach(rows[rowIndex], id: \.self) { item in
                        content(item)
                    }
                }
            }
        }
    }

    private func wrapRows(for items: [Item], limit: Int = 4) -> [[Item]] {
        var rows: [[Item]] = []
        var current: [Item] = []
        for item in items {
            current.append(item)
            if current.count == limit {
                rows.append(current)
                current = []
            }
        }
        if !current.isEmpty {
            rows.append(current)
        }
        return rows
    }
}

private struct ColorOption: Hashable {
    let name: String
    let color: Color
    let rgb: (Double, Double, Double)

    static func == (lhs: ColorOption, rhs: ColorOption) -> Bool {
        lhs.name == rhs.name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

private struct AddClothingWheelPicker: Identifiable {
    let id = UUID()
    let title: String
    let options: [String]
    let selection: String
    let onSelect: (String) -> Void
}

private struct AddClothingWheelPickerSheet: View {
    let picker: AddClothingWheelPicker
    @Environment(\.dismiss) private var dismiss
    @State private var selection: String

    init(picker: AddClothingWheelPicker) {
        self.picker = picker
        _selection = State(initialValue: picker.selection)
    }

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.black.opacity(0.08))
                .frame(width: 48, height: 6)
                .padding(.top, 8)
            Text(picker.title)
                .font(.headline)
            Picker(picker.title, selection: $selection) {
                ForEach(picker.options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 160)

            Button {
                picker.onSelect(selection)
                dismiss()
            } label: {
                Text("保存")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.primary)
                    .foregroundStyle(Color.white)
                    .clipShape(Capsule())
                    .contentShape(Rectangle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.hidden)
    }
}

private struct AddClothingColorPicker: View {
    let options: [ColorOption]
    @Binding var selection: String
    @State private var showSheet = false

    var body: some View {
        Button {
            showSheet = true
        } label: {
            HStack(spacing: 10) {
                if let option = options.first(where: { $0.name == selection }) {
                    Circle()
                        .fill(option.color)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 1))
                    Text(option.name)
                } else {
                    Text(selection.isEmpty ? "请选择色系" : selection)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color(red: 0.96, green: 0.96, blue: 0.96))
            )
            .foregroundStyle(AppTheme.bodyText)
        }
        .buttonStyle(.appPlain)
        .sheet(isPresented: $showSheet) {
            AddClothingColorSheet(title: "选择颜色", palette: options, selection: $selection)
        }
    }
}

private struct AddClothingColorSheet: View {
    let title: String
    let palette: [ColorOption]
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.black.opacity(0.08))
                .frame(width: 48, height: 6)
                .padding(.top, 8)
            Text(title)
                .font(.headline)
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(palette, id: \.name) { option in
                    Button {
                        selection = option.name
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                    )
                                if selection == option.name {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(option.name == "黑色系" ? Color.white : Color.black)
                                }
                            }
                            Text(option.name)
                                .font(.caption)
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.25))
                                )
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.appPlain)
                }
            }
            .padding(.horizontal, 20)

            Button {
                dismiss()
            } label: {
                Text("保存")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.primary)
                    .foregroundStyle(Color.white)
                    .clipShape(Capsule())
                    .contentShape(Rectangle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.hidden)
    }
}

private struct ClothingDraft: Identifiable {
    let id = UUID()
    var imageData: Data
    var originalImageData: Data
    var name: String = ""
    var category: String = "上衣"
    var subCategory: String = ""
    var color: String = "白色系"
    var material: String = ""
    var pattern: String = "纯色"
    var fit: String = "regular"
    var formality: Double = 0.5
    var styleTags: [String] = []
    var seasons: [String] = ["四季"]
    var occasions: [String] = ["休闲"]
    var brand: String = ""
    var priceText: String = ""
    var purchaseDate: Date = Date()
    var hasPurchaseDate: Bool = false
    var isProcessing: Bool = false
    var isSelected: Bool = true

    static func placeholder() -> ClothingDraft {
        ClothingDraft(imageData: Data(), originalImageData: Data())
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage) -> Void

        init(onImagePicked: @escaping (UIImage) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

private struct ProcessedImageResult {
    let imageData: Data
    let category: String
    let color: String
    let localConfidence: Double
}

private struct LocalSplitCandidate {
    let targetCategory: String
    let image: UIImage
    let sourceAreaRatio: CGFloat
}

private func splitOutfitImage(_ image: UIImage) -> [LocalSplitCandidate] {
    guard let cgImage = image.cgImage else { return [] }
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

    let rectRequest = VNDetectHumanRectanglesRequest()
    let poseRequest = VNDetectHumanBodyPoseRequest()
    try? handler.perform([rectRequest, poseRequest])

    guard let boundingBox = rectRequest.results?.first?.boundingBox else { return [] }

    let imgWidth = CGFloat(cgImage.width)
    let imgHeight = CGFloat(cgImage.height)
    let personRect = CGRect(
        x: boundingBox.origin.x * imgWidth,
        y: (1 - boundingBox.origin.y - boundingBox.height) * imgHeight,
        width: boundingBox.width * imgWidth,
        height: boundingBox.height * imgHeight
    )

    let joints = poseRequest.results?.first
    let points = joints?.availableJointNames.reduce(into: [VNHumanBodyPoseObservation.JointName: CGPoint]()) { result, name in
        if let point = try? joints?.recognizedPoint(name), point.confidence > 0.2 {
            result[name] = CGPoint(x: CGFloat(point.x) * imgWidth, y: (1 - CGFloat(point.y)) * imgHeight)
        }
    } ?? [:]

    let leftShoulderY = points[.leftShoulder]?.y ?? personRect.maxY
    let rightShoulderY = points[.rightShoulder]?.y ?? personRect.maxY
    let shoulderY: CGFloat = min(leftShoulderY, rightShoulderY)
    
    let leftHipY = points[.leftHip]?.y ?? personRect.midY
    let rightHipY = points[.rightHip]?.y ?? personRect.midY
    let hipY: CGFloat = max(leftHipY, rightHipY)
    
    let leftKneeY = points[.leftKnee]?.y ?? personRect.minY
    let rightKneeY = points[.rightKnee]?.y ?? personRect.minY
    let kneeY: CGFloat = max(leftKneeY, rightKneeY)
    
    let leftAnkleY = points[.leftAnkle]?.y ?? personRect.minY
    let rightAnkleY = points[.rightAnkle]?.y ?? personRect.minY
    let ankleY: CGFloat = max(leftAnkleY, rightAnkleY)
    let leftAnkleX = points[.leftAnkle]?.x ?? (personRect.minX + personRect.width * 0.30)
    let rightAnkleX = points[.rightAnkle]?.x ?? (personRect.minX + personRect.width * 0.70)
    let leftWristX = points[.leftWrist]?.x ?? (personRect.minX + personRect.width * 0.12)
    let leftWristY = points[.leftWrist]?.y ?? (personRect.minY + personRect.height * 0.52)
    let rightWristX = points[.rightWrist]?.x ?? (personRect.maxX - personRect.width * 0.12)
    let rightWristY = points[.rightWrist]?.y ?? (personRect.minY + personRect.height * 0.52)
    
    // VNHumanBodyPoseObservation 没有 head 关键点，使用肩膀上方估算头部位置
    let headY: CGFloat = shoulderY - personRect.height * 0.08

    let upperRect = CGRect(
        x: personRect.minX,
        y: shoulderY,
        width: personRect.width,
        height: max(hipY - shoulderY, personRect.height * 0.25)
    )
    let upperTightRect = CGRect(
        x: personRect.minX + personRect.width * 0.08,
        y: shoulderY + personRect.height * 0.01,
        width: personRect.width * 0.84,
        height: max(hipY - shoulderY, personRect.height * 0.23)
    )
    let outerRect = CGRect(
        x: personRect.minX - personRect.width * 0.04,
        y: shoulderY,
        width: personRect.width * 1.08,
        height: max(kneeY - shoulderY, personRect.height * 0.52)
    )
    let lowerRect = CGRect(
        x: personRect.minX,
        y: hipY,
        width: personRect.width,
        height: max(ankleY - hipY, personRect.height * 0.25)
    )
    let shortsRect = CGRect(
        x: personRect.minX + personRect.width * 0.05,
        y: hipY,
        width: personRect.width * 0.90,
        height: max(kneeY - hipY, personRect.height * 0.16)
    )
    let shoeRect = CGRect(
        x: personRect.minX,
        y: max(ankleY, personRect.minY),
        width: personRect.width,
        height: personRect.maxY - max(ankleY, personRect.minY)
    )
    let hatRect = CGRect(
        x: personRect.minX,
        y: max(personRect.minY, headY - personRect.height * 0.12),
        width: personRect.width,
        height: max(shoulderY - headY, personRect.height * 0.12)
    )
    let hatTightRect = CGRect(
        x: personRect.minX + personRect.width * 0.16,
        y: max(personRect.minY, headY - personRect.height * 0.08),
        width: personRect.width * 0.68,
        height: max(shoulderY - headY, personRect.height * 0.10)
    )
    let bagBandHeight = max(personRect.height * 0.46, 120)
    let bagBandY = shoulderY + personRect.height * 0.08
    let bagBandWidth = max(personRect.width * 0.42, 90)
    let bagLeftRect = CGRect(
        x: personRect.minX - bagBandWidth * 0.55,
        y: bagBandY,
        width: bagBandWidth,
        height: bagBandHeight
    )
    let bagRightRect = CGRect(
        x: personRect.maxX - bagBandWidth * 0.45,
        y: bagBandY,
        width: bagBandWidth,
        height: bagBandHeight
    )
    let bagLeftWristRect = CGRect(
        x: leftWristX - bagBandWidth * 0.40,
        y: leftWristY - bagBandHeight * 0.30,
        width: bagBandWidth,
        height: bagBandHeight * 0.80
    )
    let bagRightWristRect = CGRect(
        x: rightWristX - bagBandWidth * 0.60,
        y: rightWristY - bagBandHeight * 0.30,
        width: bagBandWidth,
        height: bagBandHeight * 0.80
    )
    let socksRect = CGRect(
        x: personRect.minX + personRect.width * 0.18,
        y: min(kneeY, ankleY),
        width: personRect.width * 0.64,
        height: max(abs(ankleY - kneeY), personRect.height * 0.14)
    )
    let leftSockRect = CGRect(
        x: leftAnkleX - personRect.width * 0.14,
        y: min(kneeY, ankleY),
        width: personRect.width * 0.26,
        height: max(abs(ankleY - kneeY), personRect.height * 0.14)
    )
    let rightSockRect = CGRect(
        x: rightAnkleX - personRect.width * 0.12,
        y: min(kneeY, ankleY),
        width: personRect.width * 0.26,
        height: max(abs(ankleY - kneeY), personRect.height * 0.14)
    )
    let leftShoeRect = CGRect(
        x: leftAnkleX - personRect.width * 0.19,
        y: max(ankleY, personRect.minY),
        width: personRect.width * 0.35,
        height: max(personRect.maxY - max(ankleY, personRect.minY), personRect.height * 0.12)
    )
    let rightShoeRect = CGRect(
        x: rightAnkleX - personRect.width * 0.16,
        y: max(ankleY, personRect.minY),
        width: personRect.width * 0.35,
        height: max(personRect.maxY - max(ankleY, personRect.minY), personRect.height * 0.12)
    )
    let accessoriesRect = CGRect(
        x: personRect.minX + personRect.width * 0.24,
        y: max(personRect.minY, headY + personRect.height * 0.06),
        width: personRect.width * 0.52,
        height: max(personRect.height * 0.22, 100)
    )

    let candidates: [(String, CGRect)] = [
        ("上衣", upperRect),
        ("上衣", upperTightRect),
        ("外套", outerRect),
        ("长裤", lowerRect),
        ("短裤", shortsRect),
        ("鞋子", shoeRect),
        ("鞋子", leftShoeRect),
        ("鞋子", rightShoeRect),
        ("帽子", hatRect),
        ("帽子", hatTightRect),
        ("箱包", bagLeftRect),
        ("箱包", bagRightRect),
        ("箱包", bagLeftWristRect),
        ("箱包", bagRightWristRect),
        ("袜子", socksRect),
        ("袜子", leftSockRect),
        ("袜子", rightSockRect),
        ("饰品", accessoriesRect)
    ]

    let wholeArea = max(imgWidth * imgHeight, 1)
    return candidates.compactMap { category, rect in
        let croppedRect = rect.intersection(CGRect(x: 0, y: 0, width: imgWidth, height: imgHeight)).integral
        guard croppedRect.width > 56, croppedRect.height > 56,
              let croppedCG = cgImage.cropping(to: croppedRect) else { return nil }
        let croppedImage = UIImage(cgImage: croppedCG)
        let segmented = extractBestInstanceFromCrop(croppedImage, targetCategory: category)
            ?? BackgroundRemoval.removeBackground(image: croppedImage)
            ?? croppedImage
        let trimmed = trimTransparentContent(segmented, padding: 8) ?? segmented
        guard hasVisibleContent(trimmed) else { return nil }
        let areaRatio = (croppedRect.width * croppedRect.height) / wholeArea
        return LocalSplitCandidate(targetCategory: category, image: trimmed, sourceAreaRatio: areaRatio)
    }
}

private func localSplitOutfitResults(from image: UIImage) -> [ProcessedImageResult] {
    let candidates = splitOutfitImage(image)
    guard !candidates.isEmpty else { return [] }

    var bestByCategory: [String: (result: ProcessedImageResult, score: Double)] = [:]
    for candidate in candidates {
        let cropped = candidate.image
        guard let pngData = cropped.pngData(),
              let processed = processImageData(pngData),
              CategoryConfig.categories.contains(processed.category) else {
            continue
        }

        let affinity = categoryAffinity(expected: candidate.targetCategory, predicted: processed.category)
        if affinity < 0.22 { continue }

        let visibleRatio = Double(visibleAlphaRatio(in: cropped))
        let areaRatio = Double(candidate.sourceAreaRatio)
        var score = affinity * 2.4 + visibleRatio * 1.0 + min(max(areaRatio, 0), 0.55) * 0.8
        score += areaPriorBonus(for: candidate.targetCategory, areaRatio: areaRatio)

        guard score >= 1.15 else { continue }

        let normalized = ProcessedImageResult(
            imageData: processed.imageData,
            category: candidate.targetCategory,
            color: processed.color,
            localConfidence: processed.localConfidence
        )

        if let current = bestByCategory[candidate.targetCategory], current.score >= score {
            continue
        }
        bestByCategory[candidate.targetCategory] = (normalized, score)
    }

    return CategoryConfig.categories.compactMap { bestByCategory[$0]?.result }
}

private func extractBestInstanceFromCrop(_ image: UIImage, targetCategory: String) -> UIImage? {
    guard #available(iOS 17.0, *), let cgImage = image.cgImage else { return nil }
    let request = VNGenerateForegroundInstanceMaskRequest()
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    do {
        try handler.perform([request])
    } catch {
        return nil
    }
    guard let result = request.results?.first else { return nil }
    let instances = result.allInstances
    guard !instances.isEmpty else { return nil }

    let context = CIContext()
    let canvasSize = CGSize(width: cgImage.width, height: cgImage.height)
    var bestScore = -Double.infinity
    var bestImage: UIImage?

    for instance in instances {
        guard let maskedBuffer = try? result.generateMaskedImage(
            ofInstances: IndexSet(integer: instance),
            from: handler,
            croppedToInstancesExtent: false
        ) else {
            continue
        }
        let masked = CIImage(cvPixelBuffer: maskedBuffer)
        guard let outputCG = context.createCGImage(masked, from: masked.extent) else { continue }
        let candidate = UIImage(cgImage: outputCG, scale: image.scale, orientation: image.imageOrientation)
        guard let bounds = alphaBoundingRect(in: candidate) else { continue }
        let score = instanceSelectionScore(bounds: bounds, canvasSize: canvasSize, targetCategory: targetCategory)
        if score > bestScore {
            bestScore = score
            bestImage = candidate
        }
    }

    guard let bestImage else { return nil }
    return trimTransparentContent(bestImage, padding: 8)
}

private func instanceSelectionScore(bounds: CGRect, canvasSize: CGSize, targetCategory: String) -> Double {
    let width = max(canvasSize.width, 1)
    let height = max(canvasSize.height, 1)
    let areaRatio = Double((bounds.width * bounds.height) / (width * height))
    let centerX = Double(bounds.midX / width)
    let centerY = Double(bounds.midY / height)
    let aspect = Double(bounds.height / max(bounds.width, 1))
    let marginX = width * 0.03
    let marginY = height * 0.03
    let touchedEdges = (bounds.minX <= marginX ? 1 : 0)
        + (bounds.maxX >= width - marginX ? 1 : 0)
        + (bounds.minY <= marginY ? 1 : 0)
        + (bounds.maxY >= height - marginY ? 1 : 0)

    func around(_ value: Double, target: Double, tolerance: Double) -> Double {
        guard tolerance > 0 else { return 0 }
        return max(0, 1 - abs(value - target) / tolerance)
    }

    var score = -Double(touchedEdges) * 0.25
    switch targetCategory {
    case "帽子":
        score += around(centerY, target: 0.24, tolerance: 0.24) * 1.8
        score += areaRatio <= 0.36 ? 0.7 : -0.9
        score += aspect <= 1.35 ? 0.35 : -0.2
    case "鞋子":
        score += around(centerY, target: 0.82, tolerance: 0.26) * 1.8
        score += areaRatio <= 0.38 ? 0.55 : -0.6
        score += aspect < 1.28 ? 0.35 : -0.2
    case "袜子":
        score += around(centerY, target: 0.72, tolerance: 0.32) * 1.3
        score += aspect > 1.08 ? 0.7 : -0.35
        score += areaRatio < 0.26 ? 0.35 : -0.35
    case "箱包":
        score += around(centerY, target: 0.55, tolerance: 0.30) * 1.1
        score += around(min(centerX, 1 - centerX), target: 0.17, tolerance: 0.20) * 1.0
        score += (areaRatio >= 0.04 && areaRatio <= 0.45) ? 0.6 : -0.7
    case "饰品":
        score += around(centerY, target: 0.42, tolerance: 0.30) * 1.1
        score += areaRatio < 0.18 ? 0.95 : -0.9
        score += aspect >= 0.5 && aspect <= 1.9 ? 0.25 : -0.2
    case "上衣":
        score += around(centerY, target: 0.44, tolerance: 0.28) * 1.5
        score += areaRatio > 0.14 ? 0.9 : -0.8
    case "外套":
        score += around(centerY, target: 0.52, tolerance: 0.30) * 1.5
        score += areaRatio > 0.18 ? 0.9 : -0.8
        score += aspect > 0.9 ? 0.25 : -0.2
    case "长裤":
        score += around(centerY, target: 0.72, tolerance: 0.24) * 1.6
        score += aspect > 1.18 ? 0.7 : -0.45
        score += areaRatio > 0.14 ? 0.55 : -0.5
    case "短裤":
        score += around(centerY, target: 0.60, tolerance: 0.25) * 1.4
        score += (aspect >= 0.8 && aspect <= 1.8) ? 0.5 : -0.4
        score += (areaRatio > 0.08 && areaRatio < 0.38) ? 0.5 : -0.45
    default:
        break
    }
    return score
}

private func categoryAffinity(expected: String, predicted: String) -> Double {
    if expected == predicted { return 1.0 }
    if (expected == "上衣" && predicted == "外套") || (expected == "外套" && predicted == "上衣") {
        return 0.72
    }
    if (expected == "长裤" && predicted == "短裤") || (expected == "短裤" && predicted == "长裤") {
        return 0.68
    }
    if (expected == "鞋子" && predicted == "袜子") || (expected == "袜子" && predicted == "鞋子") {
        return 0.45
    }
    if (expected == "箱包" && predicted == "饰品") || (expected == "饰品" && predicted == "箱包") {
        return 0.42
    }
    return 0
}

private func areaPriorBonus(for category: String, areaRatio: Double) -> Double {
    switch category {
    case "饰品":
        return areaRatio < 0.16 ? 0.4 : -0.8
    case "帽子":
        return areaRatio < 0.24 ? 0.3 : -0.5
    case "鞋子":
        return areaRatio < 0.34 ? 0.25 : -0.35
    case "袜子":
        return areaRatio < 0.28 ? 0.25 : -0.35
    case "箱包":
        return (areaRatio > 0.04 && areaRatio < 0.42) ? 0.35 : -0.45
    case "长裤", "上衣", "外套", "短裤":
        return areaRatio > 0.10 ? 0.2 : -0.4
    default:
        return 0
    }
}

private func visibleAlphaRatio(in image: UIImage) -> CGFloat {
    guard let cgImage = image.cgImage else { return 0 }
    let width = cgImage.width
    let height = cgImage.height
    guard width > 0, height > 0 else { return 0 }

    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
    guard let ctx = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return 0
    }
    ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    let sampleStep = max(1, min(width, height) / 256)
    let threshold: UInt8 = 12
    var visible = 0
    var total = 0
    for y in Swift.stride(from: 0, to: height, by: sampleStep) {
        for x in Swift.stride(from: 0, to: width, by: sampleStep) {
            let index = y * bytesPerRow + x * bytesPerPixel
            if pixels[index + 3] > threshold { visible += 1 }
            total += 1
        }
    }
    guard total > 0 else { return 0 }
    return CGFloat(visible) / CGFloat(total)
}

private func alphaBoundingRect(in image: UIImage, alphaThreshold: UInt8 = 12) -> CGRect? {
    guard let cgImage = image.cgImage else { return nil }
    let width = cgImage.width
    let height = cgImage.height
    guard width > 0, height > 0 else { return nil }

    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
    guard let ctx = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return nil
    }
    ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    var minX = width
    var minY = height
    var maxX = -1
    var maxY = -1

    for y in 0..<height {
        for x in 0..<width {
            let alpha = pixels[y * bytesPerRow + x * bytesPerPixel + 3]
            if alpha > alphaThreshold {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
    }

    guard maxX >= minX, maxY >= minY else { return nil }
    return CGRect(
        x: minX,
        y: minY,
        width: maxX - minX + 1,
        height: maxY - minY + 1
    )
}

private func trimTransparentContent(_ image: UIImage, padding: Int = 6, alphaThreshold: UInt8 = 12) -> UIImage? {
    guard let cgImage = image.cgImage,
          let bounds = alphaBoundingRect(in: image, alphaThreshold: alphaThreshold) else {
        return nil
    }
    let width = cgImage.width
    let height = cgImage.height
    let padded = bounds
        .insetBy(dx: -CGFloat(padding), dy: -CGFloat(padding))
        .intersection(CGRect(x: 0, y: 0, width: width, height: height))
        .integral
    guard padded.width > 1, padded.height > 1,
          let cropped = cgImage.cropping(to: padded) else {
        return nil
    }
    return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
}

private func hasVisibleContent(_ image: UIImage) -> Bool {
    guard let cgImage = image.cgImage else { return false }
    let alphaInfo = cgImage.alphaInfo
    let hasAlpha = alphaInfo == .premultipliedLast
        || alphaInfo == .premultipliedFirst
        || alphaInfo == .last
        || alphaInfo == .first
        || alphaInfo == .alphaOnly
    if !hasAlpha {
        return true
    }
    guard let dataProvider = cgImage.dataProvider, let data = dataProvider.data else {
        return true
    }
    let bytePtr = CFDataGetBytePtr(data)
    let length = CFDataGetLength(data)
    if length == 0 || bytePtr == nil {
        return true
    }
    let bytesPerPixel = 4
    let sampleStride = max(1, cgImage.width / 50)
    var visibleCount = 0
    var totalCount = 0
    for y in stride(from: 0, to: cgImage.height, by: sampleStride) {
        for x in stride(from: 0, to: cgImage.width, by: sampleStride) {
            let index = (y * cgImage.width + x) * bytesPerPixel
            if index + 3 >= length {
                continue
            }
            let alpha = bytePtr![index + 3]
            if alpha > 20 {
                visibleCount += 1
            }
            totalCount += 1
        }
    }
    if totalCount == 0 {
        return true
    }
    return Float(visibleCount)/Float(totalCount) > 0.06
}

private func processImageData(_ data: Data) -> ProcessedImageResult? {
    guard let image = UIImage(data: data) else { return nil }
    let normalized = image.normalizedOrientation()
    let noBackground = BackgroundRemoval.removeBackground(image: normalized) ?? normalized
    let localPrediction = WardrobeCategoryCoreMLClassifier.shared.predictCategoryResult(from: [noBackground, normalized])
    let heuristicNoBg = guessedCategory(from: noBackground)
    let heuristicOriginal = guessedCategory(from: normalized)
    var category = localPrediction?.category ?? heuristicNoBg
    if let prediction = localPrediction,
       prediction.category == "箱包",
       prediction.confidence < 0.72,
       (heuristicNoBg == "鞋子" || heuristicOriginal == "鞋子") {
        category = "鞋子"
    }
    let confidence = localPrediction?.confidence ?? 0
    let fitted = noBackground.fittedToSquareCanvas(side: 1024, scaleFactor: 0.88)
    guard let outputData = fitted.pngData() else { return nil }
    let colorName = dominantColorNameByCoverage(from: noBackground) ?? dominantColorName(from: fitted) ?? "黑色系"
    return ProcessedImageResult(
        imageData: outputData,
        category: category,
        color: colorName,
        localConfidence: confidence
    )
}

nonisolated private func downsampledImageData(_ data: Data, maxPixel: Int = 1536) -> Data? {
    let options: [CFString: Any] = [
        kCGImageSourceShouldCache: false
    ]
    guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
        return nil
    }
    let thumbOptions: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        kCGImageSourceShouldCacheImmediately: true
    ]
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else {
        return nil
    }
    return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.9)
}

nonisolated private func downsampledImageData(fileURL: URL, maxPixel: Int, quality: Double = 0.9) -> Data? {
    let options: [CFString: Any] = [
        kCGImageSourceShouldCache: false
    ]
    guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, options as CFDictionary) else {
        return nil
    }
    let thumbOptions: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        kCGImageSourceShouldCacheImmediately: true
    ]
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else {
        return nil
    }
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
        return nil
    }
    let props: [CFString: Any] = [
        kCGImageDestinationLossyCompressionQuality: quality
    ]
    CGImageDestinationAddImage(destination, cgImage, props as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        return nil
    }
    return data as Data
}

private func dominantColorName(from image: UIImage) -> String? {
    guard let ciImage = CIImage(image: image) else { return nil }
    let extent = ciImage.extent
    let filter = CIFilter(name: "CIAreaAverage")
    filter?.setValue(ciImage, forKey: kCIInputImageKey)
    filter?.setValue(CIVector(cgRect: extent), forKey: kCIInputExtentKey)
    guard let output = filter?.outputImage else { return nil }
    var pixel = [UInt8](repeating: 0, count: 4)
    let context = CIContext()
    context.render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
    let r = Double(pixel[0]) / 255.0
    let g = Double(pixel[1]) / 255.0
    let b = Double(pixel[2]) / 255.0

    let palette = [
        ("白色系", (0.96, 0.96, 0.96)),
        ("杏色系", (0.86, 0.78, 0.66)),
        ("黄色系", (0.98, 0.83, 0.32)),
        ("橙色系", (0.98, 0.57, 0.22)),
        ("红色系", (0.92, 0.28, 0.26)),
        ("粉色系", (0.96, 0.70, 0.74)),
        ("紫色系", (0.55, 0.39, 0.85)),
        ("蓝色系", (0.28, 0.50, 0.91)),
        ("绿色系", (0.40, 0.72, 0.26)),
        ("棕色系", (0.46, 0.30, 0.16)),
        ("咖色系", (0.60, 0.46, 0.36)),
        ("灰色系", (0.58, 0.58, 0.58)),
        ("黑色系", (0.12, 0.12, 0.12))
    ]

    let nearest = palette.min { lhs, rhs in
        let dl = distance((r, g, b), lhs.1)
        let dr = distance((r, g, b), rhs.1)
        return dl < dr
    }
    return nearest?.0
}

private enum FlatLayProcessingError: Error {
    case imageProcessingFailed
}

private enum BackgroundRemoval {
    nonisolated static func removeBackground(image: UIImage) -> UIImage? {
        if #available(iOS 17.0, *) {
            guard let cgImage = image.cgImage else { return nil }
            let request = VNGenerateForegroundInstanceMaskRequest()

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
                guard let result = request.results?.first else { return nil }
                let maskedBuffer = try result.generateMaskedImage(
                    ofInstances: result.allInstances,
                    from: handler,
                    croppedToInstancesExtent: false
                )
                let maskedImage = CIImage(cvPixelBuffer: maskedBuffer)
                let context = CIContext()
                guard let outputCG = context.createCGImage(maskedImage, from: maskedImage.extent) else { return nil }
                return UIImage(cgImage: outputCG, scale: image.scale, orientation: image.imageOrientation)
            } catch {
                return nil
            }
        }
        return nil
    }
}

private struct ManualEraseView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var imageData: Data?
    @State private var brushWidth: CGFloat = 60
    @State private var controller = EraseCanvasController()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                VStack(spacing: 18) {
                    Text("手动抹除")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.bodyText)
                    if let data = imageData, let image = UIImage(data: data) {
                        ZStack {
                            CheckerboardTile()
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                            EraseCanvasView(
                                image: image,
                                brushWidth: brushWidth,
                                isErasing: true,
                                controller: controller
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .padding(12)
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 420, maxHeight: 420)
                        .padding(.horizontal, 16)
                    } else {
                        Text("没有可编辑的图片")
                            .foregroundStyle(AppTheme.mutedText)
                    }

                    VStack(spacing: 12) {
                        EditorSliderRow(title: "刷子", value: $brushWidth, range: 20...140)
                    }
                    .padding(.horizontal, 16)

                    HStack(spacing: 12) {
                        eraseActionButton(title: "清空") {
                            controller.clear()
                        }
                        eraseActionButton(title: "撤销", isEnabled: controller.canUndo) {
                            controller.undo()
                        }
                        eraseActionButton(title: "重做", isEnabled: controller.canRedo) {
                            controller.redo()
                        }
                        eraseActionButton(title: "保存抹除") {
                            applyErase()
                        }
                    }
                    .padding(.bottom, 12)
                }
                .padding(.top, 12)
            }
            .navigationTitle("手动抹除")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                    }
                    .toolbarDoneButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        applyErase()
                        dismiss()
                    }
                    .toolbarDoneButton()
                }
            }
        }
    }

    private func eraseActionButton(title: String, isEnabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(AppTheme.primary.opacity(isEnabled ? 0.12 : 0.06))
                )
                .foregroundStyle(isEnabled ? AppTheme.primary : Color(red: 0.65, green: 0.65, blue: 0.65))
        }
        .buttonStyle(.appPlain)
        .disabled(!isEnabled)
        .contentShape(Rectangle())
    }

    private func applyErase() {
        guard controller.hasEdits else { return }
        guard let result = controller.renderErasedImage(),
              let outputData = result.pngData() else { return }
        imageData = outputData
        controller.clear()
    }
}

private struct CheckerboardTile: View {
    private let square: CGFloat = 18

    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                let cols = Int(size.width / square) + 1
                let rows = Int(size.height / square) + 1
                for row in 0..<rows {
                    for col in 0..<cols {
                        if (row + col).isMultiple(of: 2) {
                            let rect = CGRect(
                                x: CGFloat(col) * square,
                                y: CGFloat(row) * square,
                                width: square,
                                height: square
                            )
                            context.fill(Path(rect), with: .color(Color.black.opacity(0.06)))
                        }
                    }
                }
            }
        }
    }
}

private struct EditorSliderRow: View {
    let title: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("\(title) \(Int(value))")
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.45, green: 0.40, blue: 0.36))
                Spacer()
            }
            Slider(value: $value, in: range, step: 1)
                .tint(Color(red: 0.98, green: 0.42, blue: 0.62))
        }
    }
}

private func distance(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> Double {
    let dr = a.0 - b.0
    let dg = a.1 - b.1
    let db = a.2 - b.2
    return dr * dr + dg * dg + db * db
}

private final class WardrobeCategoryCoreMLClassifier {
    static let shared = WardrobeCategoryCoreMLClassifier()

    struct Prediction {
        let category: String
        let confidence: Double
    }

    private let model: VNCoreMLModel?
    private static var didWarnLabelMismatch = false
    private static var didWarnUnmappedPrediction = false

    private init() {
        let bundle = Bundle.main
        let candidates: [(String, String)] = [
            ("cclothes", "mlmodelc"),
            ("WardrobeClassifier", "mlmodelc"),
            ("WardrobeClassifier_5k", "mlmodelc"),
            ("WardrobeCategoryClassifier", "mlmodelc"),
            ("ClothingCategoryClassifier", "mlmodelc"),
            ("FashionCategoryClassifier", "mlmodelc")
        ]

        var loadedModel: VNCoreMLModel?
        for candidate in candidates where loadedModel == nil {
            if let url = bundle.url(forResource: candidate.0, withExtension: candidate.1),
               let mlModel = try? MLModel(contentsOf: url),
               let visionModel = try? VNCoreMLModel(for: mlModel) {
                let labels = (mlModel.modelDescription.classLabels as? [String]) ?? []
                if !labels.isEmpty {
                    let mappedCount = Set(labels.compactMap { Self.mapLabelToCategory($0) }).count
                    if mappedCount == 0 && !Self.didWarnLabelMismatch {
                        let examples = labels.prefix(3).joined(separator: ", ")
                        print("WardrobeCategoryCoreMLClassifier: \(candidate.0) 标签与项目分类未匹配，示例标签: \(examples)")
                        Self.didWarnLabelMismatch = true
                    }
                    if mappedCount == 0 {
                        continue
                    }
                }
                loadedModel = visionModel
            }
        }
        self.model = loadedModel
    }

    func predictCategory(from image: UIImage) -> String? {
        predictCategoryResult(from: image)?.category
    }

    func predictCategoryResult(from images: [UIImage]) -> Prediction? {
        guard !images.isEmpty else { return nil }

        var categoryScores: [String: Double] = [:]
        var categoryWeights: [String: Double] = [:]

        for (index, image) in images.enumerated() {
            guard let single = predictSingleCategoryResult(from: image) else { continue }
            let weight: Double = index == 0 ? 1.0 : 0.78
            categoryScores[single.category, default: 0] += single.confidence * weight
            categoryWeights[single.category, default: 0] += weight
        }

        guard let best = categoryScores.max(by: { $0.value < $1.value }),
              let weight = categoryWeights[best.key],
              weight > 0 else {
            return nil
        }

        let averagedConfidence = min(1.0, best.value / weight)
        if averagedConfidence < 0.35 { return nil }
        return Prediction(category: best.key, confidence: averagedConfidence)
    }

    func predictCategoryResult(from image: UIImage) -> Prediction? {
        predictSingleCategoryResult(from: image)
    }

    private func predictSingleCategoryResult(from image: UIImage) -> Prediction? {
        guard let model else { return nil }
        guard let cgImage = image.cgImage else { return nil }

        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .scaleFit
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let result = request.results as? [VNClassificationObservation] else {
            return nil
        }

        // 合并同类标签分数，提升稳定性
        var scores: [String: Float] = [:]
        for item in result.prefix(5) {
            guard let mapped = Self.mapLabelToCategory(item.identifier) else { continue }
            scores[mapped, default: 0] += item.confidence
        }

        guard let best = scores.max(by: { $0.value < $1.value }) else {
            if !Self.didWarnUnmappedPrediction, let rawTop = result.first?.identifier {
                print("WardrobeCategoryCoreMLClassifier: 模型输出标签无法映射，示例输出: \(rawTop)")
                Self.didWarnUnmappedPrediction = true
            }
            return nil
        }
        if best.value < 0.35 { return nil }
        return Prediction(category: best.key, confidence: Double(best.value))
    }

    private static func mapLabelToCategory(_ label: String) -> String? {
        let normalized = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty { return nil }

        let numericLabels: [String: String] = [
            "0": "上衣",
            "1": "外套",
            "2": "长裤",
            "3": "短裤",
            "4": "鞋子",
            "5": "帽子",
            "6": "箱包",
            "7": "袜子",
            "8": "饰品"
        ]
        if let mapped = numericLabels[normalized] {
            return mapped
        }

        for category in CategoryConfig.categories where normalized == category.lowercased() {
            return category
        }

        if normalized.contains("bag") || normalized.contains("backpack") || normalized.contains("handbag") || normalized.contains("purse") || normalized.contains("totebag") || normalized.contains("satchel") || normalized.contains("箱包") || normalized.contains("包") {
            return "箱包"
        }
        if normalized.contains("hat") || normalized.contains("cap") || normalized.contains("beanie") || normalized.contains("headwear") || normalized.contains("帽") {
            return "帽子"
        }
        if normalized.contains("socks") || normalized.contains("sock") || normalized.contains("袜") {
            return "袜子"
        }
        if normalized.contains("shoe") || normalized.contains("sneaker") || normalized.contains("boot") || normalized.contains("sandal") || normalized.contains("鞋") {
            return "鞋子"
        }
        if normalized.contains("shorts") || normalized.contains("短裤") {
            return "短裤"
        }
        if normalized.contains("pants") || normalized.contains("trousers") || normalized.contains("jeans") || normalized.contains("slacks") || normalized.contains("长裤") || normalized.contains("裤") {
            return "长裤"
        }
        if normalized.contains("skirt") || normalized.contains("半身裙") || normalized.contains("裙") {
            return "长裤"
        }
        if normalized.contains("dress") || normalized.contains("jumpsuit") || normalized.contains("romper") || normalized.contains("连体") {
            return "上衣"
        }
        if normalized.contains("coat") || normalized.contains("jacket") || normalized.contains("blazer") || normalized.contains("outerwear") || normalized.contains("外套") {
            return "外套"
        }
        if normalized.contains("shirt") || normalized.contains("t-shirt") || normalized.contains("tshirt") || normalized.contains("sweater") || normalized.contains("hoodie") || normalized.contains("top") || normalized.contains("blouse") || normalized.contains("上衣") {
            return "上衣"
        }
        if normalized.contains("accessory") || normalized.contains("jewelry") || normalized.contains("scarf") || normalized.contains("belt") || normalized.contains("饰品") {
            return "饰品"
        }
        return nil
    }
}

private func guessedCategory(from image: UIImage) -> String {
    guard let cg = image.cgImage else { return "上衣" }
    guard let silhouette = silhouetteStats(from: cg) else { return "上衣" }

    let ratio = silhouette.height / max(silhouette.width, 1)
    let topDensity = silhouette.topDensity
    let bottomDensity = silhouette.bottomDensity
    let splitLowerScore = silhouette.splitLowerScore
    let fill = silhouette.fillRatio
    let topShare = silhouette.topShare
    let middleShare = silhouette.middleShare
    let bottomShare = silhouette.bottomShare
    let topWidth = silhouette.topWidthRatio
    let middleWidth = silhouette.middleWidthRatio
    let bottomWidth = silhouette.bottomWidthRatio

    // 强特征快速判定，减少互相干扰
    if ratio > 1.45 && splitLowerScore > 0.28 { return "长裤" }
    if fill < 0.14 { return "饰品" }
    if ratio >= 1.68 && splitLowerScore < 0.10 && fill < 0.46 { return "袜子" }
    if ratio <= 0.66 &&
        bottomShare >= 0.42 &&
        topShare <= 0.26 &&
        middleWidth >= 0.22 &&
        fill <= 0.60 {
        return "鞋子"
    }
    if ratio >= 0.58 && ratio <= 1.38 &&
        splitLowerScore < 0.10 &&
        fill >= 0.22 && fill <= 0.72 &&
        abs(bottomWidth - topWidth) <= 0.10 &&
        middleWidth >= 0.38 &&
        topShare >= 0.18 && topShare <= 0.40 &&
        bottomShare >= 0.20 && bottomShare <= 0.42 {
        return "箱包"
    }
    if ratio >= 1.08 &&
        ratio <= 1.75 &&
        fill >= 0.46 &&
        topShare >= 0.24 &&
        middleShare >= 0.28 &&
        bottomShare >= 0.20 &&
        splitLowerScore < 0.16 &&
        bottomWidth >= topWidth + 0.08 {
        return "外套"
    }

    var scores = Dictionary(uniqueKeysWithValues: CategoryConfig.categories.map { ($0, 0.0) })
    func add(_ category: String, _ value: Double) {
        scores[category, default: 0] += value
    }

    // 上衣 / 外套
    add("上衣", 0.6)
    if ratio >= 0.80 && ratio <= 1.50 { add("上衣", 1.0) }
    if topShare >= 0.30 { add("上衣", 0.5) }
    if splitLowerScore < 0.16 { add("上衣", 0.5) }

    if ratio <= 1.15 { add("外套", 1.0) }
    if topDensity >= 0.42 { add("外套", 0.9) }
    if fill >= 0.42 { add("外套", 0.8) }
    if splitLowerScore < 0.14 { add("外套", 0.5) }
    if ratio < 0.90 { add("外套", -1.0) }
    if abs(bottomWidth - topWidth) <= 0.10 && ratio <= 1.20 { add("外套", -1.1) }
    if topShare < 0.18 { add("外套", -0.9) }
    if middleWidth >= 0.38 && splitLowerScore < 0.10 && ratio <= 1.25 { add("外套", -0.6) }

    // 下装
    if ratio >= 1.35 { add("长裤", 1.2) }
    if splitLowerScore >= 0.20 { add("长裤", 1.8) }
    if bottomShare >= 0.30 { add("长裤", 0.6) }

    if ratio >= 0.85 && ratio <= 1.45 { add("短裤", 1.2) }
    if splitLowerScore >= 0.16 { add("短裤", 1.1) }
    if bottomShare >= 0.33 { add("短裤", 0.5) }

    // 头部/脚部/配件
    if ratio <= 1.10 { add("帽子", 1.0) }
    if topShare >= 0.48 { add("帽子", 1.1) }
    if bottomShare <= 0.22 { add("帽子", 1.0) }
    if splitLowerScore < 0.10 { add("帽子", 0.5) }
    if fill < 0.62 { add("帽子", 0.4) }

    if ratio <= 0.82 { add("鞋子", 1.2) }
    if bottomShare >= 0.40 { add("鞋子", 1.0) }
    if topShare <= 0.30 { add("鞋子", 0.8) }
    if fill <= 0.56 { add("鞋子", 0.5) }
    if splitLowerScore < 0.12 { add("鞋子", 0.4) }
    if ratio <= 0.66 { add("鞋子", 1.2) }
    if bottomWidth >= topWidth + 0.12 { add("鞋子", 0.5) }
    if topShare >= 0.35 { add("鞋子", -0.8) }
    if abs(bottomWidth - topWidth) <= 0.10 && ratio >= 0.70 { add("鞋子", -0.9) }

    if ratio >= 1.55 { add("袜子", 1.3) }
    if splitLowerScore < 0.10 { add("袜子", 0.8) }
    if fill < 0.48 { add("袜子", 0.8) }
    if ratio <= 1.10 { add("袜子", -0.6) }

    if ratio >= 0.60 && ratio <= 1.45 { add("箱包", 1.1) }
    if splitLowerScore < 0.10 { add("箱包", 0.8) }
    if abs(topShare - bottomShare) < 0.18 { add("箱包", 0.7) }
    if fill >= 0.20 && fill <= 0.72 { add("箱包", 0.7) }
    if topDensity < 0.62 && bottomDensity < 0.68 { add("箱包", 0.5) }
    if abs(bottomWidth - topWidth) <= 0.14 { add("箱包", 1.2) }
    if middleWidth >= 0.34 { add("箱包", 0.6) }
    if bottomWidth > topWidth + 0.18 { add("箱包", -1.1) }
    if ratio <= 0.66 { add("箱包", -1.2) }
    if topShare < 0.14 { add("箱包", -0.8) }
    if topShare >= 0.18 && topShare <= 0.42 { add("箱包", 0.5) }
    if abs(bottomWidth - topWidth) <= 0.10 && middleWidth >= 0.38 { add("箱包", 0.9) }
    if ratio >= 0.90 && ratio <= 1.30 && splitLowerScore < 0.10 { add("箱包", 0.6) }
    if bottomWidth >= topWidth + 0.20 && ratio >= 1.05 { add("箱包", -0.8) }

    if fill < 0.20 { add("饰品", 2.2) }
    if ratio < 0.70 && fill < 0.26 { add("饰品", 0.7) }
    if ratio > 2.10 && fill < 0.24 { add("饰品", 0.7) }

    // 二次冲突抑制：统一处理容易互相误判的类别
    let bagLike = ratio >= 0.60 && ratio <= 1.40 &&
        splitLowerScore < 0.10 &&
        abs(bottomWidth - topWidth) <= 0.12 &&
        middleWidth >= 0.35 &&
        topShare >= 0.16 &&
        bottomShare >= 0.20 &&
        bottomShare <= 0.44
    if bagLike {
        add("箱包", 1.4)
        add("外套", -1.5)
        add("上衣", -0.7)
        add("鞋子", -0.8)
        add("短裤", -0.6)
        add("帽子", -0.7)
    }

    let outerLike = ratio >= 0.98 && ratio <= 1.80 &&
        fill >= 0.45 &&
        middleShare >= 0.28 &&
        bottomWidth >= topWidth + 0.08 &&
        splitLowerScore < 0.16
    if outerLike {
        add("外套", 1.1)
        add("箱包", -1.2)
        add("鞋子", -0.8)
    }

    let shoeLike = ratio <= 0.70 &&
        bottomShare >= 0.40 &&
        topShare <= 0.28 &&
        fill <= 0.60
    if shoeLike {
        add("鞋子", 1.2)
        add("箱包", -0.6)
        add("外套", -1.0)
        add("帽子", -0.7)
    }

    // 挎包/手提包：常见误判为鞋子，单独提权。
    let shoulderBagLike = ratio >= 0.72 &&
        ratio <= 1.34 &&
        splitLowerScore < 0.08 &&
        abs(bottomWidth - topWidth) <= 0.09 &&
        middleWidth >= 0.36 &&
        topShare >= 0.15 &&
        topShare <= 0.38 &&
        bottomShare >= 0.22 &&
        bottomShare <= 0.44 &&
        fill >= 0.20 &&
        fill <= 0.68
    if shoulderBagLike {
        add("箱包", 1.8)
        add("鞋子", -1.3)
        add("外套", -0.6)
        add("帽子", -0.5)
    }

    let hatLike = ratio <= 1.10 &&
        topShare >= 0.55 &&
        bottomShare <= 0.20 &&
        splitLowerScore < 0.10
    if hatLike {
        add("帽子", 1.0)
        add("箱包", -0.6)
        add("外套", -0.6)
        add("上衣", -0.6)
    }

    let sockLike = ratio >= 1.70 &&
        splitLowerScore < 0.10 &&
        fill < 0.46
    if sockLike {
        add("袜子", 1.2)
        add("长裤", -0.9)
        add("外套", -0.6)
    }

    // 围巾识别优化：长条形但填充率低，区别于裤子和袜子
    let scarfLike = ratio >= 1.45 && ratio <= 2.20 &&
        fill < 0.35 &&
        topShare >= 0.15 && topShare <= 0.35 &&
        middleShare >= 0.30 &&
        splitLowerScore < 0.12
    if scarfLike {
        // 围巾比裤子更细长，填充率更低
        add("饰品", 2.5)
        add("长裤", -2.0)
        add("袜子", -1.5)
        add("上衣", -0.8)
    }

    // 帽子 vs 箱包 区分优化
    let hatDistinct = ratio < 0.85 &&
        topShare >= 0.45 &&
        topDensity >= 0.48 &&
        fill >= 0.35 &&
        bottomShare <= 0.25
    if hatDistinct {
        // 帽子顶部占比高，密度大
        add("帽子", 2.0)
        add("箱包", -1.8)
        add("鞋子", -1.0)
    }

    // 包 vs 鞋子 区分优化
    let bagDistinct = ratio >= 0.70 && ratio <= 1.30 &&
        abs(bottomWidth - topWidth) <= 0.12 &&
        middleWidth >= 0.32 &&
        fill >= 0.25 &&
        topShare >= 0.18 && topShare <= 0.35 &&
        bottomShare >= 0.20 && bottomShare <= 0.40 &&
        (topDensity >= 0.35 && bottomDensity >= 0.35)  // 包上下都有一定密度
    if bagDistinct {
        // 包上下宽度接近，中间较宽
        add("箱包", 1.5)
        add("鞋子", -1.5)
        add("帽子", -0.8)
    }

    // 鞋子识别优化：扁平且下部占比高
    let shoeDistinct = ratio <= 0.75 &&
        bottomShare >= 0.45 &&
        bottomWidth >= topWidth + 0.10 &&
        fill <= 0.55 &&
        topShare <= 0.30
    if shoeDistinct {
        add("鞋子", 1.5)
        add("箱包", -1.0)
        add("帽子", -0.8)
    }

    // 背景不完整导致轮廓失真时，使用宽高与分布再做一层冲突裁决
    if let shoeScore = scores["鞋子"], let bagScore = scores["箱包"], abs(shoeScore - bagScore) < 0.9 {
        if ratio <= 0.74 || (bottomShare >= 0.42 && topShare <= 0.28) || bottomWidth >= topWidth + 0.14 {
            add("鞋子", 0.5)
            add("箱包", -0.5)
        } else if ratio >= 0.76 && ratio <= 1.35 && abs(bottomWidth - topWidth) <= 0.10 && middleWidth >= 0.36 {
            add("箱包", 1.2)
            add("鞋子", -1.0)
        }
    }

    if let bagScore = scores["箱包"], let outerScore = scores["外套"], abs(bagScore - outerScore) < 0.9 {
        if ratio >= 1.08 && bottomWidth >= topWidth + 0.08 && fill >= 0.46 {
            add("外套", 0.8)
            add("箱包", -0.8)
        } else if ratio <= 1.35 && abs(bottomWidth - topWidth) <= 0.10 && splitLowerScore < 0.10 {
            add("箱包", 0.8)
            add("外套", -0.8)
        }
    }

    if let bagScore = scores["箱包"], let hatScore = scores["帽子"], abs(bagScore - hatScore) < 0.8 {
        if topShare >= 0.54 && bottomShare <= 0.20 {
            add("帽子", 0.8)
            add("箱包", -0.8)
        } else if topShare >= 0.18 && topShare <= 0.40 && bottomShare >= 0.22 {
            add("箱包", 0.8)
            add("帽子", -0.8)
        }
    }

    // 当前版本无法稳定细分，保持可编辑：把不确定结果弱化到上衣
    add("上衣", 0.2 + Double(middleShare) * 0.3)

    guard let best = scores.max(by: { $0.value < $1.value }) else { return "上衣" }
    return best.value < 1.1 ? "上衣" : best.key
}

private struct SilhouetteStats {
    let width: CGFloat
    let height: CGFloat
    let fillRatio: CGFloat
    let topDensity: CGFloat
    let bottomDensity: CGFloat
    let topShare: CGFloat
    let middleShare: CGFloat
    let bottomShare: CGFloat
    let topWidthRatio: CGFloat
    let middleWidthRatio: CGFloat
    let bottomWidthRatio: CGFloat
    let splitLowerScore: CGFloat
}

private func silhouetteStats(from cgImage: CGImage) -> SilhouetteStats? {
    let width = cgImage.width
    let height = cgImage.height
    guard width > 8, height > 8 else { return nil }

    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
    guard let ctx = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return nil
    }
    ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    let alphaThreshold: UInt8 = 12
    var minX = width
    var minY = height
    var maxX = -1
    var maxY = -1

    for y in 0..<height {
        for x in 0..<width {
            let alpha = pixels[y * bytesPerRow + x * bytesPerPixel + 3]
            if alpha > alphaThreshold {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
    }

    guard maxX >= minX, maxY >= minY else { return nil }
    let boxW = maxX - minX + 1
    let boxH = maxY - minY + 1
    guard boxW > 6, boxH > 6 else { return nil }

    let topEnd = minY + Int(Double(boxH) * 0.35)
    let bottomStart = minY + Int(Double(boxH) * 0.65)

    var topVisible = 0
    var topTotal = 0
    var middleVisible = 0
    var middleTotal = 0
    var bottomVisible = 0
    var bottomTotal = 0
    var visibleTotal = 0
    var topRowCoverageSum = 0
    var topRowCount = 0
    var middleRowCoverageSum = 0
    var middleRowCount = 0
    var bottomRowCoverageSum = 0
    var bottomRowCount = 0

    var lowerRows = 0
    var splitRows = 0
    let centerBandHalf = max(1, Int(Double(boxW) * 0.08))
    let centerX = minX + boxW / 2

    for y in minY...maxY {
        var rowVisible = 0
        var leftVisible = 0
        var rightVisible = 0
        var centerVisible = 0

        for x in minX...maxX {
            let alpha = pixels[y * bytesPerRow + x * bytesPerPixel + 3]
            let isVisible = alpha > alphaThreshold
            if isVisible {
                visibleTotal += 1
                rowVisible += 1
                if x < centerX { leftVisible += 1 } else { rightVisible += 1 }
                if abs(x - centerX) <= centerBandHalf { centerVisible += 1 }
            }
        }

        if y <= topEnd {
            topVisible += rowVisible
            topTotal += boxW
            topRowCoverageSum += rowVisible
            topRowCount += 1
        } else if y < bottomStart {
            middleVisible += rowVisible
            middleTotal += boxW
            middleRowCoverageSum += rowVisible
            middleRowCount += 1
        } else if y >= bottomStart {
            bottomVisible += rowVisible
            bottomTotal += boxW
            bottomRowCoverageSum += rowVisible
            bottomRowCount += 1

            lowerRows += 1
            let leftRatio = CGFloat(leftVisible) / CGFloat(boxW)
            let rightRatio = CGFloat(rightVisible) / CGFloat(boxW)
            let centerRatio = CGFloat(centerVisible) / CGFloat(max(1, centerBandHalf * 2 + 1))
            if leftRatio > 0.16 && rightRatio > 0.16 && centerRatio < 0.20 {
                splitRows += 1
            }
        }
    }

    let topDensity = topTotal > 0 ? CGFloat(topVisible) / CGFloat(topTotal) : 0
    let middleDensity = middleTotal > 0 ? CGFloat(middleVisible) / CGFloat(middleTotal) : 0
    let bottomDensity = bottomTotal > 0 ? CGFloat(bottomVisible) / CGFloat(bottomTotal) : 0
    let topShare = visibleTotal > 0 ? CGFloat(topVisible) / CGFloat(visibleTotal) : 0
    let middleShare = visibleTotal > 0 ? CGFloat(middleVisible) / CGFloat(visibleTotal) : 0
    let bottomShare = visibleTotal > 0 ? CGFloat(bottomVisible) / CGFloat(visibleTotal) : 0
    let topWidthRatio = topRowCount > 0 ? CGFloat(topRowCoverageSum) / CGFloat(topRowCount * boxW) : 0
    let middleWidthRatio = middleRowCount > 0 ? CGFloat(middleRowCoverageSum) / CGFloat(middleRowCount * boxW) : 0
    let bottomWidthRatio = bottomRowCount > 0 ? CGFloat(bottomRowCoverageSum) / CGFloat(bottomRowCount * boxW) : 0
    let splitLowerScore = lowerRows > 0 ? CGFloat(splitRows) / CGFloat(lowerRows) : 0
    let fillRatio = CGFloat(visibleTotal) / CGFloat(max(1, boxW * boxH))

    return SilhouetteStats(
        width: CGFloat(boxW),
        height: CGFloat(boxH),
        fillRatio: fillRatio,
        topDensity: max(topDensity, middleDensity * 0.92),
        bottomDensity: bottomDensity,
        topShare: topShare,
        middleShare: middleShare,
        bottomShare: bottomShare,
        topWidthRatio: topWidthRatio,
        middleWidthRatio: middleWidthRatio,
        bottomWidthRatio: bottomWidthRatio,
        splitLowerScore: splitLowerScore
    )
}

private func dominantColorNameByCoverage(from image: UIImage) -> String? {
    guard let cgImage = image.cgImage else { return nil }
    let width = cgImage.width
    let height = cgImage.height
    guard width > 0, height > 0 else { return nil }

    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
    guard let ctx = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return nil
    }
    ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    let palette = [
        ("白色系", (0.96, 0.96, 0.96)),
        ("杏色系", (0.86, 0.78, 0.66)),
        ("黄色系", (0.98, 0.83, 0.32)),
        ("橙色系", (0.98, 0.57, 0.22)),
        ("红色系", (0.92, 0.28, 0.26)),
        ("粉色系", (0.96, 0.70, 0.74)),
        ("紫色系", (0.55, 0.39, 0.85)),
        ("蓝色系", (0.28, 0.50, 0.91)),
        ("绿色系", (0.40, 0.72, 0.26)),
        ("棕色系", (0.46, 0.30, 0.16)),
        ("咖色系", (0.60, 0.46, 0.36)),
        ("灰色系", (0.58, 0.58, 0.58)),
        ("黑色系", (0.12, 0.12, 0.12))
    ]

    var counts = Array(repeating: 0, count: palette.count)
    var visibleSamples = 0
    let alphaThreshold: UInt8 = 12
    let sampleStep = max(1, min(width, height) / 256)

    for y in Swift.stride(from: 0, to: height, by: sampleStep) {
        for x in Swift.stride(from: 0, to: width, by: sampleStep) {
            let index = y * bytesPerRow + x * bytesPerPixel
            let alpha = pixels[index + 3]
            if alpha <= alphaThreshold { continue }

            let r = Double(pixels[index]) / 255.0
            let g = Double(pixels[index + 1]) / 255.0
            let b = Double(pixels[index + 2]) / 255.0
            visibleSamples += 1

            var best = 0
            var bestDist = Double.greatestFiniteMagnitude
            for i in palette.indices {
                let d = distance((r, g, b), palette[i].1)
                if d < bestDist {
                    bestDist = d
                    best = i
                }
            }
            counts[best] += 1
        }
    }

    guard visibleSamples > 0 else { return nil }
    guard let idx = counts.enumerated().max(by: { $0.element < $1.element })?.offset else {
        return nil
    }
    return palette[idx].0
}

private func rotateImageData(_ data: Data, clockwise: Bool) -> Data? {
    guard let image = UIImage(data: data) else { return nil }
    let rotated = image.rotated(by: clockwise ? 90 : -90)
    return rotated.jpegData(compressionQuality: 0.9)
}

private extension UIImage {
    func normalizedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func rotated(by degrees: CGFloat) -> UIImage {
        let radians = degrees * .pi / 180
        let newSize = CGRect(origin: .zero, size: size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .integral.size
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { context in
            context.cgContext.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            context.cgContext.rotate(by: radians)
            draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        }
    }

    func fittedToSquareCanvas(side: CGFloat, scaleFactor: CGFloat) -> UIImage {
        let canvasSize = CGSize(width: side, height: side)
        let maxSide = max(size.width, size.height)
        let scale = (side * scaleFactor) / maxSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let origin = CGPoint(x: (side - targetSize.width) / 2, y: (side - targetSize.height) / 2)
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        return renderer.image { _ in
            UIColor.clear.setFill()
            UIRectFill(CGRect(origin: .zero, size: canvasSize))
            draw(in: CGRect(origin: origin, size: targetSize))
        }
    }
}
