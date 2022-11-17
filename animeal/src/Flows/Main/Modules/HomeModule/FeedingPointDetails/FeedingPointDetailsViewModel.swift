import Foundation

final class FeedingPointDetailsViewModel: FeedingPointDetailsViewModelLifeCycle,
                                          FeedingPointDetailsViewInteraction,
                                          FeedingPointDetailsViewState {
    // MARK: - Dependencies
    private let model: FeedingPointDetailsModelProtocol
    private let coordinator: FeedingPointCoordinatable
    private let contentMapper: FeedingPointDetailsViewMappable

    // MARK: - State
    var onContentHaveBeenPrepared: ((FeedingPointDetailsViewItem) -> Void)?
    var onMediaContentHaveBeenPrepared: ((FeedingPointMediaContent) -> Void)?

    // MARK: - Initialization
    init(
        model: FeedingPointDetailsModelProtocol,
        contentMapper: FeedingPointDetailsViewMappable,
        coordinator: FeedingPointCoordinatable
    ) {
        self.model = model
        self.contentMapper = contentMapper
        self.coordinator = coordinator
        setup()
    }

    // MARK: - Life cycle
    func setup() {
    }

    func load() {
        model.fetchFeedingPoints { [weak self] content in
            guard let self = self else { return }
            self.loadMediaContent(content.content.header.cover)
            self.onContentHaveBeenPrepared?(
                self.contentMapper.mapFeedingPoint(content)
            )
        }
    }

    private func loadMediaContent(_ key: String?) {
        guard let key = key else { return }
        model.fetchMediaContent(key: key) { [weak self] content in
            guard let self = self else { return }
            if let mediaContent = self.contentMapper.mapFeedingPointMediaContent(content) {
                self.onMediaContentHaveBeenPrepared?(mediaContent)
            }
        }
    }

    // MARK: - Interaction
    func handleActionEvent(_ event: FeedingPointEvent) {
        switch event {
        case .tapAction:
            coordinator.routeTo(.dismiss)
        }
    }
}
