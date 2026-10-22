import HotwireNative
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate, NavigatorDelegate, UITabBarControllerDelegate {
    var window: UIWindow?

    private struct Tab {
        let title: String
        let imageName: String
        let url: URL
        let navigator: Navigator
    }

    private lazy var tabBarController: UITabBarController = {
        let controller = UITabBarController()
        controller.delegate = self
        return controller
    }()

    private lazy var tabs = [
        makeTab(title: "Index", imageName: "text.magnifyingglass", path: "search"),
        makeTab(title: "Daylog", imageName: "list.bullet", path: "bullets"),
        makeTab(title: "User", imageName: "person.crop.circle", path: "user")
    ]

    private var startedTabs = Set<Int>()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        tabBarController.viewControllers = tabs.enumerated().map { index, tab in
            let controller = tab.navigator.rootViewController
            controller.tabBarItem = UITabBarItem(title: tab.title, image: UIImage(systemName: tab.imageName), tag: index)
            return controller
        }
        tabBarController.selectedIndex = 1

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = tabBarController
        self.window = window
        window.makeKeyAndVisible()
        startTab(at: 1)
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        startTab(at: tabBarController.selectedIndex)
    }

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        let index = viewController.tabBarItem.tag
        guard tabs.indices.contains(index) else { return false }
        if index == tabBarController.selectedIndex &&
            (tabs[index].navigator.rootViewController.viewControllers.count > 1 ||
             tabs[index].navigator.rootViewController.presentedViewController != nil) {
            tabs[index].navigator.clearAll(animated: true)
        }
        return true
    }

    func handle(proposal: VisitProposal, from navigator: Navigator) -> ProposalResult {
        guard let index = tabs.firstIndex(where: { tab in
            proposal.url.scheme == tab.url.scheme &&
            proposal.url.host == tab.url.host &&
            proposal.url.port == tab.url.port &&
            proposal.url.path == tab.url.path
        }), tabs[index].navigator !== navigator else { return .accept }

        tabBarController.selectedIndex = index
        let isUnstarted = startedTabs.insert(index).inserted
        if isUnstarted { tabs[index].navigator.start() }

        if proposal.url == tabs[index].url {
            if !isUnstarted && (tabs[index].navigator.rootViewController.viewControllers.count > 1 ||
                tabs[index].navigator.rootViewController.presentedViewController != nil) {
                tabs[index].navigator.clearAll(animated: false)
            }
        } else {
            tabs[index].navigator.route(proposal)
        }

        return .reject
    }

    private func makeTab(title: String, imageName: String, path: String) -> Tab {
        let url = ServerConfiguration.url.appendingPathComponent(path)
        let navigator = Navigator(configuration: .init(name: title, startLocation: url), delegate: self)
        return Tab(title: title, imageName: imageName, url: url, navigator: navigator)
    }

    private func startTab(at index: Int) {
        guard startedTabs.insert(index).inserted else { return }
        tabs[index].navigator.start()
    }
}
