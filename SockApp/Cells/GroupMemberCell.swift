import UIKit

class GroupMemberCell: UITableViewCell {
    static let identifier = "GroupMemberCell"

    var removeAction: (() -> Void)?

    private let memberInfoLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.numberOfLines = 1
        return label
    }()

    private let roleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .light)
        label.textColor = .darkGray
        return label
    }()

    private let globalStatusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13)
        label.textColor = .gray
        return label
    }()

    private let groupSpecificStatusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13)
        label.textColor = .blue // Differentiate group-specific status
        return label
    }()

    private lazy var removeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Remove", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemRed
        button.layer.cornerRadius = 5
        button.addTarget(self, action: #selector(removeButtonTapped), for: .touchUpInside)
        button.isHidden = true // Initially hidden, shown only for admins on other members
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
        let textContentStack = UIStackView(arrangedSubviews: [memberInfoLabel, roleLabel, globalStatusLabel, groupSpecificStatusLabel])
        textContentStack.axis = .vertical
        textContentStack.alignment = .leading
        textContentStack.spacing = 2

        let mainStack = UIStackView(arrangedSubviews: [textContentStack, removeButton])
        mainStack.axis = .horizontal
        mainStack.spacing = 10
        mainStack.alignment = .center // Aligns remove button vertically with the text block

        contentView.addSubview(mainStack)
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        // Make textContentStack take up available space
        textContentStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        removeButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)


        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),

            removeButton.widthAnchor.constraint(equalToConstant: 80)
        ])
    }

    func configure(with member: GroupMemberDisplay, currentUserID: String?, isAdmin: Bool) {
        memberInfoLabel.text = member.username ?? member.uid
        roleLabel.text = "Role: \(member.role)"

        globalStatusLabel.text = "Global: \(member.globalStatus ?? "N/A")"
        groupSpecificStatusLabel.text = "Group: \(member.groupSpecificStatus ?? "N/A")"

        // Show remove button if:
        // 1. Current user is an admin
        // 2. The member in this cell is NOT the current user (admin cannot remove themselves this way)
        if isAdmin && member.uid != currentUserID {
            removeButton.isHidden = false
        } else {
            removeButton.isHidden = true
        }
    }

    @objc private func removeButtonTapped() {
        removeAction?()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        removeButton.isHidden = true
        memberInfoLabel.text = nil
        roleLabel.text = nil
        globalStatusLabel.text = nil
        groupSpecificStatusLabel.text = nil
        removeAction = nil
    }
}
