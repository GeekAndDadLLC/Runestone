//
//  TreeSitterIndentStrategyDetector.swift
//  
//
//  Created by Simon on 24/03/2021.
//

import Foundation

final class TreeSitterIndentStrategyDetector {
    private let lineManager: LineManager
    private let tree: TreeSitterTree
    private let stringView: StringView

    init(lineManager: LineManager, tree: TreeSitterTree, stringView: StringView) {
        self.lineManager = lineManager
        self.tree = tree
        self.stringView = stringView
    }

    func detect() -> DetectedIndentStrategy {
        var shouldScan = true
        let iterator = lineManager.createLineIterator()
        var lineCountBeginningWithTab = 0
        var lineCountBeginningWithSpace = 0
        var scannedLineCount = 0
        var scannedLineWithContentCount = 0
        let lineCount = lineManager.lineCount
        var lowestSpaceCount = Int.max
        var detectedStrategy: DetectedIndentStrategy = .unknown
        while let line = iterator.next(), shouldScan {
            scannedLineCount += 1
            let point = TreeSitterTextPoint(row: UInt32(line.index), column: 0)
            let node = tree.rootNode.descendantForRange(from: point, to: point)
            if node.type == "comment" {
                continue
            }
            if line.data.length <= 0 {
                continue
            }
            scannedLineWithContentCount += 1
            var range = NSRange(location: line.location, length: 1)
            var character = stringView.substring(in: range)
            if character == Symbol.tab {
                lineCountBeginningWithTab += 1
            } else if character == Symbol.space {
                // Count how many spaces the line starts with.
                var spaceCount = 0
                while spaceCount < line.data.totalLength && character == Symbol.space && spaceCount < lowestSpaceCount {
                    spaceCount += 1
                    range = NSRange(location: range.location + 1, length: 1)
                    character = stringView.substring(in: range)
                }
                if spaceCount > 1 {
                    lowestSpaceCount = min(spaceCount, lowestSpaceCount)
                    lineCountBeginningWithSpace += 1
                }
            }
            // If we have scanned at least 20 lines that aren't either empty or a comment or we have seen 100 lines in
            // total, and we have found at least one line that begins with a tab or a space, then we base our suggested
            // strategy on that.
            let hasScannedEnoughLines = scannedLineCount >= min(lineCount, 100) || scannedLineWithContentCount >= min(20, lineCount)
            let canSuggestStrategy = lineCountBeginningWithTab != 0 || lineCountBeginningWithSpace != 0
            if hasScannedEnoughLines && canSuggestStrategy {
                shouldScan = false
                if lineCountBeginningWithTab > lineCountBeginningWithSpace {
                    detectedStrategy = .tab
                } else {
                    detectedStrategy = .space(length: lowestSpaceCount)
                }
            }
        }
        return detectedStrategy
    }
}