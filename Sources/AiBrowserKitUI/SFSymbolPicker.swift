import SwiftUI

/// Searchable SF Symbol grid picker.
public struct SFSymbolPicker: View {
    /// Binding to the currently selected SF Symbol name.
    @Binding public var selectedSymbol: String
    @State private var searchText: String = ""

    /// Creates an SF Symbol picker bound to a selected symbol name.
    ///
    /// - Parameter selectedSymbol: Binding that receives the picked symbol.
    public init(selectedSymbol: Binding<String>) {
        _selectedSymbol = selectedSymbol
    }

    private var filtered: [String] {
        if searchText.isEmpty { return SFSymbolList.all }
        let query = searchText.lowercased()
        return SFSymbolList.all.filter { $0.contains(query) }
    }

    /// Renders search, symbol grid, and current selection summary.
    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                TextField("Search symbols...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.body)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 36), spacing: 4)], spacing: 4) {
                    ForEach(filtered, id: \.self) { name in
                        symbolCell(name)
                    }
                }
                .padding(8)
            }
            .frame(height: 180)

            HStack(spacing: 6) {
                Image(systemName: selectedSymbol.isEmpty ? "globe" : selectedSymbol)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.accentColor)
                Text(selectedSymbol.isEmpty ? "globe" : selectedSymbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(filtered.count) symbols")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }

    private func symbolCell(_ name: String) -> some View {
        let isActive = name == selectedSymbol
        return Button { selectedSymbol = name } label: {
            Image(systemName: name)
                .font(.system(size: 14))
                .foregroundStyle(isActive ? Color.accentColor : Color.primary)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isActive ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(name)
    }
}

// MARK: - SF Symbol Name List

public enum SFSymbolList {
    /// Curated set of SF Symbol names offered by `SFSymbolPicker`.
    public static let all: [String] = [
        "globe", "globe.americas", "globe.europe.africa", "globe.asia.australia",
        "network", "wifi", "antenna.radiowaves.left.and.right",
        "link", "link.circle", "safari", "desktopcomputer",
        "chevron.left.forwardslash.chevron.right", "terminal", "terminal.fill",
        "hammer", "hammer.fill", "wrench", "wrench.fill",
        "gearshape", "gearshape.fill", "gearshape.2", "gearshape.2.fill",
        "cpu", "cpu.fill", "memorychip", "memorychip.fill",
        "server.rack", "externaldrive", "externaldrive.fill",
        "chart.bar", "chart.bar.fill", "chart.pie", "chart.pie.fill",
        "chart.line.uptrend.xyaxis", "chart.xyaxis.line",
        "gauge", "speedometer",
        "cloud", "cloud.fill", "cloud.bolt", "icloud", "icloud.fill",
        "arrow.triangle.2.circlepath", "arrow.clockwise",
        "paperplane", "paperplane.fill", "shippingbox", "shippingbox.fill",
        "lock", "lock.fill", "lock.open", "lock.shield", "lock.shield.fill",
        "shield", "shield.fill", "key", "key.fill",
        "envelope", "envelope.fill", "bubble.left", "bubble.right",
        "bell", "bell.fill", "bell.badge", "bell.badge.fill",
        "doc", "doc.fill", "doc.text", "doc.text.fill",
        "doc.on.doc", "folder", "folder.fill", "folder.badge.plus",
        "archivebox", "archivebox.fill", "book", "book.fill",
        "bookmark", "bookmark.fill",
        "rectangle.grid.2x2", "square.grid.2x2", "square.grid.3x3",
        "sidebar.left", "sidebar.right", "tablecells", "tablecells.fill",
        "list.bullet", "list.dash", "list.number",
        "play", "play.fill", "play.circle", "play.circle.fill",
        "photo", "photo.fill", "camera", "camera.fill",
        "person", "person.fill", "person.2", "person.2.fill",
        "person.crop.circle", "person.crop.circle.fill",
        "checkmark", "checkmark.circle", "checkmark.circle.fill",
        "xmark", "xmark.circle", "exclamationmark.triangle",
        "info.circle", "bolt", "bolt.fill", "flame", "flame.fill",
        "lightbulb", "lightbulb.fill",
        "star", "star.fill", "heart", "heart.fill",
        "flag", "flag.fill", "tag", "tag.fill",
        "pin", "pin.fill", "mappin", "location", "location.fill",
        "clock", "clock.fill", "timer", "calendar", "calendar.badge.plus",
        "arrow.up", "arrow.down", "arrow.left", "arrow.right",
        "arrow.up.arrow.down", "arrow.up.right.square",
        "creditcard", "creditcard.fill", "cart", "cart.fill",
        "dollarsign.circle", "dollarsign.circle.fill",
        "atom", "function", "brain", "brain.head.profile",
        "pencil", "pencil.circle", "square.and.pencil",
        "wand.and.stars", "sparkles", "wand.and.rays",
        "puzzlepiece", "puzzlepiece.fill",
        "trash", "trash.fill", "eye", "eye.fill",
        "hand.raised", "hand.raised.fill",
        "display", "laptopcomputer", "iphone",
        "house", "house.fill", "building.2", "building.2.fill",
        "leaf", "leaf.fill", "sun.max", "sun.max.fill", "moon", "moon.fill",
    ]
}
