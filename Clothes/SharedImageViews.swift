// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  SharedImageViews.swift
//  Clothes
//
//  Created by Codex on 2026/1/6.
//

import SwiftUI
import UIKit

struct FullScreenImageView: View {
    let imageData: Data?
    let imageURL: URL?
    let onClose: () -> Void
    @State private var loadedImage: UIImage?
    @State private var saveMessage: String?
    @State private var saveHandler: ImageSaveHandler?
    @State private var isSaving = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Group {
                if let data = imageData, let image = UIImage(data: data) {
                    ZoomableImageView(image: image)
                } else if let image = loadedImage {
                    ZoomableImageView(image: image)
                } else if let url = imageURL {
                    ProgressView().tint(.white)
                        .task {
                            if let data = try? await URLSession.shared.data(from: url).0,
                               let image = UIImage(data: data) {
                                loadedImage = image
                            }
                        }
                } else {
                    Text("没有可预览的图片")
                        .foregroundStyle(Color.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                HStack {
                    Button(action: saveImage) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.headline)
                            .foregroundStyle(Color(red: 0.20, green: 0.18, blue: 0.16))
                            .padding(12)
                            .background(Circle().fill(Color.white.opacity(0.92)))
                            .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 2)
                    }
                    .disabled(isSaving)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(Color(red: 0.20, green: 0.18, blue: 0.16))
                            .padding(12)
                            .background(Circle().fill(Color.white.opacity(0.92)))
                            .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 2)
                    }
                }
                .padding(20)
                Spacer()
            }
        }
        .alert("相册", isPresented: Binding(get: { saveMessage != nil }, set: { _ in saveMessage = nil })) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(saveMessage ?? "")
        }
    }

    private func saveImage() {
        guard let image = currentImage() else {
            saveMessage = "图片还在加载中。"
            return
        }
        isSaving = true
        let handler = ImageSaveHandler { success in
            isSaving = false
            saveMessage = success ? "已保存到相册。" : "保存失败，请稍后重试。"
        }
        saveHandler = handler
        UIImageWriteToSavedPhotosAlbum(image, handler, #selector(ImageSaveHandler.saveCompleted(_:didFinishSavingWithError:contextInfo:)), nil)
    }

    private func currentImage() -> UIImage? {
        if let data = imageData, let image = UIImage(data: data) {
            return image
        }
        return loadedImage
    }
}

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .clear

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        context.coordinator.imageView = imageView
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        if let imageView = context.coordinator.imageView {
            imageView.image = image
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
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
