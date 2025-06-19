import UIKit
import FirebaseAuth
import FirebaseFunctions
import FirebaseFirestore

class LoginViewController: UIViewController {

    // IBOutlets are typically connected in Interface Builder (Storyboard/XIB)
    // For this placeholder, we'll just declare them.
    var usernameTextField: UITextField!
    var emailTextField: UITextField!
    var passwordTextField: UITextField!
    var signUpButton: UIButton!
    var loginButton: UIButton!
    var activityIndicator: UIActivityIndicatorView!
    var availabilityLabel: UILabel!

    lazy var functions = Functions.functions()
    lazy var db = Firestore.firestore()

    // Simple state to toggle UI for login/signup
    var isSignUpMode: Bool = false {
        didSet {
            usernameTextField.isHidden = !isSignUpMode
            // You might want to change button titles or other UI elements here
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Basic setup - in a real app, you'd add these to the view, set constraints, etc.
        title = "Login / Sign Up"

        usernameTextField = UITextField()
        usernameTextField.placeholder = "Username"
        usernameTextField.borderStyle = .roundedRect
        usernameTextField.isHidden = true // Initially hidden

        emailTextField = UITextField()
        emailTextField.placeholder = "Email"
        emailTextField.borderStyle = .roundedRect
        emailTextField.autocapitalizationType = .none
        // Add to view hierarchy and set constraints...

        passwordTextField = UITextField()
        passwordTextField.placeholder = "Password"
        passwordTextField.isSecureTextEntry = true
        passwordTextField.borderStyle = .roundedRect
        // Add to view hierarchy and set constraints...

        availabilityLabel = UILabel()
        availabilityLabel.text = ""
        availabilityLabel.textAlignment = .center

        activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.hidesWhenStopped = true


        signUpButton = UIButton(type: .system)
        signUpButton.setTitle("Switch to Sign Up", for: .normal)
        signUpButton.addTarget(self, action: #selector(signUpOrSwitchModeTapped(_:)), for: .touchUpInside)
        // Add to view hierarchy and set constraints...

        loginButton = UIButton(type: .system)
        loginButton.setTitle("Login", for: .normal)
        loginButton.addTarget(self, action: #selector(loginTapped(_:)), for: .touchUpInside)
        // Add to view hierarchy and set constraints...

        // Example of how you might lay them out programmatically (very basic)
        let stackView = UIStackView(arrangedSubviews: [usernameTextField, emailTextField, passwordTextField, availabilityLabel, activityIndicator, signUpButton, loginButton])
        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        // Add a target to check username availability when the text field loses focus
        usernameTextField.addTarget(self, action: #selector(usernameDidChange(_:)), for: .editingDidEnd)
    }

    @objc func usernameDidChange(_ textField: UITextField) {
        guard let username = textField.text, !username.isEmpty else {
            availabilityLabel.text = ""
            return
        }
        checkUsername(username: username)
    }

    func checkUsername(username: String, completion: ((Bool, Error?) -> Void)? = nil) {
        print("Checking username: \(username)")
        setLoadingState(true, for: [signUpButton, loginButton]) // Disable buttons
        availabilityLabel.text = "Checking..."
        // activityIndicator is part of the stack view, already visible if animating

        functions.httpsCallable("checkUsernameAvailability").call(["username": username]) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self else {
                    completion?(false, error)
                    return
                }

                // Always ensure loading state is reset before calling completion
                self.setLoadingState(false, for: [self.signUpButton, self.loginButton])
                // self.activityIndicator.stopAnimating() // Handled by setLoadingState

                if let error = error as NSError? {
                    if error.domain == FunctionsErrorDomain {
                        let code = FunctionsErrorCode(rawValue: error.code)
                        let message = error.localizedDescription
                        let details = error.userInfo[FunctionsErrorDetailsKey]
                        print("Error calling function: \(String(describing: code)), \(message), \(String(describing: details))")
                    }
                    self.availabilityLabel.text = "Error checking username."
                    completion?(false, error)
                    return
                }
                if let data = result?.data as? [String: Any], let isAvailable = data["isAvailable"] as? Bool {
                    self.availabilityLabel.text = isAvailable ? "Username available" : "Username taken"
                    self.availabilityLabel.textColor = isAvailable ? .systemGreen : .systemRed
                    completion?(isAvailable, nil)
                } else {
                    self.availabilityLabel.text = "Could not parse response."
                    completion?(false, nil) // Or a custom error
                }
            }
        }
    }

    @IBAction func signUpOrSwitchModeTapped(_ sender: UIButton) {
        if !isSignUpMode {
            isSignUpMode = true
            signUpButton.setTitle("Sign Up", for: .normal)
            loginButton.setTitle("Switch to Login", for: .normal)
            availabilityLabel.text = "" // Clear previous messages
            print("Switched to Sign Up mode")
            return
        }

        print("Sign Up button tapped")
        guard let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty,
              let username = usernameTextField.text, !username.isEmpty else {
            showAlert(title: "Missing Fields", message: "Please fill in username, email, and password.")
            return
        }

        // Basic email validation
        if !isValidEmail(email) {
            showAlert(title: "Invalid Email", message: "Please enter a valid email address.")
            return
        }

        // Basic password validation (e.g., minimum length)
        if password.count < 6 {
            showAlert(title: "Weak Password", message: "Password must be at least 6 characters long.")
            return
        }

        activityIndicator.startAnimating()
        // 1. Check username availability
        checkUsername(username: username) { [weak self] (isAvailable, error) in
            guard let self = self else { return }
            // setLoadingState for checkUsername is handled within its own completion block now.

            if let error = error {
                self.setLoadingState(false, for: [self.signUpButton, self.loginButton]) // Ensure UI is re-enabled
                self.showAlert(title: "Username Check Error", message: "Could not check username: \(error.localizedDescription). Please try again.")
                // No completion() call here as this is the end of this specific action flow for sign up
                return
            }

            guard isAvailable else {
                self.setLoadingState(false, for: [self.signUpButton, self.loginButton]) // Ensure UI is re-enabled
                self.showAlert(title: "Username Taken", message: "This username is already taken. Please choose another one.")
                // No completion() call here
                return
            }

            // Username is available
            // 2. Proceed to create user (Auth and Firestore)
            // setLoadingState(true,...) is called right before Auth.auth().createUser
            // No need to call it here again, as it was called at the start of checkUsername
            // and if we reach here, it means it was reset by checkUsername's completion.
            // However, we need to set it to true again for the Auth and Firestore operations.
            self.setLoadingState(true, for: [self.signUpButton, self.loginButton])
            Auth.auth().createUser(withEmail: email, password: password) { authResult, authError in
                if let authError = authError {
                    self.setLoadingState(false, for: [self.signUpButton, self.loginButton])
                    self.showAlert(title: "Registration Error", message: "Failed to sign up: \(authError.localizedDescription). Please check your details and try again.")
                    return
                }

                guard let user = authResult?.user else {
                    self.setLoadingState(false, for: [self.signUpButton, self.loginButton])
                    self.showAlert(title: "Registration Error", message: "Could not get user after creation.")
                    return
                }

                print("User created successfully: \(user.uid) with email: \(email)")

                let userData: [String: Any] = [
                    "username": username,
                    "email": email,
                    "createdAt": Timestamp(date: Date()),
                    "groups": [],
                    "globalStatusId": NSNull(),
                    "groupSpecificStatuses": [:]
                ]

                self.db.collection("users").document(user.uid).setData(userData) { firestoreError in
                    self.setLoadingState(false, for: [self.signUpButton, self.loginButton])
                    if let firestoreError = firestoreError {
                        print("Error writing user document: \(firestoreError)")
                        // Potentially delete the Firebase Auth user if Firestore write fails, or queue for retry
                        // For now, just show error. User exists in Auth but not DB.
                        self.showAlert(title: "Registration Error", message: "Failed to save your profile: \(firestoreError.localizedDescription). Please try signing up again.")
                    } else {
                        print("User document successfully written for UID: \(user.uid)")
                        self.navigateToGroupList()
                    }
                }
            }
        }
    }

    @IBAction func loginTapped(_ sender: UIButton) {
        if isSignUpMode {
            isSignUpMode = false
            signUpButton.setTitle("Switch to Sign Up", for: .normal)
            loginButton.setTitle("Login", for: .normal)
            availabilityLabel.text = "" // Clear previous messages
            print("Switched to Login mode")
            return
        }

        print("Login button tapped")
        guard let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            showAlert(title: "Missing Fields", message: "Please fill in email and password.")
            return
        }

        setLoadingState(true, for: [loginButton, signUpButton])
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
            guard let self = self else { return }
            self.setLoadingState(false, for: [self.loginButton, self.signUpButton])

            if let error = error {
                self.showAlert(title: "Login Error", message: "Failed to log in: \(error.localizedDescription). Please check your credentials and try again.")
                return
            }
            print("User logged in successfully: \(authResult?.user.uid ?? "No UID")")
            self.navigateToGroupList()
        }
    }

