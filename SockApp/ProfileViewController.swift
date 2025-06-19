import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

class ProfileViewController: UIViewController {

    // UI Elements
    var usernameLabel: UILabel!
    var emailLabel: UILabel!
    var createdAtLabel: UILabel!
    // For displaying username and email, actual TextFields might be overkill if read-only
    var usernameValueLabel: UILabel!
    var emailValueLabel: UILabel!
    var createdAtValueLabel: UILabel!

    // Global Status UI
    var currentGlobalStatusLabel: UILabel!
    var globalStatusTextField: UITextField!
    var setGlobalStatusButton: UIButton!

    var deleteAccountButton: UIButton!
    var activityIndicator: UIActivityIndicatorView!

    lazy var db = Firestore.firestore()
    lazy var functions = Functions.functions()
    var firebaseUser: Firebase.User? // Renamed from currentUser to avoid conflict with UserProfile struct
    var userProfile: UserProfile? // To hold the fetched user profile data
    var userProfileListener: ListenerRegistration?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "Your Profile"

        firebaseUser = Auth.auth().currentUser
        setupUI()
        // loadUserData() // Listener will handle initial load
        setupUserProfileListener()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if firebaseUser == nil { // Check if user is still logged in
            dismissToLogin()
        }
        // If listener wasn't set up or was removed, set it up again.
        // For this example, assuming listener is setup in viewDidLoad and removed in deinit.
        // If view can appear multiple times without viewDidLoad being called, might need to re-attach here.
    }

    deinit {
        userProfileListener?.remove()
        print("ProfileViewController deinitialized and listener removed.")
    }

    func setupUI() {
        usernameLabel = UILabel()
        usernameLabel.text = "Username:"
        usernameLabel.font = UIFont.boldSystemFont(ofSize: 16)

        usernameValueLabel = UILabel()
        usernameValueLabel.text = "Loading..."

        emailLabel = UILabel()
        emailLabel.text = "Email:"
        emailLabel.font = UIFont.boldSystemFont(ofSize: 16)

        emailValueLabel = UILabel()
        emailValueLabel.text = "Loading..."

        createdAtLabel = UILabel()
        createdAtLabel.text = "Member Since:"
        createdAtLabel.font = UIFont.boldSystemFont(ofSize: 16)

        createdAtValueLabel = UILabel()
        createdAtValueLabel.text = "Loading..."

        deleteAccountButton = UIButton(type: .system)
        deleteAccountButton.setTitle("Delete Account", for: .normal)
        deleteAccountButton.setTitleColor(.red, for: .normal)
        deleteAccountButton.addTarget(self, action: #selector(deleteAccountTapped), for: .touchUpInside)

        // Global Status UI Setup
        let globalStatusTitleLabel = UILabel()
        globalStatusTitleLabel.text = "Global Status ID:"
        globalStatusTitleLabel.font = UIFont.boldSystemFont(ofSize: 16)

        currentGlobalStatusLabel = UILabel()
        currentGlobalStatusLabel.text = "Loading status..."
        currentGlobalStatusLabel.numberOfLines = 0 // In case status ID is long

        globalStatusTextField = UITextField()
        globalStatusTextField.placeholder = "Enter new global status ID"
        globalStatusTextField.borderStyle = .roundedRect
        globalStatusTextField.autocapitalizationType = .none

        setGlobalStatusButton = UIButton(type: .system)
        setGlobalStatusButton.setTitle("Set Global Status", for: .normal)
        setGlobalStatusButton.addTarget(self, action: #selector(setGlobalStatusTapped), for: .touchUpInside)

        let globalStatusStack = UIStackView(arrangedSubviews: [globalStatusTextField, setGlobalStatusButton])
        globalStatusStack.axis = .horizontal
        globalStatusStack.spacing = 8

        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.hidesWhenStopped = true
        // activityIndicator.center = view.center // Will be centered by constraints
        // view.addSubview(activityIndicator) // Added via main stack

        let mainStackView = UIStackView(arrangedSubviews: [
            usernameLabel, usernameValueLabel,
            emailLabel, emailValueLabel,
            createdAtLabel, createdAtValueLabel,
            globalStatusTitleLabel, currentGlobalStatusLabel,
            globalStatusStack,
            deleteAccountButton,
            activityIndicator // Added here to be part of the layout flow
        ])
        mainStackView.axis = .vertical
        mainStackView.spacing = 10
        mainStackView.setCustomSpacing(5, after: globalStatusTitleLabel) // Less space after title
        mainStackView.setCustomSpacing(20, after: globalStatusStack) // More space before delete button
        mainStackView.alignment = .fill
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStackView)

        NSLayoutConstraint.activate([
            mainStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            mainStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            mainStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        // Add a sign out button to the navigation bar for now
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Sign Out", style: .plain, target: self, action: #selector(signOutTapped))
    }

    func setupUserProfileListener() {
        guard let user = firebaseUser else {
            dismissToLogin()
            return
        }
        userProfileListener?.remove() // Remove existing listener first
        activityIndicator.startAnimating()

        userProfileListener = db.collection("users").document(user.uid)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                guard let self = self else { return }
                self.activityIndicator.stopAnimating()

                if let error = error {
                    print("Error listening to user profile updates: \(error.localizedDescription)")
                    self.showAlert(title: "Loading Error", message: "Could not load your profile data: \(error.localizedDescription). Please try again.")
                    return
                }

                guard let document = documentSnapshot, document.exists else {
                    print("User document does not exist.")
                    self.showAlert(title: "Error", message: "Profile data not found. This shouldn't happen.")
                    // This is an inconsistent state, user exists in Auth but not Firestore
                    return
                }

                do {
                    self.userProfile = try document.data(as: UserProfile.self)
                    self.updateUIWithUserProfileData()
                } catch {
                    print("Error decoding user profile: \(error)")
                    self.showAlert(title: "Data Error", message: "Could not parse your profile data. Please try again.")
                }
            }
    }

    func updateUIWithUserProfileData() {
        guard let profile = userProfile else { return }

        usernameValueLabel.text = profile.username
        emailValueLabel.text = profile.email

        if let timestamp = profile.createdAt {
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
        guard let userId = firebaseUser?.uid else {
            showAlert(title: "Error", message: "Not logged in.")
            return
        }

        let newStatusId = globalStatusTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)

        // If newStatusId is empty, we want to set it to null in Firestore.
        // Otherwise, use the entered string.
        let statusValueToSet: Any = (newStatusId == nil || newStatusId!.isEmpty) ? NSNull() : newStatusId!

        setLoadingState(true, for: [setGlobalStatusButton, deleteAccountButton], textFields: [globalStatusTextField])
        db.collection("users").document(userId).updateData(["globalStatusId": statusValueToSet]) { [weak self] error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.setLoadingState(false, for: [self.setGlobalStatusButton, self.deleteAccountButton], textFields: [self.globalStatusTextField])
                if let error = error {
                    print("Error updating global status: \(error.localizedDescription)")
                    self.showAlert(title: "Update Error", message: "Failed to set your global status: \(error.localizedDescription). Please try again.")
                } else {
                    print("Global status updated successfully.")
                    self.showAlert(title: "Success", message: "Global status updated!")
                    self.globalStatusTextField.text = "" // Clear field after successful update
                    // Listener will automatically update currentGlobalStatusLabel
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
        guard firebaseUser != nil else { // Use firebaseUser
            showAlert(title: "Error", message: "No user logged in.")
            dismissToLogin()
            return
        }

        setLoadingState(true, for: [deleteAccountButton, setGlobalStatusButton], textFields: [globalStatusTextField])
        // Also disable other interactive elements if necessary, e.g. sign out button
        navigationItem.rightBarButtonItem?.isEnabled = false


        functions.httpsCallable("deleteUserAccount").call { [weak self] (result, error) in
            guard let self = self else { return }
            DispatchQueue.main.async {
                // setLoadingState will be called after sign out attempt or error.
                // self.setLoadingState(false, for: [self.deleteAccountButton, self.setGlobalStatusButton], textFields: [self.globalStatusTextField])
                // self.navigationItem.rightBarButtonItem?.isEnabled = true

                if let error = error as NSError? {
                    self.setLoadingState(false, for: [self.deleteAccountButton, self.setGlobalStatusButton], textFields: [self.globalStatusTextField])
                    self.navigationItem.rightBarButtonItem?.isEnabled = true
                    if error.domain == FunctionsErrorDomain {
                        let code = FunctionsErrorCode(rawValue: error.code)
                        let message = error.localizedDescription
                        let details = error.userInfo[FunctionsErrorDetailsKey]
                        print("Error calling deleteUserAccount function: \(String(describing: code)), \(message), \(String(describing: details))")
                    }
                    self?.showAlert(title: "Deletion Error", message: "Failed to delete your account: \(error.localizedDescription). Please try again.")
                    return
                }

                // Function executed successfully
                print("deleteUserAccount function called successfully. Signing out client-side.")
                do {
                    try Auth.auth().signOut()
                    // No need to re-enable buttons if we are dismissing
                    self.showAlert(title: "Account Deleted", message: "Your account has been successfully deleted.", completion: {
                        self.dismissToLogin()
                    })
                } catch let signOutError {
                    self.setLoadingState(false, for: [self.deleteAccountButton, self.setGlobalStatusButton], textFields: [self.globalStatusTextField])
                     self.navigationItem.rightBarButtonItem?.isEnabled = true
                    print("Error signing out after account deletion: \(signOutError.localizedDescription)")
                    self.showAlert(title: "Account Deleted", message: "Your account data has been deleted, but a local sign-out error occurred. Please restart the app.", completion: {
                        // Still attempt to dismiss, but UI state might be inconsistent if sign out fails badly
                        self.dismissToLogin()
                    })
                }
            }
        }
    }

    private func setLoadingState(_ isLoading: Bool, for buttons: [UIButton], textFields: [UITextField] = []) {
        if isLoading {
            activityIndicator.startAnimating()
            buttons.forEach { $0.isEnabled = false }
            textFields.forEach { $0.isEnabled = false }
        } else {
            activityIndicator.stopAnimating()
            buttons.forEach { $0.isEnabled = true }
            textFields.forEach { $0.isEnabled = true }
        }
    }

    @objc func signOutTapped() {
        // It's good practice to disable UI during sign out too, though it's usually very fast.
        // For this review, focusing on the specified operations.
        do {
            try Auth.auth().signOut()
            dismissToLogin()
        } catch let signOutError {
            print("Error signing out: \(signOutError.localizedDescription)")
            showAlert(title: "Sign Out Error", message: "Could not sign you out at this time: \(signOutError.localizedDescription). Please try again.")
        }
    }

    func dismissToLogin() {
        // This assumes ProfileViewController was presented modally.
        // If using a navigation controller stack, you might pop to root.
        // For simplicity, if there's a presenting VC, dismiss it. Otherwise, try to find a LoginVC.
        if let presentingVC = presentingViewController {
             presentingVC.dismiss(animated: true, completion: nil)
        } else if let navigationController = self.navigationController {
            navigationController.popToRootViewController(animated: true)
            // If LoginViewController is not the root, a more robust solution is needed
            // like posting a notification or using a delegate to inform the app coordinator.
        } else {
            // Fallback: try to reset to LoginViewController if nothing else works
            // This is a simplistic way; a proper app coordinator/router would handle this.
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let sceneDelegate = windowScene.delegate as? SceneDelegate,
               let window = sceneDelegate.window {
                let loginVC = LoginViewController() // Ensure it's LoginViewController
                window.rootViewController = UINavigationController(rootViewController: loginVC) // Good practice to wrap in Nav
                window.makeKeyAndVisible()
            }
        }
    }

    // Helper to show alerts
    func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in completion?() }))
        present(alert, animated: true)
    }
}
