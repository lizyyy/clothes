// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  OutfitsTabView.swift
//  Clothes
//
//  Created by Codex on 2026/1/6.
//

import Photos
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct OutfitsTabView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("auth_token") private var authToken = ""
    @AppStorage("auth_username") private var authUsername = ""
    @AppStorage("profile_name") private var profileName = "周可"
    @AppStorage("profile_location") private var profileLocation = "上海"
    @AppStorage("preference_occasions") private var preferenceOccasions = "工作 / 休闲"
    @AppStorage("preference_colors") private var preferenceColors = "奶油 / 驼 / 黑白"
    @AppStorage("body_height") private var bodyHeight = "165"
    @AppStorage("body_size") private var bodySize = "S / M"
    @Query private var clothingItems: [ClothingItem]
    @Query private var outfitRecords: [OutfitRecord]
    @Query private var calendarEntries: [OutfitCalendarEntry]

    var body: some View {
        NavigationStack {
            OutfitsHomeView(
                outfits: activeOutfits,
                trashedOutfits: trashedOutfits,
                wardrobeItems: activeClothingItems,
                calendarEntries: activeCalendarEntries,
                profileName: profileName,
                profileLocation: profileLocation,
                preferenceOccasions: preferenceOccasions,
                preferenceColors: preferenceColors,
                bodyHeight: bodyHeight,
                bodySize: bodySize
            )
        }
        // Ensure switching accounts pulls the correct user's wardrobe/outfits.
        .task(id: authToken) {
            guard !authToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            await WardrobeSyncService.shared.syncNow(modelContext: modelContext)
        }
    }

    private var currentOwnerKey: String {
        let trimmed = authUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? SharedConstants.guestOwnerKey : trimmed
    }

    private var activeClothingItems: [ClothingItem] {
        let isGuest = currentOwnerKey == SharedConstants.guestOwnerKey
        return clothingItems.filter {
            $0.deletedAt == nil && ($0.ownerUsername == currentOwnerKey || (isGuest && $0.ownerUsername.isEmpty))
        }
    }

    private var activeOutfits: [OutfitRecord] {
        let isGuest = currentOwnerKey == SharedConstants.guestOwnerKey
        return outfitRecords.filter {
            $0.deletedAt == nil && ($0.ownerUsername == currentOwnerKey || (isGuest && $0.ownerUsername.isEmpty))
        }
    }

    private var trashedOutfits: [OutfitRecord] {
        let isGuest = currentOwnerKey == SharedConstants.guestOwnerKey
        return outfitRecords.filter {
            $0.deletedAt != nil && ($0.ownerUsername == currentOwnerKey || (isGuest && $0.ownerUsername.isEmpty))
        }
    }

    private var activeCalendarEntries: [OutfitCalendarEntry] {
        let isGuest = currentOwnerKey == SharedConstants.guestOwnerKey
        return calendarEntries.filter {
            $0.ownerUsername == currentOwnerKey || (isGuest && $0.ownerUsername.isEmpty)
        }
    }
}

