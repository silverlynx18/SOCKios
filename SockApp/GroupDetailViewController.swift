import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

// Simple struct to hold member data for display
struct GroupMemberDisplay {
    let uid: String
    let role: String
    var username: String? // To be fetched
    var globalStatus: String?
    var groupSpecificStatus: String?
}

class GroupDetailViewController: UIViewController {

    var group: Group! // Passed from GroupListViewController

    // UI Elements - Display Mode
    private var groupNameLabel: UILabel!
    private var primaryColorView: UIView!
    private var secondaryColorView: UIView!
    private var profilePicUrlLabel: UILabel!
    private var noMembersLabel: UILabel! // For empty member list
    // Group-Specific Status Display for Current User
    private var currentGroupSpecificStatusTitleLabel: UILabel!
    private var currentGroupSpecificStatusLabel: UILabel!

    // UI Elements - Edit Mode
    private var groupNameTextField: UITextField!
    private var primaryColorTextField: UITextField!
    private var secondaryColorTextField: UITextField!
    private var profilePicUrlTextField: UITextField!
    private var editFieldsStackView: UIStackView! // To hold text fields for group editing

    // Group-Specific Status Input for Current User
    private var groupSpecificStatusTextField: UITextField!
    private var setGroupSpecificStatusButton: UIButton!
    private var groupSpecificStatusStackView: UIStackView!


    private var membersTableView: UITableView!
    private var leaveGroupButton: UIButton!
    private var activityIndicator: UIActivityIndicatorView!

    private var displayMembers: [GroupMemberDisplay] = []
    private var groupListener: ListenerRegistration?
    private var currentUserProfileListener: ListenerRegistration? // Listener for current user's profile
    private var currentUserProfile: UserProfile? // Store current user's full profile

    private var isEditMode: Bool = false {
        didSet {
            configureUIForEditMode()
        }
    }
    private var originalEditButton: UIBarButtonItem?
    private var saveButton: UIBarButtonItem?
    private var cancelEditButton: UIBarButtonItem?


    lazy var db = Firestore.firestore()
    lazy var functions = Functions.functions()

    init(group: Group) {
        self.group = group
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = group.groupName // Set title early

        setupEditBarButtonItems()
        setupUI()
        populateGroupDetails() // Initial population
        setupGroupListener()
        setupCurrentUserProfileListener() // Listen to current user's profile for status updates
        updateEditButtonVisibility()
        updateGroupSpecificStatusUIVisibility()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateEditButtonVisibility()
        updateGroupSpecificStatusUIVisibility() // In case group membership changes elsewhere
    }

    deinit {
        groupListener?.remove()
        currentUserProfileListener?.remove()
        print("GroupDetailViewController deinitialized and listeners removed.")
    }

