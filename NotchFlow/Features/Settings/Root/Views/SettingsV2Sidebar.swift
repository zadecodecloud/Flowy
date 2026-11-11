import SwiftUI
internal import AppKit

/// v2 settings sidebar: app tile, search (⌘K), five categories where the active one
/// expands to its pages, and the account chip at the bottom. Glass lives only here.
struct SettingsV2Sidebar: View {
    typealias Section = SettingsRootViewModel.Section
    typealias Group = SettingsRootViewModel.SidebarGroup

    let groups: [(group: Group, sections: [Section])]
    let selected: Section
    @Binding var searchText: String
    let isPro: Bool
    let isUpdateAvailable: Bool
    let localized: (String, String?) -> String
    let onSelect: (Section) -> Void
    /// Category showing its overview page instead of a single page (Thông báo).
    var overviewGroup: Group?
    var onOpenGroup: (Group) -> Void = { _ in }
    var isLicenseOpen = false
    var onOpenLicense: () -> Void = {}

    /// Categories the user has expanded; the selected page's category opens automatically.
    @State private var expanded: Set<Group> = []

    @FocusState private var searchFocused: Bool

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            appTile
            searchField
            Rectangle().fill(.primary.opacity(0.10)).frame(height: 1).padding(.horizontal, 4).padding(.vertical, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(groups, id: \.group.id) { entry in
                        categoryRow(entry.group, sections: entry.sections)
                        if isSearching || (isExpandable(entry) && expanded.contains(entry.group)) {
                            if entry.group.hasOverview && !isSearching { overviewRow(entry.group) }
                            ForEach(entry.sections) { section in
                                pageRow(section)
                            }
                        }
                    }
                    if !isSearching { licenseRow }
                }
                .animation(.spring(duration: 0.3), value: expanded)
            }
            .scrollIndicators(.never)
            .overlay {
                if groups.isEmpty && isSearching {
                    Text(localized("notchflow.settings.noResults", "No matching settings"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            SettingsAccountChip(isPro: isPro)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.black.opacity(0.25)))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.10)))
        }
        .padding(.horizontal, 12)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background { CrystalGlassSurface(cornerRadius: 18) }
        .padding(10)
        .onAppear { expanded.insert(selected.sidebarGroup) }
        .onChange(of: selected) { expanded.insert(selected.sidebarGroup) }
        .background {
            // ⌘K focuses search, like the hint says.
            Button("") { searchFocused = true }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
                .accessibilityHidden(true)
        }
    }

    private var appTile: some View {
        HStack(spacing: 10) {
            // The app's own icon (capsule on dark squircle), same as Dock and Finder.
            Image(nsImage: Self.appIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: "NotchFlow").font(.system(size: 14, weight: .semibold))
                Text(verbatim: "\(isPro ? "Pro" : localized("settings.account.free", "Free Version")) · \(Self.version)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.black.opacity(0.25)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.12)))
        .accessibilityElement(children: .combine)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(localized("notchflow.settings.search", "Search settings"), text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($searchFocused)
                .accessibilityIdentifier("settings.sidebar.search")
            Text(verbatim: "⌘K")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.primary.opacity(0.14)))
                .accessibilityHidden(true)
        }
        .frame(height: 34)
        .padding(.horizontal, 10)
        .padding(.top, 6)
    }

    /// A category with a single page and no overview opens that page directly.
    private func isExpandable(_ entry: (group: Group, sections: [Section])) -> Bool {
        entry.sections.count > 1 || entry.group.hasOverview
    }

    private func categoryRow(_ group: Group, sections: [Section]) -> some View {
        let entry = (group: group, sections: sections)
        let expandable = isExpandable(entry)
        let isOpen = expanded.contains(group)
        let isDirectActive = !expandable && sections.first == selected && overviewGroup == nil && !isLicenseOpen
        let title = localized(group.titleKey ?? "", group.fallbackTitle)
        return Button {
            if expandable && !isSearching {
                if isOpen { expanded.remove(group) } else { expanded.insert(group) }
            } else if let first = sections.first {
                onSelect(first)
            }
        } label: {
            row(icon: group.v2Icon, iconOpacity: 1, title: title,
                chevron: expandable && !isSearching ? isOpen : nil,
                isActive: isDirectActive, indent: 10,
                weight: (expandable && isOpen) || isDirectActive ? .semibold : .regular, color: .primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text(verbatim: expandable ? (isOpen ? "expanded" : "collapsed") : ""))
        .accessibilityIdentifier("settings.sidebar.group.\(group.rawValue)")
    }

    private func overviewRow(_ group: Group) -> some View {
        let isActive = overviewGroup == group && !isLicenseOpen
        return Button { onOpenGroup(group) } label: {
            row(icon: "square.grid.2x2", iconOpacity: 0.6, title: localized("settings.overview.title", "Overview"),
                isActive: isActive, indent: 22, weight: .regular, color: isActive ? .primary : .secondary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .accessibilityIdentifier("settings.sidebar.overview.\(group.rawValue)")
    }

    private var licenseRow: some View {
        Button(action: onOpenLicense) {
            row(icon: isPro ? "checkmark.seal.fill" : "seal", iconColor: isPro ? Color(red: 0x1D / 255, green: 0x9B / 255, blue: 0xF0 / 255) : nil,
                iconOpacity: 1, title: localized("settings.license.title", "License"),
                isActive: isLicenseOpen, indent: 10, weight: isLicenseOpen ? .semibold : .regular, color: .primary)
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
        .accessibilityAddTraits(isLicenseOpen ? .isSelected : [])
        .accessibilityIdentifier("settings.sidebar.license")
    }

    private func pageRow(_ section: Section) -> some View {
        let isActive = section == selected && overviewGroup == nil && !isLicenseOpen
        let showsUpdate = (section == .about || section == .general) && isUpdateAvailable
        return Button { onSelect(section) } label: {
            row(icon: section.systemImage, iconOpacity: 0.6,
                title: localized(section.titleKey, section.fallbackTitle),
                dot: showsUpdate, isActive: isActive, indent: 22,
                weight: .regular, color: isActive ? .primary : .secondary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .accessibilityIdentifier("settings.sidebar.\(section.rawValue)")
    }

    private func row(icon: String, iconColor: Color? = nil, iconOpacity: Double, title: String, chevron: Bool? = nil, dot: Bool = false,
                     isActive: Bool, indent: CGFloat, weight: Font.Weight, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(iconColor ?? color)
                .frame(width: 16)
                .opacity(iconOpacity)
                .accessibilityHidden(true)
            Text(verbatim: title)
                .font(.system(size: 13, weight: weight))
                .lineLimit(1)
            Spacer(minLength: 4)
            if dot {
                Circle().fill(Color.red).frame(width: 7, height: 7).accessibilityHidden(true)
            }
            if let chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(chevron ? 90 : 0))
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(color)
        .padding(.leading, indent)
        .padding(.trailing, 10)
        .frame(height: 34)
        .contentShape(Rectangle())
        .background {
            if isActive {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.primary.opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.primary.opacity(0.14)))
                    .overlay(alignment: .top) {
                        Rectangle().fill(.white.opacity(0.18)).frame(height: 1).padding(.horizontal, 8)
                    }
            }
        }
    }

    /// Read from the bundle so a stale Launch Services icon cache can't show the generic icon.
    private static let appIcon: NSImage = Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
        .flatMap(NSImage.init(contentsOf:)) ?? NSApp.applicationIconImage

    private static let version = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
}

extension SettingsRootViewModel.SidebarGroup {
    /// Categories whose row opens an overview page (v2 Thông báo table).
    var hasOverview: Bool { self == .alerts }

    /// SF Symbol for the v2 category row.
    var v2Icon: String {
        switch self {
        case .notch: return "menubar.rectangle"
        case .pages: return "rectangle.split.3x1"
        case .alerts: return "bell"
        case .lockScreen: return "lock"
        case .application: return "gearshape"
        }
    }
}
