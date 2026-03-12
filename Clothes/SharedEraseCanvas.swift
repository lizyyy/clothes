// 文件input：系统框架、项目内模型/服务、用户或网络输入
// 文件output：页面渲染、状态更新、端内业务能力或服务调用
// 文件pos：iOS 主应用实现层
// 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
//
//  SharedEraseCanvas.swift
//  Clothes
//
//  Created by Codex on 2026/1/6.
//

import SwiftUI
import UIKit

struct EraseCanvasView: UIViewRepresentable {
    let image: UIImage
    let brushWidth: CGFloat
    let isErasing: Bool
    let controller: EraseCanvasController

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.bouncesZoom = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delaysContentTouches = false
        scrollView.canCancelContentTouches = false
        scrollView.panGestureRecognizer.minimumNumberOfTouches = 2
        scrollView.panGestureRecognizer.maximumNumberOfTouches = 2
        scrollView.pinchGestureRecognizer?.cancelsTouchesInView = false

        let eraserView = EraseCanvasUIView(image: image)
        eraserView.brushWidth = brushWidth
        eraserView.isErasing = isErasing
        eraserView.onStateChange = { controller.notifyState() }
        eraserView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(eraserView)

        NSLayoutConstraint.activate([
            eraserView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            eraserView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            eraserView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            eraserView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            eraserView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            eraserView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        context.coordinator.eraserView = eraserView
        controller.attach(eraserView)
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        guard let eraserView = context.coordinator.eraserView else { return }
        eraserView.image = image
        eraserView.brushWidth = brushWidth
        eraserView.isErasing = isErasing
        controller.attach(eraserView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    static func dismantleUIView(_ uiView: UIScrollView, coordinator: Coordinator) {
        coordinator.controller?.detach()
        coordinator.eraserView = nil
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var eraserView: EraseCanvasUIView?
        weak var controller: EraseCanvasController?

        init(controller: EraseCanvasController) {
            self.controller = controller
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            eraserView
        }
    }
}

final class EraseCanvasController {
    private weak var view: EraseCanvasUIView?
    var onStateChange: ((Bool, Bool) -> Void)?

    var hasEdits: Bool {
        view?.hasEdits ?? false
    }

    var canUndo: Bool {
        view?.canUndo ?? false
    }

    var canRedo: Bool {
        view?.canRedo ?? false
    }

    func notifyState() {
        onStateChange?(canUndo, canRedo)
    }

    func attach(_ view: EraseCanvasUIView) {
        self.view = view
    }

    func detach() {
        view = nil
        notifyState()
    }

    func clear() {
        view?.clearStrokes()
        notifyState()
    }

    func undo() {
        view?.undo()
        notifyState()
    }

    func redo() {
        view?.redo()
        notifyState()
    }

    func renderErasedImage() -> UIImage? {
        view?.renderErasedImage()
    }
}

final class EraseCanvasUIView: UIView {
    private struct EraseStroke {
        var points: [CGPoint]
        var width: CGFloat
    }

    var image: UIImage {
        didSet {
            setNeedsLayout()
            setNeedsDisplay()
        }
    }
    var brushWidth: CGFloat = 48 {
        didSet { setNeedsDisplay() }
    }
    var isErasing = false
    var onStateChange: (() -> Void)?

    private(set) var hasEdits = false
    private var strokes: [EraseStroke] = []
    private var redoStrokes: [EraseStroke] = []
    private var currentStroke: EraseStroke?
    private var imageFrame: CGRect = .zero

    init(image: UIImage) {
        self.image = image
        super.init(frame: .zero)
        backgroundColor = .clear
        isMultipleTouchEnabled = false
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateImageFrame()
    }

    override func draw(_ rect: CGRect) {
        guard imageFrame.width > 0, imageFrame.height > 0 else { return }
        image.draw(in: imageFrame)

        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        context.setBlendMode(.destinationOut)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        for stroke in strokes {
            draw(stroke, in: context)
        }
        if let currentStroke {
            draw(currentStroke, in: context)
        }
        context.restoreGState()
    }

    var canUndo: Bool {
        !strokes.isEmpty
    }

    var canRedo: Bool {
        !redoStrokes.isEmpty
    }

    func clearStrokes() {
        strokes.removeAll()
        redoStrokes.removeAll()
        currentStroke = nil
        hasEdits = false
        setNeedsDisplay()
        onStateChange?()
    }

    func undo() {
        guard let last = strokes.popLast() else { return }
        redoStrokes.append(last)
        hasEdits = !strokes.isEmpty
        setNeedsDisplay()
        onStateChange?()
    }

    func redo() {
        guard let last = redoStrokes.popLast() else { return }
        strokes.append(last)
        hasEdits = true
        setNeedsDisplay()
        onStateChange?()
    }

    func renderErasedImage() -> UIImage? {
        guard imageFrame.width > 0, imageFrame.height > 0 else { return image }
        guard hasEdits else { return image }
        let imageSize = image.size
        let scaleX = imageSize.width / imageFrame.width
        let scaleY = imageSize.height / imageFrame.height
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: imageSize))
            let cg = context.cgContext
            cg.setBlendMode(.destinationOut)
            cg.setLineCap(.round)
            cg.setLineJoin(.round)

            for stroke in strokes where !stroke.points.isEmpty {
                cg.beginPath()
                if let first = mapPoint(stroke.points[0], scaleX: scaleX, scaleY: scaleY) {
                    cg.move(to: first)
                    cg.setLineWidth(stroke.width * (scaleX + scaleY) / 2)
                    if stroke.points.count == 1 {
                        cg.addLine(to: first)
                    } else {
                        for point in stroke.points.dropFirst() {
                            if let mapped = mapPoint(point, scaleX: scaleX, scaleY: scaleY) {
                                cg.addLine(to: mapped)
                            }
                        }
                    }
                    cg.strokePath()
                }
            }
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isErasing,
              (event?.allTouches?.count ?? 0) <= 1,
              let point = touches.first?.location(in: self),
              imageFrame.contains(point) else { return }
        redoStrokes.removeAll()
        currentStroke = EraseStroke(points: [point], width: brushWidth)
        hasEdits = true
        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isErasing,
              (event?.allTouches?.count ?? 0) <= 1,
              let point = touches.first?.location(in: self),
              imageFrame.contains(point) else { return }
        currentStroke?.points.append(point)
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isErasing else { return }
        if let currentStroke, !currentStroke.points.isEmpty {
            strokes.append(currentStroke)
        }
        currentStroke = nil
        setNeedsDisplay()
        onStateChange?()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func updateImageFrame() {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        let originX = (bounds.width - width) / 2
        let originY = (bounds.height - height) / 2
        imageFrame = CGRect(x: originX, y: originY, width: width, height: height)
    }

    private func mapPoint(_ point: CGPoint, scaleX: CGFloat, scaleY: CGFloat) -> CGPoint? {
        guard imageFrame.contains(point) else { return nil }
        let x = (point.x - imageFrame.minX) * scaleX
        let y = (point.y - imageFrame.minY) * scaleY
        return CGPoint(x: x, y: y)
    }

    private func draw(_ stroke: EraseStroke, in context: CGContext) {
        guard !stroke.points.isEmpty else { return }
        context.setLineWidth(stroke.width)
        context.beginPath()
        context.move(to: stroke.points[0])
        if stroke.points.count == 1 {
            context.addLine(to: stroke.points[0])
        } else {
            for point in stroke.points.dropFirst() {
                context.addLine(to: point)
            }
        }
        context.strokePath()
    }
}
