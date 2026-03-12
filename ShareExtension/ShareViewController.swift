// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 分享扩展共享层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  ShareViewController.swift
//  ClothesShareExtension
//
//  Created by Codex on 2026/1/15.
//

import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        handleShare()
    }

    private func handleShare() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            complete()
            return
        }

        let group = DispatchGroup()
        var payloads: [SharedImportItem] = []

        for item in items {
            let providers = item.attachments ?? []
            print("[ShareExtension] attachments count:", providers.count)
            for provider in providers {
                print("[ShareExtension] provider registered types:", provider.registeredTypeIdentifiers)
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    group.enter()
                    provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                        defer { group.leave() }
                        if let error {
                            print("[ShareExtension] image data load failed:", error.localizedDescription)
                            return
                        }
                        guard let data, let fileName = self.saveImageData(data) else {
                            print("[ShareExtension] image data empty or save failed")
                            return
                        }
                        print("[ShareExtension] received IMAGE data, bytes:", data.count)
                        payloads.append(SharedImportItem(
                            id: UUID().uuidString,
                            type: .image,
                            fileName: fileName,
                            url: nil,
                            createdAt: Date().timeIntervalSince1970
                        ))
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                        defer { group.leave() }
                        if let url = item as? URL {
                            print("[ShareExtension] received URL:", url.absoluteString)
                            payloads.append(SharedImportItem(
                                id: UUID().uuidString,
                                type: .url,
                                fileName: nil,
                                url: url.absoluteString,
                                createdAt: Date().timeIntervalSince1970
                            ))
                        } else {
                            print("[ShareExtension] url load failed, raw item:", String(describing: item))
                        }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                        defer { group.leave() }
                        print("[ShareExtension] received TEXT:", String(describing: item))
                    }
                }
            }
        }

        group.notify(queue: .main) {
            print("[ShareExtension] payloads prepared:", payloads.count)
            self.appendPayloads(payloads)
            self.complete()
        }
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func saveImageData(_ data: Data) -> String? {
        guard let folder = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedConstants.appGroupID
        )?.appendingPathComponent(SharedConstants.sharedImportFolder, isDirectory: true) else {
            return nil
        }
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        let fileName = "share_\(UUID().uuidString).jpg"
        let fileURL = folder.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileName
        } catch {
            return nil
        }
    }

    private func appendPayloads(_ payloads: [SharedImportItem]) {
        guard !payloads.isEmpty,
              let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) else { return }
        var existing: [SharedImportItem] = []
        if let data = defaults.data(forKey: SharedConstants.sharedImportsKey),
           let decoded = try? JSONDecoder().decode([SharedImportItem].self, from: data) {
            existing = decoded
        }
        existing.append(contentsOf: payloads)
        if let data = try? JSONEncoder().encode(existing) {
            defaults.set(data, forKey: SharedConstants.sharedImportsKey)
        }
    }
}
