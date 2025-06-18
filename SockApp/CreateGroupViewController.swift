import UIKit
// Remove: import FirebaseAuth
// Remove: import FirebaseFunctions
// Remove: import FirebaseFirestore (NSNull might still be an issue if not handled by DTO/service)
// We'll try to avoid NSNull here by using optional properties in DTOs.
// The FirebaseFunctionsService or the Cloud Function itself should handle nil vs NSNull.

// Ensure DTOs like CreateGroupRequest, CreateGroupResponse are available.
// Ensure model types (Group) are available if needed, though not directly used here for creation.

class CreateGroupViewController: UIViewController {

    // UI Elements
    var groupNameTextField: UITextField!
    var primaryColorTextField: UITextField!
    var secondaryColorTextField: UITextField!
    var groupProfilePictureUrlTextField: UITextField!
    var createButton: UIButton!
    var activityIndicator: UIActivityIndicatorView!

    // Service dependencies
    private let dataStorageService: DataStorageServiceProtocol
    private let functionsService: FunctionsServiceProtocol
    private let authService: AuthServiceProtocol // For potential future use (e.g. creatorID)

    // Initializer for dependency injection
    init(dataStorageService: DataStorageServiceProtocol, functionsService: FunctionsServiceProtocol, authService: AuthServiceProtocol) {
        self.dataStorageService = dataStorageService
        self.functionsService = functionsService
        self.authService = authService
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented - use init(dataStorageService:functionsService:authService:)")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "Create New Group"

        setupUI()
        setupNavigationBar()
    }

    func setupNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
    }

    func setupUI() {
        // ... (UI setup code remains largely the same as in previous context)
        groupNameTextField = UITextField(); groupNameTextField.placeholder = "Group Name (Required)"; groupNameTextField.borderStyle = .roundedRect
        primaryColorTextField = UITextField(); primaryColorTextField.placeholder = "Primary Color (e.g., #RRGGBB or name)"; primaryColorTextField.borderStyle = .roundedRect
        secondaryColorTextField = UITextField(); secondaryColorTextField.placeholder = "Secondary Color (e.g., #RRGGBB or name)"; secondaryColorTextField.borderStyle = .roundedRect
        groupProfilePictureUrlTextField = UITextField(); groupProfilePictureUrlTextField.placeholder = "Group Profile Picture URL (Optional)"; groupProfilePictureUrlTextField.borderStyle = .roundedRect; groupProfilePictureUrlTextField.autocapitalizationType = .none; groupProfilePictureUrlTextField.keyboardType = .URL
        createButton = UIButton(type: .system); createButton.setTitle("Create Group", for: .normal); createButton.addTarget(self, action: #selector(createButtonTapped), for: .touchUpInside); createButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        activityIndicator = UIActivityIndicatorView(style: .large); activityIndicator.hidesWhenStopped = true
        let infoLabel = UILabel(); infoLabel.text = "Enter a URL for the group profile picture. Color fields can be hex codes (e.g., #FF0000) or color names (e.g., 'red')."; infoLabel.font = UIFont.systemFont(ofSize: 12); infoLabel.textColor = .gray; infoLabel.numberOfLines = 0; infoLabel.textAlignment = .center
        let stackView = UIStackView(arrangedSubviews: [groupNameTextField, primaryColorTextField, secondaryColorTextField, groupProfilePictureUrlTextField, infoLabel, createButton, activityIndicator])
        stackView.axis = .vertical; stackView.spacing = 15; stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    @objc func cancelTapped() {
        dismiss(animated: true, completion: nil)
    }

    @objc func createButtonTapped() {
        guard let groupName = groupNameTextField.text, !groupName.isEmpty else {
            showAlert(title: "Group Name Required", message: "Please enter a name for your group.")
            return
        }

        let primaryColor = primaryColorTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let secondaryColor = secondaryColorTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let groupProfilePictureUrl = groupProfilePictureUrlTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty

        let request = CreateGroupRequest(
            groupName: groupName,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            groupProfilePictureUrl: groupProfilePictureUrl
        )

        print("Calling createGroup function with DTO: \(request)")
        setLoadingState(true)

        functionsService.callFunction(
            name: "createGroup",
            data: request,
            responseType: CreateGroupResponse.self
        ) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let response):
                if response.success { // Assuming CreateGroupResponse has a 'success' field or similar indication
                    print("Group created successfully with ID: \(response.groupId). Invite Code: \(response.inviteLinkCode ?? "N/A")")

                    // If an invite code is returned and needs to be written to the group document separately
                    if let code = response.inviteLinkCode, !code.isEmpty {
                        self.dataStorageService.updateGroup(groupId: response.groupId, data: ["inviteLinkCode": code]) { [weak self] updateResult in
                            guard let self = self else { return }
                            DispatchQueue.main.async { // Ensure UI updates are on main thread
                                self.setLoadingState(false)
                                switch updateResult {
                                case .success:
                                    print("Group document successfully updated with inviteLinkCode: \(code)")
                                    self.showAlert(title: "Success", message: "Group '\(groupName)' created! Invite Code: \(code)") {
                                        self.dismiss(animated: true, completion: nil)
                                    }
                                case .failure(let err):
                                    print("Error updating group with inviteLinkCode: \(err)")
                                    self.showAlert(title: "Group Created (with warning)", message: "Group '\(groupName)' created, but issue saving invite code: \(err.localizedDescription). Invite Code: \(code)") {
                                        self.dismiss(animated: true, completion: nil)
                                    }
                                }
                            }
                        }
                    } else { // No invite code to update, or function handles it
                        DispatchQueue.main.async {
                            self.setLoadingState(false)
                            self.showAlert(title: "Success", message: response.message ?? "Group '\(groupName)' created successfully!") {
                                self.dismiss(animated: true, completion: nil)
                            }
                        }
                    }
                } else { // createGroup function call itself indicated failure
                    DispatchQueue.main.async {
                        self.setLoadingState(false)
                        self.showAlert(title: "Creation Error", message: response.message ?? "Failed to create group on server.")
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.setLoadingState(false)
                    print("Error calling createGroup function: \(error)")
                    self.showAlert(title: "Creation Error", message: "Failed to create group: \(error.localizedDescription)")
                }
            }
        }
    }

    private func setLoadingState(_ isLoading: Bool) {
        DispatchQueue.main.async { // Ensure UI updates are on the main thread
            self.activityIndicator.isHidden = !isLoading
            if isLoading {
                self.activityIndicator.startAnimating()
            } else {
                self.activityIndicator.stopAnimating()
            }
            self.createButton.isEnabled = !isLoading
            self.groupNameTextField.isEnabled = !isLoading
            self.primaryColorTextField.isEnabled = !isLoading
            self.secondaryColorTextField.isEnabled = !isLoading
            self.groupProfilePictureUrlTextField.isEnabled = !isLoading
            self.navigationItem.leftBarButtonItem?.isEnabled = !isLoading // Cancel button
        }
    }

    func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in completion?() }))
            self.present(alert, animated: true, completion: nil)
        }
    }
}

// Helper extension to make optional strings nil if they are empty after trimming.
extension Optional where Wrapped == String {
    var nilIfEmpty: String? {
        guard let self = self else { return nil }
        return self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}

extension String {
    var nilIfEmpty: String? {
        return self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
