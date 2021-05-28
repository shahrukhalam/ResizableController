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
    var initialTopOffset: CGFloat = 500

    override func viewDidLoad() {
        super.viewDidLoad()

        addInfoButton()
    }

    private func addInfoButton() {
        view.backgroundColor = .systemBackground
        swipeLabel.backgroundColor = UIColor.systemBackground

        view.addSubview(infoButton)
        infoButton.translatesAutoresizingMaskIntoConstraints = false
        infoButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 16).isActive = true
        infoButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16).isActive = true

        infoButton.addTarget(self, action: #selector(infoButtonTapped), for: .touchUpInside)
    }

    @objc private func infoButtonTapped() {
        let viewController = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(identifier: "ResizablePresentedViewController")
        guard let resizableViewController = viewController as? ResizablePresentedViewController else {
            return
        }

        resizableViewController.initialTopOffset = 500
        self.present(resizableViewController)
    }
}

extension ResizablePresentedViewController: ResizableControllerPositionHandler {
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
