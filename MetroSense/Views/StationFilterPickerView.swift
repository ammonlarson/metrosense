import SwiftUI

struct StationFilterPickerView: View {
    @Binding var filter: NotificationSettings.StationFilter
    let allStationNames: [String]
    var pickerLabel: String = "Stations"

    @State private var isExpanded: Bool = false
    @State private var displayOrder: [String] = []
    @State private var lastSelected: Set<String> = []

    init(
        filter: Binding<NotificationSettings.StationFilter>,
        allStationNames: [String],
        pickerLabel: String = "Stations"
    ) {
        _filter = filter
        self.allStationNames = allStationNames
        self.pickerLabel = pickerLabel
        _displayOrder = State(initialValue: allStationNames)
        if case .selected(let stations) = filter.wrappedValue {
            _lastSelected = State(initialValue: stations)
        }
    }

    var body: some View {
        Group {
            Picker(pickerLabel, selection: filterBinding) {
                Text("All Stations").tag(true)
                Text("Selected Stations").tag(false)
            }

            if case .selected(let selected) = filter {
                if selected.isEmpty {
                    Text("Select at least one station.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                DisclosureGroup(isExpanded: expandedBinding) {
                    ForEach(displayOrder, id: \.self) { name in
                        Button {
                            toggleStation(name, in: selected)
                        } label: {
                            HStack {
                                Text(name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selected.contains(name) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                } label: {
                    Text("\(selected.count) of \(allStationNames.count) stations selected")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var filterBinding: Binding<Bool> {
        Binding(
            get: {
                if case .all = filter { return true }
                return false
            },
            set: { isAll in
                if isAll {
                    if case .selected(let current) = filter {
                        lastSelected = current
                    }
                    isExpanded = false
                    filter = .all
                } else {
                    filter = .selected(lastSelected)
                }
            }
        )
    }

    private var expandedBinding: Binding<Bool> {
        Binding(
            get: { isExpanded },
            set: { newValue in
                if newValue, case .selected(let selected) = filter {
                    displayOrder = computeDisplayOrder(selected: selected)
                }
                isExpanded = newValue
            }
        )
    }

    private func toggleStation(_ name: String, in selected: Set<String>) {
        var updated = selected
        if updated.contains(name) {
            updated.remove(name)
        } else {
            updated.insert(name)
        }
        filter = .selected(updated)
        lastSelected = updated
    }

    private func computeDisplayOrder(selected: Set<String>) -> [String] {
        let selectedNames = allStationNames.filter { selected.contains($0) }
        let unselectedNames = allStationNames.filter { !selected.contains($0) }
        return selectedNames + unselectedNames
    }
}
