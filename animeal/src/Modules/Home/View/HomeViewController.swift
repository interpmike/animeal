import UIKit
import MapboxMaps
import UIComponents

class HomeViewController: UIViewController {
    private var mapView: MapView!
    private var segmentedControl = SegmentedControl()

    // MARK: - Dependencies
    private let viewModel: HomeCombinedViewModel

    // MARK: - Initialization
    init(viewModel: HomeCombinedViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle
    override public func viewDidLoad() {
        super.viewDidLoad()
        setup()
        viewModel.load()
    }

    public func mapInitOptions() -> MapInitOptions {
        let resourceOptions = ResourceOptions(
            accessToken: ResourceOptionsManager.default.resourceOptions.accessToken
        )

        return MapInitOptions(
            resourceOptions: resourceOptions,
            styleURI: .light
        )
    }
}

extension HomeViewController: HomeViewModelOutput {
    func applyFeedingPoints(_ feedingPoints: [FeedingPointViewItem]) {
        mapView.viewAnnotations.removeAll()
        feedingPoints.forEach { point in
            let options = ViewAnnotationOptions(
                geometry: MapboxMaps.Point(point.coordinates),
                width: 60,
                height: 60,
                allowOverlap: false,
                anchor: .center
            )
            let feedingPointView = FeedingPointView()
            feedingPointView.configure(point.viewModel)
            feedingPointView.tapAction = { [weak self] pointId in
                self?.viewModel.handleActionEvent(.tapFeedingPoint(pointId))
            }
            try? mapView.viewAnnotations.add(feedingPointView, options: options)
        }
    }

    func applyFilter(_ filter: FilterModel) {
        segmentedControl.configure(filter.segmentedControlModel)
        segmentedControl.onTap = { [weak self] selectedSegmentIndex in
            self?.viewModel.handleActionEvent(.tapFilterControl(selectedSegmentIndex))
        }
    }
}

// MARK: - Private API
private extension HomeViewController {
    func setup() {
        // Fake coordinates for testing needs
        let fakeLocationCoordinates = CLLocationCoordinate2D(latitude: 41.73156045955432, longitude: 44.785400636556204)
        let mapInitOptions = MapInitOptions(cameraOptions: CameraOptions(center: fakeLocationCoordinates, zoom: 15))
        // Add a map view
        mapView = MapView(frame: view.bounds, mapInitOptions: mapInitOptions)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(mapView)

        view.addSubview(segmentedControl.prepareForAutoLayout())
        segmentedControl.topAnchor ~= view.safeAreaLayoutGuide.topAnchor + 66
        segmentedControl.centerXAnchor ~= view.centerXAnchor
        segmentedControl.widthAnchor ~= 226
    }
}
