import SwiftUI

// MARK: - Vector icon system
//
// All icons are stroke-based vector glyphs drawn on a 24x24 grid, stored as
// raw SVG path data and rendered by `SVGPathParser`. This replaces SF Symbols
// with a consistent minimal line-icon language.

public enum AppGlyph: String, CaseIterable {
    case archive, arrowDown, arrowLeft, arrowRight, arrowUp
    case barChart, bell, box, cart, chat, check, checkCircle
    case chevronDown, chevronLeft, chevronRight, chevronUp
    case clipboard, clock, close, code, compass, copy, creditCard
    case dollar, download, externalLink, eye, feather, fileText, folder
    case gift, globe, grid, help, history, home, image, inbox, info
    case layers, list, lock, minus, moon, palette, pencil, percent
    case play, plus, refresh, `repeat`, scan, search, send, settings
    case shield, shieldCheck, sliders, smartphone, sparkles, splitColumns
    case star, starFilled, tag, terminal, trash, users, video, wifi, xCircle, zap

    /// Whether the glyph should be filled rather than stroked.
    public var isFilled: Bool { self == .starFilled }

    /// SVG path data on a 24x24 canvas (stroke style, round caps/joins).
    public var pathData: String {
        switch self {
        case .archive:
            return "M21 8v13H3V8M1 3h22v5H1zM10 12h4"
        case .arrowDown:
            return "M12 5v14M19 12l-7 7-7-7"
        case .arrowLeft:
            return "M19 12H5M12 19l-7-7 7-7"
        case .arrowRight:
            return "M5 12h14M12 5l7 7-7 7"
        case .arrowUp:
            return "M12 19V5M5 12l7-7 7 7"
        case .barChart:
            return "M12 20V10M18 20V4M6 20v-4"
        case .bell:
            return "M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9M13.73 21a2 2 0 0 1-3.46 0"
        case .box:
            return "M21 8l-9-5-9 5v8l9 5 9-5zM3 8l9 5 9-5M12 13v8"
        case .cart:
            return "M8 21a1 1 0 1 0 2 0 1 1 0 0 0-2 0zM17 21a1 1 0 1 0 2 0 1 1 0 0 0-2 0zM1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6"
        case .chat:
            return "M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"
        case .check:
            return "M20 6L9 17l-5-5"
        case .checkCircle:
            return "M22 11.08V12a10 10 0 1 1-5.93-9.14M22 4L12 14.01l-3-3"
        case .chevronDown:
            return "M6 9l6 6 6-6"
        case .chevronLeft:
            return "M15 18l-6-6 6-6"
        case .chevronRight:
            return "M9 18l6-6-6-6"
        case .chevronUp:
            return "M18 15l-6-6-6 6"
        case .clipboard:
            return "M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2M8 2h8a1 1 0 0 1 1 1v2a1 1 0 0 1-1 1H8a1 1 0 0 1-1-1V3a1 1 0 0 1 1-1z"
        case .clock:
            return "M2 12a10 10 0 1 0 20 0 10 10 0 0 0-20 0zM12 6v6l4 2"
        case .close:
            return "M18 6L6 18M6 6l12 12"
        case .code:
            return "M16 18l6-6-6-6M8 6l-6 6 6 6"
        case .compass:
            return "M2 12a10 10 0 1 0 20 0 10 10 0 0 0-20 0zM16.24 7.76l-2.12 6.36-6.36 2.12 2.12-6.36z"
        case .copy:
            return "M11 9h9a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-9a2 2 0 0 1-2-2v-9a2 2 0 0 1 2-2zM5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"
        case .creditCard:
            return "M3 4h18a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2zM1 10h22"
        case .dollar:
            return "M12 1v22M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"
        case .download:
            return "M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"
        case .externalLink:
            return "M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6M15 3h6v6M10 14L21 3"
        case .eye:
            return "M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8zM9 12a3 3 0 1 0 6 0 3 3 0 0 0-6 0z"
        case .feather:
            return "M20.24 12.24a6 6 0 0 0-8.49-8.49L5 10.5V19h8.5zM16 8L2 22M17.5 15H9"
        case .fileText:
            return "M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8zM14 2v6h6M16 13H8M16 17H8"
        case .folder:
            return "M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"
        case .gift:
            return "M4 8h16a1 1 0 0 1 1 1v3H3V9a1 1 0 0 1 1-1zM12 8v14M19 12v7a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2v-7M7.5 8a2.5 2.5 0 0 1 0-5A4.8 8 0 0 1 12 8a4.8 8 0 0 1 4.5-5 2.5 2.5 0 0 1 0 5"
        case .globe:
            return "M2 12a10 10 0 1 0 20 0 10 10 0 0 0-20 0zM2 12h20M12 2a4 10 0 0 1 0 20 4 10 0 0 1 0-20z"
        case .grid:
            return "M4 4h5a1 1 0 0 1 1 1v4a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1zM15 4h4a1 1 0 0 1 1 1v4a1 1 0 0 1-1 1h-4a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1zM4 15h5a1 1 0 0 1 1 1v4a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-4a1 1 0 0 1 1-1zM15 15h4a1 1 0 0 1 1 1v4a1 1 0 0 1-1 1h-4a1 1 0 0 1-1-1v-4a1 1 0 0 1 1-1z"
        case .help:
            return "M2 12a10 10 0 1 0 20 0 10 10 0 0 0-20 0zM9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3M12 17h.01"
        case .history:
            return "M1 4v6h6M3.51 15a9 9 0 1 0 2.13-9.36L1 10M12 7v5l3 2"
        case .home:
            return "M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2zM9 22V12h6v10"
        case .image:
            return "M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2zM8 10a1.5 1.5 0 1 0 3 0 1.5 1.5 0 0 0-3 0zM21 15l-5-5L5 21"
        case .inbox:
            return "M22 12h-6l-2 3h-4l-2-3H2M5.45 5.11L2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z"
        case .info:
            return "M2 12a10 10 0 1 0 20 0 10 10 0 0 0-20 0zM12 16v-4M12 8h.01"
        case .layers:
            return "M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"
        case .list:
            return "M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"
        case .lock:
            return "M5 11h14a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-7a2 2 0 0 1 2-2zM7 11V7a5 5 0 0 1 10 0v4"
        case .minus:
            return "M5 12h14"
        case .moon:
            return "M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"
        case .palette:
            return "M12 22a10 10 0 1 1 10-10 4 4 0 0 1-4 4h-2a2.5 2.5 0 0 0-1.8 4.2c.5.5.4 1.4-.4 1.8zM7.5 10.5h.01M12 7.5h.01M16.5 10.5h.01"
        case .pencil:
            return "M17 3a2.85 2.85 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5z"
        case .percent:
            return "M19 5L5 19M4 6.5a2.5 2.5 0 1 0 5 0 2.5 2.5 0 0 0-5 0zM15 17.5a2.5 2.5 0 1 0 5 0 2.5 2.5 0 0 0-5 0z"
        case .play:
            return "M5 3l14 9-14 9z"
        case .plus:
            return "M12 5v14M5 12h14"
        case .refresh:
            return "M23 4v6h-6M20.49 15a9 9 0 1 1-2.12-9.36L23 10"
        case .`repeat`:
            return "M17 1l4 4-4 4M3 11V9a4 4 0 0 1 4-4h14M7 23l-4-4 4-4M21 13v2a4 4 0 0 1-4 4H3"
        case .scan:
            return "M3 7V5a2 2 0 0 1 2-2h2M17 3h2a2 2 0 0 1 2 2v2M21 17v2a2 2 0 0 1-2 2h-2M7 21H5a2 2 0 0 1-2-2v-2M4 12h16"
        case .search:
            return "M10.5 3a7.5 7.5 0 1 0 0 15 7.5 7.5 0 0 0 0-15zM16.2 16.2L21 21"
        case .send:
            return "M22 2L11 13M22 2l-7 20-4-9-9-4z"
        case .settings:
            return "M12 9.5a2.5 2.5 0 1 0 0 5 2.5 2.5 0 0 0 0-5zM17.5 12h3M15.89 15.89l2.12 2.12M12 17.5v3M8.11 15.89l-2.12 2.12M6.5 12h-3M8.11 8.11L5.99 5.99M12 6.5v-3M15.89 8.11l2.12-2.12"
        case .shield:
            return "M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"
        case .shieldCheck:
            return "M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10zM9 11.5l2 2 4-4"
        case .sliders:
            return "M4 21v-7M4 10V3M12 21v-9M12 8V3M20 21v-5M20 12V3M1 14h6M9 8h6M17 16h6"
        case .smartphone:
            return "M7 2h10a2 2 0 0 1 2 2v16a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2zM12 18h.01"
        case .sparkles:
            return "M12 3l2 6 6 2-6 2-2 6-2-6-6-2 6-2zM19 15l.9 2.1 2.1.9-2.1.9-.9 2.1-.9-2.1-2.1-.9 2.1-.9zM5 2l.8 2 2 .8-2 .8-.8 2-.8-2-2-.8 2-.8z"
        case .splitColumns:
            return "M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2zM12 3v18"
        case .star, .starFilled:
            return "M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01z"
        case .tag:
            return "M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82zM7 7h.01"
        case .terminal:
            return "M4 17l6-6-6-6M12 19h8"
        case .trash:
            return "M3 6h18M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M5 6v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V6M10 11v6M14 11v6"
        case .users:
            return "M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2M5 7a4 4 0 1 0 8 0 4 4 0 0 0-8 0zM23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"
        case .video:
            return "M14 5H3a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h11a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2zM23 7l-7 5 7 5V7z"
        case .wifi:
            return "M5 12.55a11 11 0 0 1 14.08 0M8.53 16.11a6 6 0 0 1 6.95 0M1.42 9a16 16 0 0 1 21.16 0M12 20h.01"
        case .xCircle:
            return "M2 12a10 10 0 1 0 20 0 10 10 0 0 0-20 0zM9 9l6 6M15 9l-6 6"
        case .zap:
            return "M13 2L3 14h9l-1 8 10-12h-9l1-8z"
        }
    }

