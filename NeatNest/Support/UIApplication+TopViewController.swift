import UIKit

extension UIApplication {
    var topViewController: UIViewController? {
        guard let windowScene = connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let rootViewController = windowScene.windows.first(where: \.isKeyWindow)?.rootViewController else {
            return nil
        }

        return Self.findTopViewController(from: rootViewController)
    }

    private static func findTopViewController(from viewController: UIViewController) -> UIViewController {
        if let navigationController = viewController as? UINavigationController,
           let visibleViewController = navigationController.visibleViewController {
            return findTopViewController(from: visibleViewController)
        }

        if let tabBarController = viewController as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return findTopViewController(from: selectedViewController)
        }

        if let presentedViewController = viewController.presentedViewController {
            return findTopViewController(from: presentedViewController)
        }

        return viewController
    }
}
