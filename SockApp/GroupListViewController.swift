import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions // Import FirebaseFunctions

class GroupListViewController: UIViewController {

    var tableView: UITableView!
    var groups: [Group] = []
    var activityIndicator: UIActivityIndicatorView!

    lazy var db = Firestore.firestore()
    lazy var functions = Functions.functions() // Add lazy var for functions
    var userListener: ListenerRegistration?
    // Store listeners for individual groups if real-time updates per group are needed
    // var groupListeners: [String: ListenerRegistration] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Your Groups"
        view.backgroundColor = .white

        setupUI()
        setupNavigationBar()

        // Initial fetch. Real-time updates will be handled by listeners.
        fetchUserGroups()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if Auth.auth().currentUser == nil {
            navigateToLogin()
        } else {
            // Re-attach listener if needed, or ensure data is fresh
            // For now, fetchUserGroups will be called, which re-attaches the user listener
            if userListener == nil { // Or based on some other logic if view can appear multiple times
                 fetchUserGroups()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Detach listeners when the view is not visible to save resources
        // userListener?.remove()
        // userListener = nil
        // groupListeners.values.forEach { $0.remove() }
        // groupListeners.removeAll()
        // Decided against removing listeners here for simplicity in this step.
        // In a more complex app, manage listener lifecycle carefully.
    }

    deinit {
        userListener?.remove()
        // groupListeners.values.forEach { $0.remove() } // If individual group listeners were used
        print("GroupListViewController deinitialized and listeners removed.")
    }

    func setupUI() {
        tableView = UITableView(frame: view.bounds, style: .plain)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "GroupCell")
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = view.center
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)