private struct OutfitsHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let outfits: [OutfitRecord]
    let trashedOutfits: [OutfitRecord]
    let wardrobeItems: [ClothingItem]
    let calendarEntries: [OutfitCalendarEntry]
    let profileName: String
    let profileLocation: String
    let preferenceOccasions: String
    let preferenceColors: String
    let bodyHeight: String
    let bodySize: String
    @State private var showCalendar = false
    @State private var showRecycleBin = false
    @State private var outfitFilter = OutfitFilter.all
    @State private var showAIOutfitDetail: OutfitRecord?

    var body: some View {
        ZStack {
            WarmBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerView
                    outfitHeaderView
                    outfitsGrid
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .adaptiveContentWidth(maxWidth: 760)
            }
            .refreshable {
                // 延迟执行图片缓存预热
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    preheatOutfitCache(items: outfits.map { ImageCacheItem(id: $0.id, data: $0.imageData) })
                }
            }
        }
        .sheet(isPresented: $showCalendar) {
            OutfitCalendarView(entries: calendarEntries, outfits: outfits)
        }
        .sheet(isPresented: $showRecycleBin) {
            OutfitRecycleBinView(items: trashedOutfits) { item in
                item.deletedAt = nil
            } onDelete: { item in
                modelContext.delete(item)
            }
        }
        .fullScreenCover(item: $showAIOutfitDetail) { record in
            TryOnTabView(initialRecord: record)
        }
        .onAppear {
            Task {
                // 延迟执行图片缓存预热
                try? await Task.sleep(nanoseconds: 1_100_000_000) // 1.1s
                let snapshot = outfits.map { ImageCacheItem(id: $0.id, data: $0.imageData) }
                preheatOutfitCache(items: snapshot)
            }
        }
        .onChange(of: outfits.count) { _, _ in
            preheatOutfitCache(items: outfits.map { ImageCacheItem(id: $0.id, data: $0.imageData) })
        }
    }

    private func items(for outfit: OutfitRecord) -> [ClothingItem] {
        guard !outfit.itemIDs.isEmpty else { return [] }
        return wardrobeItems.filter { outfit.itemIDs.contains($0.id) }
    }

    private var headerView: some View {
        HStack {
            Text("搭配")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(AppTheme.titleText)
            Spacer()
            Button {
                showCalendar = true
            } label: {
                Image(systemName: "calendar")
                    .font(.title2)
                    .foregroundStyle(AppTheme.bodyText)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.9))
                    )
            }
            .buttonStyle(.appPlain)
            Button {
                showRecycleBin = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                        .font(.caption)
                    Text("回收站")
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var outfitHeaderView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("穿搭记录")
                    .font(.headline)
                    .foregroundStyle(AppTheme.bodyText)
                Spacer()
                NavigationLink {
                    OutfitTryOnView(wardrobeItems: wardrobeItems)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("添加穿搭")
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(AppTheme.primary)
                    )
                    .foregroundStyle(Color.white)
                }
            }
            HStack(spacing: 10) {
                OutfitFilterPill(title: "全部", isSelected: outfitFilter == .all) {
                    outfitFilter = .all
                }
                OutfitFilterPill(title: "我的搭配", isSelected: outfitFilter == .manual) {
                    outfitFilter = .manual
                }
                OutfitFilterPill(title: "AI搭配", isSelected: outfitFilter == .ai) {
                    outfitFilter = .ai
                }
            }
        }
    }

    private var outfitsGrid: some View {
        Group {
            if sortedVisibleOutfits.isEmpty {
                EmptyOutfitsView()
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(sortedVisibleOutfits) { outfit in
                        outfitEntry(for: outfit)
                            .contextMenu {
                                Button(role: .destructive) {
                                    moveToTrash(outfit)
                                } label: {
                                    Text("删除")
                                }
                            }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func outfitEntry(for outfit: OutfitRecord) -> some View {
        if isAITryOnRecord(outfit) {
            Button {
                showAIOutfitDetail = outfit
            } label: {
                OutfitEntryCard(outfit: outfit, items: items(for: outfit))
            }
            .buttonStyle(.appPlain)
        } else {
            NavigationLink {
                OutfitTryOnView(wardrobeItems: wardrobeItems, record: outfit)
            } label: {
                OutfitEntryCard(outfit: outfit, items: items(for: outfit))
            }
            .buttonStyle(.appPlain)
        }
    }

    private var sortedVisibleOutfits: [OutfitRecord] {
        filteredOutfits.sorted(by: { $0.createdAt > $1.createdAt })
    }

    private func moveToTrash(_ outfit: OutfitRecord) {
        outfit.deletedAt = Date()
    }

    private var columns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 3 : 2
        return Array(repeating: GridItem(.flexible()), count: count)
    }

    private var filteredOutfits: [OutfitRecord] {
        switch outfitFilter {
        case .all:
            return outfits
        case .manual:
            return outfits.filter { !isAITryOnRecord($0) }
        case .ai:
            return outfits.filter { isAITryOnRecord($0) }
        }
    }

    private func isAITryOnRecord(_ outfit: OutfitRecord) -> Bool {
        outfit.title.hasPrefix("AI推荐") || outfit.aiTryOnImageData != nil
    }

    private enum OutfitFilter: String {
        case all
        case manual
        case ai
    }
}

private struct OutfitEntryCard: View {
    let outfit: OutfitRecord
    let items: [ClothingItem]

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d"
        return formatter.string(from: outfit.createdAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                if let data = outfit.imageData, let image = cachedThumbnail(id: outfit.id, data: data, maxPixel: 420) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                } else if let tryOnData = outfit.aiTryOnImageData,
                          let image = cachedThumbnail(id: outfit.id, data: tryOnData, maxPixel: 420) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                } else if let personData = outfit.personImageData,
                          let image = cachedThumbnail(id: outfit.id, data: personData, maxPixel: 420) {
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding(8)
                        Text("尚未生成试穿效果图")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.45))
                            )
                    }
                } else {
                    if !items.isEmpty {
                        OutfitItemsCollage(items: items)
                            .padding(10)
                        VStack {
                            Spacer()
                            Text("尚未生成试穿效果图")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.45))
                                )
                                .padding(.bottom, 10)
                        }
                    } else {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(red: 0.92, green: 0.92, blue: 0.94))
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(red: 0.94, green: 0.94, blue: 0.96))
                        }
                        .padding(12)
                    }
                }
            }
            .frame(height: 190)
            .frame(maxWidth: .infinity)
            .clipped()
            .cornerRadius(16)

            Text(outfit.title)
                .font(.headline)
                .foregroundStyle(AppTheme.bodyText)

            if !items.isEmpty {
                HStack(spacing: 6) {
                    ForEach(items.prefix(3)) { item in
                        if let data = item.imageData, let image = cachedThumbnail(id: item.id, data: data, maxPixel: 80) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 32, height: 32)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    if items.count > 3 {
                        Text("+\(items.count - 3)")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.mutedText)
                    }
                }
            } else {
                Text(outfit.itemNames.isEmpty ? "已生成预览" : outfit.itemNames)
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedText)
            }

            HStack {
                Text(dateText)
                    .font(.caption2)
                    .foregroundStyle(Color(red: 0.66, green: 0.60, blue: 0.54))
                Spacer()
                Text(outfit.isShared ? "已分享" : "私密")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(outfit.isShared ? Color(red: 0.86, green: 0.90, blue: 0.86) : Color(red: 0.94, green: 0.92, blue: 0.90))
                    )
                    .foregroundStyle(Color(red: 0.36, green: 0.32, blue: 0.28))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.9))
        )
    }
}

private struct OutfitItemsCollage: View {
    let items: [ClothingItem]

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(items.prefix(4).enumerated()), id: \.element.id) { _, item in
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.95, green: 0.95, blue: 0.97))
                    if let image = cachedThumbnail(id: item.id, data: item.imageData, maxPixel: 260) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Image(systemName: "tshirt")
                            .font(.title3)
                            .foregroundStyle(Color(red: 0.70, green: 0.68, blue: 0.64))
                    }
                }
                .frame(height: 82)
            }
        }
    }
}

private struct TodayRecommendationCard: View {
    let recommendation: AIDailyRecommendation?
    let items: [ClothingItem]
    let isLoading: Bool
    let errorMessage: String?
    let onGenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(recommendation?.title.isEmpty == false ? (recommendation?.title ?? "") : "今日为你推荐")
                    .font(.headline)
                    .foregroundStyle(AppTheme.bodyText)
                Spacer()
                if recommendation == nil {
                    Button {
                        onGenerate()
                    } label: {
                        Text(isLoading ? "生成中..." : "生成推荐")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(AppTheme.primary)
                            )
                    }
                    .disabled(isLoading)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.70, green: 0.40, blue: 0.38))
            }

            if isLoading {
                ProgressView("AI 正在生成推荐...")
                    .tint(Color(red: 0.45, green: 0.38, blue: 0.32))
            } else if let recommendation {
                if !items.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(items) { item in
                                WardrobeMiniTile(item: item)
                            }
                        }
                    }
                }

                if !recommendation.reasons.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("推荐理由")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.actionText)
                        ForEach(recommendation.reasons, id: \.self) { reason in
                            Text("• \(reason)")
                                .font(.caption)
                                .foregroundStyle(AppTheme.mutedText)
                        }
                    }
                }
            } else {
                Text("结合天气、日历与个人偏好，生成适合今天的一套穿搭。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedText)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.9))
        )
    }
}

private struct WardrobeMiniTile: View {
    let item: ClothingItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .frame(width: 88, height: 96)
                .overlay(
                    Group {
                        if let data = item.imageData, let image = cachedThumbnail(id: item.id, data: data, maxPixel: 160) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .padding(6)
                        } else {
                            Image(systemName: "tshirt")
                                .font(.title3)
                                .foregroundStyle(Color(red: 0.70, green: 0.66, blue: 0.60))
                        }
                    }
                )
            Text(item.name.isEmpty ? "未命名" : item.name)
                .font(.caption2)
                .foregroundStyle(AppTheme.mutedText)
        }
    }
}

private struct EmptyOutfitsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("还没有保存的穿搭")
                .font(.headline)
                .foregroundStyle(AppTheme.bodyText)
            Text("点击右上角“添加穿搭”开始生成试穿效果。")
                .font(.caption)
                .foregroundStyle(AppTheme.mutedText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.9))
        )
    }
}

