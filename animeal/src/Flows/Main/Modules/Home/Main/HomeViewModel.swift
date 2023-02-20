import Services
import Common
import CoreLocation
import Amplify

final class HomeViewModel: HomeViewModelLifeCycle, HomeViewInteraction, HomeViewState {
    // MARK: - Dependencies
    private let model: HomeModelProtocol
    private let locationService: LocationServiceProtocol
    private let feedingPointViewMapper: FeedingPointViewMappable
    private let segmentsViewMapper: FilterViewMappable
    private let feedingActionMapper: FeedingActionMapper
    private var coordinator: HomeCoordinatable & HomeCoordinatorEventHandlerProtocol
    private var feedingStatus: FeedingResponse.Status = .none
    private enum Constants {
        static let feedingCountdownTimer: TimeInterval = 3600
    }

    // MARK: - State
    var onFeedingPointsHaveBeenPrepared: (([FeedingPointViewItem]) -> Void)?
    var onFeedingPointCameraMoveRequired: ((FeedingPointCameraMove) -> Void)?
    var onSegmentsHaveBeenPrepared: ((FilterModel) -> Void)?
    var onRouteRequestHaveBeenPrepared: ((FeedingPointRouteRequest) -> Void)?
    var onFeedingActionHaveBeenPrepared: ((FeedingActionMapper.FeedingAction) -> Void)?
    var onFeedingHaveBeenCompleted: (() -> Void)?

    // MARK: - Initialization
    init(
        model: HomeModelProtocol,
        coordinator: HomeCoordinatable & HomeCoordinatorEventHandlerProtocol,
        locationService: LocationServiceProtocol = AppDelegate.shared.context.locationService,
        feedingPointViewMapper: FeedingPointViewMappable = FeedingPointViewMapper(),
        feedingActionMapper: FeedingActionMapper = FeedingActionMapper(),
        segmentsViewMapper: FilterViewMappable = SegmentedControlMapper()
    ) {
        self.model = model
        self.locationService = locationService
        self.feedingPointViewMapper = feedingPointViewMapper
        self.feedingActionMapper = feedingActionMapper
        self.segmentsViewMapper = segmentsViewMapper
        self.coordinator = coordinator
    }

    // MARK: - Life cycle
    func setup() {
        coordinator.moveToFeedingPointEvent = { [weak self] in
            self?.handleMoveToFeedingPoint(pointId: $0)
        }
    }

    func load() {
        Task { [weak self] in
            guard let self else { return }
            let hasUnfinishedFeeding = await fetchUnfinishedFeeding()
            if !hasUnfinishedFeeding {
                self.fetchFeedingPoints(isInitialLoad: true)
            }
            self.fetchFilterItems()
            self.startFeedingPoinsEventsListener()
        }
    }

    // MARK: - Interaction
    func handleActionEvent(_ event: HomeViewActionEvent) {
        switch event {
        case .tapFeedingPoint(let pointId):
            handleTapFeedingPoint(pointId: pointId)
        case .tapFilterControl(let filterItemId):
            guard let itemIdentifier = HomeModel.FilterItemIdentifier(rawValue: filterItemId) else {
                logError("[APP] \(#function) no filter with \(filterItemId)")
                return
            }
            model.proceedFilter(itemIdentifier)
            fetchFeedingPoints()
        case .tapCancelFeeding:
            let action = model.fetchFeedingAction(request: .cancelFeeding)
            onFeedingActionHaveBeenPrepared?(feedingActionMapper.mapFeedingAction(action))
        case .autoCancelFeeding:
            let action = model.fetchFeedingAction(request: .autoCancelFeeding)
            onFeedingActionHaveBeenPrepared?(feedingActionMapper.mapFeedingAction(action))
        case .confirmCancelFeeding:
            handleConfirmCancelFeeding()
        }
    }

    func fetchUnfinishedFeeding() async -> Bool {
        guard
            let snapshot = model.fetchFeedingSnapshot(),
            (Date.now - Constants.feedingCountdownTimer) < snapshot.feedStartingDate
        else {
            return false
        }
        do {
            let feedingPoint = try await model.fetchFeedingPoint(snapshot.pointId)
            let pointItemView = feedingPointViewMapper.mapFeedingPoint(feedingPoint)
            // Update view with feedingPoint details
            onFeedingPointsHaveBeenPrepared?([pointItemView])
            // Request build route
            let timePassSinceFeedingStarted = Date.now - snapshot.feedStartingDate
            onRouteRequestHaveBeenPrepared?(
                .init(
                    feedingPointCoordinates: pointItemView.coordinates,
                    countdownTime: Constants.feedingCountdownTimer - timePassSinceFeedingStarted,
                    feedingPointId: snapshot.pointId,
                    isUnfinishedFeeding: true
                )
            )
            feedingStatus = .progress
            return true
        } catch {
            return false
        }
    }

