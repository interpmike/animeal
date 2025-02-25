import Foundation
import UIComponents

// sourcery: AutoMockable
protocol FeedingActionMappable {
    func mapFeedingAction(_ input: HomeModel.FeedingAction) -> FeedingActionMapper.FeedingAction
}

final class FeedingActionMapper: FeedingActionMappable {
    func mapFeedingAction(_ input: HomeModel.FeedingAction) -> FeedingActionMapper.FeedingAction {
        let actions: [FeedingAction.Action] = input.actions.map { action in
            FeedingAction.Action(
                title: action.title,
                style: self.convert(action.style)
            )
        }
        return FeedingActionMapper.FeedingAction(
            title: input.title, actions: actions
        )
    }

    private func convert(
        _ style: HomeModel.FeedingAction.Style
    ) -> FeedingActionMapper.FeedingAction.Style {
        switch style {
        case .accent(let action):
            return .accent(action)
        case .inverted:
            return .inverted
        }
    }
}

extension FeedingActionMapper {
    struct FeedingAction {
        let title: String
        let actions: [Action]

        enum Style {
            case accent(HomeModel.FeedingActionRequest)
            case inverted

            var alertActionStyle: AlertAction.Style {
                switch self {
                case .accent:
                    return .accent
                case .inverted:
                    return .inverted
                }
            }
        }

        struct Action {
            let title: String
            let style: Style
        }
    }
}
