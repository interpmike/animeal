import Foundation

enum SearchViewActionEvent {
    case sectionDidTap(String)
    case itemDidTap(String)
    case filterDidTap(String)
    case toggleFavorite(String)
}
