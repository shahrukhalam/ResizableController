//
//  PresentingViewController.swift
//  ResizableControllerSample
//
//  Created by Arjun Baru on 04/11/20.
//

import UIKit
import ResizableController

class PresentingViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Resizable Controller"

        view.backgroundColor = .systemBackground
    }

    @IBAction func onTapOfCustomHeightController(_ sender: Any) {

        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "ResizablePresentedViewController") as ResizablePresentedViewController
        self.present(viewController)
//        self.present(viewController, animated: true, completion: nil)
    }

    @IBAction func onTapOfFixedHeightController(_ sender: Any) {
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "FixedPresentingViewController") as FixedHeightPresentedViewController
        self.present(viewController)
    }
}