private struct OutfitCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    let entries: [OutfitCalendarEntry]
    let outfits: [OutfitRecord]
    @State private var currentMonth = Date()
    @State private var selectedDate = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackdrop()
                VStack(spacing: 16) {
                    monthHeader
                    weekdayHeader
                    calendarGrid
                    entryList
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("穿搭日历")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .toolbarDoneButton()
                }
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
            } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(monthTitle(currentMonth))
                .font(.headline)
                .foregroundStyle(AppTheme.bodyText)
            Spacer()
            Button {
                currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .foregroundStyle(Color(red: 0.40, green: 0.36, blue: 0.32))
    }

    private var weekdayHeader: some View {
        let symbols = Calendar.current.shortWeekdaySymbols
        return HStack {
            ForEach(symbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtleText)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarGrid: some View {
        let days = calendarDays(for: currentMonth)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
            ForEach(days, id: \.self) { date in
                Button {
                    selectedDate = date
                } label: {
                    VStack(spacing: 4) {
                        Text(dayNumber(date))
                            .font(.subheadline.weight(isSameDay(date, selectedDate) ? .semibold : .regular))
                            .foregroundStyle(isSameMonth(date, currentMonth) ? AppTheme.bodyText : Color(red: 0.75, green: 0.70, blue: 0.64))
                        Circle()
                            .fill(hasEntry(on: date) ? Color(red: 0.58, green: 0.47, blue: 0.37) : Color.clear)
                            .frame(width: 6, height: 6)
                    }
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isSameDay(date, selectedDate) ? Color.white.opacity(0.9) : Color.clear)
                    )
                }
                .buttonStyle(.appPlain)
            }
        }
    }

    private var entryList: some View {
        let items = entriesForSelectedDate()
        return VStack(alignment: .leading, spacing: 8) {
            Text("当天穿搭")
                .font(.headline)
                .foregroundStyle(AppTheme.bodyText)
            if items.isEmpty {
                Text("暂无记录")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtleText)
            } else {
                ForEach(items) { entry in
                    if let outfit = outfitForEntry(entry) {
                        OutfitCalendarRow(outfit: outfit, fallbackTitle: entry.title)
                    } else {
                        Text(entry.title)
                            .font(.subheadline)
                            .foregroundStyle(Color(red: 0.30, green: 0.26, blue: 0.22))
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.9))
        )
    }

    private func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年 M月"
        return formatter.string(from: date)
    }

    private func dayNumber(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private func calendarDays(for month: Date) -> [Date] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return [] }
        let startWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingDays = (startWeekday + 5) % 7
        var days: [Date] = []
        for offset in -leadingDays..<42 {
            if let date = calendar.date(byAdding: .day, value: offset, to: monthInterval.start) {
                days.append(date)
            }
        }
        return days
    }

    private func isSameMonth(_ lhs: Date, _ rhs: Date) -> Bool {
        Calendar.current.isDate(lhs, equalTo: rhs, toGranularity: .month)
    }

    private func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        Calendar.current.isDate(lhs, inSameDayAs: rhs)
    }

    private func hasEntry(on date: Date) -> Bool {
        entries.contains { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    private func entriesForSelectedDate() -> [OutfitCalendarEntry] {
        entries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private func outfitForEntry(_ entry: OutfitCalendarEntry) -> OutfitRecord? {
        guard let id = entry.outfitID else { return nil }
        return outfits.first { $0.id == id }
    }
}

private struct OutfitCalendarRow: View {
    let outfit: OutfitRecord
    let fallbackTitle: String

    private var title: String {
        outfit.title.isEmpty ? fallbackTitle : outfit.title
    }

    var body: some View {
        HStack(spacing: 12) {
            if let data = outfit.imageData, let image = cachedThumbnail(id: outfit.id, data: data, maxPixel: 160) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.93, green: 0.92, blue: 0.94))
                    .frame(width: 52, height: 52)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(red: 0.30, green: 0.26, blue: 0.22))
                Text(outfit.itemNames.isEmpty ? "已生成预览" : outfit.itemNames)
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedText)
            }
        }
    }
}