    func setupUI() {
        groupNameLabel = UILabel()
        groupNameLabel.font = UIFont.boldSystemFont(ofSize: 24)
        groupNameLabel.textAlignment = .center

        // Edit Mode TextFields (initially hidden)
        groupNameTextField = createTextField(placeholder: "Group Name")
        primaryColorTextField = createTextField(placeholder: "Primary Color (hex or name)")
        secondaryColorTextField = createTextField(placeholder: "Secondary Color (hex or name)")
        profilePicUrlTextField = createTextField(placeholder: "Profile Picture URL", keyboardType: .URL)

        editFieldsStackView = UIStackView(arrangedSubviews: [
            groupNameTextField, primaryColorTextField, secondaryColorTextField, profilePicUrlTextField
        ])
        editFieldsStackView.axis = .vertical
        editFieldsStackView.spacing = 10
        editFieldsStackView.isHidden = true // Initially hidden

        // Group-Specific Status UI
        currentGroupSpecificStatusTitleLabel = UILabel()
        currentGroupSpecificStatusTitleLabel.text = "Your Status in this Group:"
        currentGroupSpecificStatusTitleLabel.font = UIFont.boldSystemFont(ofSize: 16)

        currentGroupSpecificStatusLabel = UILabel()
        currentGroupSpecificStatusLabel.text = "Loading..."
        currentGroupSpecificStatusLabel.font = UIFont.systemFont(ofSize: 14)
        currentGroupSpecificStatusLabel.numberOfLines = 0

        groupSpecificStatusTextField = createTextField(placeholder: "Set your status for this group")
        setGroupSpecificStatusButton = UIButton(type: .system)
        setGroupSpecificStatusButton.setTitle("Set Status", for: .normal)
        setGroupSpecificStatusButton.addTarget(self, action: #selector(setGroupSpecificStatusTapped), for: .touchUpInside)

        groupSpecificStatusStackView = UIStackView(arrangedSubviews: [
            currentGroupSpecificStatusTitleLabel, currentGroupSpecificStatusLabel,
            groupSpecificStatusTextField, setGroupSpecificStatusButton
        ])
        groupSpecificStatusStackView.axis = .vertical
        groupSpecificStatusStackView.spacing = 8
        groupSpecificStatusStackView.isHidden = true // Initially hidden, shown if user is a member


        primaryColorView = UIView()
        secondaryColorView = UIView()
        primaryColorView.layer.borderWidth = 1
        primaryColorView.layer.borderColor = UIColor.lightGray.cgColor
        secondaryColorView.layer.borderWidth = 1
        secondaryColorView.layer.borderColor = UIColor.lightGray.cgColor

        let colorStack = UIStackView(arrangedSubviews: [primaryColorView, secondaryColorView])
        colorStack.axis = .horizontal
        colorStack.distribution = .fillEqually
        colorStack.spacing = 10

        profilePicUrlLabel = UILabel()
        profilePicUrlLabel.font = UIFont.systemFont(ofSize: 12)
        profilePicUrlLabel.numberOfLines = 0
        profilePicUrlLabel.textAlignment = .center
        profilePicUrlLabel.lineBreakMode = .byWordWrapping
        profilePicUrlLabel.isUserInteractionEnabled = true // Allow tap to copy if desired

        membersTableView = UITableView()
        membersTableView.dataSource = self
        membersTableView.delegate = self
        membersTableView.register(GroupMemberCell.self, forCellReuseIdentifier: GroupMemberCell.identifier)
        membersTableView.rowHeight = UITableView.automaticDimension
        membersTableView.estimatedRowHeight = 80 // Adjusted for potentially more text in cells

        noMembersLabel = UILabel()
        noMembersLabel.text = "This group has no members."
        noMembersLabel.textColor = .gray
        noMembersLabel.textAlignment = .center
        noMembersLabel.isHidden = true
        membersTableView.backgroundView = noMembersLabel
        // self.noMembersLabel is already assigned by declaration if it's a property.


        leaveGroupButton = UIButton(type: .system)
        leaveGroupButton.setTitle("Leave Group", for: .normal)
        leaveGroupButton.setTitleColor(.white, for: .normal)
        leaveGroupButton.backgroundColor = .systemRed
        leaveGroupButton.layer.cornerRadius = 8
        leaveGroupButton.addTarget(self, action: #selector(leaveGroupTapped), for: .touchUpInside)

        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.hidesWhenStopped = true

        let mainStack = UIStackView(arrangedSubviews: [
            groupNameLabel, editFieldsStackView, colorStack, profilePicUrlLabel,
            groupSpecificStatusStackView, // Add group-specific status UI to main stack
            membersTableView, leaveGroupButton
        ])
        mainStack.axis = .vertical
        // Control visibility of label vs textfield via isEditMode
        mainStack.spacing = 15
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStack)
        view.addSubview(activityIndicator)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            mainStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),

            colorStack.heightAnchor.constraint(equalToConstant: 30),
            membersTableView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100), // Give some space for members
            leaveGroupButton.heightAnchor.constraint(equalToConstant: 44),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    func populateGroupDetails() {
        // Display Labels
        groupNameLabel.text = group.groupName
        primaryColorView.backgroundColor = UIColor(hexString: group.primaryColor ?? "#FFFFFF")
        secondaryColorView.backgroundColor = UIColor(hexString: group.secondaryColor ?? "#EFEFEF")
        if let urlString = group.groupProfilePictureUrl, !urlString.isEmpty {
            profilePicUrlLabel.text = "Profile URL: \(urlString)"
        } else {
            profilePicUrlLabel.text = "No profile picture URL."
        }

        // Edit TextFields (for when edit mode is toggled)
        groupNameTextField.text = group.groupName
        primaryColorTextField.text = group.primaryColor
        secondaryColorTextField.text = group.secondaryColor
        profilePicUrlTextField.text = group.groupProfilePictureUrl

        updateDisplayMembers()
        updateEditButtonVisibility()
        updateGroupSpecificStatusUIVisibility()
        updateCurrentGroupSpecificStatusLabel()
        updateNoMembersLabelVisibility() // Initial check
    }

