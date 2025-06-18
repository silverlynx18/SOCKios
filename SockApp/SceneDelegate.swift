import UIKit
// Remove: import FirebaseAuth - No longer directly needed here for currentUser check

// Import Service Protocols and Implementations
// Make sure these paths are correct based on your project structure.
// Assuming they are accessible via module name or bridging header if needed.
// For this example, direct import if they are in the same module and target.
// import SockApp.Services.Protocols (if they were a separate module)
// import SockApp.Services.Firebase (if they were a separate module)

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    // Instantiate services. These could be in a separate AppServices container/singleton.
    // For simplicity, keeping them here for now.
    lazy var authService: AuthServiceProtocol = FirebaseAuthenticationService()
    lazy var dataStorageService: DataStorageServiceProtocol = FirebaseDataStorageService()
    lazy var functionsService: FunctionsServiceProtocol = FirebaseFunctionsService()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        window = UIWindow(windowScene: windowScene)

        // Check if a user is already signed in using the authService
        if authService.getCurrentUser() != nil {
            // User is signed in, show GroupListViewController
            // GroupListViewController will also need service injection
            let groupListVC = GroupListViewController(
                authService: authService,
                dataStorageService: dataStorageService,
                functionsService: functionsService
            )
            let navController = UINavigationController(rootViewController: groupListVC)
            window?.rootViewController = navController
            print("User is signed in. Starting with GroupListViewController.")
        } else {
            // No user signed in, show LoginViewController
            let loginVC = LoginViewController(
                authService: authService,
                dataStorageService: dataStorageService,
                functionsService: functionsService
            )
            let navController = UINavigationController(rootViewController: loginVC)
            window?.rootViewController = navController
            print("No user signed in. Starting with LoginViewController.")
        }

        window?.makeKeyAndVisible()
    }

    // ... rest of SceneDelegate remains the same
    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
}

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
}