struct OutfitTryOnView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("auth_token") private var authToken = ""
    @AppStorage("auth_username") private var authUsername = ""

    let wardrobeItems: [ClothingItem]
    var record: OutfitRecord? = nil

    @State private var selectedItemIDs: Set<UUID> = []
    @State private var showWardrobePicker = false
    @State private var personPhotoItem: PhotosPickerItem?
    @State private var personPhotoData: Data?
    @State private var isGenerating = false
    @State private var resultURL: URL?
    @State private var resultImageData: Data?
    @State private var showPreview = false
    @State private var showPersonPreview = false
    @State private var errorMessage: String?
    @State private var hasLoadedRecord = false
    @State private var showAIPlanner = false
    @State private var calendarMessage: String?
    @State private var lastGeneratedRecordID: UUID?
    @State private var savedRecordID: UUID?
    @State private var outfitTitle = ""
    @State private var saveMessage: String?
    @State private var saveHandler: ImageSaveHandler?
    @State private var countdownRemaining = 40
    @State private var countdownProgress: Double = 0
    @State private var countdownTimer: Timer?
    @State private var showDeleteConfirm = false
    @State private var hasSaved = false
    @State private var isUpdatingVisibility = false
    @AppStorage("outfit_name_counter") private var outfitNameCounter = 0

    init(wardrobeItems: [ClothingItem], record: OutfitRecord? = nil) {
        self.wardrobeItems = wardrobeItems
        self.record = record
    }

    private var currentOwnerKey: String {
        let trimmed = authUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? SharedConstants.guestOwnerKey : trimmed
    }

    var body: some View {
        ZStack {
            WarmBackdrop()
            mainContent
        }
        .navigationTitle("搭配")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") {
                    if saveOutfitIfNeeded() {
                        dismiss()
                    }
                }
                    .foregroundStyle(AppTheme.actionText)
            }
        }
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.white, for: .navigationBar)
        .sheet(isPresented: $showWardrobePicker) {
            WardrobePickerSheet(items: wardrobeItems, selectedItemIDs: $selectedItemIDs)
        }
        .sheet(isPresented: $showAIPlanner) {
            AIStylePlannerSheet(
                wardrobeItems: wardrobeItems
            )
        }
        .fullScreenCover(isPresented: $showPreview) {
            FullScreenImageView(imageData: resultImageData, imageURL: resultURL) {
                showPreview = false
            }
        }
        .fullScreenCover(isPresented: $showPersonPreview) {
            FullScreenImageView(imageData: personPhotoData, imageURL: nil) {
                showPersonPreview = false
            }
        }
        .onAppear {
            guard !hasLoadedRecord, let record else { return }
            selectedItemIDs = Set(record.itemIDs)
            personPhotoData = record.personImageData
            resultImageData = record.imageData
            outfitTitle = record.title == "AI试穿预览" ? "" : record.title
            hasLoadedRecord = true
        }
        .onChange(of: personPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    personPhotoData = data
                }
            }
        }
        .alert("生成失败", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "请稍后重试")
        }
        .alert("日历", isPresented: Binding(get: { calendarMessage != nil }, set: { _ in calendarMessage = nil })) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(calendarMessage ?? "")
        }
        .alert("相册", isPresented: Binding(get: { saveMessage != nil }, set: { _ in saveMessage = nil })) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(saveMessage ?? "")
        }
        .alert("删除穿搭", isPresented: $showDeleteConfirm) {
            Button("删除", role: .destructive) { deleteRecord() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后无法恢复。")
        }
        .onDisappear {
            stopCountdown()
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 16) {
                    Text("最终效果预览（点击可放大）")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(red: 0.36, green: 0.30, blue: 0.26))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    OutfitHeroCard(
                        imageData: resultImageData,
                        imageURL: resultURL,
                        isGenerating: isGenerating,
                        countdownRemaining: countdownRemaining,
                        countdownProgress: countdownProgress
                    )
                    .onTapGesture {
                        if resultImageData != nil || resultURL != nil {
                            showPreview = true
                        }
                    }

                    Text("选择用于虚拟试穿的物品")
                        .font(.headline)
                        .foregroundStyle(AppTheme.bodyText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("", text: $outfitTitle, prompt: Text("搭配名称（可选）").foregroundStyle(AppTheme.placeholder))
                        .appInputStyle()

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            OutfitAddCard()
                                .onTapGesture {
                                    showWardrobePicker = true
                                }
                            ForEach(selectedItems) { item in
                                OutfitItemTile(
                                    id: item.id,
                                    name: item.name,
                                    tag: item.category,
                                    imageData: item.imageData,
                                    onRemove: { selectedItemIDs.remove(item.id) }
                                )
                            }
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.92))
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("上传本人照片")
                        .font(.headline)
                        .foregroundStyle(AppTheme.bodyText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    PhotosPicker(selection: $personPhotoItem, matching: .images, photoLibrary: .shared()) {
                        OutfitPhotoCard(imageData: personPhotoData) {
                            showPersonPreview = true
                        }
                    }
                }
                .padding(.top, 6)
                .zIndex(1)
                .padding(.bottom, 6)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text("虚拟试穿价格")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.mutedText)
                        Text("10穿贝/次")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.bodyText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color(red: 0.95, green: 0.90, blue: 0.84))
                            )
                    }

                    Button {
                        Task {
                            await generatePreview()
                        }
                    } label: {
                        Text(isGenerating ? "生成中..." : "虚拟试穿")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(AppTheme.primary)
                            )
                    }
                    .disabled(isGenerating)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.92))
                )
                .padding(.top, 8)

                if let editable = editableRecord() {
                    detailActionButton(
                        title: editable.isShared ? "设为私密" : "公开我的穿搭",
                        icon: editable.isShared ? "eye.slash" : "globe.asia.australia",
                        style: editable.isShared ? .normal : .primary,
                        isLoading: isUpdatingVisibility
                    ) {
                        Task { await togglePublicStatus(for: editable) }
                    }
                }

                if resultImageData != nil {
                    HStack(spacing: 12) {
                        detailQuickActionButton(
                            title: "相册",
                            icon: "square.and.arrow.down",
                            accessibilityLabel: "保存到相册"
                        ) {
                            saveToPhotos()
                        }
                        detailQuickActionButton(
                            title: "日历",
                            icon: "calendar.badge.plus",
                            accessibilityLabel: "加入日历"
                        ) {
                            addToCalendar()
                        }
                    }
                }

                if record != nil {
                    HStack {
                        Spacer()
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("删除穿搭", systemImage: "trash")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color(red: 0.62, green: 0.22, blue: 0.22))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.95))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color(red: 0.82, green: 0.46, blue: 0.46), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.appPlain)
                    }
                }

            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .adaptiveContentWidth(maxWidth: 760)
        }
    }

    private var selectedItems: [ClothingItem] {
        wardrobeItems.filter { selectedItemIDs.contains($0.id) }
    }

    private func generatePreview() async {
        guard !authToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "请先登录后再生成穿搭。"
            return
        }
        guard let personPhotoData else {
            errorMessage = "请先上传本人照片。"
            return
        }
        if selectedItems.count > 10 {
            errorMessage = "当前最多支持 10 件衣物进行试穿。"
            return
        }
        let clothingImages = selectedItems.compactMap { $0.imageData }
        guard !clothingImages.isEmpty else {
            errorMessage = "请选择至少一件衣物。"
            return
        }

        isGenerating = true
        startCountdown()
        defer {
            isGenerating = false
            stopCountdown()
        }

        do {
            let service = AIVirtualTryOnService()
            let prompt = buildPrompt(items: selectedItems)
            let imageInputs = [personPhotoData] + clothingImages
            let generatedURL = try await service.generateTryOn(prompt: prompt, images: imageInputs)
            let (data, _) = try await URLSession.shared.data(from: generatedURL)
            await MainActor.run {
                resultImageData = data
                resultURL = generatedURL
            }
            let names = selectedItems.map { $0.name }.joined(separator: "、")
            let ids = selectedItems.map { $0.id }
            if let editable = editableRecord() {
                editable.title = resolvedOutfitTitle()
                editable.itemNames = names
                editable.itemIDs = ids
                editable.imageData = data
                editable.personImageData = personPhotoData
                markOutfitDirtyAndSync(editable)
            } else {
                let record = OutfitRecord(
                    ownerUsername: currentOwnerKey,
                    title: resolvedOutfitTitle(),
                    itemNames: names,
                    itemIDs: ids,
                    imageData: data,
                    personImageData: personPhotoData
                )
                modelContext.insert(record)
                lastGeneratedRecordID = record.id
                savedRecordID = record.id
                markOutfitDirtyAndSync(record)
            }
            UsageTracker.increment(ids: ids)
        } catch {
            errorMessage = TryOnErrorReporting.handleOutfitPreviewFailure(error: error, selectedItemCount: selectedItems.count, clothingImageCount: clothingImages.count, promptLength: buildPrompt(items: selectedItems).count, hasPersonPhoto: personPhotoData != nil)
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

    private func saveToPhotos() {
        guard let data = resultImageData, let image = UIImage(data: data) else {
            errorMessage = "图片还未生成完成。"
            return
        }
        saveToAlbum(image: image, albumName: "穿起来") { success in
            saveMessage = success ? "已保存到相册「穿起来」。" : "保存失败，请稍后重试。"
        }
    }

    private func saveToAlbum(image: UIImage, albumName: String, completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status == .authorized || status == .limited {
            save(image: image, toAlbum: albumName, completion: completion)
        } else if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    save(image: image, toAlbum: albumName, completion: completion)
                } else {
                    DispatchQueue.main.async { completion(false) }
                }
            }
        } else {
            completion(false)
        }
    }

    private func save(image: UIImage, toAlbum albumName: String, completion: @escaping (Bool) -> Void) {
        var placeholder: PHObjectPlaceholder?
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
            placeholder = request.placeholderForCreatedAsset
        }) { success, _ in
            guard success, let assetPlaceholder = placeholder else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            let collection = fetchOrCreateAlbum(named: albumName)
            guard let album = collection else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            PHPhotoLibrary.shared().performChanges({
                if let changeRequest = PHAssetCollectionChangeRequest(for: album) {
                    changeRequest.addAssets([assetPlaceholder] as NSArray)
                }
            }) { added, _ in
                DispatchQueue.main.async { completion(added) }
            }
        }
    }

    private func fetchOrCreateAlbum(named name: String) -> PHAssetCollection? {
        let fetch = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        var collection: PHAssetCollection?
        fetch.enumerateObjects { item, _, stop in
            if item.localizedTitle == name {
                collection = item
                stop.pointee = true
            }
        }
        if let collection {
            return collection
        }
        var placeholder: PHObjectPlaceholder?
        try? PHPhotoLibrary.shared().performChangesAndWait {
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            placeholder = request.placeholderForCreatedAssetCollection
        }
        guard let collectionID = placeholder?.localIdentifier else { return nil }
        return PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [collectionID], options: nil).firstObject
    }

    private func addToCalendar() {
        let title = "穿搭：\(selectedItems.map { $0.name }.joined(separator: "、"))"
        let entry = OutfitCalendarEntry(ownerUsername: currentOwnerKey, date: Date(), title: title, outfitID: record?.id ?? lastGeneratedRecordID)
        modelContext.insert(entry)
        calendarMessage = "已添加到应用日历。"
    }

    private func deleteRecord() {
        if let record {
            modelContext.delete(record)
        } else if let id = lastGeneratedRecordID {
            if let match = (try? modelContext.fetch(FetchDescriptor<OutfitRecord>()))?.first(where: { $0.id == id }) {
                modelContext.delete(match)
            }
        }
        dismiss()
    }

    private func saveOutfitIfNeeded() -> Bool {
        guard !selectedItems.isEmpty else {
            return true
        }

        let names = selectedItems.map { $0.name }.joined(separator: "、")
        let ids = selectedItems.map { $0.id }
        let title = resolvedOutfitTitle()

        if let editable = editableRecord() {
            editable.title = title
            editable.itemNames = names
            editable.itemIDs = ids
            markOutfitDirtyAndSync(editable)
        } else {
            let record = OutfitRecord(ownerUsername: currentOwnerKey, title: title, itemNames: names, itemIDs: ids)
            modelContext.insert(record)
            savedRecordID = record.id
            markOutfitDirtyAndSync(record)
        }
        hasSaved = true
        return true
    }

    private func resolvedOutfitTitle() -> String {
        let trimmed = outfitTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        outfitNameCounter += 1
        return "我的穿搭\(outfitNameCounter)"
    }

    private func editableRecord() -> OutfitRecord? {
        if let record {
            return record
        }
        if let id = savedRecordID ?? lastGeneratedRecordID {
            return (try? modelContext.fetch(FetchDescriptor<OutfitRecord>()))?.first(where: { $0.id == id })
        }
        return nil
    }

    private func buildPrompt(items: [ClothingItem]) -> String {
        AIPrompts.virtualTryOn(itemNames: items.map { $0.name })
    }

    @ViewBuilder
    private func detailActionButton(
        title: String,
        icon: String,
        style: DetailActionStyle,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(style.foreground)
                } else {
                    Image(systemName: icon)
                        .font(.footnote)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(style.foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(style.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(style.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.appPlain)
        .disabled(isLoading)
    }

    private func detailQuickActionButton(
        title: String,
        icon: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.headline)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(AppTheme.bodyText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(red: 0.86, green: 0.80, blue: 0.74), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.appPlain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func togglePublicStatus(for outfit: OutfitRecord) async {
        guard !isUpdatingVisibility else { return }
        let token = UserDefaults.standard.string(forKey: "auth_token")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !token.isEmpty else {
            errorMessage = "请先登录后再设置公开状态。"
            return
        }

        isUpdatingVisibility = true
        defer { isUpdatingVisibility = false }

        var didUpdateLocalShared = false
        do {
            let api = ClothesAPIService.shared
            api.setAuthToken(token)

            if outfit.serverOutfitID == nil {
                WardrobeSyncService.shared.markOutfitPending(outfit)
                try await WardrobeSyncService.shared.syncOutfitNow(outfit, modelContext: modelContext)
            }

            if outfit.serverOutfitID == nil, let recoveredID = await recoverServerOutfitID(for: outfit, api: api) {
                outfit.serverOutfitID = recoveredID
                outfit.lastRemoteUpdatedAt = Date()
                outfit.syncStatus = .synced
                outfit.syncRetryCount = 0
                outfit.syncErrorMessage = ""
            }

            guard let serverID = outfit.serverOutfitID else {
                let syncHint = outfit.syncErrorMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                if syncHint.isEmpty {
                    errorMessage = "请先生成并保存穿搭后再设置公开状态。"
                } else {
                    errorMessage = "请先生成并保存穿搭后再设置公开状态（同步失败：\(syncHint)）。"
                }
                return
            }

            let next = !outfit.isShared
            outfit.isShared = next
            didUpdateLocalShared = true
            try await api.setOutfitVisibility(id: serverID, shared: next)
            outfit.updatedAt = Date()
            outfit.lastRemoteUpdatedAt = Date()
            outfit.syncStatus = .synced
            outfit.syncRetryCount = 0
            outfit.syncErrorMessage = ""
        } catch {
            if didUpdateLocalShared {
                outfit.isShared.toggle()
            }
            errorMessage = "更新公开状态失败：\(error.localizedDescription)"
        }
    }

    private func recoverServerOutfitID(for outfit: OutfitRecord, api: ClothesAPIService) async -> Int64? {
        let expectedTitle = normalizedOutfitMatchValue(
            outfit.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "我的搭配" : outfit.title
        )
        let expectedImage = normalizedOutfitMatchValue(SharedConstants.normalizedImagePath(outfit.remoteImageURL))
        let expectedItems = normalizedOutfitItems(outfit.itemNames)

        do {
            let remoteOutfits = try await api.getMyOutfits()
            var best: (id: Int64, score: Int)?

            for remote in remoteOutfits {
                var score = 0
                let remoteTitle = normalizedOutfitMatchValue(remote.title)
                let remoteImage = normalizedOutfitMatchValue(SharedConstants.normalizedImagePath(remote.image_url))
                let remoteItems = Set(remote.items.map { normalizedOutfitMatchValue($0.name) }.filter { !$0.isEmpty })

                if remoteTitle == expectedTitle {
                    score += 4
                }
                if !expectedImage.isEmpty, remoteImage == expectedImage {
                    score += 3
                }
                if !expectedItems.isEmpty {
                    if remoteItems == expectedItems {
                        score += 2
                    } else if !remoteItems.isDisjoint(with: expectedItems) {
                        score += 1
                    }
                }

                guard score > 0 else { continue }
                if let currentBest = best {
                    if score > currentBest.score {
                        best = (remote.id, score)
                    }
                } else {
                    best = (remote.id, score)
                }
            }

            return best?.id
        } catch {
            return nil
        }
    }

    private func normalizedOutfitMatchValue(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func normalizedOutfitItems(_ raw: String) -> Set<String> {
        Set(
            raw.components(separatedBy: CharacterSet(charactersIn: "、,，/|"))
                .map { normalizedOutfitMatchValue($0) }
                .filter { !$0.isEmpty }
        )
    }

    private func markOutfitDirtyAndSync(_ outfit: OutfitRecord) {
        WardrobeSyncService.shared.markOutfitPending(outfit)
        Task { @MainActor in
            await WardrobeSyncService.shared.syncNow(modelContext: modelContext)
        }
    }
}

private enum DetailActionStyle {
    case normal
    case primary
    case danger

    var background: Color {
        switch self {
        case .normal:
            return Color.white
        case .primary:
            return Color(red: 0.12, green: 0.12, blue: 0.14)
        case .danger:
            return Color(red: 0.62, green: 0.22, blue: 0.22)
        }
    }

    var foreground: Color {
        switch self {
        case .normal:
            return AppTheme.bodyText
        case .primary, .danger:
            return .white
        }
    }

    var border: Color {
        switch self {
        case .normal:
            return Color(red: 0.86, green: 0.80, blue: 0.74)
        case .primary, .danger:
            return .clear
        }
    }
}

private final class ImageSaveHandler: NSObject {
    let completion: (Bool) -> Void

    init(completion: @escaping (Bool) -> Void) {
        self.completion = completion
    }

    @objc func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        completion(error == nil)
    }
}

private struct OutfitHeaderBar<Trailing: View>: View {
    let title: String
    let onBack: () -> Void
    let trailing: Trailing

    init(title: String, onBack: @escaping () -> Void, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.onBack = onBack
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundStyle(AppTheme.bodyText)
            }
            Spacer()
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.titleText)
            Spacer()
            trailing
        }
        .padding(.top, 10)
    }
}

