import SwiftUI

// v2 settings page kit: dashboards built from a 3-column grid of solid tiles.
// Glass is used only for the floating chip bar on top of a preview (HIG: glass on controls, not content).

enum V2 {
    static let blue = Color(red: 10 / 255, green: 132 / 255, blue: 1)
    static let green = Color(red: 48 / 255, green: 209 / 255, blue: 88 / 255)
    static let orange = Color(red: 1, green: 159 / 255, blue: 10 / 255)

    /// Short bilingual copy for v2 labels (same approach as AboutAppSettingsView).
    static func text(_ locale: Locale, _ vi: String, _ en: String) -> String {
        locale.language.languageCode?.identifier == "vi" ? vi : en
    }
}

// MARK: - Page + grid

/// Scrolling v2 page: grid rows stacked with 14 pt gaps, 22 pt side margins.
struct V2Page<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) { content }
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
                .frame(maxWidth: 980, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct V2SpanKey: LayoutValueKey { static let defaultValue = 1 }

extension View {
    /// Number of the row's columns this tile covers (default 1).
    func v2Span(_ span: Int) -> some View { layoutValue(key: V2SpanKey.self, value: span) }
}

/// A row of tiles sharing `columns` equal columns; every tile in the row gets the same height.
struct V2Row: Layout {
    var columns = 3
    var spacing: CGFloat = 14

    private func widths(_ subviews: Subviews, total: CGFloat) -> [CGFloat] {
        let unit = (total - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        return subviews.map { sub in
            let span = min(columns, max(1, sub[V2SpanKey.self]))
            return unit * CGFloat(span) + spacing * CGFloat(span - 1)
        }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let total = proposal.width ?? 600
        let ws = widths(subviews, total: total)
        let height = zip(subviews, ws).map { $0.sizeThatFits(.init(width: $1, height: nil)).height }.max() ?? 0
        return CGSize(width: total, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for (sub, w) in zip(subviews, widths(subviews, total: bounds.width)) {
            sub.place(at: CGPoint(x: x, y: bounds.minY), proposal: .init(width: w, height: bounds.height))
            x += w + spacing
        }
    }
}

// MARK: - Tiles

/// Solid content tile with an optional title, hint and trailing accessory.
struct V2Tile<Accessory: View, Content: View>: View {
    var title: String?
    var hint: String?
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if title != nil || hint != nil {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        if let title {
                            Text(verbatim: title).font(.system(size: 13, weight: .semibold))
                                .accessibilityAddTraits(.isHeader)
                        }
                        if let hint {
                            Text(verbatim: hint).font(.system(size: 11)).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 8)
                    accessory
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SettingsSolidCardSurface(cornerRadius: 16))
    }
}

extension V2Tile where Accessory == EmptyView {
    init(title: String? = nil, hint: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(title: title, hint: hint, accessory: { EmptyView() }, content: content)
    }
}

/// Big value + slider, e.g. "Độ trong 100%".
struct V2ValueTile: View {
    let title: String
    var hint: String?
    let valueText: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var identifier: String?

    var body: some View {
        V2Tile(title: title, hint: hint) {
            Text(verbatim: valueText)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .accessibilityHidden(true)
            Spacer(minLength: 0)
            Slider(value: $value, in: range, step: step)
                .tint(V2.blue)
                .accessibilityLabel(Text(verbatim: title))
                .accessibilityValue(Text(verbatim: valueText))
                .accessibilityIdentifier(identifier ?? "")
        }
    }
}

// MARK: - Controls

/// Pill segmented control; selected pill is solid blue.
struct V2Chips<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> Text
    var identifier: String?

    var body: some View {
        // Pills when they fit, a menu when the tile is too narrow.
        ViewThatFits(in: .horizontal) {
            pills
            Picker(selection: $selection) {
                ForEach(options, id: \.self) { title($0).tag($0) }
            } label: { EmptyView() }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
                .accessibilityIdentifier(identifier ?? "")
        }
    }

    private var pills: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let isOn = option == selection
                Button { withAnimation(.snappy(duration: 0.2)) { selection = option } } label: {
                    title(option)
                        .font(.system(size: 12, weight: isOn ? .semibold : .regular))
                        .lineLimit(1)
                        .padding(.horizontal, 11)
                        .frame(height: 26)
                        .foregroundStyle(isOn ? Color.white : Color.primary)
                        .background {
                            if isOn { Capsule().fill(V2.blue.opacity(0.9)) }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Capsule().fill(.primary.opacity(0.07)))
        .overlay(Capsule().strokeBorder(.primary.opacity(0.10)))
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier ?? "")
    }
}

/// Large selectable option card with a small visual on top (styles, shapes).
struct V2OptionCard<Visual: View>: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder var visual: Visual

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                visual
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.black.opacity(0.35)))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isSelected ? V2.blue : .primary.opacity(0.12), lineWidth: isSelected ? 1.5 : 1))
                Text(verbatim: title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

struct V2ToggleItem: Identifiable {
    let id: String
    let label: String
    var note: String?
    let isOn: Binding<Bool>
    var isDisabled = false
}

/// Stack of label/note + switch rows separated by hairlines.
struct V2ToggleList: View {
    let items: [V2ToggleItem]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { Rectangle().fill(.primary.opacity(0.08)).frame(height: 1) }
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: item.label).font(.system(size: 13))
                        if let note = item.note {
                            Text(verbatim: note).font(.system(size: 11)).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Toggle(isOn: item.isOn) { Text(verbatim: item.label) }
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(V2.green)
                }
                .disabled(item.isDisabled)
                .opacity(item.isDisabled ? 0.5 : 1)
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("settings.v2.toggle.\(item.id)")
            }
        }
    }
}

/// Status pill ("Đã cấp", "Đang bật").
struct V2Pill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.16)))
    }
}

// MARK: - Stage

/// Preview stage: content on a rounded plane, a floating glass chip bar at the bottom.
struct V2Stage<Preview: View, Bar: View>: View {
    var height: CGFloat = 250
    var caption: String?
    @ViewBuilder var preview: Preview
    @ViewBuilder var bar: Bar

    var body: some View {
        ZStack(alignment: .bottom) {
            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(spacing: 6) {
                bar
                    .padding(3)
                    .background { CrystalGlassSurface(cornerRadius: 16) }
                if let caption {
                    Text(verbatim: caption).font(.system(size: 11)).foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.bottom, 12)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.10)))
    }
}

/// Collapsed "All settings" section that keeps every original control reachable.
struct V2MoreSettings<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.snappy(duration: 0.25)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .accessibilityHidden(true)
                    Text(verbatim: title).font(.system(size: 13, weight: .semibold))
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(Text(verbatim: isExpanded ? "expanded" : "collapsed"))
            .accessibilityIdentifier("settings.v2.more")
            if isExpanded {
                VStack(alignment: .leading, spacing: 20) { content }
                    .padding(.horizontal, -10)
            }
        }
        .padding(.top, 6)
    }
}
