// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  WardrobeTabView.swift
//  Clothes
//
//  Created by Codex on 2026/1/6.
//

import CoreImage
import ImageIO
import Photos
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import UIKit
import Vision

struct WardrobeTabView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("auth_token") private var authToken = ""
    @AppStorage("auth_username") private var authUsername = ""
    @State private var showAddClothing = false
    @Query private var clothingItems: [ClothingItem]

    var body: some View {
        NavigationStack {
            WardrobeCatalogView(items: visibleItems) {
                showAddClothing = true
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        // When switching accounts, pull server data for the new token so lists refresh.
        .task(id: authToken) {
            // UI tests seed deterministic local data; avoid background sync/network flakiness.
            if ProcessInfo.processInfo.arguments.contains("-uiTesting") { return }
            guard !authToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            await WardrobeSyncService.shared.syncNow(modelContext: modelContext)
        }
        .sheet(isPresented: $showAddClothing) {
            AddClothingFlowView()
        }
    }

    private var currentOwnerKey: String {
        let trimmed = authUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? SharedConstants.guestOwnerKey : trimmed
    }

    private var visibleItems: [ClothingItem] {
        // Legacy (empty owner) items are only visible in guest mode. Logged-in users must only see their own partition.
        let isGuest = currentOwnerKey == SharedConstants.guestOwnerKey
        return clothingItems.filter {
            $0.ownerUsername == currentOwnerKey || (isGuest && $0.ownerUsername.isEmpty)
        }
    }
}

private struct WardrobeCatalogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let items: [ClothingItem]
    let onAdd: () -> Void

    @State private var sortByUsage = false
    @State private var selectedCategory = "全部"
    @State private var isEditing = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var showCategoryPicker = false
    @State private var showDeleteConfirm = false
    @State private var showRecycleBin = false
    @State private var batchCategory = "上衣"
    @State private var showBrowseCatalog = false
    private let categories = CategoryConfig.categories
    var body: some View {
        ZStack {
            WarmBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    wardrobeHeader
                    wardrobeControls
                    wardrobeTabs
                    wardrobeGrid
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .adaptiveContentWidth(maxWidth: 760)
            }
            .refreshable {
                ImageCache.shared.cache.removeAllObjects()
            }
            if isEditing {
                WardrobeBatchBar(
                    selectionCount: selectedIDs.count,
                    onEditCategory: { showCategoryPicker = true },
                    onDelete: { showDeleteConfirm = true },
                    onDone: {
                        isEditing = false
                        selectedIDs.removeAll()
                    }
                )
            }
        }
        .onAppear {
            prewarmPhotoAccess()
            // 延迟执行图片缓存预热，避免首次加载卡顿
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                preheatWardrobeCache(items: activeItems.map { ImageCacheItem(id: $0.id, data: $0.imageData) })
            }
        }
        .onChange(of: activeItems.count) { _, _ in
            preheatWardrobeCache(items: activeItems.map { ImageCacheItem(id: $0.id, data: $0.imageData) })
        }
        .sheet(isPresented: $showCategoryPicker) {
            BatchCategoryPickerSheet(
                title: "批量分类",
                options: categories,
                selection: $batchCategory,
                onSave: {
                    applyBatchCategory()
                    showCategoryPicker = false
                },
                onCancel: { showCategoryPicker = false }
            )
        }
        .sheet(isPresented: $showRecycleBin) {
            RecycleBinView(items: trashedItems) { item in
                item.deletedAt = nil
            } onDelete: { item in
                modelContext.delete(item)
            }
        }
        .sheet(isPresented: $showBrowseCatalog) {
            BrowseCatalogView()
        }
        .alert("删除衣物", isPresented: $showDeleteConfirm) {
            Button("删除", role: .destructive) { deleteSelectedItems() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将把所选 \(selectedIDs.count) 件衣物移入回收站，可在 30 天内恢复。")
        }
        .onAppear {
            purgeExpiredTrash()
        }
    }

    private var wardrobeHeader: some View {
        HStack(spacing: 10) {
            Text("衣橱")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color(red: 0.20, green: 0.20, blue: 0.20))
            Spacer()
            Button {
                showRecycleBin = true
            } label: {
                Label("回收站", systemImage: "trash")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(AppTheme.primary.opacity(0.12))
                    )
                    .foregroundStyle(AppTheme.primary)
            }
            .buttonStyle(.appPlain)
            .contentShape(Rectangle())

            Button {
                isEditing.toggle()
                if !isEditing {
                    selectedIDs.removeAll()
                }
            } label: {
                Label(isEditing ? "完成" : "编辑", systemImage: "square.and.pencil")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(AppTheme.primary.opacity(0.12))
                    )
                    .foregroundStyle(AppTheme.primary)
            }
            .buttonStyle(.appPlain)
            .contentShape(Rectangle())

            // MARK: - 逛服装库功能（下一期开放）
            // 暂时隐藏，保留代码供后续开发使用
            /*
            Button {
                showBrowseCatalog = true
            } label: {
                Label("逛服装库", systemImage: "bag")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(AppTheme.primary.opacity(0.12))
                    )
                    .foregroundStyle(AppTheme.primary)
            }
            .buttonStyle(.appPlain)
            .contentShape(Rectangle())
            */
        }
    }

    private var wardrobeControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button(action: onAdd) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("添加衣物")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Color.white)
                    .frame(height: 44)
                    .padding(.horizontal, 18)
                    .background(
                        Capsule()
                            .fill(AppTheme.primary)
                    )
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Button {
                    sortByUsage = false
                } label: {
                    Text("按添加时间")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(sortByUsage ? Color.white : AppTheme.primary)
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            sortByUsage
                                                ? Color(red: 0.86, green: 0.84, blue: 0.80)
                                                : AppTheme.primary,
                                            lineWidth: 1
                                        )
                                )
                        )
                        .foregroundStyle(sortByUsage ? Color(red: 0.40, green: 0.40, blue: 0.42) : Color.white)
                }
                .buttonStyle(.appPlain)

                Button {
                    sortByUsage = true
                } label: {
                    Text("按使用频次")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(sortByUsage ? AppTheme.primary : Color.white)
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            sortByUsage
                                                ? AppTheme.primary
                                                : Color(red: 0.86, green: 0.84, blue: 0.80),
                                            lineWidth: 1
                                        )
                                )
                        )
                        .foregroundStyle(sortByUsage ? Color.white : Color(red: 0.40, green: 0.40, blue: 0.42))
                }
                .buttonStyle(.appPlain)
            }
        }
    }

    private var wardrobeTabs: some View {
        DetailWrapStack(items: availableCategories, limit: 6) { category in
            WardrobeTabChip(
                title: category,
                systemImage: categoryIconName(for: category),
                isActive: selectedCategory == category
            )
            .onTapGesture {
                selectedCategory = category
            }
        }
    }


    private var wardrobeGrid: some View {
        let usageCounts = usageCountsByID
        return LazyVGrid(columns: gridColumns, spacing: 0) {
            ForEach(sortedItems) { item in
                let usageCount = usageCounts[item.id, default: 0]
                if isEditing {
                    Button {
                        toggleSelection(id: item.id)
                    } label: {
                        WardrobeGridCard(item: item, usageCount: usageCount, isEditing: true, isSelected: selectedIDs.contains(item.id))
                            .equatable()
                    }
                    .buttonStyle(.appPlain)
                    .accessibilityLabel(Text(item.name))
                    .accessibilityIdentifier("wardrobe.grid.select.\(item.id.uuidString)")
                } else {
                    NavigationLink {
                        WardrobeItemDetailView(item: item)
                    } label: {
                        WardrobeGridCard(item: item, usageCount: usageCount, isEditing: false, isSelected: false)
                            .equatable()
                    }
                    .buttonStyle(.appPlain)
                    .accessibilityLabel(Text(item.name))
                    .accessibilityIdentifier("wardrobe.grid.open.\(item.id.uuidString)")
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteItem(item)
                        } label: {
                            Text("删除")
                        }
                    }
                }
            }
            WardrobeAddTile(action: onAdd)
        }
        .padding(.top, 8)
    }

    private var sortedItems: [ClothingItem] {
        let filtered = selectedCategory == "全部" ? activeItems : activeItems.filter { $0.category == selectedCategory }
        let finalItems = filtered
        if sortByUsage {
            let usageCounts = UsageTracker.countsMap()
            return finalItems.sorted { lhs, rhs in
                let lhsCount = usageCounts[lhs.id.uuidString] ?? 0
                let rhsCount = usageCounts[rhs.id.uuidString] ?? 0
                if lhsCount == rhsCount {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhsCount > rhsCount
            }
        }
        return finalItems.sorted { $0.createdAt > $1.createdAt }
    }

    private var usageCountsByID: [UUID: Int] {
        let usageCounts = UsageTracker.countsMap()
        var result: [UUID: Int] = [:]
        result.reserveCapacity(activeItems.count)
        for item in activeItems {
            result[item.id] = usageCounts[item.id.uuidString] ?? 0
        }
        return result
    }

    private var availableCategories: [String] {
        let order = CategoryConfig.categoryOrderWithAll
        let present = Set(activeItems.map { $0.category })
        return order.filter { $0 == "全部" || present.contains($0) }
    }

    private var activeItems: [ClothingItem] {
        items.filter { $0.deletedAt == nil }
    }

    private var gridColumns: [GridItem] {
        let columnCount = horizontalSizeClass == .regular ? 4 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 0), count: columnCount)
    }

    private var trashedItems: [ClothingItem] {
        items.filter { $0.deletedAt != nil }
    }

    private func toggleSelection(id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func categoryIconName(for category: String) -> String {
        switch category {
        case "全部":
            return "square.grid.2x2"
        case "上衣":
            return "tshirt"
        case "长裤":
            return "rectangle.split.2x1"
        case "短裤":
            return "rectangle.split.2x1"
        case "半身裙":
            return "figure.stand"
        case "连体装":
            return "figure.dress"
        case "外套":
            return "wind"
        case "鞋子":
            return "shoeprints.fill"
        case "袜子":
            return "tag"
        case "箱包":
            return "bag.fill"
        case "饰品":
            return "sparkles"
        case "帽子":
            return "graduationcap.fill"
        default:
            return "tag"
        }
    }

    private func applyBatchCategory() {
        guard !selectedIDs.isEmpty else { return }
        items.filter { selectedIDs.contains($0.id) }.forEach { $0.category = batchCategory }
        selectedIDs.removeAll()
        isEditing = false
    }

    private func deleteSelectedItems() {
        guard !selectedIDs.isEmpty else { return }
        items.filter { selectedIDs.contains($0.id) }.forEach { $0.deletedAt = Date() }
        selectedIDs.removeAll()
        isEditing = false
    }

    private func deleteItem(_ item: ClothingItem) {
        item.deletedAt = Date()
    }

    private func prewarmPhotoAccess() {
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") { return }
        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in }
        }
    }

    private func purgeExpiredTrash() {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) else { return }
        items.filter { item in
            if let deletedAt = item.deletedAt {
                return deletedAt <= cutoff
            }
            return false
        }.forEach { modelContext.delete($0) }
    }
}