    func updateDisplayMembers() {
        self.displayMembers = (group.members ?? [:]).map { GroupMemberDisplay(uid: $0.key, role: $0.value, username: nil) }
                                                .sorted(by: {
                                                    // Prioritize sorting by role ("owner" > "admin" > "member"), then by UID
                                                    let roleOrder: [String: Int] = ["owner": 0, "admin": 1, "member": 2]
                                                    let role1 = roleOrder[$0.role.lowercased()] ?? 3
                                                    let role2 = roleOrder[$1.role.lowercased()] ?? 3
                                                    if role1 != role2 {
                                                        return role1 < role2
                                                    }
                                                    return $0.uid < $1.uid
                                                })
        fetchUsernamesForDisplayMembers()
        // updateNoMembersLabelVisibility() will be called after fetchUsernames completes
    }

    func fetchUsernamesForDisplayMembers() {
        let uidsToFetch = displayMembers.filter { $0.username == nil }.map { $0.uid }

        // This guard also handles the case where displayMembers is initially empty.
        guard !uidsToFetch.isEmpty else {
            self.membersTableView.reloadData() // Ensure table is empty if no UIDs
            self.updateCurrentGroupSpecificStatusLabel()
            self.updateNoMembersLabelVisibility() // Crucial for empty initial state
            return
        }

        let usersCollection = db.collection("users")
        let fetchGroupDispatch = DispatchGroup()

        for i in 0..<displayMembers.count {
            // Only fetch if username is not already populated or marked as error
            if displayMembers[i].username == nil || displayMembers[i].username == (displayMembers[i].uid + " (Error)") {
                fetchGroupDispatch.enter()
                usersCollection.document(displayMembers[i].uid).getDocument { [weak self] (documentSnapshot, error) in
                    defer { fetchGroupDispatch.leave() }
                    guard let self = self else { return }

                    if let document = documentSnapshot, document.exists, let userData = try? document.data(as: UserProfile.self) {
                        self.displayMembers[i].username = userData.username
                        self.displayMembers[i].globalStatus = userData.globalStatusId
                        if let groupID = self.group.id {
                            self.displayMembers[i].groupSpecificStatus = userData.groupSpecificStatuses?[groupID]
                        }
                        if self.displayMembers[i].uid == Auth.auth().currentUser?.uid {
                            self.currentUserProfile = userData
                        }
                    } else {
                        print("Could not fetch UserProfile for UID: \(self.displayMembers[i].uid). Error: \(String(describing: error))")
                        self.displayMembers[i].username = self.displayMembers[i].uid + " (Error)"
                    }
                }
            }
        }

        fetchGroupDispatch.notify(queue: .main) { [weak self] in
            self?.membersTableView.reloadData()
            self?.updateCurrentGroupSpecificStatusLabel()
            self?.updateNoMembersLabelVisibility()
        }
    }

    func updateNoMembersLabelVisibility() {
        noMembersLabel?.isHidden = !displayMembers.isEmpty
    }

    func setupCurrentUserProfileListener() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        currentUserProfileListener?.remove()

