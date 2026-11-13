//
//  LiveGraph.swift
//  Taskr
//
//  The scrolling area graph used on every Performance page and device card.
//

import SwiftUI

/// One line-with-fill in a graph.
struct GraphSeries {
    var values: [Double]
    var line: Color
    var fill: Color
    var fillOpacity: Double
}

/// A 60-second area graph. Series are drawn in order, later ones on top; newest reading at the right edge.
struct LiveGraph: View {
    let series: [GraphSeries]
    /// The value at the top of the graph; readings above it are clipped to the top.
    let maxValue: Double
    var showGrid = true
    var lineWidth: CGFloat = 1.5

    var body: some View {
        Canvas { context, size in
            if showGrid { drawGrid(in: context, size: size) }
            for item in series { draw(item, in: context, size: size) }
        }
    }

    // MARK: Drawing

    /// Ten columns and four rows of faint lines, like the design.
    private func drawGrid(in context: GraphicsContext, size: CGSize) {
        var grid = Path()
        for column in 1..<10 {
            let x = size.width * CGFloat(column) / 10
            grid.move(to: CGPoint(x: x, y: 0))
            grid.addLine(to: CGPoint(x: x, y: size.height))
        }
        for row in 1..<4 {
            let y = size.height * CGFloat(row) / 4
            grid.move(to: CGPoint(x: 0, y: y))
            grid.addLine(to: CGPoint(x: size.width, y: y))
        }
        context.stroke(grid, with: .color(Color.primary.opacity(0.09)), lineWidth: 1)
    }

    private func draw(_ item: GraphSeries, in context: GraphicsContext, size: CGSize) {
        let points = points(for: item.values, in: size)
        guard let first = points.first, let last = points.last, points.count > 1 else { return }

        var line = Path()
        line.move(to: first)
        for point in points.dropFirst() { line.addLine(to: point) }

        var area = line
        area.addLine(to: CGPoint(x: last.x, y: size.height))
        area.addLine(to: CGPoint(x: first.x, y: size.height))
        area.closeSubpath()

        context.fill(area, with: .color(item.fill.opacity(item.fillOpacity)))
        context.stroke(line, with: .color(item.line), lineWidth: lineWidth)
    }

    /// Maps readings to points, right-aligned so a partly filled window grows from the right.
    private func points(for values: [Double], in size: CGSize) -> [CGPoint] {
        let slots = MetricHistory.capacity
        let offset = slots - values.count
        let top = max(maxValue, .leastNonzeroMagnitude)
        return values.enumerated().map { index, value in
            CGPoint(x: size.width * CGFloat(offset + index) / CGFloat(slots - 1),
                    y: size.height * (1 - CGFloat(min(max(value / top, 0), 1))))
        }
    }
}
