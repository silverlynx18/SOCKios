import UIKit
// Remove: import FirebaseAuth
// Remove: import FirebaseFirestore (unless Timestamp is not handled by service/model layer)
// Remove: import FirebaseFunctions
import FirebaseFirestore // Keep for Timestamp if UserProfile model uses it directly

// Ensure DTOs like GenericFunctionResponse are available.
// Ensure model types (UserProfile) are available.

class ProfileViewController: UIViewController {

    // UI Elements
    var usernameLabel: UILabel!
    var emailLabel: UILabel!
    var createdAtLabel: UILabel!
    var usernameValueLabel: UILabel!
    var emailValueLabel: UILabel!
    var createdAtValueLabel: UILabel!
    var currentGlobalStatusLabel: UILabel!
    var globalStatusTextField: UITextField!
    var setGlobalStatusButton: UIButton!
    var deleteAccountButton: UIButton!
    var activityIndicator: UIActivityIndicatorView!

    // Service dependencies
    private let authService: AuthServiceProtocol
    private let dataStorageService: DataStorageServiceProtocol
    private let functionsService: FunctionsServiceProtocol

    private var localUserProfile: UserProfile? // Hold the fetched user profile data
    private var userProfileListener: ListenerRegistrationProtocol?
    private var currentAuthUser: AuthUser? // Store current authenticated user