        currentUserProfileListener = db.collection("users").document(currentUserID)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("Error listening to current user's profile: \(error.localizedDescription)")
                    return
                }
                guard let document = documentSnapshot, document.exists,
                      let userProfile = try? document.data(as: UserProfile.self) else {
                    print("Current user's profile document not found or failed to decode.")
                    self.currentUserProfile = nil // Clear profile if not found
                    self.updateCurrentGroupSpecificStatusLabel()
                    return
                }
                self.currentUserProfile = userProfile
                self.updateCurrentGroupSpecificStatusLabel()
            }
    }

    func updateCurrentGroupSpecificStatusLabel() {
        guard let groupID = group.id else {
            currentGroupSpecificStatusLabel.text = "N/A (Group ID missing)"
            return
        }
        if let status = currentUserProfile?.groupSpecificStatuses?[groupID], !status.isEmpty {
            currentGroupSpecificStatusLabel.text = status
        } else {
            currentGroupSpecificStatusLabel.text = "Not set for this group."
        }
    }

    func updateGroupSpecificStatusUIVisibility() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            groupSpecificStatusStackView.isHidden = true
            return
        }
        // Show if current user is a member of the group
        groupSpecificStatusStackView.isHidden = (group.members?[currentUserID] == nil)
    }


    func setupGroupListener() {
        guard let groupId = group.id else { return }
        groupListener?.remove() // Remove existing listener first

        activityIndicator.startAnimating()
        groupListener = db.collection("groups").document(groupId)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                guard let self = self else { return }
                self.activityIndicator.stopAnimating()

                if let error = error {
                    print("Error listening to group updates: \(error)")
                    self.showAlert(title: "Error", message: "Could not get group updates. \(error.localizedDescription)")
                    return
                }

                guard let document = documentSnapshot, document.exists else {
                    print("Group document \(groupId) deleted or no longer exists.")
                    self.showAlert(title: "Group Not Found", message: "This group may have been deleted.") {
                        self.navigationController?.popViewController(animated: true)
                    }
                    return
                }

                do {
                    let updatedGroup = try document.data(as: Group.self)
                    let wasAdminBefore = self.isCurrentUserAdmin()
                    let previousMembers = self.group.members
                    self.group = updatedGroup
                    self.populateGroupDetails() // This will call updateDisplayMembers -> updateNoMembersLabelVisibility
                    let isAdminNow = self.isCurrentUserAdmin()

                    if wasAdminBefore != isAdminNow {
                        self.updateEditButtonVisibility()
                    }
                    if previousMembers?[Auth.auth().currentUser?.uid ?? ""] != self.group.members?[Auth.auth().currentUser?.uid ?? ""] {
                        self.updateGroupSpecificStatusUIVisibility()
                    }
                    // self.updateNoMembersLabelVisibility() // Called within populateGroupDetails via updateDisplayMembers
                } catch {
                    print("Error decoding updated group data: \(error)")
                    self.showAlert(title: "Update Error", message: "Could not process group updates.")
                }
            }
    }

    @objc func leaveGroupTapped() {
        let groupNameToDisplay = self.group.groupName
        let confirmAlert = UIAlertController(title: "Leave Group", message: "Are you sure you want to leave '\(groupNameToDisplay)'?", preferredStyle: .alert)
        confirmAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        confirmAlert.addAction(UIAlertAction(title: "Leave", style: .destructive, handler: { [weak self] _ in
            self?.performLeaveGroup()
        }))
        present(confirmAlert, animated: true)
    }

    func performLeaveGroup() {
        guard let groupId = group.id else {
            showAlert(title: "Error", message: "Group ID is missing.")
            return
        }
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            showAlert(title: "Error", message: "Could not get current user ID.")
            return
        }

        activityIndicator.startAnimating()
        let callData: [String: Any] = [
            "groupId": groupId,
            "userIdToRemove": currentUserId // User is leaving themselves
        ]

        functions.httpsCallable("handleUserLeaveOrRemove").call(callData) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                if let error = error as NSError? {
                    self?.handleFirebaseFunctionError(error, defaultMessage: "Failed to leave group.")
                    return
                }

                if let data = result?.data as? [String: Any], let success = data["success"] as? Bool, success == true {
                    self?.showAlert(title: "Success", message: "You have successfully left '\(groupNameToDisplay)'.") {
                        self?.navigationController?.popViewController(animated: true)
                    }
                } else {
                    let message = (result?.data as? [String: Any])?["message"] as? String ?? "Could not process leave group request."
                    self?.showAlert(title: "Error", message: message)
                }
            }
        }
    }

    private func handleFirebaseFunctionError(_ error: NSError, defaultMessage: String) {
        var errorMessage = defaultMessage
        if error.domain == FunctionsErrorDomain {
            if let details = error.userInfo[FunctionsErrorDetailsKey] as? [String: Any], let message = details["message"] as? String {
                 errorMessage = message
            } else { // Fallback to generic Firebase error if no custom message from details
                errorMessage = error.localizedDescription
            }
        } else { // Non-Firebase function error
             errorMessage = error.localizedDescription
        }
        print("Firebase Function Error: \(errorMessage), details: \(error.userInfo)")
        showAlert(title: "Error", message: errorMessage)
    }


    // Helper to show alerts
    func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in completion?() }))
        present(alert, animated: true, completion: nil)
    }

    // MARK: - Admin Editing Logic

    func isCurrentUserAdmin() -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        // Assuming "admin" or "owner" roles grant edit permissions
        let userRole = group.members?[currentUserId]
        return userRole == "admin" || userRole == "owner"
    }

    func setupEditBarButtonItems() {
        originalEditButton = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editGroupTapped))
        saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveGroupTapped))
        cancelEditButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelEditTapped))
    }

    func updateEditButtonVisibility() {
        if isCurrentUserAdmin() {
            if isEditMode {
                navigationItem.rightBarButtonItems = [saveButton!, cancelEditButton!]
            } else {
                navigationItem.rightBarButtonItem = originalEditButton
            }
        } else {
            navigationItem.rightBarButtonItem = nil // No edit button if not admin
            if isEditMode { // If was in edit mode and lost admin rights, cancel edit
                isEditMode = false
            }
        }
    }

    @objc func editGroupTapped() {
        isEditMode = true
    }

    @objc saveGroupTapped() {
        guard let groupId = group.id else {
            showAlert(title: "Error", message: "Group ID is missing.")
            return
        }
        guard let newGroupName = groupNameTextField.text, !newGroupName.isEmpty else {
            showAlert(title: "Validation Error", message: "Group name cannot be empty.")
            return
        }

        let newPrimaryColor = primaryColorTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let newSecondaryColor = secondaryColorTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let newProfilePicUrl = profilePicUrlTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)

        var updatedFields: [String: Any] = [:]
        if newGroupName != group.groupName { updatedFields["groupName"] = newGroupName }
        if newPrimaryColor != group.primaryColor { updatedFields["primaryColor"] = newPrimaryColor ?? NSNull() }
        if newSecondaryColor != group.secondaryColor { updatedFields["secondaryColor"] = newSecondaryColor ?? NSNull() }
        if newProfilePicUrl != group.groupProfilePictureUrl { updatedFields["groupProfilePictureUrl"] = newProfilePicUrl ?? NSNull() }

        if updatedFields.isEmpty {
            showAlert(title: "No Changes", message: "You haven't made any changes to save.")
            isEditMode = false // Exit edit mode
            return
        }

        // Firestore Security Rules Reminder:
        // Ensure your Firestore rules protect these fields so only admins/owners can update them.
        // e.g., allow update: if request.auth.uid != null && get(/databases/$(database)/documents/groups/$(resource.id)).data.members[request.auth.uid] in ['admin', 'owner'];

        activityIndicator.startAnimating()
        db.collection("groups").document(groupId).updateData(updatedFields) { [weak self] error in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                if let error = error {
                    print("Error updating group details: \(error)")
                    self?.showAlert(title: "Update Error", message: "Failed to save changes: \(error.localizedDescription)")
                } else {
                    print("Group details updated successfully.")
                    self?.showAlert(title: "Success", message: "Group details for '\(newGroupName)' saved successfully.")
                    self?.isEditMode = false
                }
            }
        }
    }

    @objc func cancelEditTapped() {
        isEditMode = false
        populateGroupDetails()
    }

    @objc func setGroupSpecificStatusTapped() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            showAlert(title: "Error", message: "Not logged in.")
            return
        }
        guard let groupID = group.id else {
            showAlert(title: "Error", message: "Group ID missing.")
            return
        }

        let newStatus = groupSpecificStatusTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let statusValueToSet: Any = (newStatus == nil || newStatus!.isEmpty) ? NSNull() : newStatus!

        let fieldPath = "groupSpecificStatuses.\(groupID)"

        activityIndicator.startAnimating()
        db.collection("users").document(currentUserID).updateData([fieldPath: statusValueToSet]) { [weak self] error in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                if let error = error {
                    print("Error updating group-specific status: \(error.localizedDescription)")
                    self?.showAlert(title: "Update Error", message: "Failed to set status: \(error.localizedDescription)")
                } else {
                    print("Group-specific status updated successfully.")
                    self?.showAlert(title: "Success", message: "Your status for '\(self.group.groupName ?? "this group")' has been updated!")
                    self?.groupSpecificStatusTextField.text = ""
                }
            }
        }
    }

    private func configureUIForEditMode() {
        groupNameLabel.isHidden = isEditMode
        // Hide color views and URL label if you want, or keep them visible
        // primaryColorView.isHidden = isEditMode
        // secondaryColorView.isHidden = isEditMode
        // profilePicUrlLabel.isHidden = isEditMode

        editFieldsStackView.isHidden = !isEditMode

        leaveGroupButton.isEnabled = !isEditMode // Disable leave while editing

        updateEditButtonVisibility() // This will set the correct nav bar buttons
    }

    private func createTextField(placeholder: String, keyboardType: UIKeyboardType = .default) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.borderStyle = .roundedRect
        textField.keyboardType = keyboardType
        if keyboardType == .URL {
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
        }
        return textField
    }
}

