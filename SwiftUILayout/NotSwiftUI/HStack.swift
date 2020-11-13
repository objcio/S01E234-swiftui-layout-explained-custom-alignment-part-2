//
//  HStack.swift
//  SwiftUILayout
//
//  Created by Chris Eidhof on 03.11.20.
//

import SwiftUI

@propertyWrapper
final class LayoutState<A> {
    var wrappedValue: A
    init(wrappedValue: A) {
        self.wrappedValue = wrappedValue
    }
}

extension Array where Element == CGFloat {
    func average() -> CGFloat? { 
        guard !isEmpty else { return nil }
        let factor = 1/CGFloat(count)
        return map { $0 * factor }.reduce(0,+)
    }
}

struct HStack_: View_, BuiltinView {
    var children: [AnyView_]
    var alignment: VerticalAlignment_ = .center
    let spacing: CGFloat? = 0
    @LayoutState var sizes: [CGSize] = []
    
    func customAlignment(for alignment: HorizontalAlignment_, in size: CGSize) -> CGFloat? {
        if alignment.builtin { return nil }
        
        var currentX: CGFloat = 0
        var values: [CGFloat] = []
        for idx in children.indices {
            let child = children[idx]
            let childSize = sizes[idx]
            if let value = child.customAlignment(for: alignment, in: childSize) {
                values.append(value + currentX)
            }
            currentX += childSize.width
        }
        return values.average() ?? nil
    }

    func render(context: RenderingContext, size: CGSize) {
        let stackY = alignment.alignmentID.defaultValue(in: size)
        var currentX: CGFloat = 0
        for idx in children.indices {
            let child = children[idx]
            let childSize = sizes[idx]
            let childY = alignment.alignmentID.defaultValue(in: childSize)
            context.saveGState()
            context.translateBy(x: currentX, y: stackY-childY)
            child.render(context: context, size: childSize)
            context.restoreGState()
            currentX += childSize.width
        }
    }
    
    func size(proposed: ProposedSize) -> CGSize {
        layout(proposed: proposed)
        let width: CGFloat = sizes.reduce(0) { $0 + $1.width }
        let height: CGFloat = sizes.reduce(0) { max($0, $1.height) }
        return CGSize(width: width, height: height)
    }
    
    func layout(proposed: ProposedSize) {
        let flexibility: [CGFloat] = children.map { child in
            let lower = child.size(proposed: ProposedSize(width: 0, height: proposed.height)).width
            let upper = child.size(proposed: ProposedSize(width: .greatestFiniteMagnitude, height: proposed.height)).width
            return upper-lower
        }
        var remainingIndices = children.indices.sorted { l, r in
            flexibility[l] < flexibility[r]
        }
        var remainingWidth = proposed.width! // TODO
        var sizes: [CGSize] = Array(repeating: .zero, count: children.count)
        while !remainingIndices.isEmpty {
            let width = remainingWidth / CGFloat(remainingIndices.count)
            let idx = remainingIndices.removeFirst()
            let child = children[idx]
            let size = child.size(proposed: ProposedSize(width: width, height: proposed.height))
            sizes[idx] = size
            remainingWidth -= size.width
            if remainingWidth < 0 { remainingWidth = 0 }
        }
        self.sizes = sizes
    }
    
    var swiftUI: some View {
        HStack(alignment: alignment.swiftUI, spacing: spacing) {
            ForEach(children.indices, id: \.self) { idx in
                children[idx].swiftUI
            }
        }
    }
}

class AnyViewBase: BuiltinView {
    func customAlignment(for alignment: HorizontalAlignment_, in size: CGSize) -> CGFloat? {
        fatalError()
    }
    func render(context: RenderingContext, size: CGSize) {
        fatalError()
    }
    func size(proposed: ProposedSize) -> CGSize {
        fatalError()
    }
}

final class AnyViewImpl<V: View_>: AnyViewBase {
    let view: V
    init(_ view: V) {
        self.view = view
    }
    override func customAlignment(for alignment: HorizontalAlignment_, in size: CGSize) -> CGFloat? {
        view._customAlignment(for: alignment, in: size)
    }
    override func render(context: RenderingContext, size: CGSize) {
        view._render(context: context, size: size)
    }
    override func size(proposed: ProposedSize) -> CGSize {
        view._size(proposed: proposed)
    }
}

struct AnyView_: View_, BuiltinView {
    let swiftUI: AnyView
    let impl: AnyViewBase
    
    init<V: View_>(_ view: V) {
        self.swiftUI = AnyView(view.swiftUI)
        self.impl = AnyViewImpl(view)
    }
    
    func customAlignment(for alignment: HorizontalAlignment_, in size: CGSize) -> CGFloat? {
        impl.customAlignment(for: alignment, in: size)
    }
    
    func render(context: RenderingContext, size: CGSize) {
        impl.render(context: context, size: size)
    }
    
    func size(proposed: ProposedSize) -> CGSize {
        impl.size(proposed: proposed)
    }
}