private struct RecycleBinView: View {
    @Environment(\.dismiss) private var dismiss
    let items: [ClothingItem]
    let onRestore: (ClothingItem) -> Void
    let onDelete: (ClothingItem) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackdrop()
                List {
                    if items.isEmpty {
                        Text("回收站为空")
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(items) { item in
                            HStack(spacing: 12) {
                                if let data = item.imageData, let image = cachedThumbnail(id: item.id, data: data, maxPixel: 80) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 56, height: 56)
                                        .clipped()
                                        .cornerRadius(12)
                                } else {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(red: 0.93, green: 0.91, blue: 0.87))
                                        .frame(width: 56, height: 56)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name)
                                        .font(.subheadline.weight(.medium))
                                    Text(item.category)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("恢复") {
                                    onRestore(item)
                                }
                                .buttonStyle(.bordered)
                            }
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    onDelete(item)
                                } label: {
                                    Text("彻底删除")
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("回收站")
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

private struct WardrobeTabChip: View {
    let title: String
    let systemImage: String
    let isActive: Bool

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isActive ? Color(red: 0.24, green: 0.24, blue: 0.24) : Color(red: 0.60, green: 0.60, blue: 0.60))
            .opacity(isActive ? 1.0 : 0.5)
            Capsule()
                .fill(isActive ? AppTheme.primary : Color.clear)
                .frame(height: 2)
                .frame(maxWidth: 46)
        }
    }
}

