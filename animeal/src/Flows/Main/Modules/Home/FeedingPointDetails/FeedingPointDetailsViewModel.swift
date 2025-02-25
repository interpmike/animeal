import Foundation
import CoreLocation
import UIComponents
import Services

final class FeedingPointDetailsViewModel: FeedingPointDetailsViewModelLifeCycle,
                                          FeedingPointDetailsViewInteraction,
                                          FeedingPointDetailsViewState {
    // MARK: - Dependencies
    private let model: (FeedingPointDetailsModelProtocol & FeedingPointDetailsDataStoreProtocol)
    private let coordinator: FeedingPointCoordinatable
    private let contentMapper: FeedingPointDetailsViewMappable
    private let locationService: LocationServiceProtocol

    // MARK: - State
    var onContentHaveBeenPrepared: ((FeedingPointDetailsViewMapper.FeedingPointDetailsViewItem) -> Void)?
    var onFeedingHistoryHaveBeenPrepared: ((FeedingPointDetailsViewMapper.FeedingPointFeeders) -> Void)?
    var onMediaContentHaveBeenPrepared: ((FeedingPointDetailsViewMapper.FeedingPointMediaContent) -> Void)?
    var onFavoriteMutationFailed: (() -> Void)?
    var onFavoriteMutation: (() -> Void)?
    var onRequestLocationAccess: (() -> Void)?
    var historyInitialized = false

    // TODO: Move this strange logic to model
    let isOverMap: Bool
    private var shouldShowOnMap = true
    var showOnMapAction: ButtonView.Model? {
        if isOverMap { return .none }

        if !shouldShowOnMap { return .none }

        return ButtonView.Model(
            identifier: UUID().uuidString,
            viewType: TextButtonView.self,
            title: L10n.Action.showOnMap
        )
    }

    let shimmerScheduler = ShimmerViewScheduler()

    // MARK: - Initialization
    init(
        isOverMap: Bool,
        model: (FeedingPointDetailsModelProtocol & FeedingPointDetailsDataStoreProtocol),
        locationService: LocationServiceProtocol = AppDelegate.shared.context.locationService,
        contentMapper: FeedingPointDetailsViewMappable,
        coordinator: FeedingPointCoordinatable
    ) {
        self.isOverMap = isOverMap
        self.model = model
        self.contentMapper = contentMapper
        self.coordinator = coordinator
        self.locationService = locationService
        setup()
    }

    // MARK: - Life cycle
    func setup() { }

    func load() {
        model.fetchFeedingPoint { [weak self] content in
            DispatchQueue.main.async {
                self?.updateContent(content)
            }
        }
        model.fetchFeedingHistory { [weak self] content in
            DispatchQueue.main.async {
                self?.historyInitialized = true
                self?.updateFeedingHistoryContent(content)
            }
        }
        model.onFeedingPointChange = { [weak self] content, mutateFavorites in
            DispatchQueue.main.async {
                if mutateFavorites {
                    self?.updateFavorites()
                } else {
                    self?.updateContent(content)
                }
            }
        }
    }

    private func loadMediaContent(_ key: String?) {
        guard let key = key else { return }
        model.fetchMediaContent(key: key) { [weak self] content in
            if let mediaContent = self?.contentMapper.mapFeedingPointMediaContent(content) {
                DispatchQueue.main.async {
                    self?.onMediaContentHaveBeenPrepared?(mediaContent)
                }
            }
        }
    }

    private func updateContent(_ modelContent: FeedingPointDetailsModel.PointContent) {
        shouldShowOnMap = modelContent.action.isEnabled
        loadMediaContent(modelContent.content.header.cover)
        onContentHaveBeenPrepared?(contentMapper.mapFeedingPoint(modelContent))
    }

    private func updateFavorites() {
        onFavoriteMutation?()
    }

    private func updateFeedingHistoryContent(_ modelContent: [FeedingPointDetailsModel.Feeder]) {
        let mappedContent = contentMapper.mapFeedingHistory(modelContent)
        onFeedingHistoryHaveBeenPrepared?(mappedContent)
    }

    // MARK: - Interaction
    func handleActionEvent(_ event: FeedingPointEvent) {
        switch event {
        case .tapAction:
            switch self.locationService.locationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                coordinator.routeTo(
                    .feed(
                        FeedingPointFeedDetails(
                            identifier: model.feedingPointId,
                            coordinates: model.feedingPointLocation
                        )
                    )
                )

            case .denied, .restricted, .notDetermined:
                self.onRequestLocationAccess?()

            default:
                break
            }

        case .tapFavorite:
            Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    let success = try await model.mutateFavorite()
                    if !success {
                        self.onFavoriteMutationFailed?()
                    }
                } catch {
                    self.onFavoriteMutationFailed?()
                }
            }

        case .tapShowOnMap:
            coordinator.routeTo(
                .map(identifier: model.feedingPointId)
            )

        case .tapCancelLocationRequest:
            coordinator.routeTo(
                .feed(
                    FeedingPointFeedDetails(
                        identifier: model.feedingPointId,
                        coordinates: model.feedingPointLocation
                    )
                )
            )
        }
    }
}