    private func setLoadingState(_ isLoading: Bool, for buttons: [UIButton]) {
        if isLoading {
            activityIndicator.startAnimating()
            buttons.forEach { $0.isEnabled = false }
            // Potentially disable text fields too
            usernameTextField.isEnabled = false
            emailTextField.isEnabled = false
            passwordTextField.isEnabled = false
        } else {
            activityIndicator.stopAnimating()
            buttons.forEach { $0.isEnabled = true }
            usernameTextField.isEnabled = true
            emailTextField.isEnabled = true
            passwordTextField.isEnabled = true
        }
    }

    func navigateToGroupList() {
        DispatchQueue.main.async {
            let groupListVC = GroupListViewController()
            let navController = UINavigationController(rootViewController: groupListVC)
            navController.modalPresentationStyle = .fullScreen

            // Attempt to get the window scene and set the root view controller
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let sceneDelegate = windowScene.delegate as? SceneDelegate,
               let window = sceneDelegate.window {
                window.rootViewController = navController
                window.makeKeyAndVisible()
                UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil, completion: nil)
            } else {
                // Fallback for environments where SceneDelegate might not be available (e.g. older projects or testing)
                // This might not be ideal if LoginVC is not the root or is presented modally itself.
                self.present(navController, animated: true, completion: nil)
            }
        }
    }

    // Helper for basic email validation
    func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }

    // Helper to show alerts
    func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in completion?() }))
            self.present(alert, animated: true)
        }
    }
}