    /// Maps an SF Symbol name (or an `AppGlyph` rawValue) to a glyph so callers
    /// can keep the existing string vocabulary.
    public static func mapped(from name: String) -> AppGlyph {
        if let glyph = AppGlyph(rawValue: name) { return glyph }
        switch name {
        case "magnifyingglass", "magnifyingglass.circle", "magnifyingglass.circle.fill": return .search
        case "bolt.badge.clock", "bolt.badge.clock.fill": return .scan
        case "bolt", "bolt.fill", "bolt.circle", "bolt.circle.fill": return .zap
        case "bolt.shield", "bolt.shield.fill": return .shieldCheck
        case "arrow.clockwise", "arrow.clockwise.circle", "arrow.clockwise.circle.fill": return .refresh
        case "arrow.triangle.2.circlepath", "repeat", "repeat.1", "repeat.circle", "repeat.circle.fill": return .repeat
        case "clock.arrow.circlepath", "arrow.counterclockwise", "memories": return .history
        case "clock", "clock.fill", "timer": return .clock
        case "arrow.up.forward.app", "arrow.up.forward.app.fill", "link", "arrow.up.right.square": return .externalLink
        case "arrow.right", "arrow.right.circle", "arrow.right.circle.fill": return .arrowRight
        case "arrow.left", "arrow.left.circle": return .arrowLeft
        case "arrow.down", "arrow.down.circle": return .arrowDown
        case "arrow.up", "arrow.up.circle": return .arrowUp
        case "doc.on.doc", "doc.on.doc.fill", "square.on.square": return .copy
        case "doc.on.clipboard", "list.clipboard", "list.bullet.clipboard": return .clipboard
        case "doc", "doc.fill", "doc.text", "doc.plaintext", "note.text": return .fileText
        case "star", "star.circle": return .star
        case "star.fill", "star.circle.fill", "star.leadinghalf.filled": return .starFilled
        case "app", "app.fill", "app.badge", "app.badge.fill", "square.grid.2x2", "square.grid.2x2.fill": return .grid
        case "play", "play.fill", "play.circle", "play.circle.fill": return .play
        case "play.rectangle", "play.rectangle.fill", "rectangle.on.rectangle": return .tag
        case "video", "video.fill", "tv", "tv.fill": return .video
        case "bubble.left.and.bubble.right.fill", "bubble.left", "bubble.left.fill", "bubble.right",
             "message", "message.fill", "text.bubble", "text.bubble.fill": return .chat
        case "bird", "bird.fill": return .feather
        case "paintpalette", "paintpalette.fill", "paintbrush", "paintbrush.fill", "paintbrush.pointed.fill": return .palette
        case "photo", "photo.fill", "photo.on.rectangle", "camera", "camera.fill": return .image
        case "paperplane", "paperplane.fill", "paperplane.circle": return .send
        case "wand.and.stars", "wand.and.stars.inverse", "wand.and.rays", "wand.and.rays.inverse",
             "sparkles", "sparkle", "rays": return .sparkles
        case "gearshape", "gearshape.fill", "gearshape.2", "gear", "gearshape.circle": return .settings
        case "folder", "folder.fill", "folder.badge.plus": return .folder
        case "square.stack.3d.up", "square.stack.3d.up.fill", "square.stack", "square.stack.fill": return .layers
        case "square.split.2x1", "square.split.2x1.fill", "rectangle.split.2x1", "square.split.1x2": return .splitColumns
        case "terminal", "terminal.fill", "apple.terminal": return .terminal
        case "trash", "trash.fill", "trash.circle", "trash.circle.fill": return .trash
        case "archivebox", "archivebox.fill", "archivebox.circle": return .archive
        case "shippingbox", "shippingbox.fill", "cube", "cube.fill", "cube.box": return .box
        case "exclamationmark.octagon", "exclamationmark.octagon.fill", "exclamationmark.triangle",
             "exclamationmark.triangle.fill", "exclamationmark.circle", "exclamationmark.circle.fill": return .alertOctagon
        case "person.2.fill", "person.2", "person.fill", "person", "person.3", "person.3.fill",
             "person.crop.circle", "person.circle": return .users
        case "chevron.left.forwardslash.chevron.right": return .code
        case "chevron.left": return .chevronLeft
        case "chevron.right": return .chevronRight
        case "chevron.down": return .chevronDown
        case "chevron.up": return .chevronUp
        case "moon", "moon.fill", "moon.circle", "circle.lefthalf.filled", "sun.max", "sun.max.fill": return .moon
        case "globe", "network": return .globe
        case "creditcard", "creditcard.fill", "banknote", "banknote.fill": return .creditCard
        case "square.and.arrow.down", "arrow.down.to.line", "icloud.and.arrow.down", "tray.and.arrow.down": return .download
        case "tray", "tray.fill", "tray.full", "tray.full.fill": return .inbox
        case "line.3.horizontal.decrease.circle", "line.3.horizontal.decrease.circle.fill",
             "line.3.horizontal.decrease", "slider.horizontal.3": return .sliders
        case "xmark.circle.fill", "xmark.circle", "xmark.octagon": return .xCircle
        case "xmark", "x": return .close
        case "checkmark.seal", "checkmark.seal.fill", "checkmark": return .check
        case "checkmark.circle", "checkmark.circle.fill", "checkmark.square", "checkmark.square.fill": return .checkCircle
        case "cart", "cart.fill", "cart.badge.plus", "bag", "bag.fill", "basket": return .cart
        case "tag", "tag.fill", "tag.circle": return .tag
        case "dollarsign", "dollarsign.circle", "dollarsign.circle.fill": return .dollar
        case "plus.circle.fill", "plus.circle", "plus", "plus.app", "plus.square": return .plus
        case "minus.circle.fill", "minus.circle", "minus", "minus.square": return .minus
        case "pencil.circle.fill", "pencil.circle", "pencil", "square.and.pencil", "pencil.tip": return .pencil
        case "info.circle", "info.circle.fill", "info": return .info
        case "questionmark.circle", "questionmark.circle.fill", "questionmark": return .help
        case "eye", "eye.fill", "eye.circle", "eye.slash", "eye.slash.fill": return .eye
        case "lock", "lock.fill", "lock.shield", "lock.circle": return .lock
        case "wifi", "antenna.radiowaves.left.and.right": return .wifi
        case "chart.bar", "chart.bar.fill", "chart.pie", "chart.xyaxis.line": return .barChart
        case "list.bullet", "list.dash", "line.horizontal.3", "list.bullet.rectangle": return .list
        case "house", "house.fill": return .home
        case "bell", "bell.fill", "bell.badge": return .bell
        case "gift", "gift.fill", "giftcard", "giftcard.fill": return .gift
        case "percent", "percent.circle": return .percent
        case "safari", "safari.fill": return .compass
        case "apple.logo", "applelogo", "apps.iphone", "iphone", "iphone.gen3", "ipad": return .smartphone
        case "shield", "shield.fill", "shield.lefthalf.filled": return .shield
        case "checkmark.shield", "checkmark.shield.fill", "shield.checkered": return .shieldCheck
        default: return .grid
        }
    }
}