private struct OutfitHeroCard: View {
    let imageData: Data?
    let imageURL: URL?
    let isGenerating: Bool
    let countdownRemaining: Int
    let countdownProgress: Double
    private let cornerRadius: CGFloat = 22

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.94, green: 0.94, blue: 0.96))
                .frame(height: 320)
                .overlay(
                    Group {
                        if let data = imageData, let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(12)
                                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        } else if let url = imageURL {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .padding(12)
                                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                            } placeholder: {
                                ProgressView()
                            }
                        } else {
                            VStack {
                                Spacer()
                                Text("试穿图片预览")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.secondaryText)
                                Spacer()
                            }
                        }
                    }
                )

            if isGenerating {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.24))
                VStack(spacing: 10) {
                    AIGeneratingIconView()
                    Text("AI 正在生成效果图…")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.white)
                    Text("预计剩余 \(countdownRemaining) 秒")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.9))
                    ProgressView(value: countdownProgress)
                        .tint(Color.white)
                        .frame(width: 190)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.black.opacity(0.35))
                )
            }
        }
    }
}

private struct OutfitAddCard: View {
    var body: some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.95, green: 0.94, blue: 0.92))
                .frame(width: 110, height: 120)
                .overlay(
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundStyle(Color(red: 0.70, green: 0.64, blue: 0.58))
                )
            Text("添加")
                .font(.caption)
                .foregroundStyle(AppTheme.mutedText)
        }
    }
}