private struct BrowseCatalogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("auth_username") private var authUsername = ""
    @State private var searchText = ""
    @State private var selectedCategory = "全部"
    @State private var products: [MallProduct] = []
    @State private var isLoading = false
    @State private var noticeMessage: String?
    @State private var addingIDs: Set<Int64> = []

    private let categoryOptions = ["全部", "男士羽绒", "男士外套", "女士棉服", "女士裤子"]

    private var currentOwnerKey: String {
        let trimmed = authUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? SharedConstants.guestOwnerKey : trimmed
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        searchBar
                        categoryTabs
                        filterRow
                        catalogGrid
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 32)
                    .adaptiveContentWidth(maxWidth: 760)
                }
            }
            .navigationTitle("逛服装库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                    }
                }
            }
            .task {
                await loadCatalog()
            }
            .alert("提示", isPresented: Binding(get: { noticeMessage != nil }, set: { _ in noticeMessage = nil })) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(noticeMessage ?? "")
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color(red: 0.60, green: 0.58, blue: 0.54))
            TextField("", text: $searchText, prompt: Text("搜索喜欢的衣物").foregroundStyle(AppTheme.placeholder))
                .textInputAutocapitalization(.never)
                .foregroundStyle(Color.black)
            if isLoading {
                ProgressView()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.96, green: 0.96, blue: 0.97))
        )
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(categoryOptions, id: \.self) { category in
                    VStack(spacing: 6) {
                        Text(category)
                            .font(.subheadline.weight(selectedCategory == category ? .semibold : .regular))
                            .foregroundStyle(selectedCategory == category ? AppTheme.titleText : AppTheme.secondaryText)
                        Capsule()
                            .fill(selectedCategory == category ? AppTheme.titleText : Color.clear)
                            .frame(height: 2)
                    }
                    .onTapGesture {
                        selectedCategory = category
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var filterRow: some View {
        HStack(spacing: 10) {
            ForEach(summaryTags, id: \.self) { title in
                HStack(spacing: 6) {
                    Text(title)
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.9))
                )
                .foregroundStyle(Color(red: 0.40, green: 0.38, blue: 0.34))
            }
            Spacer()
            Button {
                Task { await loadCatalog() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.36, green: 0.32, blue: 0.28))
                    .padding(10)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.9))
                    )
            }
        }
    }

    private var catalogGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 18) {
            ForEach(filteredProducts) { item in
                BrowseCatalogCard(item: item, isAdding: addingIDs.contains(item.id)) {
                    Task { await addToWardrobe(item) }
                }
            }
        }
    }

    private var filteredProducts: [MallProduct] {
        let byCategory: [MallProduct]
        switch selectedCategory {
        case "男士羽绒":
            byCategory = products.filter { $0.gender == "男士" && ($0.subCategory == "羽绒" || $0.category == "棉羽") }
        case "男士外套":
            byCategory = products.filter { $0.gender == "男士" && ($0.subCategory == "外套" || $0.category == "外套") }
        case "女士棉服":
            byCategory = products.filter { $0.gender == "女士" && ($0.subCategory == "棉服" || $0.category == "棉羽") }
        case "女士裤子":
            byCategory = products.filter { $0.gender == "女士" && ($0.subCategory == "裤子" || $0.category == "裤子") }
        default:
            byCategory = products
        }
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return byCategory }
        return byCategory.filter {
            $0.name.localizedCaseInsensitiveContains(keyword)
                || $0.brand.localizedCaseInsensitiveContains(keyword)
                || $0.category.localizedCaseInsensitiveContains(keyword)
                || $0.subCategory.localizedCaseInsensitiveContains(keyword)
        }
    }

    private var summaryTags: [String] {
        [
            "商品 \(products.count)",
            "当前 \(filteredProducts.count)",
            "来源 商城"
        ]
    }

    private func loadCatalog() async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await MallCatalogService().fetchProducts(gender: nil, subCategory: nil, keyword: nil, limit: 400)
        } catch {
            noticeMessage = "加载商城数据失败：\(error.localizedDescription)"
        }
    }

    private func addToWardrobe(_ product: MallProduct) async {
        if addingIDs.contains(product.id) { return }
        addingIDs.insert(product.id)
        defer { addingIDs.remove(product.id) }

        guard let imageURL = SharedConstants.resolvedImageURL(from: product.imageURL) else {
            noticeMessage = "图片地址无效，无法加入衣橱。"
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            let wardrobeCategory = mapMallToWardrobeCategory(product)
            guard let processed = await Task.detached(priority: .userInitiated, operation: {
                processMallCatalogImage(data, targetCategory: wardrobeCategory)
            }).value else {
                noticeMessage = "图片处理失败，无法加入衣橱。"
                return
            }

            let item = ClothingItem(
                ownerUsername: currentOwnerKey,
                name: product.name,
                category: wardrobeCategory,
                subCategory: product.subCategory,
                color: processed.colorName,
                material: "",
                pattern: "纯色",
                fit: "regular",
                formality: 0.5,
                seasons: ["四季"],
                occasions: ["休闲"],
                styleTags: ["来源:商城", "来源站点:\(product.sourceSite.uppercased())", "商城类目:\(product.gender)-\(product.subCategory)"],
                brand: product.brand.isEmpty ? "UR" : product.brand,
                price: product.price > 0 ? product.price : nil,
                purchaseDate: nil,
                imageData: processed.imageData
            )
            modelContext.insert(item)
            noticeMessage = "已加入我的衣橱：\(product.name)"
        } catch {
            noticeMessage = "下载或保存失败：\(error.localizedDescription)"
        }
    }

    private func mapMallToWardrobeCategory(_ product: MallProduct) -> String {
        let text = "\(product.category) \(product.subCategory)"
        if text.contains("裤") {
            return "长裤"
        }
        if text.contains("棉") || text.contains("羽") || text.contains("外套") {
            return "外套"
        }
        return "上衣"
    }
}

private struct BrowseCatalogCard: View {
    let item: MallProduct
    let isAdding: Bool
    let onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .frame(height: 160)
                        .overlay(
                            Group {
                                if let url = SharedConstants.resolvedImageURL(from: item.imageURL) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .padding(12)
                                    } placeholder: {
                                        ProgressView()
                                    }
                                } else {
                                    Image(systemName: "tshirt")
                                        .font(.title2)
                                        .foregroundStyle(Color(red: 0.70, green: 0.68, blue: 0.64))
                                }
                            }
                        )

                    Circle()
                        .fill(Color.black.opacity(0.45))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Group {
                                if isAdding {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "plus")
                                        .foregroundStyle(Color.white)
                                        .font(.headline)
                                }
                            }
                        )
                        .padding(10)
                }

                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.bodyText)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text("A")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.bodyText)
                        .frame(width: 18, height: 18)
                        .background(
                            Circle()
                                .fill(Color(red: 0.92, green: 0.92, blue: 0.94))
                        )
                    Text("\(item.brand.isEmpty ? "UR" : item.brand) · ¥\(String(format: "%.2f", item.price))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedText)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.appPlain)
        .disabled(isAdding)
    }
}

private struct MallProcessedImageResult {
    let imageData: Data
    let colorName: String
}

nonisolated private func processMallCatalogImage(_ data: Data, targetCategory: String) -> MallProcessedImageResult? {
    guard let image = UIImage(data: data) else { return nil }
    let normalized = image.mallNormalizedOrientation()
    let noBackground = MallBackgroundRemoval.removeBackground(image: normalized) ?? normalized
    let categoryFocused = mallExtractCategoryFocusImage(from: noBackground, targetCategory: targetCategory) ?? noBackground
    let fitted = categoryFocused.mallFittedToSquareCanvas(side: 1024, scaleFactor: 0.88)
    guard let outputData = fitted.pngData() else { return nil }
    let colorName = mallDominantColorName(from: fitted) ?? "黑色系"
    return MallProcessedImageResult(imageData: outputData, colorName: colorName)
}