    // Initializer for dependency injection
    init(authService: AuthServiceProtocol, dataStorageService: DataStorageServiceProtocol, functionsService: FunctionsServiceProtocol) {
        self.authService = authService
        self.dataStorageService = dataStorageService
        self.functionsService = functionsService
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented - use init(authService:dataStorageService:functionsService:)")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "Your Profile"

        currentAuthUser = authService.getCurrentUser() // Get initial auth user state
        setupUI()

        if currentAuthUser != nil {
            setupUserProfileListener()
        } else {
            // This case should ideally be handled before even navigating here,
            // but as a safeguard:
            updateUIForLoggedOutState()
            showAlert(title: "Error", message: "No user logged in.") { [weak self] in
                self?.dismissToLogin()
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        currentAuthUser = authService.getCurrentUser() // Refresh auth user state
        if currentAuthUser == nil {
            dismissToLogin()
        }
        // Listener is setup in viewDidLoad if user is logged in.
        // If it could be removed and needs re-adding, logic would go here.
    }

    deinit {
        userProfileListener?.remove()
        print("ProfileViewController deinitialized and listener removed.")
    }

    func setupUI() {
        // ... (UI setup code remains largely the same as provided in previous context)
        // Ensure activityIndicator is part of the layout and centered.
        usernameLabel = UILabel(); usernameLabel.text = "Username:"; usernameLabel.font = .boldSystemFont(ofSize: 16)
        usernameValueLabel = UILabel(); usernameValueLabel.text = "Loading..."
        emailLabel = UILabel(); emailLabel.text = "Email:"; emailLabel.font = .boldSystemFont(ofSize: 16)
        emailValueLabel = UILabel(); emailValueLabel.text = "Loading..."
        createdAtLabel = UILabel(); createdAtLabel.text = "Member Since:"; createdAtLabel.font = .boldSystemFont(ofSize: 16)
        createdAtValueLabel = UILabel(); createdAtValueLabel.text = "Loading..."

        currentGlobalStatusLabel = UILabel(); currentGlobalStatusLabel.text = "Loading status..."; currentGlobalStatusLabel.numberOfLines = 0
        globalStatusTextField = UITextField(); globalStatusTextField.placeholder = "Enter new global status ID"; globalStatusTextField.borderStyle = .roundedRect; globalStatusTextField.autocapitalizationType = .none
        setGlobalStatusButton = UIButton(type: .system); setGlobalStatusButton.setTitle("Set Global Status", for: .normal)
        setGlobalStatusButton.addTarget(self, action: #selector(setGlobalStatusTapped), for: .touchUpInside)

        let globalStatusTitleLabel = UILabel(); globalStatusTitleLabel.text = "Global Status ID:"; globalStatusTitleLabel.font = .boldSystemFont(ofSize: 16)
        let globalStatusStack = UIStackView(arrangedSubviews: [globalStatusTextField, setGlobalStatusButton]); globalStatusStack.axis = .horizontal; globalStatusStack.spacing = 8

        deleteAccountButton = UIButton(type: .system); deleteAccountButton.setTitle("Delete Account", for: .normal); deleteAccountButton.setTitleColor(.red, for: .normal)
        deleteAccountButton.addTarget(self, action: #selector(deleteAccountTapped), for: .touchUpInside)

        activityIndicator = UIActivityIndicatorView(style: .large); activityIndicator.hidesWhenStopped = true

        let mainStackView = UIStackView(arrangedSubviews: [
            usernameLabel, usernameValueLabel, emailLabel, emailValueLabel, createdAtLabel, createdAtValueLabel,
            globalStatusTitleLabel, currentGlobalStatusLabel, globalStatusStack,
            deleteAccountButton, activityIndicator
        ])
        mainStackView.axis = .vertical; mainStackView.spacing = 10
        mainStackView.setCustomSpacing(5, after: globalStatusTitleLabel)
        mainStackView.setCustomSpacing(20, after: globalStatusStack)
        mainStackView.alignment = .fill; mainStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStackView)

        NSLayoutConstraint.activate([
            mainStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            mainStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            mainStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Sign Out", style: .plain, target: self, action: #selector(signOutTapped))
    }

    func updateUIForLoggedOutState() {
        usernameValueLabel.text = "N/A"
        emailValueLabel.text = "N/A"
        createdAtValueLabel.text = "N/A"
        currentGlobalStatusLabel.text = "N/A"
        globalStatusTextField.isEnabled = false
        setGlobalStatusButton.isEnabled = false
        deleteAccountButton.isEnabled = false
    }

    func setupUserProfileListener() {
        guard let authUser = currentAuthUser else {
            dismissToLogin()
            return
        }
        userProfileListener?.remove() // Remove existing listener first
        activityIndicator.startAnimating()

        userProfileListener = dataStorageService.addUserProfileListener(uid: authUser.uid) { [weak self] result in
            guard let self = self else { return }
            self.activityIndicator.stopAnimating()
            switch result {
            case .success(let userProfile):
                self.localUserProfile = userProfile
                self.updateUIWithUserProfileData()
            case .failure(let error):
                print("Error listening to user profile updates: \(error.localizedDescription)")
                self.showAlert(title: "Error", message: "Could not load profile data. \(error.localizedDescription)")
            }
        }
    }

    func updateUIWithUserProfileData() {
        guard let profile = localUserProfile else {
            updateUIForLoggedOutState() // Should not happen if listener is working and user is logged in
            return
        }

        usernameValueLabel.text = profile.username
        emailValueLabel.text = profile.email

        if let timestamp = profile.createdAt { // Assuming UserProfile.createdAt is Firestore.Timestamp
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .none
            createdAtValueLabel.text = dateFormatter.string(from: timestamp.dateValue())
        } else {
            createdAtValueLabel.text = "N/A"
        }
        currentGlobalStatusLabel.text = profile.globalStatusId ?? "No global status set."
        currentGlobalStatusLabel.textColor = profile.globalStatusId == nil ? .gray : .black
    }

    @objc func setGlobalStatusTapped() {
        guard let userId = currentAuthUser?.uid else {
            showAlert(title: "Error", message: "Not logged in."); return
        }
        let newStatusId = globalStatusTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let statusValueToSet: Any = (newStatusId == nil || newStatusId!.isEmpty) ? NSNull() : newStatusId! // Firestore specific NSNull for field deletion

        setLoadingStateForActions(true)
        // Note: For a self-hosted backend, NSNull() might translate to sending `null` or omitting the field.
        // The DataStorageService implementation for self-hosted would handle this.
        dataStorageService.updateUserProfile(uid: userId, data: ["globalStatusId": statusValueToSet]) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.setLoadingStateForActions(false)
                switch result {
                case .success:
                    print("Global status updated successfully.")
                    self.showAlert(title: "Success", message: "Global status updated!")
                    self.globalStatusTextField.text = ""
                case .failure(let error):
                    print("Error updating global status: \(error.localizedDescription)")
                    self.showAlert(title: "Update Error", message: "Failed to set global status: \(error.localizedDescription)")
                }
            }
        }
    }

    @objc func deleteAccountTapped() {
        let confirmAlert = UIAlertController(title: "Delete Account", message: "Are you sure you want to permanently delete your account? This action cannot be undone.", preferredStyle: .alert)
        confirmAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        confirmAlert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            self?.performAccountDeletion()
        }))
        present(confirmAlert, animated: true)
    }

