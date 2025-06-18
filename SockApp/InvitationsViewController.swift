import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

class InvitationsViewController: UIViewController {

    var tableView: UITableView!
    var invitations: [Invitation] = []
    var activityIndicator: UIActivityIndicatorView!
    var noInvitationsLabel: UILabel!

    lazy var db = Firestore.firestore()
    lazy var functions = Functions.functions()
    var invitationsListener: ListenerRegistration?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Pending Invitations"
        view.backgroundColor = .white

        setupUI()
        // setupNavigationBar() // No specific nav bar items needed for now, uses back button

        fetchPendingInvitations()
    }

    deinit {
        invitationsListener?.remove()
        print("InvitationsViewController deinitialized and listener removed.")
    }

    func setupUI() {
        tableView = UITableView(frame: view.bounds, style: .plain)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(InvitationCell.self, forCellReuseIdentifier: InvitationCell.identifier)
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 70 // Estimate

        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = view.center
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)

        noInvitationsLabel = UILabel()
        noInvitationsLabel.text = "You have no pending invitations."
        noInvitationsLabel.textColor = .gray
        noInvitationsLabel.textAlignment = .center
        noInvitationsLabel.isHidden = true
        tableView.backgroundView = noInvitationsLabel
    }

    // func setupNavigationBar() {
    //     // Example: could add a refresh button if not using listeners
    // }

    func fetchPendingInvitations() {
        guard let currentUser = Auth.auth().currentUser else {
            print("No current user. Cannot fetch invitations.")
            // Potentially navigate to login or show an error
            return
        }

        activityIndicator.startAnimating()
        invitationsListener?.remove() // Remove previous listener

        invitationsListener = db.collection("invitations")
            .whereField("invitedUserID", isEqualTo: currentUser.uid)
            .whereField("status", isEqualTo: "pending")
            .order(by: "createdAt", descending: true) // Show newest first
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                self.activityIndicator.stopAnimating()

                if let error = error {
                    print("Error fetching invitations: \(error)")
                    self.showAlert(title: "Error", message: "Could not load invitations. \(error.localizedDescription)")
                    return
                }

                guard let documents = querySnapshot?.documents else {
                    print("No invitation documents found.")
                    self.invitations.removeAll()
                    self.tableView.reloadData()
                    self.updateNoInvitationsLabel()
                    return
                }

                self.invitations = documents.compactMap { document -> Invitation? in
                    do {
                        return try document.data(as: Invitation.self)
                    } catch {
                        print("Error decoding invitation: \(error) for document \(document.documentID)")
                        return nil
                    }
                }

                // Here you could fetch groupName if it's not denormalized and you need it.
                // For simplicity, this example assumes groupName might be part of Invitation or can be handled by cell.

                self.tableView.reloadData()
                self.updateNoInvitationsLabel()
                print("Fetched \(self.invitations.count) pending invitations.")
            }
    }

    func updateNoInvitationsLabel() {
        noInvitationsLabel.isHidden = !invitations.isEmpty
    }

    func handleAcceptInvitation(invitationId: String) {
        guard !invitationId.isEmpty else {
            showAlert(title: "Error", message: "Invalid invitation ID.")
            return
        }
        print("Accepting invitation: \(invitationId)")
        setLoadingState(true, forInvitationId: invitationId)
        functions.httpsCallable("acceptInvitation").call(["invitationId": invitationId]) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.setLoadingState(false, forInvitationId: invitationId)
                if let error = error as NSError? {
                    self?.handleFirebaseFunctionError(error, defaultMessage: "Failed to accept invitation.")
                    return
                }
                if let data = result?.data as? [String: Any], let success = data["success"] as? Bool, success == true {
                    let groupId = data["groupId"] as? String ?? "N/A"
                    self?.showAlert(title: "Success", message: "Invitation accepted! You've joined the group (ID: \(groupId)).")
                    // Listener should auto-update the table.
                } else {
                    let message = (result?.data as? [String: Any])?["message"] as? String ?? "Could not accept invitation."
                    self?.showAlert(title: "Error", message: message)
                }
            }
        }
    }

    func handleDeclineInvitation(invitationId: String) {
        guard !invitationId.isEmpty else {
            showAlert(title: "Error", message: "Invalid invitation ID.")
            return
        }
        print("Declining invitation: \(invitationId)")
        setLoadingState(true, forInvitationId: invitationId)
        functions.httpsCallable("declineInvitation").call(["invitationId": invitationId]) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.setLoadingState(false, forInvitationId: invitationId)
                if let error = error as NSError? {
                    self?.handleFirebaseFunctionError(error, defaultMessage: "Failed to decline invitation.")
                    return
                }
                if let data = result?.data as? [String: Any], let success = data["success"] as? Bool, success == true {
                    self?.showAlert(title: "Success", message: "Invitation declined.")
                    // Listener should auto-update the table.
                } else {
                     let message = (result?.data as? [String: Any])?["message"] as? String ?? "Could not decline invitation."
                    self?.showAlert(title: "Error", message: message)
                }
            }
        }
    }

    private func setLoadingState(_ isLoading: Bool, forInvitationId: String?) {
        if isLoading {
            activityIndicator.startAnimating() // General indicator
        } else {
            activityIndicator.stopAnimating()
        }
        // Disable/enable buttons in the specific cell if an invitationId is provided
        if let invId = forInvitationId, let index = invitations.firstIndex(where: { $0.id == invId }) {
            if let cell = tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? InvitationCell {
                cell.setButtonsEnabled(!isLoading)
            }
        } else if isLoading == false { // If no specific ID, and we are stopping loading, enable all visible cells
            tableView.visibleCells.forEach { cell in
                (cell as? InvitationCell)?.setButtonsEnabled(true)
            }
        }
    }

    private func handleFirebaseFunctionError(_ error: NSError, defaultMessage: String) {
        var errorMessage = defaultMessage
        if error.domain == FunctionsErrorDomain {
            if let details = error.userInfo[FunctionsErrorDetailsKey] as? [String: Any], let message = details["message"] as? String {
                 errorMessage = message
            } else {
                errorMessage = error.localizedDescription // Fallback to generic Firebase error if no custom message
            }
        } else {
             errorMessage = error.localizedDescription // Non-Firebase function error
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
}

extension InvitationsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return invitations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: InvitationCell.identifier, for: indexPath) as? InvitationCell else {
            return UITableViewCell()
        }
        let invitation = invitations[indexPath.row]
        cell.configure(with: invitation)

        cell.acceptAction = { [weak self] in
            self?.handleAcceptInvitation(invitationId: invitation.id ?? "")
        }
        cell.declineAction = { [weak self] in
            self?.handleDeclineInvitation(invitationId: invitation.id ?? "")
        }
        // Ensure buttons are enabled if this cell is being reused and was previously disabled
        cell.setButtonsEnabled(true)
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return invitations.isEmpty ? nil : "Tap to accept or decline"
    }
}