private func mallExtractCategoryFocusImage(from image: UIImage, targetCategory: String) -> UIImage? {
    guard let content = image.mallTrimmedToOpaqueBounds() else { return nil }
    let bounds = CGRect(origin: .zero, size: content.size)
    if bounds.height < 10 || bounds.width < 10 {
        return content
    }

    let focusRect: CGRect
    if targetCategory.contains("裤") {
        // 下装优先保留下半身区域
        focusRect = CGRect(
            x: bounds.minX,
            y: bounds.minY + bounds.height * 0.30,
            width: bounds.width,
            height: bounds.height * 0.70
        )
    } else {
        // 上装/外套优先保留上半身区域
        focusRect = CGRect(
            x: bounds.minX,
            y: bounds.minY,
            width: bounds.width,
            height: bounds.height * 0.82
        )
    }

    let clipped = focusRect.intersection(bounds)
    guard clipped.width > 1, clipped.height > 1 else { return content }
    return content.mallCropped(to: clipped)?.mallTrimmedToOpaqueBounds() ?? content
}

private func mallDominantColorName(from image: UIImage) -> String? {
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
        ("白色系", (0.96, 0.96, 0.96)), ("杏色系", (0.86, 0.78, 0.66)), ("黄色系", (0.98, 0.83, 0.32)),
        ("橙色系", (0.98, 0.57, 0.22)), ("红色系", (0.92, 0.28, 0.26)), ("粉色系", (0.96, 0.70, 0.74)),
        ("紫色系", (0.55, 0.39, 0.85)), ("蓝色系", (0.28, 0.50, 0.91)), ("绿色系", (0.40, 0.72, 0.26)),
        ("棕色系", (0.46, 0.30, 0.16)), ("咖色系", (0.60, 0.46, 0.36)), ("灰色系", (0.58, 0.58, 0.58)),
        ("黑色系", (0.12, 0.12, 0.12))
    ]
    let nearest = palette.min { lhs, rhs in
        mallColorDistance((r, g, b), lhs.1) < mallColorDistance((r, g, b), rhs.1)
    }
    return nearest?.0
}

private func mallColorDistance(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> Double {
    let dr = a.0 - b.0
    let dg = a.1 - b.1
    let db = a.2 - b.2
    return dr * dr + dg * dg + db * db
}

private enum MallBackgroundRemoval {
    static func removeBackground(image: UIImage) -> UIImage? {
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

private extension UIImage {
    func mallNormalizedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func mallFittedToSquareCanvas(side: CGFloat, scaleFactor: CGFloat) -> UIImage {
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

    func mallCropped(to rect: CGRect) -> UIImage? {
        guard let cg = cgImage else { return nil }
        let scale = self.scale
        let scaledRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.size.width * scale,
            height: rect.size.height * scale
        ).integral
        guard let cropped = cg.cropping(to: scaledRect) else { return nil }
        return UIImage(cgImage: cropped, scale: scale, orientation: .up)
    }

    func mallTrimmedToOpaqueBounds(alphaThreshold: UInt8 = 8) -> UIImage? {
        guard let cg = cgImage else { return nil }
        let width = cg.width
        let height = cg.height
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

        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

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

        guard maxX >= minX, maxY >= minY else { return self }
        let cropRect = CGRect(
            x: CGFloat(minX),
            y: CGFloat(minY),
            width: CGFloat(maxX - minX + 1),
            height: CGFloat(maxY - minY + 1)
        )
        guard let trimmed = cg.cropping(to: cropRect) else { return self }
        return UIImage(cgImage: trimmed, scale: scale, orientation: .up)
    }
}

private struct WardrobeGridCard: View, Equatable {
    let item: ClothingItem
    let usageCount: Int
    let isEditing: Bool
    let isSelected: Bool

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d"
        return formatter
    }()

    static func == (lhs: WardrobeGridCard, rhs: WardrobeGridCard) -> Bool {
        lhs.item.id == rhs.item.id
            && lhs.item.brand == rhs.item.brand
            && lhs.item.createdAt == rhs.item.createdAt
            && lhs.item.imageData?.count == rhs.item.imageData?.count
            && lhs.usageCount == rhs.usageCount
            && lhs.isEditing == rhs.isEditing
            && lhs.isSelected == rhs.isSelected
    }

    private var dateText: String {
        Self.dateFormatter.string(from: item.createdAt)
    }

    private var cardBackground: Color {
        Color.clear
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size.width
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    Color.clear
                        .frame(height: size * 0.88)

                    WardrobeCardThumbnail(id: item.id, data: item.imageData, maxPixel: 320, height: size * 0.86)

                    if usageCount > 0 {
                        VStack {
                            HStack {
                                Spacer()
                                Text("\(usageCount) 次")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color.black.opacity(0.08))
                                    )
                                    .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.45))
                            }
                            Spacer()
                        }
                        .padding(8)
                    }

                    if isEditing {
                        VStack {
                            HStack {
                                Spacer()
                                Circle()
                                    .fill(isSelected ? AppTheme.primary : Color.white.opacity(0.9))
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Image(systemName: isSelected ? "checkmark" : "circle")
                                            .font(.caption)
                                            .foregroundStyle(isSelected ? Color.white : Color(red: 0.60, green: 0.56, blue: 0.52))
                                    )
                            }
                            Spacer()
                        }
                        .padding(8)
                    }
                }

                Text(dateText)
                    .font(.caption2)
                    .foregroundStyle(Color(red: 0.42, green: 0.42, blue: 0.42))
                    .padding(.top, -14)
            }
            .padding(12)
            .frame(width: size, height: size)
            .background(
                Rectangle()
                    .fill(cardBackground)
            )
            .overlay(
                Rectangle()
                    .stroke(Color(red: 0.90, green: 0.90, blue: 0.90), lineWidth: 0.5)
            )
        }
        .aspectRatio(1, contentMode: .fit)
        // The grid card doesn't render the item name; expose it for UI testing and accessibility.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(item.name))
        .accessibilityValue(Text(item.category))
        .accessibilityIdentifier("wardrobe.grid.\(item.id.uuidString)")
    }
}

private struct WardrobeCardThumbnail: View {
    let id: UUID
    let data: Data?
    let maxPixel: Int
    let height: CGFloat

    @State private var image: UIImage?

    private var loadKey: String {
        "\(id.uuidString)-\(maxPixel)-\(data?.count ?? 0)"
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: height)
                    .clipped()
                    .padding(4)
            } else {
                Image(systemName: "tshirt")
                    .font(.title2)
                    .foregroundStyle(Color(red: 0.70, green: 0.66, blue: 0.60))
            }
        }
        .task(id: loadKey) {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        guard let data else {
            image = nil
            return
        }
        if let cached = cachedThumbnailIfAvailable(id: id, data: data, maxPixel: maxPixel) {
            image = cached
            return
        }
        if let prepared = await prepareThumbnail(id: id, data: data, maxPixel: maxPixel) {
            image = prepared
        }
    }
}