        let noGroupsLabel = UILabel()
        noGroupsLabel.text = "You are not a member of any groups yet. Create one!"
        noGroupsLabel.textColor = .gray
        noGroupsLabel.textAlignment = .center
        noGroupsLabel.isHidden = true // Initially hidden
        tableView.backgroundView = noGroupsLabel
    }

    func setupNavigationBar() {
        let profileButton = UIBarButtonItem(title: "Profile", style: .plain, target: self, action: #selector(profileTapped))
        let signOutButton = UIBarButtonItem(title: "Sign Out", style: .plain, target: self, action: #selector(signOutTapped))
        let invitationsButton = UIBarButtonItem(title: "Invites", style: .plain, target: self, action: #selector(invitationsTapped)) // New button for invitations
        navigationItem.leftBarButtonItems = [profileButton, signOutButton, invitationsButton]

        let createGroupButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(createGroupTapped))
        let joinGroupButton = UIBarButtonItem(title: "Join", style: .plain, target: self, action: #selector(joinGroupViaCodeTapped))
        navigationItem.rightBarButtonItems = [createGroupButton, joinGroupButton]
    }

    @objc func profileTapped() {
        let profileVC = ProfileViewController()
        navigationController?.pushViewController(profileVC, animated: true)
    }

    @objc func createGroupTapped() {
        let createGroupVC = CreateGroupViewController()
        let navController = UINavigationController(rootViewController: createGroupVC)
        // Set modal presentation style if desired, e.g., .fullScreen or .pageSheet
        // navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true, completion: nil)
    }

    @objc func signOutTapped() {
        do {
            try Auth.auth().signOut()
            navigateToLogin()
        } catch let signOutError {
            showAlert(title: "Sign Out Error", message: "Could not sign out: \(signOutError.localizedDescription)")
        }
    }

    @objc func invitationsTapped() {
        let invitationsVC = InvitationsViewController()
        navigationController?.pushViewController(invitationsVC, animated: true)
    }

    @objc func joinGroupViaCodeTapped() {
        let alertController = UIAlertController(title: "Join Group via Code", message: "Enter the invite code:", preferredStyle: .alert)

        alertController.addTextField { textField in
            textField.placeholder = "Invite Code"
            textField.autocapitalizationType = .none
        }

        let submitAction = UIAlertAction(title: "Submit", style: .default) { [weak self, weak alertController] _ in
            guard let textField = alertController?.textFields?.first, let code = textField.text, !code.isEmpty else {
                self?.showAlert(title: "Error", message: "Invite code cannot be empty.")
                return
            }
            self?.submitInviteCode(code: code)
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

        alertController.addAction(submitAction)
        alertController.addAction(cancelAction)

        present(alertController, animated: true)
    }

    func submitInviteCode(code: String) {
        print("Submitting invite code: \(code)")
        activityIndicator.startAnimating() // Show activity indicator

        functions.httpsCallable("processInviteLink").call(["inviteLinkCode": code]) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating() // Hide activity indicator

                if let error = error as NSError? {
                    var errorMessage = error.localizedDescription
                    if error.domain == FunctionsErrorDomain {
                        if let details = error.userInfo[FunctionsErrorDetailsKey] as? [String: Any], let message = details["message"] as? String {
                             errorMessage = message // Use specific message from backend if available
                        }
                        // You could further check error.code (FunctionsErrorCode) for more specific client-side messages
                        // e.g. .notFound, .alreadyExists etc.
                    }
                    print("Error processing invite code: \(errorMessage), details: \(error.userInfo)")
                    self?.showAlert(title: "Error Processing Code", message: errorMessage)
                    return
                }

                if let data = result?.data as? [String: Any], let success = data["success"] as? Bool, success == true {
                    let invitationId = data["invitationId"] as? String ?? "N/A"
                    print("Invite code processed successfully. Invitation ID: \(invitationId)")
                    // The user document listener should eventually update the UI if a new pending invitation appears.
                    // For now, just inform the user.
                    self?.showAlert(title: "Success", message: "Invitation code processed! You'll be able to accept the invitation soon.")
                } else {
                    // This case might occur if success is false or data is not as expected
                    let responseData = result?.data as? [String: Any]
                    let message = responseData?["message"] as? String ?? "Could not process invite code. Please try again."
                    print("processInviteLink function returned success:false or unexpected data: \(String(describing: result?.data))")
                    self?.showAlert(title: "Processing Error", message: message)
                }
            }
        }
    }

    func fetchUserGroups() {
        guard let currentUser = Auth.auth().currentUser else {
            print("No current user. Cannot fetch groups.")
            navigateToLogin()
            return
        }

        activityIndicator.startAnimating()

        // Remove previous listener if any, to avoid multiple listeners on the same document
        userListener?.remove()

        userListener = db.collection("users").document(currentUser.uid)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                guard let self = self else { return }
                // self.activityIndicator.stopAnimating() // Stop indicator once initial user data is processed

                if let error = error {
                    print("Error fetching user document: \(error)")
                    self.showAlert(title: "Error", message: "Could not load your group information. \(error.localizedDescription)")
                    self.activityIndicator.stopAnimating() // Ensure indicator stops on error
                    return
                }

                guard let document = documentSnapshot, document.exists, let userData = document.data() else {
                    print("User document not found or empty.")
                    self.groups.removeAll() // Clear existing groups
                    self.tableView.reloadData()
                    self.updateNoGroupsLabel()
                    self.activityIndicator.stopAnimating() // Ensure indicator stops
                    return
                }

                let groupIds = userData["groups"] as? [String] ?? []
                print("User is part of group IDs: \(groupIds)")

                if groupIds.isEmpty {
                    self.groups.removeAll()
                    self.tableView.reloadData()
                    self.updateNoGroupsLabel()
                    self.activityIndicator.stopAnimating()
                    return
                }
                self.fetchGroupDetails(groupIds: groupIds)
            }
    }

    func fetchGroupDetails(groupIds: [String]) {
        if groupIds.isEmpty { // Should be caught by the caller, but as a safeguard
            self.groups.removeAll()
            self.tableView.reloadData()
            self.updateNoGroupsLabel()
            self.activityIndicator.stopAnimating()
            return
        }

        let dispatchGroup = DispatchGroup()
        var fetchedGroups: [Group] = []
        var anyError: Error? = nil

        // Not using snapshot listeners for individual groups in this iteration for simplicity
        // but it would be the way to get real-time updates for group name changes, etc.
        for groupId in groupIds {
            dispatchGroup.enter()
            db.collection("groups").document(groupId).getDocument { (document, error) in
                defer { dispatchGroup.leave() }
                if let error = error {
                    print("Error fetching group \(groupId): \(error)")
                    anyError = error // Capture the last error
                    return
                }
                if let document = document, document.exists {
                    do {
                        let group = try document.data(as: Group.self)
                        fetchedGroups.append(group)
                    } catch let decodeError {
                        print("Error decoding group \(groupId): \(decodeError)")
                        anyError = decodeError
                    }
                } else {
                    print("Group document \(groupId) does not exist.")
                    // Handle missing group, maybe mark as an error or skip
                }
            }
        }

        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.activityIndicator.stopAnimating()
            if let error = anyError { // If any error occurred during fetching individual groups
                 // Only show alert if no groups were fetched at all, otherwise partial data might be ok
                if fetchedGroups.isEmpty {
                    self.showAlert(title: "Error Fetching Groups", message: "Some group details could not be loaded. \(error.localizedDescription)")
                }
            }

            // Sort groups by name, or any other criteria
            self.groups = fetchedGroups.sorted(by: { $0.groupName.lowercased() < $1.groupName.lowercased() })
            self.tableView.reloadData()
            self.updateNoGroupsLabel()
            print("Fetched group details. Total groups: \(self.groups.count)")
        }
    }

    func updateNoGroupsLabel() {
        if let backgroundView = tableView.backgroundView as? UILabel {
            backgroundView.isHidden = !groups.isEmpty
        }
    }

    func navigateToLogin() {
        // This assumes GroupListViewController is the root or within a UINavigationController
        // that was presented by LoginViewController or SceneDelegate.
        // A more robust solution uses a coordinator or delegate pattern.

        // If GroupList is part of a nav controller that was presented modally (e.g. by LoginVC)
        if let presentingVC = self.navigationController?.presentingViewController {
            presentingVC.dismiss(animated: true, completion: nil)
        } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let sceneDelegate = windowScene.delegate as? SceneDelegate,
                  let window = sceneDelegate.window {
            // Fallback: Reset root view controller to LoginViewController
            let loginVC = LoginViewController()
            window.rootViewController = UINavigationController(rootViewController: loginVC) // Embed in Nav
            window.makeKeyAndVisible()
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil, completion: nil)
        } else {
             // If this VC itself was presented modally without a NavController
             self.dismiss(animated: true, completion: nil)
        }
    }

    // Helper to show alerts
    func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in completion?() }))
        present(alert, animated: true, completion: nil)
    }
}