    func startFeeding(feedingPointId id: String) {
        coordinator.displayActivityIndicator { [weak self] in
            guard let self else { return }
            let result = try await self.model.processStartFeeding(feedingPointId: id)
            let feedingPoint = try await self.model.fetchFeedingPoint(result.feedingPoint)
            let pointItemView = self.feedingPointViewMapper.mapFeedingPoint(feedingPoint)
            self.onFeedingPointsHaveBeenPrepared?([pointItemView])
            self.feedingStatus = result.feedingStatus
        }
    }

    func finishFeeding(imageKeys: [String]) {
        let task = { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.model.processFinishFeeding(imageKeys: imageKeys)
                let feedingPoint = try await self.model.fetchFeedingPoint(result.feedingPoint)
                let pointItemView = self.feedingPointViewMapper.mapFeedingPoint(feedingPoint)
                self.onFeedingPointsHaveBeenPrepared?([pointItemView])
                self.feedingStatus = result.feedingStatus
                self.onFeedingHaveBeenCompleted?()
                self.coordinator.routeTo(.feedingComplete)
            } catch {
                self.coordinator.displayAlert(message: error.localizedDescription)
            }
        }
        coordinator.displayActivityIndicator(waitUntil: task)
    }
}

private extension HomeViewModel {
    func fetchFeedingPoints(isInitialLoad: Bool = false) {
        let task = { [weak self] in
            guard let self else { return }
            let points = try await self.model.fetchFeedingPoints()
            let viewItems = points.map { self.feedingPointViewMapper.mapFeedingPoint($0) }
            self.onFeedingPointsHaveBeenPrepared?(viewItems)
        }
        if isInitialLoad {
            Task { try await task() }
        } else {
            coordinator.displayActivityIndicator(waitUntil: task)
        }
    }

    func startFeedingPoinsEventsListener() {
        model.onFeedingPointChange = { [weak self] feedingPoints in
            guard let self else { return }
            guard self.feedingStatus != .progress else { return }
            let viewItems = feedingPoints.map {
                self.feedingPointViewMapper.mapFeedingPoint($0)
            }
            DispatchQueue.main.async {
                self.onFeedingPointsHaveBeenPrepared?(viewItems)
            }
        }
    }

    func fetchFilterItems() {
        model.fetchFilterItems { [weak self] filterItems in
            guard let self = self else { return }
            let model = self.segmentsViewMapper.mapFilterModel(filterItems)
            self.onSegmentsHaveBeenPrepared?(model)
        }
    }

    func handleConfirmCancelFeeding() {
        coordinator.displayActivityIndicator { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.model.processCancelFeeding()
                self.feedingStatus = result.feedingStatus
            } catch {
                logError("[APP] \(#function) failed to cancel feeding: \(error.localizedDescription)")
            }
            let points = try await self.model.fetchFeedingPoints()
            let viewItems = points.map { self.feedingPointViewMapper.mapFeedingPoint($0) }
            self.onFeedingPointsHaveBeenPrepared?(viewItems)
        }
    }

    func proceedFeedingPointSelection(pointId: String) {
        model.proceedFeedingPointSelection(pointId) { [weak self] points in
            guard let self = self else { return }
            let viewItems = points.map {
                self.feedingPointViewMapper.mapFeedingPoint($0)
            }
            self.onFeedingPointsHaveBeenPrepared?(viewItems)
            self.coordinator.routeTo(.details(pointId))
            self.coordinator.feedingDidStartedEvent = { [weak self] event in
                self?.onRouteRequestHaveBeenPrepared?(
                    .init(
                        feedingPointCoordinates: event.coordinates,
                        countdownTime: Constants.feedingCountdownTimer,
                        feedingPointId: event.identifier,
                        isUnfinishedFeeding: false
                    )
                )
            }
        }
    }

    func handleTapFeedingPoint(pointId: String) {
        switch feedingStatus {
        case .progress:
            coordinator.routeTo(.attachPhoto(pointId))
            coordinator.feedingDidFinishEvent = { [weak self] event in
                self?.finishFeeding(imageKeys: event)
            }
        case .none:
            proceedFeedingPointSelection(pointId: pointId)
        }
    }

    func handleMoveToFeedingPoint(pointId: String) {
        coordinator.displayActivityIndicator { [weak self] in
            guard let self else { return }
            let feedingPoint = try await self.model.fetchFeedingPoint(pointId)
            let viewItem = self.feedingPointViewMapper.mapFeedingPoint(feedingPoint)

            do { // change filter for requested pet
                self.model.proceedFilter({
                    switch feedingPoint.pet {
                    case .cats: return .cats
                    case .dogs: return .dogs
                    }
                }())
                self.fetchFilterItems()
            }

            self.proceedFeedingPointSelection(pointId: pointId)
            self.onFeedingPointCameraMoveRequired?(
                .init(feedingPointCoordinate: viewItem.coordinates)
            )
        }
    }
}