private struct WardrobeAddTile: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GeometryReader { proxy in
                let size = proxy.size.width
                VStack(spacing: 10) {
                    Circle()
                        .fill(Color(red: 0.92, green: 0.92, blue: 0.94))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.headline)
                                .foregroundStyle(Color(red: 0.55, green: 0.55, blue: 0.55))
                        )
                    Text("添加衣物")
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.55, green: 0.55, blue: 0.55))
                }
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.98, green: 0.97, blue: 0.95))
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                )
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.appPlain)
    }
}

private struct WardrobeBatchBar: View {
    let selectionCount: Int
    let onEditCategory: () -> Void
    let onDelete: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Text("已选 \(selectionCount) 件")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.bodyText)
                Spacer()
                Button("批量分类") {
                    onEditCategory()
                }
                .font(.subheadline.weight(.semibold))
                .frame(height: 40)
                .padding(.horizontal, 18)
                .background(
                    Capsule()
                        .fill(AppTheme.primary)
                )
                .foregroundStyle(Color.white)
                .contentShape(Rectangle())
                .disabled(selectionCount == 0)
                Button("删除") {
                    onDelete()
                }
                .font(.subheadline.weight(.semibold))
                .frame(height: 40)
                .padding(.horizontal, 18)
                .background(
                    Capsule()
                        .fill(Color(red: 0.82, green: 0.40, blue: 0.36))
                )
                .foregroundStyle(Color.white)
                .contentShape(Rectangle())
                .disabled(selectionCount == 0)
                Button("完成") {
                    onDone()
                }
                .font(.subheadline.weight(.semibold))
                .frame(height: 40)
                .padding(.horizontal, 18)
                    .background(
                        Capsule()
                            .fill(Color.white)
                            .overlay(
                                Capsule()
                                    .stroke(Color(red: 0.86, green: 0.86, blue: 0.86), lineWidth: 1)
                            )
                    )
                    .foregroundStyle(Color(red: 0.36, green: 0.36, blue: 0.36))
                    .contentShape(Rectangle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.96))
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: -2)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
}

private struct BatchCategoryPickerSheet: View {
    let title: String
    let options: [String]
    @Binding var selection: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.black.opacity(0.08))
                .frame(width: 48, height: 6)
                .padding(.top, 8)
            Text(title)
                .font(.headline)
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 180)

            HStack(spacing: 12) {
                Button("取消", action: onCancel)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .overlay(
                        Capsule()
                            .stroke(Color.black.opacity(0.2), lineWidth: 1)
                    )
                    .foregroundStyle(Color.black)
                    .clipShape(Capsule())
                    .contentShape(Rectangle())
                    .buttonStyle(.appPlain)
                Button("保存", action: onSave)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.primary)
                    .foregroundStyle(Color.white)
                    .clipShape(Capsule())
                    .contentShape(Rectangle())
                    .buttonStyle(.appPlain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.hidden)
        .onAppear {
            if selection.isEmpty {
                selection = options.first ?? ""
            }
        }
    }
}