// Custom TableViewCell for Invitations
class InvitationCell: UITableViewCell {
    static let identifier = "InvitationCell"

    var acceptAction: (() -> Void)?
    var declineAction: (() -> Void)?

    private let groupNameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        return label
    }()

    private let statusLabel: UILabel = { // Could show status or creation date
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .gray
        return label
    }()

    private lazy var acceptButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Accept", for: .normal)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 5
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        button.addTarget(self, action: #selector(acceptButtonTapped), for: .touchUpInside)
        return button
    }()

    private lazy var declineButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Decline", for: .normal)
        button.backgroundColor = .systemRed
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 5
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        button.addTarget(self, action: #selector(declineButtonTapped), for: .touchUpInside)
        return button
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCellUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupCellUI() {
        let textStack = UIStackView(arrangedSubviews: [groupNameLabel, statusLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let buttonStack = UIStackView(arrangedSubviews: [acceptButton, declineButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 8
        buttonStack.distribution = .fillEqually

        let mainStack = UIStackView(arrangedSubviews: [textStack, buttonStack])
        mainStack.axis = .horizontal
        mainStack.spacing = 10
        mainStack.alignment = .center // Align button center with text block center

        contentView.addSubview(mainStack)
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),

            acceptButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            declineButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])
    }

    func configure(with invitation: Invitation) {
        groupNameLabel.text = "Join: \(invitation.groupName ?? invitation.groupId)"
        if let createdAt = invitation.createdAt {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            statusLabel.text = "Received: \(dateFormatter.string(from: createdAt.dateValue()))"
        } else {
            statusLabel.text = "Status: \(invitation.status)"
        }
    }

    @objc private func acceptButtonTapped() {
        acceptAction?()
    }

    @objc private func declineButtonTapped() {
        declineAction?()
    }

    func setButtonsEnabled(_ enabled: Bool) {
        acceptButton.isEnabled = enabled
        declineButton.isEnabled = enabled
        acceptButton.alpha = enabled ? 1.0 : 0.5
        declineButton.alpha = enabled ? 1.0 : 0.5
    }
}