// MARK: - Rendering

/// A `Shape` that draws SVG path data scaled into the given rect. The source
/// canvas is 24x24 and is centered inside the destination rect.
public struct GlyphShape: Shape {
    public let data: String

    public init(_ data: String) {
        self.data = data
    }

    public func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24.0
        let transform = CGAffineTransform(
            a: scale, b: 0, c: 0, d: scale,
            tx: rect.midX - 12 * scale,
            ty: rect.midY - 12 * scale
        )
        return SVGPathParser.parse(data).applying(transform)
    }
}

/// Drop-in replacement for `Image(systemName:)` that renders a vector glyph.
public struct GlyphView: View {
    public let glyph: AppGlyph
    public let size: CGFloat
    public let color: Color
    public let strokeWidth: CGFloat

    public init(_ glyph: AppGlyph, size: CGFloat = 20, color: Color = .iappayTextPrimary, strokeWidth: CGFloat = 2) {
        self.glyph = glyph
        self.size = size
        self.color = color
        self.strokeWidth = strokeWidth
    }

    /// Convenience initializer that accepts the previous SF Symbol name
    /// strings so call sites only swap the view.
    public init(sf name: String, size: CGFloat = 20, color: Color = .iappayTextPrimary, strokeWidth: CGFloat = 2) {
        self.init(AppGlyph.mapped(from: name), size: size, color: color, strokeWidth: strokeWidth)
    }

