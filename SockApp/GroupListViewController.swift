import UIKit
// Remove: import FirebaseAuth
// Remove: import FirebaseFirestore
// Remove: import FirebaseFunctions

// Ensure DTOs like ProcessInviteLinkRequest, ProcessBlindUsernameInviteRequest,
// and GenericFunctionResponse are available from FunctionsServiceProtocol.swift or other DTO files.
// Ensure model types (Group, UserProfile) are available.

class GroupListViewController: UIViewController {

    var tableView: UITableView!
    var groups: [Group] = []
    var activityIndicator: UIActivityIndicatorView!
    var noGroupsLabel: UILabel! // Added for clarity

    // Service dependencies
    private let authService: AuthServiceProtocol
    private let dataStorageService: DataStorageServiceProtocol
    private let functionsService: FunctionsServiceProtocol

    private var userProfileListener: ListenerRegistrationProtocol?

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
        title = "Your Groups"
        view.backgroundColor = .white

        setupUI()
        setupNavigationBar()

        // Initial fetch will be triggered by viewWillAppear if user is logged in.
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if authService.getCurrentUser() == nil {
            navigateToLogin()
        } else {
            // Start listening to user profile for group list if not already listening
            if userProfileListener == nil {
                 fetchUserGroups()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Optionally remove listener if view is not visible, depends on app's data freshness needs.
        // For this example, keeping it active while this VC is in nav stack.
        // userProfileListener?.remove()
        // userProfileListener = nil
    }

    deinit {
        userProfileListener?.remove()
        print("GroupListViewController deinitialized and userProfileListener removed.")
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

        noGroupsLabel = UILabel() // ensure this is initialized
        noGroupsLabel.text = "You are not a member of any groups yet. Create one or join using an invite code!"
        noGroupsLabel.textColor = .gray
        noGroupsLabel.textAlignment = .center
        noGroupsLabel.numberOfLines = 0
        noGroupsLabel.isHidden = true
        tableView.backgroundView = noGroupsLabel
    }

    func setupNavigationBar() {
        let profileButton = UIBarButtonItem(title: "Profile", style: .plain, target: self, action: #selector(profileTapped))
        let signOutButton = UIBarButtonItem(title: "Sign Out", style: .plain, target: self, action: #selector(signOutTapped))
        let invitationsButton = UIBarButtonItem(title: "Invites", style: .plain, target: self, action: #selector(invitationsTapped))
        navigationItem.leftBarButtonItems = [profileButton, signOutButton, invitationsButton]

        let createGroupButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(createGroupTapped))
        let joinGroupButton = UIBarButtonItem(title: "Join", style: .plain, target: self, action: #selector(joinGroupViaCodeTapped))
        navigationItem.rightBarButtonItems = [createGroupButton, joinGroupButton]
    }

    @objc func profileTapped() {
        let profileVC = ProfileViewController(authService: authService, dataStorageService: dataStorageService, functionsService: functionsService)
        navigationController?.pushViewController(profileVC, animated: true)
    }

    @objc func createGroupTapped() {
        let createGroupVC = CreateGroupViewController(dataStorageService: dataStorageService, functionsService: functionsService, authService: authService)
        let navController = UINavigationController(rootViewController: createGroupVC)
        present(navController, animated: true, completion: nil)
    }

    @objc func signOutTapped() {
        authService.signOut { [weak self] error in
            if let error = error {
                self?.showAlert(title: "Sign Out Error", message: "Could not sign out: \(error.localizedDescription)")
            } else {
                self?.navigateToLogin()
            }
        }
    }

    @objc func invitationsTapped() {
        let invitationsVC = InvitationsViewController(dataStorageService: dataStorageService, functionsService: functionsService, authService: authService)
        navigationController?.pushViewController(invitationsVC, animated: true)
    }

    @objc func joinGroupViaCodeTapped() {
        let alertController = UIAlertController(title: "Join Group via Code", message: "Enter the invite code:", preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = "Invite Code"
            textField.autocapitalizationType = .none
        }
        let submitAction = UIAlertAction(title: "Submit", style: .default) { [weak self, weak alertController] _ in
            guard let code = alertController?.textFields?.first?.text, !code.isEmpty else {
                self?.showAlert(title: "Error", message: "Invite code cannot be empty.")
                return
            }
            self?.submitInviteCode(code: code)
        }
        alertController.addAction(submitAction)
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alertController, animated: true)
    }

    func submitInviteCode(code: String) {
        print("Submitting invite code: \(code)")
        activityIndicator.startAnimating()

        let request = ProcessInviteLinkRequest(inviteLinkCode: code)
        // Assuming GenericFunctionResponse is suitable, or define a more specific DTO if needed.
        functionsService.callFunction(
            name: "processInviteLink",
            data: request,
            responseType: GenericFunctionResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                switch result {
                case .success(let response):
                    if response.success {
                        print("Invite code processed successfully. Message: \(response.message ?? "N/A")")
                        self?.showAlert(title: "Success", message: response.message ?? "Invitation code processed! You'll be able to accept the invitation soon.")
                    } else {
                        self?.showAlert(title: "Processing Error", message: response.message ?? "Could not process invite code.")
                    }
                case .failure(let error):
                    print("Error processing invite code function: \(error)")
                    self?.showAlert(title: "Error Processing Code", message: error.localizedDescription)
                }
            }
        }
    }

    func fetchUserGroups() {
        guard let currentAuthUser = authService.getCurrentUser() else {
            print("No current user. Cannot fetch groups.")
            navigateToLogin()
            return
        }

        activityIndicator.startAnimating()
        userProfileListener?.remove() // Remove previous listener if any

        userProfileListener = dataStorageService.addUserProfileListener(uid: currentAuthUser.uid) { [weak self] result in
            guard let self = self else { return }
            // activityIndicator should be stopped after group details are fetched or if groupIDs are empty.

            switch result {
            case .success(let userProfile):
                let groupIds = userProfile.groups ?? []
                print("User is part of group IDs: \(groupIds)")
                if groupIds.isEmpty {
                    self.groups.removeAll()
                    self.tableView.reloadData()
                    self.updateNoGroupsLabel()
                    self.activityIndicator.stopAnimating()
                } else {
                    self.fetchGroupDetails(groupIds: groupIds)
                }
            case .failure(let error):
                print("Error fetching user profile: \(error)")
                self.showAlert(title: "Error", message: "Could not load your group information. \(error.localizedDescription)")
                self.activityIndicator.stopAnimating()
            }
        }
    }

    func fetchGroupDetails(groupIds: [String]) {
        // activityIndicator is already started by fetchUserGroups
        dataStorageService.getGroups(groupIds: groupIds) { [weak self] result in
            guard let self = self else { return }
            self.activityIndicator.stopAnimating()

            switch result {
            case .success(let fetchedGroups):
                // The service already sorts them.
                self.groups = fetchedGroups
                self.tableView.reloadData()
                self.updateNoGroupsLabel()
                print("Fetched group details. Total groups: \(self.groups.count)")
            case .failure(let error):
                 // Only show alert if no groups were fetched at all, otherwise partial data might be ok
                if self.groups.isEmpty { // Check if groups array is still empty
                    self.showAlert(title: "Error Fetching Groups", message: "Some group details could not be loaded. \(error.localizedDescription)")
                }
                print("Error in fetchGroupDetails: \(error.localizedDescription)")
                // Potentially update UI to show partial data if some groups were fetched before an error.
                // The current getGroups implementation in service might return partials.
            }
        }
    }

    func updateNoGroupsLabel() {
        // This was tableView.backgroundView in the original.
        // Ensure noGroupsLabel is added to the view hierarchy correctly if it's not a backgroundView.
        // If it's the backgroundView of the tableView:
        if let bgView = tableView.backgroundView as? UILabel {
            bgView.isHidden = !groups.isEmpty
        } else { // If it's a separate label added to view:
            noGroupsLabel.isHidden = !groups.isEmpty
            tableView.isHidden = groups.isEmpty
        }
    }

    func navigateToLogin() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let sceneDelegate = windowScene.delegate as? SceneDelegate,
           let window = sceneDelegate.window {
            let loginVC = LoginViewController(
                authService: sceneDelegate.authService, // Use services from SceneDelegate
                dataStorageService: sceneDelegate.dataStorageService,
                functionsService: sceneDelegate.functionsService
            )
            window.rootViewController = UINavigationController(rootViewController: loginVC)
            window.makeKeyAndVisible()
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil, completion: nil)
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

extension GroupListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groups.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "GroupCell", for: indexPath)
        let group = groups[indexPath.row]
        cell.textLabel?.text = group.groupName
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let selectedGroup = groups[indexPath.row]

        let actionSheet = UIAlertController(title: selectedGroup.groupName, message: "Select an action", preferredStyle: .actionSheet)

        actionSheet.addAction(UIAlertAction(title: "Show Invite Code", style: .default) { [weak self] _ in
            self?.displayInviteCode(for: selectedGroup)
        })
        actionSheet.addAction(UIAlertAction(title: "Invite by Username", style: .default) { [weak self] _ in
            self?.promptForUsernameAndInvite(to: selectedGroup)
        }))
        actionSheet.addAction(UIAlertAction(title: "Open Group Details", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let detailVC = GroupDetailViewController(
                group: selectedGroup,
                authService: self.authService,
                dataStorageService: self.dataStorageService,
                functionsService: self.functionsService
            )
            self.navigationController?.pushViewController(detailVC, animated: true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popoverController = actionSheet.popoverPresentationController {
            if let cell = tableView.cellForRow(at: indexPath) {
                popoverController.sourceView = cell
                popoverController.sourceRect = cell.bounds
            } else { // Fallback for popover source
                 popoverController.sourceView = self.view
                 popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                 popoverController.permittedArrowDirections = []
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
        alertController.addAction(UIAlertAction(title: "Copy Code", style: .default) { _ in
            UIPasteboard.general.string = inviteCode
            self.showAlert(title: "Copied!", message: "Invite code copied to clipboard.")
        }))
        alertController.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alertController, animated: true, completion: nil)
    }

    func promptForUsernameAndInvite(to group: Group) {
        guard let groupId = group.id else {
            showAlert(title: "Error", message: "Group ID is missing."); return
        }
        let alertController = UIAlertController(title: "Invite to \(group.groupName)", message: "Enter username to invite:", preferredStyle: .alert)
        alertController.addTextField { $0.placeholder = "Target Username"; $0.autocapitalizationType = .none }
        let submitAction = UIAlertAction(title: "Submit Invite", style: .default) { [weak self, weak alertController] _ in
            guard let targetUsername = alertController?.textFields?.first?.text, !targetUsername.isEmpty else {
                self?.showAlert(title: "Error", message: "Target username cannot be empty."); return
            }
            self?.callProcessBlindUsernameInvite(targetUsername: targetUsername, groupId: groupId)
        }
        alertController.addAction(submitAction)
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alertController, animated: true)
    }

    func callProcessBlindUsernameInvite(targetUsername: String, groupId: String) {
        print("Inviting user '\(targetUsername)' to group ID '\(groupId)'")
        activityIndicator.startAnimating()

        let request = ProcessBlindUsernameInviteRequest(targetUsername: targetUsername, groupId: groupId)
        // Assuming GenericFunctionResponse is suitable
        functionsService.callFunction(
            name: "processBlindUsernameInvite",
            data: request,
            responseType: GenericFunctionResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                switch result {
                case .success(let response):
                    self?.showAlert(title: response.success ? "Invite Sent (Potentially)" : "Invite Error", message: response.message ?? "Request processed.")
                case .failure(let error):
                    print("Error calling processBlindUsernameInvite: \(error)")
                    self?.showAlert(title: "Invite Error", message: error.localizedDescription)
                }
            }
        }
    }
}
