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
    /// - Parameter duration: animation duration with which change will take effect.
    func willMoveTopOffset(value: CGFloat, duration: TimeInterval)
    
    /// Override this property to add behaviours to view controller before it settles.
    /// - Parameter value: new top offset to which view controller will settle.
    /// - Parameter animator: UIViewPropertyAnimator which animates the change to effect
    /// This takes scroll speed with which user lifts the finger into account
    /// Client should animate their changes on this `animator` for fluid experience
    func willSettleTopOffset(value: CGFloat, animator: UIViewPropertyAnimator)
    
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
    
    func willMoveTopOffset(value: CGFloat, duration: TimeInterval) {  }
    
    func willSettleTopOffset(value: CGFloat, animator: UIViewPropertyAnimator) {  }
    
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
    
    private weak var presentedViewController: UIViewController?
    private weak var view: UIView?
    private let animationDuration: TimeInterval
    
    weak var delegate: ResizableControllerPositionHandler?
    weak var presentingVC: UIViewController?
    
    var estimatedFinalTopOffset = UIScreen.main.bounds.height * 0.06
    var estimatedInitialTopOffset = UIScreen.main.bounds.height * 0.55
    static var automaticMinY: CGFloat = 0
    static var automaticHeight: CGFloat = 0
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
    
    init(in presentedViewController: UIViewController,
         duration: TimeInterval = 0.3,
         delegate: ResizableControllerPositionHandler? = nil) {
        self.presentedViewController = presentedViewController
        self.view = presentedViewController.view
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
        
        // Translates Presented View & Transforms Presenting View
        let translationValue = translationValueIfAny(gestureState: gestureState,
                                                     viewOriginY: viewOriginY,
                                                     gestureYTranslation: gestureYTranslation)
        if let value = translationValue {
            translate(value: value, animationDuration: 0)
        }
        
        // Settle or Dismiss Presented ViewController
        let velocityY = panGesture.velocity(in: currentView).y
        let settlingValue = settlingValueIfAny(gestureState: gestureState,
                                               viewOriginY: viewOriginY,
                                               velocityY: velocityY)
        if let value = settlingValue {
            let relativeVelocity = relativeSettlingVelocity(value: value,
                                                            viewOriginY: viewOriginY,
                                                            velocityY: velocityY)
            settle(value: value, velocity: relativeVelocity)
            switchModeIfNeeded(value: value, presentedViewController: presentedViewController)
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
                            viewOriginY: CGFloat,
                            velocityY: CGFloat) -> CGFloat? {
        switch gestureState {
        case .possible, .began, .changed:
            return nil
        case .ended, .cancelled, .failed:
            let projectedY = project(initialVelocity: velocityY, decelerationRate: .normal)
            let expecedY = viewOriginY + projectedY
            let upperDividePercentage: CGFloat = 60/100
            let lowerDividePercentage: CGFloat = 60/100
            let upperDivide = estimatedFinalTopOffset + (estimatedInitialTopOffset - estimatedFinalTopOffset) * upperDividePercentage
            let lowerDivide = estimatedInitialTopOffset + (screenTopOffset - estimatedInitialTopOffset) * lowerDividePercentage

            let isOnUpperPart = (viewOriginY > estimatedFinalTopOffset &&
                                    viewOriginY < estimatedInitialTopOffset)
            let isComingDown = velocityY > 0
            if isOnUpperPart && isComingDown {
                if expecedY <= upperDivide {
                    return estimatedFinalTopOffset
                } else {
                    return estimatedInitialTopOffset
                }
            } else {
                if expecedY <= upperDivide {
                    return estimatedFinalTopOffset
                } else if (expecedY > upperDivide) && (expecedY <= lowerDivide) {
                    return estimatedInitialTopOffset
                } else {
                    return screenTopOffset
                }
            }
        @unknown default:
            return nil
        }
    }
    
    func project(initialVelocity: CGFloat, decelerationRate: UIScrollView.DecelerationRate) -> CGFloat {
        let deceleration = decelerationRate.rawValue
        return (initialVelocity / 1000.0) * deceleration / (1.0 - deceleration)
    }
    
    func relativeSettlingVelocity(value: CGFloat, viewOriginY: CGFloat, velocityY: CGFloat) -> CGVector {
        let changeY = value - viewOriginY
        return CGVector(dx: 0, dy: velocityY / changeY)
    }
    
    func settle(value: CGFloat, velocity: CGVector) {
        // Damping(Bounciness) of 0.9 is used for hinting Boundaries, normally 1 is used
        // Response(period of the spring oscillation) of 0.4 is used for a little stiffer spring that yields a greater amount of force for moving objects
        let timingParameters = UISpringTimingParameters(dampingRatio: 0.9,
                                                        frequencyResponse: 0.4,
                                                        initialVelocity: velocity)
        let animator = UIViewPropertyAnimator(duration: 0, timingParameters: timingParameters)

        delegate?.willSettleTopOffset(value: value, animator: animator)
        
        animator.addAnimations {
            self.view?.frame.origin.y = value
            self.presentingTranslation(viewController: self.presentingVC, transaltion: value)
        }
        
        animator.addCompletion { _ in
            self.panGesture.setTranslation(.zero, in: self.view)
            self.delegate?.didMoveTopOffset(value: value)
        }
        
        animator.startAnimation()
    }
    
    func switchModeIfNeeded(value: CGFloat, presentedViewController: UIViewController?) {
        guard let viewController = presentedViewController as? ResizableContainerViewController else {
            return
        }
        
        switch value {
        case estimatedFinalTopOffset:
            viewController.mode = .fullScreen
        case estimatedInitialTopOffset:
            viewController.mode = .popUp
        case screenTopOffset:
            break
        default:
            assertionFailure("Unexpected Settling Value")
        }
    }
}

