//
//  TextView+Layout.swift
//  CodeEditTextView
//
//  Created by Khan Winter on 6/15/24.
//

import Foundation

extension TextView {
    override public func layout() {
        super.layout()
        layoutManager.layoutLines()
        selectionManager.updateSelectionViews(skipTimerReset: true)
    }

    open override class var isCompatibleWithResponsiveScrolling: Bool {
        true
    }

    open override func prepareContent(in rect: NSRect) {
        needsLayout = true
        super.prepareContent(in: rect)
    }

    override public func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if isSelectable {
            selectionManager.drawSelections(in: dirtyRect)
        }
        emphasisManager?.updateLayerBackgrounds()
    }

    override open var isFlipped: Bool {
        true
    }

    override public var visibleRect: NSRect {
        if let scrollView {
            var rect = scrollView.documentVisibleRect
            rect.origin.y += scrollView.contentInsets.top
            return rect.pixelAligned
        } else {
            return super.visibleRect
        }
    }

    public var visibleTextRange: NSRange? {
        // Expand the visible rect by a small buffer so syntax highlighting can be prefetched.
        // This prevents newly visible text from appearing as "plain" during fast scrolling.
        let estimatedHeight = layoutManager.estimatedHeight()

        let bufferLines = max(0, min(visibleTextRangeBufferLines, 500))
        let lineHeight = max(layoutManager.estimateLineHeight(), 1)
        let buffer = CGFloat(bufferLines) * lineHeight

        // Clamp into the document content height (not including overscroll padding).
        var minY = max(visibleRect.minY - buffer, 0)
        var maxY = min(visibleRect.maxY + buffer, estimatedHeight)
        minY = min(minY, estimatedHeight) // Handle overscroll past the end of the document

        // Avoid querying exactly at the document boundary where line lookups may fail.
        let maxYPos = max(0, min(maxY, max(estimatedHeight - 1, 0)))
        let minYPos = max(0, min(minY, maxYPos))

        guard let minYLine = layoutManager.textLineForPosition(minYPos),
              let maxYLine = layoutManager.textLineForPosition(maxYPos) else {
            return nil
        }
        return NSRange(
            location: minYLine.range.location,
            length: (maxYLine.range.location - minYLine.range.location) + maxYLine.range.length
        )
    }

    public func updatedViewport(_ newRect: CGRect) {
        if !updateFrameIfNeeded() {
            layoutManager.layoutLines()
        }
        inputContext?.invalidateCharacterCoordinates()
    }

    /// Updates the view's frame if needed depending on wrapping lines, a new maximum width, or changed available size.
    /// - Returns: Whether or not the view was updated.
    @discardableResult
    public func updateFrameIfNeeded() -> Bool {
        var availableSize = scrollView?.contentSize ?? .zero
        availableSize.height -= (scrollView?.contentInsets.top ?? 0) + (scrollView?.contentInsets.bottom ?? 0)

        let extraHeight = availableSize.height * overscrollAmount
        let newHeight = max(layoutManager.estimatedHeight() + extraHeight, availableSize.height, 0)
        let newWidth = layoutManager.estimatedWidth()

        var didUpdate = false

        if newHeight >= availableSize.height && frame.size.height != newHeight {
            frame.size.height = newHeight
            // No need to update layout after height adjustment
        }

        if wrapLines && frame.size.width != availableSize.width {
            frame.size.width = availableSize.width
            didUpdate = true
        } else if !wrapLines && frame.size.width != max(newWidth, availableSize.width) {
            frame.size.width = max(newWidth, availableSize.width)
            didUpdate = true
        }

        if didUpdate {
            needsLayout = true
            needsDisplay = true
            layoutManager.setNeedsLayout()
        }

        if isSelectable {
            selectionManager?.updateSelectionViews()
        }

        return didUpdate
    }
}
