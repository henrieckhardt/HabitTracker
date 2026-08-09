import Foundation

/// Computes the new `sortOrder` value for an item dropped between two
/// neighbors after a drag-and-drop move, using the standard fractional/
/// midpoint indexing technique — only the moved row's value changes, no
/// renumbering of the rest of the list is needed.
enum DisplayOrderReordering {
    static func newSortOrder(before: Double?, after: Double?) -> Double {
        switch (before, after) {
        case let (before?, after?):
            return (before + after) / 2
        case let (before?, nil):
            return before + 1
        case let (nil, after?):
            return after - 1
        case (nil, nil):
            return 0
        }
    }
}
