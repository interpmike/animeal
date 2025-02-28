import Foundation
import Services
import Amplify
import CoreLocation
import Combine

final class FeedingPointDetailsModel: FeedingPointDetailsModelProtocol, FeedingPointDetailsDataStoreProtocol {
    // MARK: - Private properties
    private let mapper: FeedingPointDetailsModelMapperProtocol

    typealias Context = NetworkServiceHolder
                        & DataStoreServiceHolder
                        & UserProfileServiceHolder
                        & FeedingPointsServiceHolder
    private let context: Context
    private var cachedFeedingPoint: FullFeedingPoint?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - DataStore properties
    let feedingPointId: String
    var feedingPointLocation: CLLocationCoordinate2D {
        guard
            let latitude = cachedFeedingPoint?.feedingPoint.location.lat,
            let longitude = cachedFeedingPoint?.feedingPoint.location.lon
        else {
            return CLLocationCoordinate2D()
        }
        return  CLLocationCoordinate2D(
            latitude: latitude,
            longitude: longitude
        )
    }
    // MARK: - Subscription Event
    var onFeedingPointChange: ((FeedingPointDetailsModel.PointContent, Bool) -> Void)?

    // MARK: - Initialization
    init(
        pointId: String,
        mapper: FeedingPointDetailsModelMapperProtocol = FeedingPointDetailsModelMapper(),
        context: Context = AppDelegate.shared.context
    ) {
        self.feedingPointId = pointId
        self.mapper = mapper
        self.context = context
        subscribeForFeedingPointChangeEvents()
    }

    func fetchFeedingPoint(_ completion: ((FeedingPointDetailsModel.PointContent) -> Void)?) {
        Task { [weak self] in
            guard let self else { return }
            let fullFeedingPoint = context.feedingPointsService.storedFeedingPoints.first { point in
                point.feedingPoint.id == self.feedingPointId
            }

            var canBook = false
            do {
                canBook = try await self.context.feedingPointsService
                    .canBookFeedingPoint(for: self.feedingPointId)
            } catch {
                logError(error.localizedDescription)
            }

            if let feedingPointModel = fullFeedingPoint {
                cachedFeedingPoint = fullFeedingPoint
                completion?(
                    mapper.map(
                        feedingPointModel.feedingPoint,
                        isFavorite: feedingPointModel.isFavorite,
                        isEnabled: canBook
                    )
                )
            }
        }
    }

    func fetchFeedingHistory(_ completion: (([FeedingPointDetailsModel.Feeder]) -> Void)?) {
        Task {
            let history = try await self.fetchFeedingHistory()
            completion?(history)
        }
    }

    func fetchFeedingHistory() async throws -> [FeedingPointDetailsModel.Feeder] {
        guard let fullFeedingPoint = context.feedingPointsService.storedFeedingPoints.first(where: { point in
            point.feedingPoint.id == self.feedingPointId
        }) else {
            return []
        }

        let history = try await context.feedingPointsService.fetchFeedingHistory(for: fullFeedingPoint.identifier)
        guard !history.isEmpty else { return [] }

        let sortedByDateHistory = history.sorted { $0.updatedAt > $1.updatedAt }

        let historyUsers = sortedByDateHistory.map { $0.userId }
        let namesMap = try await context.profileService.fetchUserNames(for: historyUsers)

        let feedingPointDetails = mapper.map(history: sortedByDateHistory, namesMap: namesMap)
        let right = feedingPointDetails.count < 5 ? feedingPointDetails.count : 5
        return feedingPointDetails[..<right].map { $0 }
    }

    func mutateFavorite() async throws -> Bool {
        guard let feedingPoint = cachedFeedingPoint else {
            return false
        }
        if feedingPoint.isFavorite {
            try await context.feedingPointsService.deleteFromFavorites(byIdentifier: feedingPointId)
        } else {
            try await context.feedingPointsService.addToFavorites(byIdentifier: feedingPointId)
        }
        return true
    }

    func fetchMediaContent(key: String, completion: ((Data?) -> Void)?) {
        context.dataStoreService.downloadData(
            key: key,
            options: .init(accessLevel: .guest)
        ) { result in
            switch result {
            case .success(let data):
                DispatchQueue.main.async {
                    completion?(data)
                }
            case .failure(let error):
                // TODO: Handele error
                print(error.localizedDescription)
            }
        }
    }

    private func subscribeForFeedingPointChangeEvents() {
        context.feedingPointsService.feedingPoints
            .sink { result in
                Task { [weak self] in
                    guard let self else { return }
                    let points = result.uniqueValues
                    let updatedFeeding = points.first {
                        $0.feedingPoint.id == self.feedingPointId
                    }
                    let canBook = try? await self.context.feedingPointsService
                        .canBookFeedingPoint(for: self.feedingPointId)
                    if let feedingPointModel = updatedFeeding,
                       feedingPointModel != self.cachedFeedingPoint {
                        var justFavoriteMutated = false
                        if let cached = self.cachedFeedingPoint {
                            justFavoriteMutated = feedingPointModel.onlyFavoriteMutatedOf(cached)
                        }

                        self.cachedFeedingPoint = feedingPointModel
                        self.onFeedingPointChange?(
                                                   self.mapper.map(
                                                   feedingPointModel.feedingPoint,
                                                   isFavorite: feedingPointModel.isFavorite,
                                                   isEnabled: canBook ?? false
                                                   ), justFavoriteMutated
                                                   )
                    }
                }
            }
            .store(in: &cancellables)
    }
}

extension FeedingPointDetailsModel {
    struct PointContent {
        let content: Content
        let action: Action
    }

    struct Content {
        let header: Header
        let description: Description
        let status: Status
        let feeders: [Feeder]
        let isFavorite: Bool
    }

    struct Feeder {
        let name: String
        let lastFeeded: String
    }

    struct Header {
        let cover: String?
        let title: String
    }

    struct Description {
        let text: String
    }

    struct Action {
        let identifier: String
        let title: String
        let isEnabled: Bool
    }

    enum Status {
        case success(String)
        case attention(String)
        case error(String)
    }
}

private extension FullFeedingPoint {
    func onlyFavoriteMutatedOf(_ point: FullFeedingPoint) -> Bool {
        guard self != point else {
            return false
        }

        if self.identifier != point.identifier ||
            self.imageURL != point.imageURL ||
            self.feedingPoint != point.feedingPoint {
            return false
        }
        return true
    }
}