extension GroupListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groups.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "GroupCell", for: indexPath)
        let group = groups[indexPath.row]
        cell.textLabel?.text = group.groupName
        // TODO: Add async image loading for groupProfilePictureUrl
        // TODO: Set cell accessory type for navigation to group chat (later subtask)
        cell.accessoryType = .disclosureIndicator // Placeholder for tapping a group
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let selectedGroup = groups[indexPath.row]

        let actionSheet = UIAlertController(title: selectedGroup.groupName, message: "Select an action", preferredStyle: .actionSheet)

        // Action to Show Invite Code
        let showInviteCodeAction = UIAlertAction(title: "Show Invite Code", style: .default) { [weak self] _ in
            self?.displayInviteCode(for: selectedGroup)
        }
        actionSheet.addAction(showInviteCodeAction)

        // Action to Invite by Username
        let inviteByUsernameAction = UIAlertAction(title: "Invite by Username", style: .default) { [weak self] _ in
            self?.promptForUsernameAndInvite(to: selectedGroup)
        }
        actionSheet.addAction(inviteByUsernameAction)

        let openGroupAction = UIAlertAction(title: "Open Group Details", style: .default) { [weak self] _ in
            let detailVC = GroupDetailViewController(group: selectedGroup)
            self?.navigationController?.pushViewController(detailVC, animated: true)
        }
        actionSheet.addAction(openGroupAction)

        // Placeholder for navigation to group chat view (can be added here)
        // let navigateToGroupChatAction = UIAlertAction(title: "Open Group Chat", style: .default) { [weak self] _ in
        //     // Placeholder navigation
        //     print("Navigate to chat for group: \(selectedGroup.groupName)")
        //     self?.showAlert(title: "Coming Soon", message: "Group chat functionality will be implemented later.")
        // }
        // actionSheet.addAction(navigateToGroupChatAction)


        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        actionSheet.addAction(cancelAction)

        // For iPad support with action sheets
        if let popoverController = actionSheet.popoverPresentationController {
            if let cell = tableView.cellForRow(at: indexPath) {
                popoverController.sourceView = cell
                popoverController.sourceRect = cell.bounds
            }
        }

        present(actionSheet, animated: true, completion: nil)
    }

    func displayInviteCode(for group: Group) {
        guard let inviteCode = group.inviteLinkCode, !inviteCode.isEmpty else {
            showAlert(title: "Invite Code", message: "Invite code not available for this group.")
            return
        }

        let alertController = UIAlertController(title: "Group Invite Code", message: inviteCode, preferredStyle: .alert)

        let copyAction = UIAlertAction(title: "Copy Code", style: .default) { _ in
            UIPasteboard.general.string = inviteCode
            self.showAlert(title: "Copied!", message: "Invite code copied to clipboard.")
        }
        alertController.addAction(copyAction)

        let okAction = UIAlertAction(title: "OK", style: .cancel)
        alertController.addAction(okAction)

        present(alertController, animated: true, completion: nil)
    }

    func promptForUsernameAndInvite(to group: Group) {
        guard let groupId = group.id else {
            showAlert(title: "Error", message: "Group ID is missing.")
            return
        }

        let alertController = UIAlertController(title: "Invite to \(group.groupName)", message: "Enter username to invite:", preferredStyle: .alert)

        alertController.addTextField { textField in
            textField.placeholder = "Target Username"
            textField.autocapitalizationType = .none
        }

        let submitAction = UIAlertAction(title: "Submit Invite", style: .default) { [weak self, weak alertController] _ in
            guard let textField = alertController?.textFields?.first, let targetUsername = textField.text, !targetUsername.isEmpty else {
                self?.showAlert(title: "Error", message: "Target username cannot be empty.")
                return
            }
            self?.callProcessBlindUsernameInvite(targetUsername: targetUsername, groupId: groupId)
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

        alertController.addAction(submitAction)
        alertController.addAction(cancelAction)

        present(alertController, animated: true)
    }

    func callProcessBlindUsernameInvite(targetUsername: String, groupId: String) {
        print("Inviting user '\(targetUsername)' to group ID '\(groupId)'")
        activityIndicator.startAnimating()

        let callData: [String: Any] = [
            "targetUsername": targetUsername,
            "groupId": groupId
        ]

        functions.httpsCallable("processBlindUsernameInvite").call(callData) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()

                if let error = error as NSError? {
                    var errorMessage = error.localizedDescription
                    if error.domain == FunctionsErrorDomain {
                         if let details = error.userInfo[FunctionsErrorDetailsKey] as? [String: Any], let message = details["message"] as? String {
                            errorMessage = message
                        }
                    }
                    print("Error calling processBlindUsernameInvite: \(errorMessage), details: \(error.userInfo)")
                    self?.showAlert(title: "Invite Error", message: errorMessage)
                    return
                }

                if let data = result?.data as? [String: Any], let success = data["success"] as? Bool, success == true {
                    let message = data["message"] as? String ?? "Invite will be processed if username is valid."
                    print("processBlindUsernameInvite successful: \(message)")
                    self?.showAlert(title: "Invite Sent (Potentially)", message: message)
                } else {
                    let responseData = result?.data as? [String: Any]
                    let message = responseData?["message"] as? String ?? "Could not process blind invite. Please try again."
                    print("processBlindUsernameInvite function returned success:false or unexpected data: \(String(describing: result?.data))")
                    self?.showAlert(title: "Invite Error", message: message)
                }
            }
        }
    }
}