extension GroupDetailViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayMembers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: GroupMemberCell.identifier, for: indexPath) as? GroupMemberCell else {
            return UITableViewCell() // Should not happen
        }
        let member = displayMembers[indexPath.row]
        let currentUserID = Auth.auth().currentUser?.uid

        cell.configure(with: member, currentUserID: currentUserID, isAdmin: isCurrentUserAdmin())

        cell.removeAction = { [weak self] in
            guard let self = self, self.isCurrentUserAdmin(), member.uid != currentUserID else { return }
            self.confirmAndRemoveMember(member)
        }
        return cell
    }

    func confirmAndRemoveMember(_ memberToRemove: GroupMemberDisplay) {
        let confirmAlert = UIAlertController(
            title: "Remove Member",
            message: "Are you sure you want to remove '\(memberToRemove.username ?? memberToRemove.uid)' from '\(self.group.groupName)'?",
            preferredStyle: .alert
        )
        confirmAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        confirmAlert.addAction(UIAlertAction(title: "Remove", style: .destructive, handler: { [weak self] _ in
            self?.performRemoveMember(userIdToRemove: memberToRemove.uid)
        }))
        present(confirmAlert, animated: true)
    }

    func performRemoveMember(userIdToRemove: String) {
        guard let groupId = group.id else {
            showAlert(title: "Error", message: "Group ID is missing.")
            return
        }
        // Admin is removing another user. Current user is the admin.
        activityIndicator.startAnimating()
        let callData: [String: Any] = [
            "groupId": groupId,
            "userIdToRemove": userIdToRemove
        ]

        functions.httpsCallable("handleUserLeaveOrRemove").call(callData) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                if let error = error as NSError? {
                    self?.handleFirebaseFunctionError(error, defaultMessage: "Failed to remove member.")
                    return
                }

                if let data = result?.data as? [String: Any], let success = data["success"] as? Bool, success == true {
                    self?.showAlert(title: "Success", message: "'\(memberToRemove.username ?? memberToRemove.uid)' has been removed from the group.")
                } else {
                    let message = (result?.data as? [String: Any])?["message"] as? String ?? "Could not process member removal."
                    self?.showAlert(title: "Error", message: message)
                }
            }
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return displayMembers.isEmpty ? "No members to display." : "Members (\(displayMembers.count))"
    }
}

// Helper extension for UIColor from hex string
extension UIColor {
    convenience init?(hexString: String) {
        var cString:String = hexString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if (cString.hasPrefix("#")) {
            cString.remove(at: cString.startIndex)
        }

        if ((cString.count) != 6) {
            // Try common color names as a fallback
            switch cString.lowercased() {
                case "red": self.init(red: 1, green: 0, blue: 0, alpha: 1)
                case "green": self.init(red: 0, green: 1, blue: 0, alpha: 1)
                case "blue": self.init(red: 0, green: 0, blue: 1, alpha: 1)
                case "black": self.init(red: 0, green: 0, blue: 0, alpha: 1)
                case "white": self.init(red: 1, green: 1, blue: 1, alpha: 1)
                case "gray": self.init(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
                case "purple": self.init(red: 0.5, green: 0, blue: 0.5, alpha: 1)
                case "orange": self.init(red: 1, green: 0.5, blue: 0, alpha: 1)
                case "yellow": self.init(red: 1, green: 1, blue: 0, alpha: 1)
                // Add more common colors if needed
                default: return nil
            }
            return
        }

        var rgbValue:UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)

        self.init(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
}