private struct OutfitPhotoCard: View {
    let imageData: Data?
    let onPreview: () -> Void

    var body: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color.white)
            .frame(height: 200)
            .overlay(
                Group {
                    if let data = imageData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding(10)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundStyle(Color(red: 0.60, green: 0.58, blue: 0.54))
                            Text("添加照片")
                                .font(.subheadline)
                                .foregroundStyle(Color(red: 0.60, green: 0.58, blue: 0.54))
                        }
                        .padding(.vertical, 12)
                    }
                }
                .clipped()
                .cornerRadius(18)
            )
            .overlay(alignment: .topTrailing) {
                if imageData != nil {
                    Button(action: onPreview) {
                        Label("预览", systemImage: "eye")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.60))
                            )
                            .foregroundStyle(Color.white)
                    }
                    .buttonStyle(.appPlain)
                    .padding(10)
                }
            }
    }
}

private struct WardrobePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let items: [ClothingItem]
    @Binding var selectedItemIDs: Set<UUID>

    private let categories = CategoryConfig.categories

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(categories, id: \.self) { category in
                            let filtered = items.filter { $0.category == category }
                            if !filtered.isEmpty {
                                Text(category)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.bodyText)
                                LazyVGrid(columns: columns, spacing: 14) {
                                    ForEach(filtered) { item in
                                        WardrobeSelectCard(item: item, isSelected: selectedItemIDs.contains(item.id)) {
                                            toggle(item.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .animation(.none, value: selectedItemIDs)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .adaptiveContentWidth(maxWidth: 760)
                }
            }
            .navigationTitle("选择衣物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
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

    private var columns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 4 : 3
        return Array(repeating: GridItem(.flexible()), count: count)
    }
}

private struct WardrobeSelectCard: View {
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
                Text(item.name)
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

private struct AIStylePlannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("auth_username") private var authUsername = ""
    let wardrobeItems: [ClothingItem]

    @State private var height = ""
    @State private var weight = ""
    @State private var occasion = "通勤"
    @State private var climate = "温和"
    @State private var colorTaboos = ""
    @State private var stylePreference = "极简"
    @State private var plan: AIStylePlan?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isLoadingRecommendation = false
    @State private var recommendationError: String?
    @State private var recommendation: AIDailyRecommendation?
    @State private var recommendedItems: [ClothingItem] = []
    @FocusState private var focusedField: PlannerField?

    private let occasions = ["通勤", "休闲", "社交", "运动", "旅行"]
    private let climates = ["寒冷", "温和", "炎热", "雨天"]

    private var currentOwnerKey: String {
        let trimmed = authUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? SharedConstants.guestOwnerKey : trimmed
    }

    private enum PlannerField {
        case height
        case weight
        case colorTaboos
        case stylePreference
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("AI 场景搭配")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.bodyText)

                        TodayRecommendationCard(
                            recommendation: recommendation,
                            items: recommendedItems,
                            isLoading: isLoadingRecommendation,
                            errorMessage: recommendationError,
                            onGenerate: {
                                Task {
                                    await generateDailyRecommendation()
                                }
                            }
                        )

                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                TextField("", text: $height, prompt: Text("身高（cm）").foregroundStyle(AppTheme.placeholder))
                                    .keyboardType(.numberPad)
                                    .appInputStyle()
                                    .focused($focusedField, equals: .height)
                                TextField("", text: $weight, prompt: Text("体重（kg）").foregroundStyle(AppTheme.placeholder))
                                    .keyboardType(.numberPad)
                                    .appInputStyle()
                                    .focused($focusedField, equals: .weight)
                                Picker("场合", selection: $occasion) {
                                    ForEach(occasions, id: \.self) { item in
                                        Text(item).tag(item)
                                    }
                                }
                                .pickerStyle(.segmented)
                                Picker("气候", selection: $climate) {
                                    ForEach(climates, id: \.self) { item in
                                        Text(item).tag(item)
                                    }
                                }
                                .pickerStyle(.segmented)
                                TextField("", text: $colorTaboos, prompt: Text("颜色禁忌（可选）").foregroundStyle(AppTheme.placeholder))
                                    .appInputStyle()
                                    .focused($focusedField, equals: .colorTaboos)
                                TextField("", text: $stylePreference, prompt: Text("风格偏好（可选）").foregroundStyle(AppTheme.placeholder))
                                    .appInputStyle()
                                    .focused($focusedField, equals: .stylePreference)
                            }
                        } label: {
                            Text("个人信息")
                                .font(.headline)
                        }

                        if let plan {
                            GroupBox {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("风格标签：\(plan.styleTags.joined(separator: "、"))")
                                    Text("颜色建议：\(plan.colors.joined(separator: "、"))")
                                    Text("推荐品类：\(plan.categories.joined(separator: "、"))")
                                    Text(plan.notes)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.mutedText)
                                }
                            } label: {
                                Text("推荐结果")
                                    .font(.headline)
                            }
                        }

                        if isLoading {
                            ProgressView("生成中...")
                        }

                        Button {
                            Task {
                                await generatePlan()
                            }
                        } label: {
                            Text("生成推荐")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(AppTheme.primary)
                                )
                        }

                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("AI 场景搭配")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .toolbarDoneButton()
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { focusedField = nil }
                }
            }
            .alert("生成失败", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "请稍后重试")
            }
        }
    }

    private func generatePlan() async {
        isLoading = true
        defer { isLoading = false }

        let profile = AIStyleProfile(
            height: height,
            weight: weight,
            occasion: occasion,
            climate: climate,
            colorTaboos: colorTaboos.isEmpty ? "无" : colorTaboos,
            stylePreference: stylePreference.isEmpty ? "极简" : stylePreference
        )
        do {
            let recommender = AIStyleRecommender()
            plan = try await recommender.recommendStyle(profile: profile)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func generateDailyRecommendation() async {
        isLoadingRecommendation = true
        recommendationError = nil
        defer { isLoadingRecommendation = false }

        let context = DailyContext(
            date: Date(),
            name: "我",
            location: "",
            weather: climate,
            temperature: temperatureHint(from: climate),
            isWeekend: Calendar.current.isDateInWeekend(Date()),
            calendarSummary: "无",
            availableColors: availableWardrobeColors()
        )
        let profile = AIStyleProfile(
            height: height.isEmpty ? "未知" : height,
            weight: weight.isEmpty ? "未知" : weight,
            occasion: occasion,
            climate: climate,
            colorTaboos: colorTaboos.isEmpty ? "无" : colorTaboos,
            stylePreference: stylePreference.isEmpty ? "无" : stylePreference
        )

        do {
            let recommender = AIStyleRecommender()
            let result = try await recommender.recommendDaily(profile: profile, context: context)
            recommendation = result
            recommendedItems = pickItems(for: result)

            let itemIDs = recommendedItems.map { $0.id }
            let itemNames = recommendedItems.map { $0.name.isEmpty ? "未命名" : $0.name }.joined(separator: "、")
            let titleSuffix = result.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = titleSuffix.isEmpty ? "AI推荐" : "AI推荐 \(titleSuffix)"
            let record = OutfitRecord(ownerUsername: currentOwnerKey, title: title, itemNames: itemNames, itemIDs: itemIDs)
            modelContext.insert(record)
        } catch {
            recommendationError = error.localizedDescription
        }
    }

    private func pickItems(for recommendation: AIDailyRecommendation) -> [ClothingItem] {
        let targetCategories = recommendation.categories
        let preferredColors = recommendation.colors
        var picked: [ClothingItem] = []
        for category in targetCategories {
            if let match = wardrobeItems.first(where: { $0.category == category && colorMatch($0.color, preferredColors) }) ??
                wardrobeItems.first(where: { $0.category == category }) {
                picked.append(match)
            }
        }
        return picked
    }

    private func availableWardrobeColors() -> [String] {
        let colors = wardrobeItems.map { $0.color }.filter { !$0.isEmpty }
        return Array(Set(colors)).sorted()
    }

    private func temperatureHint(from climate: String) -> String {
        switch climate {
        case "寒冷": return "5"
        case "炎热": return "30"
        case "雨天": return "15"
        default: return "20"
        }
    }

    private func colorMatch(_ color: String, _ preferred: [String]) -> Bool {
        preferred.isEmpty || preferred.contains(where: { color.contains($0) || $0.contains(color) })
    }
}

private struct OutfitItemTile: View {
    let id: UUID
    let name: String
    let tag: String
    let imageData: Data?
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .frame(width: 110, height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(red: 0.90, green: 0.88, blue: 0.84), lineWidth: 1)
                    )
                if let image = cachedThumbnail(id: id, data: imageData, maxPixel: 180) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                }
                Button(action: onRemove) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: "xmark")
                                .font(.caption2)
                                .foregroundStyle(Color(red: 0.60, green: 0.55, blue: 0.50))
                        )
                }
                .offset(x: -6, y: 6)
            }
            Text(name)
                .font(.caption)
                .foregroundStyle(Color(red: 0.30, green: 0.24, blue: 0.19))
            Text(tag)
                .font(.caption2)
                .foregroundStyle(AppTheme.mutedText)
        }
    }
}

