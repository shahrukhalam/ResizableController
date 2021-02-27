//
//  ResizablePresentedViewController.swift
//  ResizableControllerSample
//
//  Created by Arjun Baru on 05/11/20.
//

import UIKit
import ResizableController

class ResizablePresentedViewController: UIViewController {

    @IBOutlet weak var swipeLabel: UILabel!
    private let infoButton = UIButton(type: .infoLight)

    override func viewDidLoad() {
        super.viewDidLoad()

        addInfoButton()
    }

    private func addInfoButton() {
        view.backgroundColor = .white

        view.addSubview(infoButton)
        infoButton.translatesAutoresizingMaskIntoConstraints = false
        infoButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 16).isActive = true
        infoButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16).isActive = true

        infoButton.addTarget(self, action: #selector(infoButtonTapped), for: .touchUpInside)
    }

    @objc private func infoButtonTapped() {
        let viewController = PinkPresentedViewController()
        self.present(viewController)
    }
}

extension ResizablePresentedViewController: ResizableControllerPositionHandler {
    var initialTopOffset: CGFloat {
        500
    }

    func didMoveTopOffset(value: CGFloat) {
        if value == initialTopOffset {
            self.swipeLabel.text = "Swipe up to full size"
        }

        if value == finalTopOffset {
            self.swipeLabel.text = "Swipe down to half screen"
        }

        if value >= UIScreen.main.bounds.height {
            self.dismiss(animated: true, completion: nil)
        }
    }
}

class PinkPresentedViewController: UIViewController, ResizableControllerPositionHandler {
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemPink
    }

    var initialTopOffset: CGFloat {
        500
    }
}