private struct WardrobeItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("auth_username") private var authUsername = ""
    @Bindable var item: ClothingItem
    @State private var alertMessage: String?
    @State private var showPhotoPreview = false
    @State private var showImageEditor = false
    @State private var editorOriginalData: Data?
    @State private var detailTab = 0
    @State private var isFlattening = false
    @Query private var outfitRecords: [OutfitRecord]
    @State private var activePicker: DetailWheelPicker?
    @State private var showColorSheet = false
    @State private var initialSnapshot = ""

    private let categories = CategoryConfig.categories
    private let seasons = ["春", "夏", "秋", "冬", "四季"]
    private let occasions = ["工作", "休闲", "运动", "校园", "约会", "居家", "度假", "宴会"]
    private let colorOptions: [DetailColorOption] = [
        DetailColorOption(name: "白色系", color: Color(red: 0.96, green: 0.96, blue: 0.96)),
        DetailColorOption(name: "杏色系", color: Color(red: 0.86, green: 0.78, blue: 0.66)),
        DetailColorOption(name: "黄色系", color: Color(red: 0.98, green: 0.83, blue: 0.32)),
        DetailColorOption(name: "橙色系", color: Color(red: 0.98, green: 0.57, blue: 0.22)),
        DetailColorOption(name: "红色系", color: Color(red: 0.92, green: 0.28, blue: 0.26)),
        DetailColorOption(name: "粉色系", color: Color(red: 0.96, green: 0.70, blue: 0.74)),
        DetailColorOption(name: "紫色系", color: Color(red: 0.55, green: 0.39, blue: 0.85)),
        DetailColorOption(name: "蓝色系", color: Color(red: 0.28, green: 0.50, blue: 0.91)),
        DetailColorOption(name: "绿色系", color: Color(red: 0.40, green: 0.72, blue: 0.26)),
        DetailColorOption(name: "棕色系", color: Color(red: 0.46, green: 0.30, blue: 0.16)),
        DetailColorOption(name: "咖色系", color: Color(red: 0.60, green: 0.46, blue: 0.36)),
        DetailColorOption(name: "灰色系", color: Color(red: 0.58, green: 0.58, blue: 0.58)),
        DetailColorOption(name: "黑色系", color: Color(red: 0.12, green: 0.12, blue: 0.12))
    ]

    private var currentOwnerKey: String {
        let trimmed = authUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? SharedConstants.guestOwnerKey : trimmed
    }

    var body: some View {
        ZStack {
            WarmBackdrop()
            ScrollView {
                VStack(spacing: 16) {
                    detailPhotoSection
                    detailSegmentedControl
                    if detailTab == 0 {
                        detailInfoSection
                    } else {
                        detailOutfitSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .adaptiveContentWidth(maxWidth: 760)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("我的服饰详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") { dismiss() }
                    .toolbarDoneButton()
            }
        }
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.white, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .fullScreenCover(isPresented: $showImageEditor) {
            ItemImageEditorView(
                imageData: $item.imageData,
                originalData: editorOriginalData
            )
        }
        .fullScreenCover(isPresented: $showPhotoPreview) {
            FullScreenImageView(imageData: item.imageData, imageURL: nil) {
                showPhotoPreview = false
            }
        }
        .alert("提示", isPresented: Binding(get: { alertMessage != nil }, set: { _ in alertMessage = nil })) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .onAppear {
            initialSnapshot = currentSnapshot()
        }
        .onDisappear {
            if currentSnapshot() != initialSnapshot {
                markItemDirtyAndSync()
            }
        }
        .onChange(of: item.imageData) { _, _ in
            markItemDirtyAndSync()
        }
    }

    private var detailPhotoSection: some View {
        WardrobeDetailPhoto(
            imageData: item.imageData,
            onEdit: {
                editorOriginalData = item.imageData
                showImageEditor = true
            },
            onFlatLay: {
                generateFlatLay()
            },
            onPreview: {
                if item.imageData != nil {
                    showPhotoPreview = true
                }
            },
            isFlattening: isFlattening,
            wearCount: UsageTracker.count(for: item.id)
        )
    }

    private var detailSegmentedControl: some View {
        VStack(spacing: 6) {
            HStack {
                detailTabButton(title: "信息", tag: 0)
                detailTabButton(title: "穿搭方案", tag: 1)
            }
            Rectangle()
                .fill(Color(red: 0.86, green: 0.84, blue: 0.82))
                .frame(height: 1)
        }
    }

    private var detailInfoSection: some View {
        DetailEditSection(title: "信息") {
            DetailListRow(title: "品类", showDivider: true) {
                DetailValueCapsule(text: item.category.isEmpty ? "未选择" : item.category)
            } onTap: {
                activePicker = DetailWheelPicker(
                    title: "选择品类",
                    options: categories,
                    selection: item.category.isEmpty ? (categories.first ?? "") : item.category,
                    useDarkStyle: false
                ) { selected in
                    item.category = selected
                    markItemDirtyAndSync()
                }
            }
            DetailListRow(title: "季节", showDivider: true) {
                DetailValueCapsule(text: item.seasons.first ?? "未选择")
            } onTap: {
                activePicker = DetailWheelPicker(
                    title: "选择季节",
                    options: seasons,
                    selection: item.seasons.first ?? (seasons.first ?? ""),
                    useDarkStyle: false
                ) { selected in
                    item.seasons = [selected]
                    markItemDirtyAndSync()
                }
            }
            DetailListRow(title: "适用场景", showDivider: true) {
                DetailValueCapsule(text: item.occasions.first ?? "未选择")
            } onTap: {
                activePicker = DetailWheelPicker(
                    title: "选择适用场景",
                    options: occasions,
                    selection: item.occasions.first ?? (occasions.first ?? ""),
                    useDarkStyle: false
                ) { selected in
                    item.occasions = [selected]
                    markItemDirtyAndSync()
                }
            }
            DetailListRow(title: "色系", showDivider: false) {
                DetailValueCapsule(text: item.color.isEmpty ? "未选择" : item.color)
            } onTap: {
                showColorSheet = true
            }
        }
        .sheet(item: $activePicker) { picker in
            DetailWheelPickerSheet(picker: picker)
        }
        .sheet(isPresented: $showColorSheet) {
            DetailColorSheet(
                title: "选择颜色",
                palette: colorOptions,
                selection: Binding(
                    get: { item.color.isEmpty ? (colorOptions.first?.name ?? "") : item.color },
                    set: {
                        item.color = $0
                        markItemDirtyAndSync()
                    }
                )
            )
        }
    }

    private var detailOutfitSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("穿搭方案")
                .font(.headline)
                .foregroundStyle(AppTheme.bodyText)
            if usedOutfits.isEmpty {
                Text("暂无使用该单品的穿搭记录。")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedText)
            } else {
                VStack(spacing: 12) {
                    ForEach(usedOutfits) { outfit in
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                                .frame(width: 72, height: 72)
                                .overlay(
                                    Group {
                                        if let data = outfit.imageData,
                                           let image = cachedThumbnail(id: outfit.id, data: data, maxPixel: 160) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFit()
                                                .padding(6)
                                        } else {
                                            Image(systemName: "sparkles")
                                                .font(.title3)
                                                .foregroundStyle(Color(red: 0.70, green: 0.66, blue: 0.60))
                                        }
                                    }
                                )
                            VStack(alignment: .leading, spacing: 6) {
                                Text(outfit.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.bodyText)
                                Text(outfit.itemNames.isEmpty ? "未填写物品" : outfit.itemNames)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.mutedText)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.9))
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.9))
        )
    }

    private func detailTabButton(title: String, tag: Int) -> some View {
        Button {
            detailTab = tag
        } label: {
            VStack(spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(detailTab == tag ? .semibold : .regular))
                    .foregroundStyle(detailTab == tag ? AppTheme.titleText : Color(red: 0.62, green: 0.58, blue: 0.52))
                Capsule()
                    .fill(detailTab == tag ? AppTheme.primary : Color.clear)
                    .frame(height: 2)
                    .frame(width: 62)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.appPlain)
    }

    private var usedOutfits: [OutfitRecord] {
        let isGuest = currentOwnerKey == SharedConstants.guestOwnerKey
        return outfitRecords
            .filter { ($0.ownerUsername == currentOwnerKey || (isGuest && $0.ownerUsername.isEmpty)) && $0.deletedAt == nil && $0.itemIDs.contains(item.id) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func generateFlatLay() {
        guard !isFlattening else { return }
        guard let data = item.imageData else {
            alertMessage = "请先添加衣物照片。"
            return
        }

        isFlattening = true
        Task {
            do {
                let service = AIVirtualTryOnService()
                let url = try await service.generateFlatLay(imageData: data, prompt: AIPrompts.flatLay)

                // 使用临时文件下载，避免一次性将大图加载到内存
                let (fileURL, _) = try await URLSession.shared.download(from: url)

                // 在后台线程进行图片压缩和降采样，避免内存溢出
                let compressedData = try await Task.detached(priority: .userInitiated) {
                    let data: Data? = autoreleasepool {
                        downsampledImageData(fileURL: fileURL, maxPixel: 2048, quality: 0.85)
                    }
                    guard let data else {
                        throw FlatLayProcessingError.imageProcessingFailed
                    }
                    return data
                }.value

                try? FileManager.default.removeItem(at: fileURL)

                await MainActor.run {
                    item.imageData = compressedData
                    markItemDirtyAndSync()
                    isFlattening = false
                }
            } catch {
                await MainActor.run {
                    if error is FlatLayProcessingError {
                        alertMessage = "整理美化失败：图片处理失败，请稍后再试。"
                    } else {
                        alertMessage = "整理美化失败：\(error.localizedDescription)"
                    }
                    isFlattening = false
                }
            }
        }
    }

    private func markItemDirtyAndSync() {
        WardrobeSyncService.shared.markItemPending(item)
        Task { @MainActor in
            await WardrobeSyncService.shared.syncNow(modelContext: modelContext)
        }
    }

    private func currentSnapshot() -> String {
        [
            item.name,
            item.category,
            item.subCategory,
            item.brand,
            item.color,
            item.material,
            item.pattern,
            item.fit,
            String(item.formality),
            item.seasons.joined(separator: "|"),
            item.occasions.joined(separator: "|"),
            item.styleTags.joined(separator: "|"),
            item.remoteImageURL,
            String(item.imageData?.count ?? 0)
        ].joined(separator: "§")
    }

}

private enum FlatLayProcessingError: Error {
    case imageProcessingFailed
}

private struct WardrobeDetailPhoto: View {
    let imageData: Data?
    let onEdit: () -> Void
    let onFlatLay: () -> Void
    let onPreview: () -> Void
    let isFlattening: Bool
    let wearCount: Int

    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white)
                    .frame(height: 260)
                    .overlay(
                        Group {
                            if let data = imageData, let image = UIImage(data: data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .padding(12)
                                    .onTapGesture {
                                        onPreview()
                                    }
                            } else {
                                VStack(spacing: 8) {
                                    Image(systemName: "photo")
                                        .font(.title2)
                                        .foregroundStyle(Color(red: 0.60, green: 0.58, blue: 0.54))
                                    Text("尚未添加照片")
                                        .font(.subheadline)
                                        .foregroundStyle(Color(red: 0.60, green: 0.58, blue: 0.54))
                                }
                            }
                        }
                    )
                    .overlay(
                        Group {
                            if isFlattening {
                                Color.white.opacity(0.7)
                                ProgressView("整理美化处理中")
                                    .progressViewStyle(.circular)
                                    .foregroundStyle(AppTheme.bodyText)
                            }
                        }
                    )

            }

            HStack(spacing: 12) {
                Button(action: onFlatLay) {
                    buttonLabel(systemName: "square.stack.3d.up", title: isFlattening ? "处理中..." : "整理美化")
                }
                .disabled(isFlattening || imageData == nil)
                Button(action: {}) {
                    buttonLabel(systemName: "repeat", title: "穿过 \(wearCount) 次")
                }
                .disabled(true)
                Button(action: onEdit) {
                    buttonLabel(systemName: "pencil", title: "编辑")
                }
                .disabled(imageData == nil)
                Spacer()
            }
        }
    }

    private func buttonLabel(systemName: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemName)
            Text(title)
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.white)
        )
        .overlay(
            Capsule()
                .stroke(Color(red: 0.18, green: 0.18, blue: 0.20), lineWidth: 1)
        )
        .foregroundStyle(Color(red: 0.18, green: 0.18, blue: 0.20))
    }
}