private struct OutfitLinkRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.bodyText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Color(red: 0.70, green: 0.64, blue: 0.58))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.9))
        )
    }
}

private struct OutfitNewIdeaView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            WarmBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    OutfitSimpleHeader(title: "新的想法") {
                        dismiss()
                    }

                    HStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .frame(width: 120, height: 160)
                            .overlay(
                                VStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(red: 0.90, green: 0.90, blue: 0.92))
                                        .frame(height: 60)
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(red: 0.92, green: 0.92, blue: 0.94))
                                        .frame(height: 60)
                                }
                                .padding(10)
                            )

                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(red: 0.96, green: 0.96, blue: 0.98))
                            .frame(height: 160)
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "plus")
                                        .font(.title2)
                                        .foregroundStyle(Color(red: 0.60, green: 0.58, blue: 0.54))
                                    Text("添加图片")
                                        .font(.subheadline)
                                        .foregroundStyle(Color(red: 0.60, green: 0.58, blue: 0.54))
                                }
                            )
                    }

                    Text("长按图像以更换排序")
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.52, green: 0.46, blue: 0.40))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.92, green: 0.94, blue: 0.98))
                        )

                    Text("这是什么样的穿搭？介绍一下这个穿搭")
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 0.60, green: 0.58, blue: 0.54))
                        .padding(.vertical, 8)

                    Text("穿搭信息")
                        .font(.headline)
                        .foregroundStyle(AppTheme.bodyText)

                    HStack(spacing: 10) {
                        OutfitTagButton(title: "风格")
                        OutfitTagButton(title: "TPO")
                        OutfitTagButton(title: "季节感")
                    }

                    HStack {
                        Text("标签")
                            .font(.headline)
                            .foregroundStyle(AppTheme.bodyText)
                        Spacer()
                        Image(systemName: "plus")
                            .foregroundStyle(Color(red: 0.60, green: 0.58, blue: 0.54))
                    }

                    Text("我的评分")
                        .font(.headline)
                        .foregroundStyle(AppTheme.bodyText)

                    HStack(spacing: 10) {
                        ForEach(0..<5, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.title2)
                                .foregroundStyle(Color(red: 0.85, green: 0.86, blue: 0.88))
                        }
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("分享穿搭，为他人带来灵感！")
                                .font(.headline)
                                .foregroundStyle(AppTheme.bodyText)
                            Text("了解更多 >")
                                .font(.caption)
                                .foregroundStyle(AppTheme.mutedText)
                        }
                        Spacer()
                        Toggle("", isOn: .constant(false))
                            .labelsHidden()
                    }

                    Button("创造穿搭想法") {}
                        .font(.headline)
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(AppTheme.primary)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct OutfitWardrobePickerView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            WarmBackdrop()
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title3)
                                .foregroundStyle(AppTheme.bodyText)
                        }
                        Spacer()
                        Button("继续") {}
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(AppTheme.primary)
                            )
                            .foregroundStyle(Color.white)
                    }

                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .frame(height: 320)
                        .overlay(
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                                        .foregroundStyle(Color(red: 0.50, green: 0.50, blue: 0.54))
                                        .padding(10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white)
                                                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                                        )
                                }
                            }
                            .padding(16)
                        )

                    HStack(spacing: 20) {
                        ForEach(["square.split.2x2", "photo", "textformat", "face.smiling", "sparkles", "trash"], id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.title3)
                                .foregroundStyle(Color(red: 0.40, green: 0.38, blue: 0.34))
                        }
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.9))
                    )

                    HStack(spacing: 12) {
                        OutfitFilterPill(title: "所有服饰")
                        OutfitFilterPill(title: "按添加日期排序")
                    }

                    HStack(spacing: 18) {
                        OutfitCategoryTab(title: "全部", isActive: true)
                        OutfitCategoryTab(title: "上衣", isActive: false)
                        OutfitCategoryTab(title: "裤子", isActive: false)
                        OutfitCategoryTab(title: "外套", isActive: false)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(0..<6, id: \.self) { _ in
                            VStack(alignment: .leading, spacing: 8) {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                                    .frame(height: 140)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(red: 0.90, green: 0.88, blue: 0.84), lineWidth: 1)
                                    )
                                Text("无品牌")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.mutedText)
                                Text("2026/1/6")
                                    .font(.caption2)
                                    .foregroundStyle(Color(red: 0.70, green: 0.66, blue: 0.60))
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct OutfitSimpleHeader: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundStyle(AppTheme.bodyText)
            }
            Spacer()
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.titleText)
            Spacer()
            Color.clear.frame(width: 24)
        }
        .padding(.top, 10)
    }
}

