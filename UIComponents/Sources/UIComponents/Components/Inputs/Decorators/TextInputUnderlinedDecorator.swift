import UIKit

open class TextInputUnderlinedDecorator<ContentView: TextFieldContainerView>: UIView, TextInputDecoratable {
    // MARK: - Model
    public struct Model {
        public let identifier: String
        public let title: String
        public let state: TextInputView.State
        public let content: ContentView.Model

        public init(
            identifier: String,
            title: String,
            state: TextInputView.State,
            content: ContentView.Model
        ) {
            self.identifier = identifier
            self.title = title
            self.state = state
            self.content = content
        }
    }

    // MARK: - UI properties
    private let contentView: ContentView
    private var textView: TextFieldContainable { contentView.textView }

    private lazy var titleView: UILabel = {
        let item = UILabel().prepareForAutoLayout()
        item.font = designEngine.fonts.primary.medium(14.0)
        item.textColor = designEngine.colors.textPrimary
        item.numberOfLines = 1
        item.textAlignment = .left
        return item
    }()

    private lazy var lineView: UIView = {
        let item = UIView().prepareForAutoLayout()
        item.heightAnchor ~= 1.0
        item.backgroundColor = designEngine.colors.disabled
        return item
    }()

    private lazy var descriptionView: UILabel = {
        let item = UILabel().prepareForAutoLayout()
        item.font = designEngine.fonts.primary.medium(10.0)
        item.textColor = designEngine.colors.textSecondary
        item.numberOfLines = 1
        item.textAlignment = .right
        return item
    }()

    // MARK: - Handlers
    public var shouldBeginEditing: ((TextFieldContainable) -> Bool)? {
        get { textView.shouldBeginEditing }
        set { textView.shouldBeginEditing = newValue }
    }

    public var didBeginEditing: ((TextFieldContainable) -> Void)? {
        get { textView.didBeginEditing }
        set { textView.didBeginEditing = newValue }
    }

    public var shouldEndEditing: ((TextFieldContainable) -> Bool)? {
        get { textView.shouldEndEditing }
        set { textView.shouldEndEditing = newValue }
    }

    public var didEndEditing: ((TextFieldContainable) -> Void)? {
        get { textView.didEndEditing }
        set { textView.didEndEditing = newValue }
    }

    public var shouldChangeCharacters: ((TextFieldContainable, NSRange, String) -> Bool)? {
        get { textView.shouldChangeCharacters }
        set { textView.shouldChangeCharacters = newValue }
    }

    public var didChange: ((TextFieldContainable) -> Void)? {
        get { textView.didChange }
        set { textView.didChange = newValue }
    }

    public var shouldClear: ((TextFieldContainable) -> Bool)? {
        get { textView.shouldClear }
        set { textView.shouldClear = newValue }
    }

    public var shouldReturn: ((TextFieldContainable) -> Bool)? {
        get { textView.shouldReturn }
        set { textView.shouldReturn = newValue }
    }

    // MARK: - Identifiable
    public private(set) var identifier: String = UUID().uuidString

    // MARK: - Initialization
    public init(contentView: ContentView) {
        self.contentView = contentView.prepareForAutoLayout()
        super.init(frame: CGRect.zero)
        setup()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration
    open func configure(_ model: Model) {
        identifier = model.identifier
        titleView.text = model.title
        switch model.state {
        case .normal:
            descriptionView.text = nil
            descriptionView.isHidden = true
        case .error(let error):
            descriptionView.text = error
            descriptionView.isHidden = false
        }
        contentView.configure(model.content)
        configureStyle(model.state)
    }

    private func configureStyle(_ textFieldState: TextInputView.State) {
        switch textFieldState {
        case .normal:
            textView.font = designEngine.fonts.primary.medium(16.0)
            textView.textColor = designEngine.colors.textPrimary
            lineView.backgroundColor = designEngine.colors.disabled
            descriptionView.textColor = designEngine.colors.textSecondary
        case .error:
            textView.font = designEngine.fonts.primary.medium(16.0)
            textView.textColor = designEngine.colors.textPrimary
            lineView.backgroundColor = designEngine.colors.error
            descriptionView.textColor = designEngine.colors.error
        }
    }

    // MARK: - Setup
    private func setup() {
        addSubview(titleView)
        titleView.leadingAnchor ~= leadingAnchor
        titleView.topAnchor ~= topAnchor
        titleView.trailingAnchor ~= trailingAnchor
        titleView.setContentHuggingPriority(
            UILayoutPriority.required,
            for: NSLayoutConstraint.Axis.vertical
        )
        titleView.setContentCompressionResistancePriority(
            UILayoutPriority.required,
            for: NSLayoutConstraint.Axis.vertical
        )

        addSubview(contentView)
        contentView.leadingAnchor ~= titleView.leadingAnchor
        contentView.topAnchor ~= titleView.bottomAnchor + 16.0
        contentView.trailingAnchor ~= titleView.trailingAnchor

        addSubview(lineView)
        lineView.leadingAnchor ~= titleView.leadingAnchor
        lineView.topAnchor ~= contentView.bottomAnchor + 16.0
        lineView.trailingAnchor ~= titleView.trailingAnchor

        addSubview(descriptionView)
        descriptionView.leadingAnchor ~= titleView.leadingAnchor
        descriptionView.topAnchor ~= lineView.bottomAnchor + 2.0
        descriptionView.trailingAnchor ~= titleView.trailingAnchor
        descriptionView.bottomAnchor ~= bottomAnchor
        let descriptionHeightConstraint = descriptionView.heightAnchor.constraint(
            equalToConstant: 0.0
        )
        descriptionHeightConstraint.priority = UILayoutPriority.defaultHigh
        descriptionHeightConstraint.isActive = true

        descriptionView.setContentHuggingPriority(
            UILayoutPriority.required,
            for: NSLayoutConstraint.Axis.vertical
        )
        descriptionView.setContentCompressionResistancePriority(
            UILayoutPriority.required,
            for: NSLayoutConstraint.Axis.vertical
        )
    }
}