private struct ItemImageEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var imageData: Data?
    let originalData: Data?

    @State private var workingData: Data?
    @State private var alertMessage: String?
    @State private var brushWidth: CGFloat = 60
    @State private var activeTool: EditorTool = .erase
    @State private var controller = EraseCanvasController()
    @State private var initialData: Data?
    @State private var canUndo = false
    @State private var canRedo = false
    @State private var isSaving = false

    private enum EditorTool {
        case erase
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                VStack(spacing: 18) {
                    if let image = currentImage {
                        editorCanvas(image: image)
                    } else {
                        Text("没有可编辑的图片")
                            .foregroundStyle(AppTheme.mutedText)
                    }

                    VStack(spacing: 12) {
                        EditorSliderRow(title: "刷子", value: $brushWidth, range: 20...140)
                    }
                    .padding(.horizontal, 10)

                    HStack(spacing: 14) {
                        EditorToolTabButton(title: "旋转左", systemImage: "rotate.left", isActive: false) {
                            rotateWorkingImage(clockwise: false)
                        }
                        EditorToolTabButton(title: "旋转右", systemImage: "rotate.right", isActive: false) {
                            rotateWorkingImage(clockwise: true)
                        }
                        EditorToolTabButton(title: "擦除", systemImage: "scribble", isActive: activeTool == .erase) {
                            activeTool = .erase
                        }
                        EditorToolTabButton(title: "恢复", systemImage: "arrow.counterclockwise", isActive: false) {
                            workingData = initialData
                            controller.clear()
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                if isSaving {
                    SavingOverlay()
                }
            }
            .navigationTitle("服饰编辑页")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                    }
                    .foregroundStyle(Color.black)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: applyChanges) {
                        Image(systemName: "checkmark")
                    }
                    .foregroundStyle(Color.black)
                }
            }
        }
        .onAppear {
            let data = imageData ?? originalData
            workingData = data
            initialData = data
            controller.onStateChange = { undoAvailable, redoAvailable in
                canUndo = undoAvailable
                canRedo = redoAvailable
            }
            controller.notifyState()
        }
        .onDisappear {
            controller.clear()
            controller.onStateChange = nil
        }
        .alert("提示", isPresented: Binding(get: { alertMessage != nil }, set: { _ in alertMessage = nil })) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var currentImage: UIImage? {
        guard let data = workingData else { return nil }
        return UIImage(data: data)
    }

    private func editorCanvas(image: UIImage) -> some View {
        ZStack {
            CheckerboardTile()
                .clipShape(RoundedRectangle(cornerRadius: 20))
            EraseCanvasView(
                image: image,
                brushWidth: brushWidth,
                isErasing: activeTool == .erase,
                controller: controller
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .padding(12)
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        }
        .frame(maxWidth: .infinity, minHeight: 420, maxHeight: 420)
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 10) {
                EditorIconButton(systemImage: "arrow.uturn.left") {
                    controller.undo()
                }
                .disabled(!canUndo)
                EditorIconButton(systemImage: "arrow.uturn.right") {
                    controller.redo()
                }
                .disabled(!canRedo)
            }
            .padding(14)
        }
    }

    private func applyChanges() {
        guard !isSaving else { return }
        isSaving = true
        Task { @MainActor in
            await Task.yield()
            commitEraseIfNeeded()
            imageData = workingData
            isSaving = false
            dismiss()
        }
    }

    private func rotateWorkingImage(clockwise: Bool) {
        commitEraseIfNeeded()
        guard let data = workingData else {
            alertMessage = "请先选择一张衣物照片。"
            return
        }
        Task {
            let rotated: Data? = autoreleasepool {
                guard let image = downsampleImage(data: data, maxPixel: 1600) else { return nil }
                let output = image.rotated(by: clockwise ? 90 : -90)
                return output.pngData()
            }
            if let rotated {
                workingData = rotated
            } else {
                alertMessage = "旋转失败，请稍后再试。"
            }
        }
    }

    private func commitEraseIfNeeded() {
        guard controller.hasEdits,
              let result = controller.renderErasedImage(),
              let output = result.pngData() else { return }
        workingData = output
        controller.clear()
    }
}

private struct CheckerboardBackground: View {
    private let square: CGFloat = 18

    var body: some View {
        GeometryReader { proxy in
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
        .ignoresSafeArea()
    }
}

private func downsampleImage(data: Data, maxPixel: Int) -> UIImage? {
    let options: [CFString: Any] = [
        kCGImageSourceShouldCache: false
    ]
    guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
        return nil
    }
    let thumbOptions: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        kCGImageSourceShouldCacheImmediately: false
    ]
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else {
        return nil
    }
    return UIImage(cgImage: cgImage)
}

