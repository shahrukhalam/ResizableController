//
//  ResizableControllerObserver.swift
//
//  Created by Arjun Baru on 05/05/20.
//  Copyright © 2020 Paytm Money 🚀. All rights reserved.
//

import UIKit

/// Protocol to integrate Resizable Controller model presentation. To be conformed by the modally presented controller
public protocol ResizableControllerPositionHandler: UIViewController {

    /// Override this property if you do not want to include intuitive slide up indicator. Disabled by default for non-resizable views controllers.
    var shouldShowSlideUpIndication: Bool { get }

    /// Override this property to give differnent colour to Slider up indicator. Defaults to darkGrey with alpha 0.5
    var sliderBackgroundColor: UIColor { get }

    /// Override this property to give initial custom height, calculated from top.
    var initialTopOffset: CGFloat { get }

    /// Override this property to give custom final height, calculated from top. Resizable controller will change its height from initialTopOffset to finalTopOffset.
    var finalTopOffset: CGFloat { get }

    /// Override this property to add behaviours to view controller before it changes it size.
    /// - Parameter value: new top offset to which view controller will shifted position.
    func willMoveTopOffset(value: CGFloat)

    /// Override this property to add additional behaviours to view controller after it changes it size.
    /// - Parameter value: new top offset after view controller has shifted position
    func didMoveTopOffset(value: CGFloat)
}


extension ResizableControllerPositionHandler {
    var onView: UIView {
        return self.view
    }
}

// MARK: Public default Implementation for protocol

public extension ResizableControllerPositionHandler {

    func willMoveTopOffset(value: CGFloat) {  }

    func didMoveTopOffset(value: CGFloat) {
        if value == UIScreen.main.bounds.height {
            self.dismiss(animated: true, completion: nil)
        }
    }

    var sliderBackgroundColor: UIColor {
        UIColor.darkGray.withAlphaComponent(0.5)
    }

    var initialTopOffset: CGFloat {
        return ResizableConstants.maximumTopOffset
    }

    var finalTopOffset: CGFloat {
        return ResizableConstants.maximumTopOffset
    }

    var shouldShowSlideUpIndication: Bool {
        return initialTopOffset != finalTopOffset
    }
}


/// This class is responsible for handling swipe related recoganisation.
/// It provides call backs on to ResizableControllerPositionHandler protocol conformed class once user interacts with the view controller.
/// Refer to ResizableControllerPositionHandler to see what observations can be subscibed
class ResizableControllerObserver: NSObject, UIGestureRecognizerDelegate, UIScrollViewDelegate {

    private let panGesture = UIPanGestureRecognizer()
    private var viewPosition: SliderPosition = .present

    private weak var view: UIView?
    private let animationDuration: TimeInterval

    weak var delegate: ResizableControllerPositionHandler?
    weak var presentingVC: UIViewController?

    var estimatedFinalTopOffset = UIScreen.main.bounds.height * 0.06
    var estimatedInitialTopOffset = UIScreen.main.bounds.height * 0.55
    var presentingVCminY: CGFloat = 0
    private let screenTopOffset = UIScreen.main.bounds.height
    private let middleTopOffset = UIScreen.main.bounds.height * (1 + 0.06) * 0.5
    private let presentingViewPeek: CGFloat = 10
    private lazy var minTransformXY: CGFloat = {
        let finalTopOffset = UIScreen.main.bounds.height * 0.06
        return 1 - (finalTopOffset - presentingViewPeek) / (UIScreen.main.bounds.height / 2)
    }()
    private let maxTransformXY: CGFloat = 1
    private let settlingDuration: TimeInterval = 0.2

