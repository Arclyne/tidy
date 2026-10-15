import SwiftUI
import TidyCore

@MainActor
protocol ItemSelecting: AnyObject {
    var selectedItemIDs: Set<URL> { get set }
}

extension ItemSelecting {
    func selectionBinding(for item: ScanItem) -> Binding<Bool> {
        Binding(
            get: { [unowned self] in
                self.selectedItemIDs.contains(item.id)
            },
            set: { [unowned self] isSelected in
                if isSelected {
                    self.selectedItemIDs.insert(item.id)
                } else {
                    self.selectedItemIDs.remove(item.id)
                }
            }
        )
    }

    func selectionBindings(for items: [ScanItem]) -> [Binding<Bool>] {
        items.map { selectionBinding(for: $0) }
    }
}
