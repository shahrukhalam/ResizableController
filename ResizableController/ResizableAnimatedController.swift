//
//  ResizableAnimatedController.swift
//
//  Created by Arjun Baru on 25/04/20.
//  Copyright © 2020 Paytm Money 🚀. All rights reserved.
//

import UIKit

/// Handles presentation cases for all type of presentation
enum PresentingViewType {
    case custom, `default`, none
}

/// Manages scaling for presenting view controller
enum ViewControlerScale {
    case backgroundPopUpScale
    case backgroundFullScreenScale
    case reset

    var transform: CATransform3D {
        switch self {
        case .backgroundPopUpScale:
            return CATransform3DMakeScale(1, 1, 1)
        case .backgroundFullScreenScale:
            let transformXY = 0.88 + 20 / UIScreen.main.bounds.height
            return CATransform3DMakeScale(transformXY, transformXY, 1)
        case .reset:
            return CATransform3DMakeScale(1, 1, 1)
        }
    }
}

/// Provides transitionContext for view controller's custom presentation
class ResizableAnimatedController: NSObject {

    let initialTopOffset: CGFloat
    var estimatedFinalTopOffset: CGFloat
    let animationDuration: TimeInterval
    var isPresenting: Bool

    private var presntingViewControlerMinY: CGFloat?
    private weak var viewToBeDismissed: UIViewController?
    private let tapGesture = UITapGestureRecognizer()

    private lazy var dimmingView: UIView = {
        let view = UIView()
        view.isOpaque = false
        view.addGestureRecognizer(tapGesture)
        tapGesture.addTarget(self, action: #selector(onTapOfDimmingView))
        view.backgroundColor = UIColor.black
        view.alpha = 0
        return view
    }()

    init?(initialTopOffset: CGFloat,
          animationDuration: TimeInterval,
          isPresenting: Bool,
          estimatedFinalTopOffset: CGFloat) {

        guard initialTopOffset >= ResizableConstants.maximumTopOffset else { return nil }

        self.animationDuration = animationDuration
        self.initialTopOffset = initialTopOffset
        self.isPresenting = isPresenting
        self.estimatedFinalTopOffset = estimatedFinalTopOffset
    }

    @objc func onTapOfDimmingView() {
        viewToBeDismissed?.dismiss(animated: true, completion: nil)
    }

}

// MARK: Transitioning Delegate Implementation
extension ResizableAnimatedController: UIViewControllerAnimatedTransitioning {

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return animationDuration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromVC = transitionContext.viewController(forKey: .from),
              let toVC = transitionContext.viewController(forKey: .to) else { return }

        let containerView = transitionContext.containerView

        if isPresenting {
            viewToBeDismissed = toVC

            toVC.view.frame = CGRect(x: 0.0,
                                     y: fromVC.view.frame.maxY,
                                     width: UIScreen.main.bounds.width,
                                     height: UIScreen.main.bounds.height)

            containerView.addSubview(dimmingView)
            dimmingView.edgesToSuperView()
            containerView.addSubview(toVC.view)

            fromVC.beginAppearanceTransition(false, animated: true)
            toVC.beginAppearanceTransition(true, animated: true)
            toVC.modalPresentationCapturesStatusBarAppearance = true

            UIView.animate(withDuration: animationDuration, animations: {
                fromVC.setupViewCorners(radius: 10)
                let isPresentedFullScreen = self.initialTopOffset == self.estimatedFinalTopOffset
                let transform = isPresentedFullScreen ? ViewControlerScale.backgroundFullScreenScale.transform : ViewControlerScale.backgroundPopUpScale.transform
                fromVC.view.layer.transform = transform
                toVC.view.frame.origin.y = self.initialTopOffset
                toVC.setupViewCorners(radius: 10)
                self.dimmingView.alpha = 0.2
            }, completion: { _ in
                self.presntingViewControlerMinY = fromVC.view.frame.minY
                fromVC.endAppearanceTransition()
                toVC.endAppearanceTransition()
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            })
        } else {
            containerView.addSubview(fromVC.view)

            fromVC.beginAppearanceTransition(false, animated: true)
            toVC.beginAppearanceTransition(true, animated: true)
            UIView.animate(withDuration: animationDuration, animations: {
                fromVC.view.frame.origin.y = UIScreen.main.bounds.maxY
                toVC.view.layer.transform = ViewControlerScale.reset.transform

                self.dimmingView.alpha = 0
                switch toVC.viewPresentationStyle() {
                case .custom, .default:
                    toVC.view.frame.origin.y = self.presntingViewControlerMinY ?? 0
                case .none:
                    toVC.view.frame.origin.y = 0
                    toVC.view.roundedCorners(withRadius: 0)
                }
            }, completion: { _ in
                fromVC.endAppearanceTransition()
                toVC.endAppearanceTransition()
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            })
        }
    }
}

// MARK: Helper extension of UIViewController
extension UIViewController {
    func viewPresentationStyle() -> PresentingViewType {
        if self.modalPresentationStyle == .custom {
            return .custom
        } else if self.presentingViewController != nil && self.modalPresentationStyle != .custom {
            return .default
        } else {
            return .none
        }
    }

    func setupViewCorners(radius: CGFloat) {
        view.roundedCorners(withRadius: 12)
        view.clipsToBounds = true
    }
}