nonisolated private func downsampledImageData(fileURL: URL, maxPixel: Int, quality: Double = 0.85) -> Data? {
    let options: [CFString: Any] = [
        kCGImageSourceShouldCache: false
    ]
    guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, options as CFDictionary) else {
        return nil
    }
    let thumbOptions: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        kCGImageSourceShouldCacheImmediately: false
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

private struct CheckerboardTile: View {
    private let square: CGFloat = 18

    var body: some View {
        GeometryReader { proxy in
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

private struct EditorToolTabButton: View {
    let title: String
    let systemImage: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(title)
                    .font(.caption)
            }
            .foregroundStyle(isActive ? Color(red: 0.20, green: 0.14, blue: 0.12) : Color(red: 0.55, green: 0.52, blue: 0.48))
            .frame(maxWidth: .infinity)
        }
    }
}

private struct EditorIconButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.85))
                )
                .foregroundStyle(Color.white)
        }
        .buttonStyle(.appPlain)
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

private struct SavingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                HangerAnimationView()
                Text("保存中…")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.black.opacity(0.7))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
            )
        }
    }
}

private struct HangerAnimationView: View {
    @State private var swing = false

    var body: some View {
        HangerShape()
            .stroke(Color.black.opacity(0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .frame(width: 46, height: 36)
            .rotationEffect(.degrees(swing ? 10 : -10), anchor: .top)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: swing)
            .onAppear { swing = true }
    }
}

private struct HangerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let hookRadius = rect.width * 0.18
        let hookCenter = CGPoint(x: rect.midX, y: rect.minY + hookRadius)

        path.addArc(
            center: hookCenter,
            radius: hookRadius,
            startAngle: .degrees(200),
            endAngle: .degrees(-20),
            clockwise: false
        )

        let topPoint = CGPoint(x: rect.midX, y: rect.minY + hookRadius * 2.2)
        let leftPoint = CGPoint(x: rect.minX + rect.width * 0.08, y: rect.maxY - rect.height * 0.08)
        let rightPoint = CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.maxY - rect.height * 0.08)

        path.move(to: topPoint)
        path.addLine(to: leftPoint)
        path.addLine(to: rightPoint)
        path.addLine(to: topPoint)
        return path
    }
}

private struct DetailEditSection<Content: View>: View {
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

private struct DetailListRow<Content: View>: View {
    let title: String
    let showDivider: Bool
    let content: Content
    let onTap: (() -> Void)?

    init(title: String, showDivider: Bool, @ViewBuilder content: () -> Content, onTap: (() -> Void)? = nil) {
        self.title = title
        self.showDivider = showDivider
        self.content = content()
        self.onTap = onTap
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

private struct DetailValueCapsule: View {
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

private struct DetailInfoRow<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.actionText)
                Spacer()
            }
            content
        }
        .padding(.vertical, 4)
    }
}

private struct DetailChipGroup: View {
    let title: String
    let options: [String]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.actionText)
            DetailWrapStack(items: options) { option in
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

private struct DetailMultiChipGroup: View {
    let title: String
    let options: [String]
    @Binding var selection: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.actionText)
            DetailWrapStack(items: options) { option in
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

private struct DetailColorPalettePicker: View {
    let title: String
    @Binding var selection: String
    var useInlineStyle: Bool = false
    @State private var showSheet = false

    private let palette: [ColorPaletteOption] = [
        ColorPaletteOption(name: "白色系", color: Color(red: 0.96, green: 0.96, blue: 0.96)),
        ColorPaletteOption(name: "杏色系", color: Color(red: 0.86, green: 0.78, blue: 0.66)),
        ColorPaletteOption(name: "黄色系", color: Color(red: 0.98, green: 0.83, blue: 0.32)),
        ColorPaletteOption(name: "橙色系", color: Color(red: 0.98, green: 0.57, blue: 0.22)),
        ColorPaletteOption(name: "红色系", color: Color(red: 0.92, green: 0.28, blue: 0.26)),
        ColorPaletteOption(name: "粉色系", color: Color(red: 0.96, green: 0.70, blue: 0.74)),
        ColorPaletteOption(name: "紫色系", color: Color(red: 0.55, green: 0.39, blue: 0.85)),
        ColorPaletteOption(name: "蓝色系", color: Color(red: 0.28, green: 0.50, blue: 0.91)),
        ColorPaletteOption(name: "绿色系", color: Color(red: 0.40, green: 0.72, blue: 0.26)),
        ColorPaletteOption(name: "棕色系", color: Color(red: 0.46, green: 0.30, blue: 0.16)),
        ColorPaletteOption(name: "咖色系", color: Color(red: 0.60, green: 0.46, blue: 0.36)),
        ColorPaletteOption(name: "灰色系", color: Color(red: 0.58, green: 0.58, blue: 0.58)),
        ColorPaletteOption(name: "黑色系", color: Color(red: 0.12, green: 0.12, blue: 0.12))
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !useInlineStyle {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.actionText)
            }
            Button {
                showSheet = true
            } label: {
                HStack(spacing: 10) {
                    if let option = palette.first(where: { $0.name == selection }) {
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
        }
        .sheet(isPresented: $showSheet) {
            ColorPaletteSheet(
                title: "选择颜色",
                palette: palette,
                selection: $selection
            )
        }
    }
}

private struct ColorPaletteOption: Hashable {
    let name: String
    let color: Color
}

private struct ColorPaletteSheet: View {
    let title: String
    let palette: [ColorPaletteOption]
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
                ForEach(palette, id: \.self) { option in
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
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.white)
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

private struct DetailWrapStack<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content
    let limit: Int

    init(items: [Item], limit: Int = 4, @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
        self.limit = limit
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

    private func wrapRows(for items: [Item]) -> [[Item]] {
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

private struct DetailWheelPicker: Identifiable {
    let id = UUID()
    let title: String
    let options: [String]
    let selection: String
    let useDarkStyle: Bool
    let onSelect: (String) -> Void
}

private struct DetailWheelPickerSheet: View {
    let picker: DetailWheelPicker
    @Environment(\.dismiss) private var dismiss
    @State private var selection: String

    init(picker: DetailWheelPicker) {
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
                .foregroundStyle(picker.useDarkStyle ? Color.white : Color.primary)
            Picker(picker.title, selection: $selection) {
                ForEach(picker.options, id: \.self) { option in
                    Text(option)
                        .foregroundStyle(picker.useDarkStyle ? Color.white : Color.primary)
                        .tag(option)
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
        .background(picker.useDarkStyle ? Color.black : Color.clear)
        .preferredColorScheme(picker.useDarkStyle ? .dark : nil)
    }
}

private struct DetailColorOption: Hashable {
    let name: String
    let color: Color
}

private struct DetailColorSheet: View {
    let title: String
    let palette: [DetailColorOption]
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

private extension UIImage {
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
}