extension UISpringTimingParameters {
    
    /// A design-friendly way to create a spring timing curve.
    ///
    /// - Parameters:
    ///   - dampingRatio: The 'bounciness' of the spring animation. Value must be between 0 and 1.
    ///   - frequencyResponse: The 'period' of the spring oscillation.
    ///   - initialVelocity: The vector describing the velocity with which mass hits the spring
    convenience init(dampingRatio: CGFloat, frequencyResponse: CGFloat, initialVelocity: CGVector) {
        let isDampingRatioValid = (dampingRatio >= 0 && dampingRatio <= 1)
        precondition(isDampingRatioValid, "Damping Ratio should be in percentage")
        precondition(frequencyResponse > 0, "Frequency Response should be greater than 0")

        let mass: CGFloat = 1
        let stiffness = pow(2 * .pi / frequencyResponse, 2) * mass
        let damping = 4 * .pi * dampingRatio * mass / frequencyResponse
        self.init(mass: mass, stiffness: stiffness, damping: damping, initialVelocity: initialVelocity)
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
        delegate?.willMoveTopOffset(value: value, duration: animationDuration)
        
        UIView.animate(withDuration: animationDuration, animations: {
            self.view?.frame.origin.y = value
            self.presentingTranslation(viewController: self.presentingVC, transaltion: value)
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
    func presentingTranslation(viewController: UIViewController?, transaltion: CGFloat) {
        guard let viewController = viewController else {
            return
        }
        
        let presentationStyle = viewController.viewPresentationStyle()
        switch presentationStyle {
        case .default:
            var superView = viewController.view.superview
            while superView != nil {
                if superView?.frame.origin.y != 0 {
                    let initialY = estimatedFinalTopOffset - presentingViewPeek
                    let values = presentingTranslationValues(initialY: initialY,
                                                             finalY: Self.automaticMinY,
                                                             transaltion: transaltion)
                    viewController.view.layer.transform = values.t
                    let scaleY = values.t.m11
                    let changeYByScale = (1 - scaleY) * Self.automaticHeight / 2
                    let expectedY = values.y
                    let minY = estimatedFinalTopOffset - presentingViewPeek
                    let upperBoundary = max(minY, expectedY)
                    let lowerBoundary = min(Self.automaticMinY, upperBoundary)
                    let yAccountingScale = lowerBoundary - changeYByScale
                    superView?.frame.origin.y = yAccountingScale
                }
                
                superView = superView?.superview
            }
        case .none:
            let initialY = estimatedFinalTopOffset - presentingViewPeek
            let values = presentingTranslationValues(initialY: initialY, finalY: 0, transaltion: transaltion)
            viewController.view.layer.transform = values.t
        case .custom:
            guard let resizableVC = viewController as? ResizableContainerViewController else {
                assertionFailure("Must be a ResizableContainerViewController with Custom Presentation")
                return
            }
            
            switch resizableVC.mode {
            case .popUp:
                let initialY = estimatedInitialTopOffset
                let finalY = estimatedFinalTopOffset - presentingViewPeek
                let values = presentingTranslationValues(initialY: initialY,
                                                         finalY: finalY,
                                                         transaltion: transaltion)
                resizableVC.view.layer.transform = values.t
                let presentingViewController = resizableVC.presentingViewController
                presentingTranslation(viewController: presentingViewController, transaltion: transaltion)
            case .fullScreen:
                let initialY = estimatedFinalTopOffset - presentingViewPeek
                let finalY = estimatedFinalTopOffset
                let values = presentingTranslationValues(initialY: initialY,
                                                         finalY: finalY,
                                                         transaltion: transaltion)
                resizableVC.view.layer.transform = values.t
                resizableVC.view.frame.origin.y = values.y
            }
        }
    }
    
    func presentingTranslationValues(initialY: CGFloat,
                                     finalY: CGFloat,
                                     transaltion: CGFloat) -> (y: CGFloat, t: CATransform3D) {
        let presentingViewYMin = finalY
        let presentingViewYMax = initialY
        
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