    public var body: some View {
        Group {
            if glyph.isFilled {
                GlyphShape(data: glyph.pathData).fill(color)
            } else {
                GlyphShape(data: glyph.pathData)
                    .stroke(color, style: StrokeStyle(
                        lineWidth: strokeWidth * size / 24.0,
                        lineCap: .round,
                        lineJoin: .round
                    ))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Minimal SVG path parser

enum SVGPathParser {
    static func parse(_ d: String) -> Path {
        var path = Path()
        var index = d.startIndex
        var cmd: Character = "\0"
        var cursor = CGPoint.zero
        var subpathStart = CGPoint.zero
        var prevCubicControl: CGPoint?
        var prevQuadControl: CGPoint?

        func isSeparator(_ c: Character) -> Bool {
            c == " " || c == "," || c == "\n" || c == "\t" || c == "\r"
        }

        func skipSeparators() {
            while index < d.endIndex && isSeparator(d[index]) {
                index = d.index(after: index)
            }
        }

        func readNumber() -> Double? {
            skipSeparators()
            guard index < d.endIndex else { return nil }
            var end = index
            var hasDigit = false
            var seenDot = false
            var seenExp = false
            if d[end] == "-" || d[end] == "+" { end = d.index(after: end) }
            while end < d.endIndex {
                let c = d[end]
                if c.isNumber {
                    hasDigit = true
                    end = d.index(after: end)
                } else if c == "." && !seenDot && !seenExp {
                    seenDot = true
                    end = d.index(after: end)
                } else if (c == "e" || c == "E") && hasDigit && !seenExp {
                    seenExp = true
                    end = d.index(after: end)
                    if end < d.endIndex && (d[end] == "-" || d[end] == "+") {
                        end = d.index(after: end)
                    }
                } else {
                    break
                }
            }
            guard hasDigit else { return nil }
            let value = Double(d[index..<end])
            index = end
            return value
        }

        func readPoint(relative: Bool) -> CGPoint? {
            guard let x = readNumber(), let y = readNumber() else { return nil }
            if relative { return CGPoint(x: cursor.x + x, y: cursor.y + y) }
            return CGPoint(x: x, y: y)
        }

        while true {
            skipSeparators()
            guard index < d.endIndex else { break }
            let c = d[index]
            if c.isLetter {
                cmd = c
                index = d.index(after: index)
            } else {
                if cmd == "M" { cmd = "L" }
                else if cmd == "m" { cmd = "l" }
                else if cmd == "\0" { break }
            }

            let relative = cmd.isLowercase
            switch Character(cmd.uppercased()) {
            case "M":
                guard let p = readPoint(relative: relative) else { return path }
                path.move(to: p)
                cursor = p
                subpathStart = p
            case "L":
                guard let p = readPoint(relative: relative) else { return path }
                path.addLine(to: p)
                cursor = p
            case "H":
                guard let x = readNumber() else { return path }
                let p = CGPoint(x: relative ? cursor.x + x : x, y: cursor.y)
                path.addLine(to: p)
                cursor = p
            case "V":
                guard let y = readNumber() else { return path }
                let p = CGPoint(x: cursor.x, y: relative ? cursor.y + y : y)
                path.addLine(to: p)
                cursor = p
            case "C":
                guard let c1 = readPoint(relative: relative),
                      let c2 = readPoint(relative: relative),
                      let p = readPoint(relative: relative) else { return path }
                path.addCurve(to: p, control1: c1, control2: c2)
                prevCubicControl = c2
                cursor = p
            case "S":
                guard let c2 = readPoint(relative: relative),
                      let p = readPoint(relative: relative) else { return path }
                let c1: CGPoint
                if let prev = prevCubicControl {
                    c1 = CGPoint(x: 2 * cursor.x - prev.x, y: 2 * cursor.y - prev.y)
                } else {
                    c1 = cursor
                }
                path.addCurve(to: p, control1: c1, control2: c2)
                prevCubicControl = c2
                cursor = p
            case "Q":
                guard let c1 = readPoint(relative: relative),
                      let p = readPoint(relative: relative) else { return path }
                path.addQuadCurve(to: p, control: c1)
                prevQuadControl = c1
                cursor = p
            case "T":
                guard let p = readPoint(relative: relative) else { return path }
                let c1: CGPoint
                if let prev = prevQuadControl {
                    c1 = CGPoint(x: 2 * cursor.x - prev.x, y: 2 * cursor.y - prev.y)
                } else {
                    c1 = cursor
                }
                path.addQuadCurve(to: p, control: c1)
                prevQuadControl = c1
                cursor = p
            case "A":
                guard let rx = readNumber(), let ry = readNumber(),
                      let rot = readNumber(),
                      let large = readNumber(), let sweep = readNumber(),
                      let p = readPoint(relative: relative) else { return path }
                addArc(to: &path, from: cursor, rx: rx, ry: ry,
                       rotation: rot, largeArc: large != 0, sweep: sweep != 0, end: p)
                cursor = p
            case "Z":
                path.closeSubpath()
                cursor = subpathStart
            default:
                index = d.index(after: index)
            }

            if cmd != "C" && cmd != "c" && cmd != "S" && cmd != "s" { prevCubicControl = nil }
            if cmd != "Q" && cmd != "q" && cmd != "T" && cmd != "t" { prevQuadControl = nil }
        }
        return path
    }

    /// Converts an SVG elliptical arc into cubic bezier segments
    /// (endpoint -> center parameterization, per SVG spec F.6.5).
    private static func addArc(to path: inout Path, from start: CGPoint,
                               rx: Double, ry: Double, rotation: Double,
                               largeArc: Bool, sweep: Bool, end: CGPoint) {
        var rx = abs(rx)
        var ry = abs(ry)
        guard rx > 0, ry > 0, !(start.x == end.x && start.y == end.y) else {
            path.addLine(to: end)
            return
        }

        let phi = rotation * .pi / 180
        let cosP = cos(phi)
        let sinP = sin(phi)
        let dx = (start.x - end.x) / 2
        let dy = (start.y - end.y) / 2
        let x1p = cosP * dx + sinP * dy
        let y1p = -sinP * dx + cosP * dy

        var lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 {
            let s = sqrt(lambda)
            rx *= s
            ry *= s
            lambda = 1
        }

        let numerator = max(0, rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p)
        let denominator = rx * rx * y1p * y1p + ry * ry * x1p * x1p
        var coef = denominator == 0 ? 0 : sqrt(numerator / denominator)
        if largeArc == sweep { coef = -coef }
        let cxp = coef * rx * y1p / ry
        let cyp = coef * -ry * x1p / rx
        let cx = cosP * cxp - sinP * cyp + (start.x + end.x) / 2
        let cy = sinP * cxp + cosP * cyp + (start.y + end.y) / 2

        func angle(_ ux: Double, _ uy: Double, _ vx: Double, _ vy: Double) -> Double {
            let len = hypot(ux, uy) * hypot(vx, vy)
            guard len > 0 else { return 0 }
            var a = acos(Swift.min(1, Swift.max(-1, (ux * vx + uy * vy) / len)))
            if ux * vy - uy * vx < 0 { a = -a }
            return a
        }

        let v1x = (x1p - cxp) / rx
        let v1y = (y1p - cyp) / ry
        let theta1 = angle(1, 0, v1x, v1y)
        var deltaTheta = angle(v1x, v1y, -v1x - 2 * cxp / rx, -v1y - 2 * cyp / ry)
        if !sweep && deltaTheta > 0 { deltaTheta -= 2 * .pi }
        if sweep && deltaTheta < 0 { deltaTheta += 2 * .pi }

        let segments = max(1, Int(ceil(abs(deltaTheta) / (Double.pi / 2))))
        let segmentAngle = deltaTheta / Double(segments)
        let alpha = 4.0 / 3.0 * tan(segmentAngle / 4)

        func ellipsePoint(_ t: Double) -> CGPoint {
            CGPoint(
                x: cx + rx * cosP * cos(t) - ry * sinP * sin(t),
                y: cy + rx * sinP * cos(t) + ry * cosP * sin(t)
            )
        }
        func ellipseDerivative(_ t: Double) -> CGPoint {
            CGPoint(
                x: -rx * cosP * sin(t) - ry * sinP * cos(t),
                y: -rx * sinP * sin(t) + ry * cosP * cos(t)
            )
        }

        for segment in 0..<segments {
            let t1 = theta1 + Double(segment) * segmentAngle
            let t2 = t1 + segmentAngle
            let e1 = ellipsePoint(t1)
            let e2 = ellipsePoint(t2)
            let d1 = ellipseDerivative(t1)
            let d2 = ellipseDerivative(t2)
            path.addCurve(
                to: e2,
                control1: CGPoint(x: e1.x + alpha * d1.x, y: e1.y + alpha * d1.y),
                control2: CGPoint(x: e2.x - alpha * d2.x, y: e2.y - alpha * d2.y)
            )
        }
    }
}
