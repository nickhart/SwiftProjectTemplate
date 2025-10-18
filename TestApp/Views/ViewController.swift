import UIKit

final class ViewController: UIViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground

    let label = UILabel()
    label.text = "Hello, TestApp!"
    label.font = .preferredFont(forTextStyle: .largeTitle)
    label.textAlignment = .center
    label.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(label)

    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
    ])
  }
}
