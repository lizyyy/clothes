// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  BrandPickerView.swift
//  Clothes
//
//  Created by Codex on 2026/1/10.
//

import SwiftUI

struct BrandPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: String
    @State private var query = ""

    private var filteredBrands: [String] {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return BrandCatalog.brands
        }
        return BrandCatalog.brands.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    private var sections: [(String, [String])] {
        let grouped = Dictionary(grouping: filteredBrands) { brand -> String in
            let first = brand.first.map { String($0).uppercased() } ?? "#"
            return first.range(of: "^[A-Z]$", options: .regularExpression) != nil ? first : "#"
        }
        return grouped.keys.sorted().map { key in
            let values = grouped[key]?.sorted() ?? []
            return (key, values)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sections, id: \.0) { section in
                    Section(section.0) {
                        ForEach(section.1, id: \.self) { brand in
                            Button(brand) {
                                selection = brand
                                dismiss()
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择品牌")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "搜索品牌")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                        .toolbarDoneButton()
                }
            }
        }
    }
}