private struct OutfitRecycleBinView: View {
    @Environment(\.dismiss) private var dismiss
    let items: [OutfitRecord]
    let onRestore: (OutfitRecord) -> Void
    let onDelete: (OutfitRecord) -> Void

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
                        ForEach(items.sorted(by: { $0.createdAt > $1.createdAt })) { item in
                            HStack(spacing: 12) {
                                if let data = item.imageData,
                                   let image = cachedThumbnail(id: item.id, data: data, maxPixel: 120) {
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
                                    Text(item.title)
                                        .font(.subheadline.weight(.medium))
                                    Text(item.itemNames.isEmpty ? "未填写物品" : item.itemNames)
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

private struct OutfitTagButton: View {
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.subheadline)
            Image(systemName: "chevron.down")
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.86, green: 0.82, blue: 0.76), lineWidth: 1)
        )
        .foregroundStyle(Color(red: 0.32, green: 0.28, blue: 0.24))
    }
}

private struct OutfitFilterPill: View {
    let title: String
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        let content = HStack(spacing: 6) {
            Image(systemName: "slider.horizontal.3")
                .font(.caption)
            Text(title)
                .font(.caption.weight(isSelected ? .semibold : .regular))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isSelected ? Color(red: 0.18, green: 0.18, blue: 0.20) : Color.white.opacity(0.9))
        )
        .foregroundStyle(isSelected ? Color.white : Color(red: 0.40, green: 0.38, blue: 0.34))

        if let onTap {
            Button(action: onTap) {
                content
            }
            .buttonStyle(.appPlain)
        } else {
            content
        }
    }
}

private struct OutfitCategoryTab: View {
    let title: String
    let isActive: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.subheadline.weight(isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? AppTheme.titleText : AppTheme.secondaryText)
            Capsule()
                .fill(isActive ? AppTheme.bodyText : Color.clear)
                .frame(height: 2)
                .frame(maxWidth: 48)
        }
    }
}