    func performAccountDeletion() {
        guard currentAuthUser != nil else {
            showAlert(title: "Error", message: "No user logged in."); dismissToLogin(); return
        }
        setLoadingStateForActions(true)
        navigationItem.rightBarButtonItem?.isEnabled = false // Disable sign out during deletion

        // Assuming "deleteUserAccount" takes no parameters or they are implicit (current user)
        functionsService.callFunction(
            name: "deleteUserAccount",
            data: [String:Any](), // Empty dict if no params, or specific DTO
            responseType: GenericFunctionResponse.self // Assuming a generic success/message response
        ) { [weak self] result in
            guard let self = self else { return }
            // setLoadingStateForActions(false) will be called after signout attempt or if function call fails before signout.
            // navigationItem.rightBarButtonItem?.isEnabled = true will be re-enabled if deletion fails before signout.

            switch result {
            case .success(let response):
                if response.success {
                    print("deleteUserAccount function reported success. Signing out client-side.")
                    self.authService.signOut { [weak self] signOutError in
                        guard let self = self else { return }
                        self.setLoadingStateForActions(false) // Ensure UI is re-enabled
                        self.navigationItem.rightBarButtonItem?.isEnabled = true

                        if let signOutError = signOutError {
                            self.showAlert(title: "Account Deleted (Sign Out Failed)", message: "Account data deleted, but sign-out failed: \(signOutError.localizedDescription). Please restart.")
                        } else {
                            self.showAlert(title: "Account Deleted", message: response.message ?? "Your account has been successfully deleted.") {
                                self.dismissToLogin()
                            }
                        }
                    }
                } else {
                    self.setLoadingStateForActions(false)
                    self.navigationItem.rightBarButtonItem?.isEnabled = true
                    self.showAlert(title: "Deletion Error", message: response.message ?? "Failed to delete account on server.")
                }
            case .failure(let error):
                self.setLoadingStateForActions(false)
                self.navigationItem.rightBarButtonItem?.isEnabled = true
                self.showAlert(title: "Deletion Error", message: "Failed to call delete account function: \(error.localizedDescription)")
            }
        }
    }

    private func setLoadingStateForActions(_ isLoading: Bool) {
        if isLoading {
            activityIndicator.startAnimating()
            setGlobalStatusButton.isEnabled = false
            deleteAccountButton.isEnabled = false
            globalStatusTextField.isEnabled = false
        } else {
            activityIndicator.stopAnimating()
            setGlobalStatusButton.isEnabled = true
            deleteAccountButton.isEnabled = true
            globalStatusTextField.isEnabled = true
        }
    }

    @objc func signOutTapped() {
        authService.signOut { [weak self] error in
            if let error = error {
                print("Error signing out: \(error.localizedDescription)")
                self?.showAlert(title: "Sign Out Error", message: "Could not sign you out: \(error.localizedDescription)")
            } else {
                self?.dismissToLogin()
            }
        }
    }

    func dismissToLogin() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let sceneDelegate = windowScene.delegate as? SceneDelegate,
           let window = sceneDelegate.window {
            // Ensure services are passed to LoginViewController
            let loginVC = LoginViewController(
                authService: sceneDelegate.authService,
                dataStorageService: sceneDelegate.dataStorageService,
                functionsService: sceneDelegate.functionsService
            )
            window.rootViewController = UINavigationController(rootViewController: loginVC)
            window.makeKeyAndVisible()
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil, completion: nil)
        } else if let navigationController = self.navigationController {
            // If presented within a navigation stack that should go back to a login screen at root.
            navigationController.popToRootViewController(animated: true)
            // This assumes LoginVC is the root. If not, this might not lead to login.
            // The SceneDelegate reset is more robust for ensuring a fresh login start.
        } else if presentingViewController != nil {
            // If presented modally
            dismiss(animated: true, completion: nil)
        }
    }

    func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in completion?() }))
            self.present(alert, animated: true)
        }
    }
}
