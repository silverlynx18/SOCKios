import UIKit
// Remove: import FirebaseAuth
// Remove: import FirebaseFunctions
// Remove: import FirebaseFirestore
import FirebaseFirestore // Still needed for Timestamp, consider moving Timestamp to a model or using Date directly. Or ensure DataStorageService handles Date to Timestamp conversion.

// Make sure model and DTOs are found.
// e.g. import SockApp.Models (if you have a module for models)

class LoginViewController: UIViewController {

    var usernameTextField: UITextField!
    var emailTextField: UITextField!
    var passwordTextField: UITextField!
    var signUpButton: UIButton!
    var loginButton: UIButton!
    var activityIndicator: UIActivityIndicatorView!
    var availabilityLabel: UILabel!

    // Service dependencies
    private let authService: AuthServiceProtocol
    private let dataStorageService: DataStorageServiceProtocol
    private let functionsService: FunctionsServiceProtocol

    var isSignUpMode: Bool = false {
        didSet {
            usernameTextField.isHidden = !isSignUpMode
            signUpButton.setTitle(isSignUpMode ? "Sign Up" : "Switch to Sign Up", for: .normal)
            loginButton.setTitle(isSignUpMode ? "Switch to Login" : "Login", for: .normal)
        }
    }

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
        title = "Login / Sign Up"
        view.backgroundColor = .white // Ensure view has a background color for visibility
        setupUI()
        usernameTextField.addTarget(self, action: #selector(usernameDidChange(_:)), for: .editingDidEnd)
    }

