import TapaCore

/// Which websites the Leave Behind table shows.
enum LeaveBehindFilter: Hashable {
    case all
    case list(LeaveBehindList.ID)

    var listID: LeaveBehindList.ID? {
        switch self {
        case .all: nil
        case .list(let id): id
        }
    }
}