    private lazy var slideIndicativeView: UIView = {
        let view = UIView()
        view.backgroundColor = delegate?.sliderBackgroundColor
        view.widthAnchor.constraint(equalToConstant: 55).isActive = true
        view.heightAnchor.constraint(equalToConstant: 5).isActive = true
        view.layer.cornerRadius = 2
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    init(in view: UIView, duration: TimeInterval = 0.3, delegate: ResizableControllerPositionHandler? = nil) {
        self.view = view
        self.animationDuration = duration
        super.init()

        setupDelegate(delegate)
        commonInit()
    }

    private func commonInit() {
        setupGestureRecoganisers()
        addSliderView()
    }

    private func setupGestureRecoganisers() {
        guard let view = view else { return }
        self.panGesture.addTarget(self, action: #selector(handlePan))
        self.panGesture.delegate = self
        view.addGestureRecognizer(panGesture)
    }

    fileprivate func setupDelegate(_ delegate: ResizableControllerPositionHandler?) {
        self.delegate = delegate

        if let finalTopOffset = delegate?.finalTopOffset {
            self.estimatedFinalTopOffset = finalTopOffset
        }

        if let initialTopOffset = delegate?.initialTopOffset {
            self.estimatedInitialTopOffset = initialTopOffset
        }
    }

    /// handles user's swipe interactions
    @objc private func handlePan(_ gestureRecognizer: UIGestureRecognizer) {
        guard let view = view,
              let currentView = panGesture.view,
              gestureRecognizer == panGesture else { return }

        let gestureState = panGesture.state
        let gestureYTranslation = panGesture.translation(in: currentView).y
        let viewOriginY = view.frame.origin.y

        setPresentingVCMinYIfNeededForDefaultIOSTransitions(gestureState: gestureState)

        // Translates Presented View & Transforms Presenting View
        let translationValue = translationValueIfAny(gestureState: gestureState,
                                                     viewOriginY: viewOriginY,
                                                     gestureYTranslation: gestureYTranslation)
        if let value = translationValue {
            translate(value: value, animationDuration: 0)
        }
        
        // Settle or Dismiss Presented ViewController
        let settlingValue = settlingValueIfAny(gestureState: gestureState,
                                               viewOriginY: viewOriginY)
        if let value = settlingValue {
            translate(value: value, animationDuration: settlingDuration)
        }
    }

    func setPresentingVCMinYIfNeededForDefaultIOSTransitions(gestureState: UIGestureRecognizer.State) {
        switch gestureState {
        case .began:
            if let viewController = presentingVC, presentingVCminY == 0 {
//                let presentingView: UIView = viewController.view
//                let convertedRectWRTWindow = presentingView.convert(presentingView.frame, to: nil)
//                presentingVCminY = convertedRectWRTWindow.minY
                presentingVCminY = viewController.view.frame.minY
            }
        default:
            break
        }
    }

    func translationValueIfAny(gestureState: UIGestureRecognizer.State,
                               viewOriginY: CGFloat,
                               gestureYTranslation: CGFloat) -> CGFloat? {
        switch gestureState {
        case .possible, .began:
            return nil
        case .changed:
            let expectedOriginY = viewOriginY + gestureYTranslation
            let upperBoundary = max(expectedOriginY, estimatedFinalTopOffset)
            let lowerBoundary = min(upperBoundary, screenTopOffset)
            return lowerBoundary
        case .ended, .cancelled, .failed:
            return nil
        @unknown default:
            return nil
        }
    }

    func settlingValueIfAny(gestureState: UIGestureRecognizer.State,
                            viewOriginY: CGFloat) -> CGFloat? {
        switch gestureState {
        case .possible, .began, .changed:
            return nil
        case .ended, .cancelled, .failed:
            let upperHalf = (estimatedFinalTopOffset + estimatedInitialTopOffset)/2
            let lowerHalf = (estimatedInitialTopOffset + screenTopOffset)/2
            if viewOriginY <= upperHalf {
                return estimatedFinalTopOffset
            } else if (viewOriginY > upperHalf) && (viewOriginY <= lowerHalf) {
                return estimatedInitialTopOffset
            } else {
                return screenTopOffset
            }
        @unknown default:
            return nil
        }
    }
}

// MARK: PanGesture Delegates
extension ResizableControllerObserver {

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {

        guard let currentView = panGesture.view, gestureRecognizer == panGesture else {
            return false
        }

        switch panGesture.dragDirection(inView: currentView) {
        case .upwards where !isHeightEqualToEstimatedHeight:
            guard delegate?.initialTopOffset != delegate?.finalTopOffset else { return false }
            return true
        case .downwards:
            return true
        case .idle where !isHeightEqualToEstimatedHeight:
            return true
        default: return false
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let currentView = gestureRecognizer.view,
              let otherView = otherGestureRecognizer.view else {
            return false
        }

        let isPanGesture = gestureRecognizer == panGesture
        let isDescendant = otherView.isDescendant(of: currentView)

        guard isPanGesture && isDescendant else {
            return false
        }

        guard let scrollView = otherView as? UIScrollView else {
            return true
        }

        return scrollView.contentOffset.y == 0
    }
}

// MARK: All About View Transaltion

private extension ResizableControllerObserver {

    var isHeightEqualToEstimatedHeight: Bool {
        guard let view = view else { return false }
        return Int(view.frame.minY) == Int(estimatedFinalTopOffset)
    }

    /// performs resizable transformation for presented and presenting view controllers
    func translate(value: CGFloat, animationDuration: TimeInterval) {
        delegate?.willMoveTopOffset(value: value)

        UIView.animate(withDuration: animationDuration, animations: {
            self.view?.frame.origin.y = value
            self.presentingTranslation(viewController: self.presentingVC,
                                       minY: self.presentingVCminY,
                                       transaltion: value)
        }, completion: { _ in
            self.panGesture.setTranslation(.zero, in: self.view)
            self.delegate?.didMoveTopOffset(value: value)
        })
    }

    func addSliderView() {
        guard let currentView = view, delegate?.shouldShowSlideUpIndication == true else { return }

        currentView.addSubview(slideIndicativeView)

        NSLayoutConstraint.activate([
            slideIndicativeView.centerXAnchor.constraint(equalTo: currentView.centerXAnchor),
            slideIndicativeView.topAnchor.constraint(equalTo: currentView.topAnchor, constant: 15)
        ])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.addSliderAnimation()
        }
    }

    /// Scales presenting view controller as per translation
    func presentingTranslation(viewController: UIViewController?, minY: CGFloat, transaltion: CGFloat) {
        guard let viewController = viewController else {
            return
        }

        guard viewController.viewPresentationStyle() != .default else {
            return
        }

        let values = presentingTranslationValues(minY: minY, transaltion: transaltion)
        viewController.view.layer.transform = values.t

        guard let resizableContainerViewController = viewController as? ResizableContainerViewController,
              resizableContainerViewController.viewPresentationStyle() == .custom else {
            return
        }

        switch resizableContainerViewController.mode {
        case .popUp:
            var presentingViewController = resizableContainerViewController.presentingViewController
            while presentingViewController != nil {
                presentingViewController?.view.layer.transform = values.t
                presentingViewController = presentingViewController?.presentingViewController
            }
        case .fullScreen:
            resizableContainerViewController.view.frame.origin.y = values.y
        }
    }

    func presentingTranslationValues(minY: CGFloat, transaltion: CGFloat) -> (y: CGFloat, t: CATransform3D) {
        let presentingViewYMin = minY
        let presentingViewYMax = estimatedFinalTopOffset - presentingViewPeek

        let presentedViewYMin = estimatedFinalTopOffset
        let isPresentedFullScreen = estimatedInitialTopOffset == estimatedFinalTopOffset
        let presentedViewYMax = isPresentedFullScreen ? middleTopOffset : estimatedInitialTopOffset
        let currentPresentedViewY = min(transaltion, presentedViewYMax)
        let percentage = (presentedViewYMax - currentPresentedViewY)/(presentedViewYMax - presentedViewYMin)

        let y = presentingViewYMin + (presentingViewYMax - presentingViewYMin) * percentage

        let presentingViewTMin = minTransformXY
        let presentingViewTMax = maxTransformXY
        let transformXY = presentingViewTMax - (presentingViewTMax - presentingViewTMin) * percentage
        let transform = CATransform3DMakeScale(transformXY, transformXY, 1)

        return (y, transform)
    }

    /// adds slider bar animation
    func addSliderAnimation() {
        let group = CAAnimationGroup()

        let animation = CABasicAnimation(keyPath: "position")
        animation.fromValue = NSValue(cgPoint: CGPoint(x: self.slideIndicativeView.layer.position.x,
                                                       y: self.slideIndicativeView.layer.position.y))
        animation.toValue = NSValue(cgPoint: CGPoint(x: self.slideIndicativeView.layer.position.x,
                                                     y: self.slideIndicativeView.layer.position.y - 6))

        let animationForOpactity = CABasicAnimation(keyPath: "opacity")
        animationForOpactity.fromValue = 1
        animationForOpactity.toValue = 0.7

        group.animations = [animation, animationForOpactity]
        group.duration = 0.6
        group.autoreverses = true
        group.repeatCount = 2
        group.speed = 2
        group.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)

        self.slideIndicativeView.layer.add(group, forKey: "position")
    }
}

// MARK: Pan helper functions to derive swipe direction
extension UIPanGestureRecognizer {
    enum DraggingState {
        case upwards, downwards, idle
    }

    func dragDirection(inView view: UIView) -> DraggingState {
        let velocity = self.velocity(in: view)
        guard abs(velocity.x) < abs(velocity.y) else { return .idle }
        return velocity.y < 0 ? .upwards : .downwards
    }
}

enum SliderPosition {
    case present
    case dismiss

    mutating func toggle(on view: UIView) {
        switch self {
        case .present:
            view.alpha = 0
            self = .dismiss
        case .dismiss:
            view.alpha = 1
            self = .present
        }
    }
}