    func setupUI() {
        usernameTextField = UITextField()
        usernameTextField.placeholder = "Username"
        usernameTextField.borderStyle = .roundedRect
        usernameTextField.autocorrectionType = .no
        usernameTextField.autocapitalizationType = .none
        usernameTextField.isHidden = true

        emailTextField = UITextField()
        emailTextField.placeholder = "Email"
        emailTextField.borderStyle = .roundedRect
        emailTextField.keyboardType = .emailAddress
        emailTextField.autocorrectionType = .no
        emailTextField.autocapitalizationType = .none

        passwordTextField = UITextField()
        passwordTextField.placeholder = "Password"
        passwordTextField.isSecureTextEntry = true
        passwordTextField.borderStyle = .roundedRect

        availabilityLabel = UILabel()
        availabilityLabel.text = ""
        availabilityLabel.textAlignment = .center
        availabilityLabel.font = .systemFont(ofSize: 14)

        activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.hidesWhenStopped = true

        signUpButton = UIButton(type: .system)
        signUpButton.setTitle("Switch to Sign Up", for: .normal)
        signUpButton.addTarget(self, action: #selector(signUpOrSwitchModeTapped(_:)), for: .touchUpInside)

        loginButton = UIButton(type: .system)
        loginButton.setTitle("Login", for: .normal)
        loginButton.addTarget(self, action: #selector(loginTapped(_:)), for: .touchUpInside)

        let stackView = UIStackView(arrangedSubviews: [usernameTextField, emailTextField, passwordTextField, availabilityLabel, activityIndicator, signUpButton, loginButton])
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30)
        ])
    }

    @objc func usernameDidChange(_ textField: UITextField) {
        guard let username = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !username.isEmpty else {
            availabilityLabel.text = ""
            return
        }
        // Optional: Add a small delay (e.g., 0.3s) before calling checkUsername to avoid API spamming while typing.
        // For now, direct call on editingDidEnd.
        checkUsername(username: username)
    }

    func checkUsername(username: String, completion внешнего_вызова: ((Bool, Error?) -> Void)? = nil) {
        // 'completion' here is renamed to 'внешнего_вызова' to avoid conflict with service completion blocks.
        print("Checking username: \(username)")
        // Only set loading state for the availability label and potentially the username field itself.
        // The main buttons (sign up/login) have their own loading state management when an action is tapped.
        availabilityLabel.text = "Checking..."
        availabilityLabel.textColor = .gray

        let request = CheckUsernameAvailabilityRequest(username: username)
        functionsService.callFunction(
            name: "checkUsernameAvailability",
            data: request,
            responseType: CheckUsernameAvailabilityResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.availabilityLabel.text = response.isAvailable ? "Username available" : "Username taken"
                    self?.availabilityLabel.textColor = response.isAvailable ? .systemGreen : .systemRed
                    внешнего_вызова?(response.isAvailable, nil)
                case .failure(let error):
                    print("Error calling checkUsernameAvailability function: \(error)")
                    self?.availabilityLabel.text = "Error checking."
                    self?.availabilityLabel.textColor = .systemRed
                    внешнего_вызова?(false, error)
                }
            }
        }
    }

    @IBAction func signUpOrSwitchModeTapped(_ sender: UIButton) {
        if !isSignUpMode {
            isSignUpMode = true
            // availabilityLabel.text = "" // Clear previous availability messages
            return
        }

        // Sign Up action
        guard let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty,
              let username = usernameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !username.isEmpty else {
            showAlert(title: "Missing Fields", message: "Please fill in username, email, and password.")
            return
        }
        if !isValidEmail(email) { showAlert(title: "Invalid Email", message: "Please enter a valid email address."); return }
        if password.count < 6 { showAlert(title: "Weak Password", message: "Password must be at least 6 characters long."); return }

        setLoadingState(true, forMainActions: true)

        // 1. Re-check username availability right before signup attempt for robustness
        checkUsername(username: username) { [weak self] (isAvailable, error) in
            guard let self = self else { return }

            if let error = error {
                self.setLoadingState(false, forMainActions: true)
                self.showAlert(title: "Username Check Error", message: "Could not verify username. \(error.localizedDescription)")
                return
            }

            guard isAvailable else {
                self.setLoadingState(false, forMainActions: true)
                self.showAlert(title: "Username Taken", message: "This username is already taken. Please choose another one.")
                return
            }

            // 2. Username is available, proceed with Auth sign up
            self.authService.signUp(email: email, password: password, username: username) { [weak self] authResult in
                guard let self = self else { return }
                switch authResult {
                case .success(let authUser):
                    print("User created successfully via authService: \(authUser.uid)")

                    let userProfile = UserProfile(
                        id: authUser.uid,
                        username: username,
                        email: email,
                        createdAt: Timestamp(date: Date()), // Firestore Timestamp
                        groups: [],
                        globalStatusId: nil,
                        groupSpecificStatuses: [:]
                    )

                    self.dataStorageService.createUserProfile(uid: authUser.uid, data: userProfile) { [weak self] profileResult in
                        guard let self = self else { return }
                        self.setLoadingState(false, forMainActions: true)

                        switch profileResult {
                        case .success:
                            print("User document successfully written for UID: \(authUser.uid)")
                            self.navigateToGroupList()
                        case .failure(let profileError):
                            print("Error writing user document: \(profileError)")
                            self.showAlert(title: "Registration Error", message: "Failed to save user profile: \(profileError.localizedDescription)")
                        }
                    }
                case .failure(let authError):
                    self.setLoadingState(false, forMainActions: true)
                    self.showAlert(title: "Registration Error", message: authError.localizedDescription)
                }
            }
        }
    }

    @IBAction func loginTapped(_ sender: UIButton) {
        if isSignUpMode { // If in Sign Up mode, this button means "Switch to Login"
            isSignUpMode = false
            // availabilityLabel.text = "" // Clear previous availability messages
            return
        }

        // Login action
        guard let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            showAlert(title: "Missing Fields", message: "Please fill in email and password.")
            return
        }

        setLoadingState(true, forMainActions: true)
        authService.login(email: email, password: password) { [weak self] result in
            guard let self = self else { return }
            self.setLoadingState(false, forMainActions: true)

            switch result {
            case .success(let authUser):
                print("User logged in successfully: \(authUser.uid)")
                self.navigateToGroupList()
            case .failure(let error):
                self.showAlert(title: "Login Error", message: error.localizedDescription)
            }
        }
    }

    private func setLoadingState(_ isLoading: Bool, forMainActions: Bool) {
        // Disables/Enables main action buttons (Login/Sign Up) and text fields
        if isLoading {
            activityIndicator.startAnimating()
            signUpButton.isEnabled = false
            loginButton.isEnabled = false
            usernameTextField.isEnabled = false
            emailTextField.isEnabled = false
            passwordTextField.isEnabled = false
        } else {
            activityIndicator.stopAnimating()
            signUpButton.isEnabled = true
            loginButton.isEnabled = true
            usernameTextField.isEnabled = true // Or keep username disabled if availability check is ongoing
            emailTextField.isEnabled = true
            passwordTextField.isEnabled = true
        }
    }

    func navigateToGroupList() {
        DispatchQueue.main.async {
            let groupListVC = GroupListViewController(
                authService: self.authService,
                dataStorageService: self.dataStorageService,
                functionsService: self.functionsService
            )
            let navController = UINavigationController(rootViewController: groupListVC)
            navController.modalPresentationStyle = .fullScreen

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let sceneDelegate = windowScene.delegate as? SceneDelegate,
               let window = sceneDelegate.window {
                window.rootViewController = navController
                window.makeKeyAndVisible()
                UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil, completion: nil)
            } else {
                self.present(navController, animated: true, completion: nil)
            }
        }
    }

    func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }

    func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in completion?() }))
            self.present(alert, animated: true)
        }
    }
}
