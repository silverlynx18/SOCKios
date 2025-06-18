import UIKit
import FirebaseAuth
import FirebaseFunctions
import FirebaseFirestore

class CreateGroupViewController: UIViewController {

    // UI Elements
    var groupNameTextField: UITextField!
    var primaryColorTextField: UITextField!
    var secondaryColorTextField: UITextField!
    var groupProfilePictureUrlTextField: UITextField!
    var createButton: UIButton!
    var activityIndicator: UIActivityIndicatorView!

    lazy var functions = Functions.functions()
    // db might not be strictly needed if all work is done via functions, but good to have.
    lazy var db = Firestore.firestore()

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
        groupNameTextField = UITextField()
        groupNameTextField.placeholder = "Group Name (Required)"
        groupNameTextField.borderStyle = .roundedRect

        primaryColorTextField = UITextField()
        primaryColorTextField.placeholder = "Primary Color (e.g., #RRGGBB or name)"
        primaryColorTextField.borderStyle = .roundedRect

        secondaryColorTextField = UITextField()
        secondaryColorTextField.placeholder = "Secondary Color (e.g., #RRGGBB or name)"
        secondaryColorTextField.borderStyle = .roundedRect

        groupProfilePictureUrlTextField = UITextField()
        groupProfilePictureUrlTextField.placeholder = "Group Profile Picture URL (Optional)"
        groupProfilePictureUrlTextField.borderStyle = .roundedRect
        groupProfilePictureUrlTextField.autocapitalizationType = .none
        groupProfilePictureUrlTextField.keyboardType = .URL

        createButton = UIButton(type: .system)
        createButton.setTitle("Create Group", for: .normal)
        createButton.addTarget(self, action: #selector(createButtonTapped), for: .touchUpInside)
        createButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)

        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.hidesWhenStopped = true

        let infoLabel = UILabel()
        infoLabel.text = "Enter a URL for the group profile picture. Color fields can be hex codes (e.g., #FF0000) or color names (e.g., 'red')."
        infoLabel.font = UIFont.systemFont(ofSize: 12)
        infoLabel.textColor = .gray
        infoLabel.numberOfLines = 0
        infoLabel.textAlignment = .center

        let stackView = UIStackView(arrangedSubviews: [
            groupNameTextField,
            primaryColorTextField,
            secondaryColorTextField,
            groupProfilePictureUrlTextField,
            infoLabel,
            createButton,
            activityIndicator
        ])
        stackView.axis = .vertical
        stackView.spacing = 15
        stackView.translatesAutoresizingMaskIntoConstraints = false
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

        let primaryColor = primaryColorTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let secondaryColor = secondaryColorTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let groupProfilePictureUrl = groupProfilePictureUrlTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)

        let callData: [String: Any] = [
            "groupName": groupName,
            "primaryColor": primaryColor ?? NSNull(), // Send NSNull if empty/nil
            "secondaryColor": secondaryColor ?? NSNull(),
            "groupProfilePictureUrl": groupProfilePictureUrl ?? NSNull()
        ]

        print("Calling createGroup function with data: \(callData)")
        setLoadingState(true)

        functions.httpsCallable("createGroup").call(callData) { [weak self] result, error in
            // Nested Firestore call, so manage loading state carefully.
            // setLoadingState(false) will be called after the Firestore update (if any) or error.

            guard let self = self else { return }

            if let error = error as NSError? {
                DispatchQueue.main.async {
                    self.setLoadingState(false)
                    if error.domain == FunctionsErrorDomain {
                        let code = FunctionsErrorCode(rawValue: error.code)
                        let message = error.localizedDescription
                        let details = error.userInfo[FunctionsErrorDetailsKey]
                        print("Error calling createGroup function: \(String(describing: code)), \(message), \(String(describing: details))")
                        self?.showAlert(title: "Creation Error", message: "Failed to create group: \(message)")
                    } else {
                        self?.showAlert(title: "Creation Error", message: "An unexpected error occurred: \(error.localizedDescription)")
                    }
                    return
                }

                guard let data = result?.data as? [String: Any], let groupId = data["groupId"] as? String else {
                    print("createGroup function returned unexpected data or no groupId: \(String(describing: result?.data))")
                    self?.showAlert(title: "Creation Error", message: "Group created, but couldn't get group ID or invite code from response.") {
                        // Still dismiss as the group might have been created. User's list will update.
                        self.dismiss(animated: true, completion: nil)
                    }
                    return
                }

                print("Group created successfully with ID: \(groupId)")
                let inviteLinkCode = data["inviteLinkCode"] as? String

                if let code = inviteLinkCode, !code.isEmpty {
                    // setLoadingState(true) is already active from the function call
                    self.db.collection("groups").document(groupId).updateData(["inviteLinkCode": code]) { [weak self] err in
                        guard let self = self else { return }
                        DispatchQueue.main.async {
                            self.setLoadingState(false) // Final loading state change
                            if let err = err {
                                print("Error updating group with inviteLinkCode: \(err)")
                                self.showAlert(title: "Group Created (with warning)", message: "Group '\(groupName)' created, but there was an issue saving its invite code: \(err.localizedDescription). Invite Code: \(code)") {
                                    self.dismiss(animated: true, completion: nil)
                                }
                            } else {
                                print("Group document successfully updated with inviteLinkCode: \(code)")
                                self.showAlert(title: "Success", message: "Group '\(groupName)' created successfully! Invite Code: \(code)") {
                                    self.dismiss(animated: true, completion: nil)
                                }
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.setLoadingState(false) // Final loading state change
                        print("No inviteLinkCode returned from createGroup function or it was empty.")
                        self.showAlert(title: "Success", message: "Group '\(groupName)' created successfully! (No invite code generated this time).") {
                            self.dismiss(animated: true, completion: nil)
                        }
                    }
                }
            }
        }
    }

    private func setLoadingState(_ isLoading: Bool) {
        if isLoading {
            activityIndicator.startAnimating()
            createButton.isEnabled = false
            groupNameTextField.isEnabled = false
            primaryColorTextField.isEnabled = false
            secondaryColorTextField.isEnabled = false
            groupProfilePictureUrlTextField.isEnabled = false
            navigationItem.leftBarButtonItem?.isEnabled = false // Cancel button
        } else {
            activityIndicator.stopAnimating()
            createButton.isEnabled = true
            groupNameTextField.isEnabled = true
            primaryColorTextField.isEnabled = true
            secondaryColorTextField.isEnabled = true
            groupProfilePictureUrlTextField.isEnabled = true
            navigationItem.leftBarButtonItem?.isEnabled = true
        }
    }

    // Helper to show alerts
    func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in completion?() }))
        present(alert, animated: true, completion: nil)
    }
}
