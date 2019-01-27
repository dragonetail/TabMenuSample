import UIKit

open class SideMenuController: UIViewController {
    /// 配置
    open var configs: Configs = Configs()

    /// 缓存
    private lazy var lazyCachedViewControllerGenerators: [String: () -> UIViewController?] = [:]
    private lazy var lazyCachedViewControllers: [String: UIViewController] = [:]

    /// 通知代理
    public weak var delegate: SideMenuControllerDelegate?

    /// 区分内部和外部更新contentViewController的动作
    private var shouldCallSwitchingDelegate = true

    /// 更新内容ViewController，如果更新的ViewController是当前ViewController的子对象，则忽略。
    /// 可以使用缓存，然后使用`setContentViewController(with)`进行更新。
    open var contentViewController: UIViewController! {
        didSet {
            guard contentViewController !== oldValue &&
                isViewLoaded &&
                !children.contains(contentViewController) else {
                    return
            }

            if shouldCallSwitchingDelegate {
                delegate?.sideMenuController?(self, willShow: contentViewController, animated: false)
            }

            load(contentViewController, on: contentContainerView)
            contentContainerView.sendSubviewToBack(contentViewController.view)
            unload(oldValue)

            if shouldCallSwitchingDelegate {
                delegate?.sideMenuController?(self, didShow: contentViewController, animated: false)
            }

            setNeedsStatusBarAppearanceUpdate()
        }
    }

    /// 侧栏菜单控制器
    open var menuViewController: UIViewController! {
        didSet {
            guard menuViewController !== oldValue && isViewLoaded else {
                return
            }

            load(menuViewController, on: menuContainerView)
            unload(oldValue)
        }
    }

    private let menuContainerView = UIView()
    private let contentContainerView = UIView()
    private var statusBarScreenShotView: UIView?

    /// 侧栏菜单是否打开看状态
    open var isMenuOpenning = false

    /// 判断横向拖拉动作状态
    private var isDraggingBegan = false
    private var draggingStartX: CGFloat = 0
    private lazy var panGestureRecognizer: UIPanGestureRecognizer = {
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(SideMenuController.handlePanGesture(_:)))
        panGestureRecognizer.delegate = self
        return panGestureRecognizer
    }()

    /// 构造方法
    public convenience init(contentViewController: UIViewController, menuViewController: UIViewController) {
        self.init(nibName: nil, bundle: nil)

        // 不会触发didSet方法
        self.contentViewController = contentViewController
        self.menuViewController = menuViewController
    }

    deinit {
        unregisterNotifications()
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        guard let menuViewController = menuViewController,
            let contentViewController = contentViewController else {
                fatalError("[SideMenuSwift] `menuViewController`和`contentViewController`不能为空。")
        }

        contentContainerView.frame = view.bounds
        view.addSubview(contentContainerView)

        // 根据语言UI方向，判断UIView的方向
        resolveDirection(with: contentContainerView)

        menuContainerView.frame = sideMenuFrame(visibility: false)
        view.addSubview(menuContainerView)

        load(contentViewController, on: contentContainerView)
        load(menuViewController, on: menuContainerView)

        if configs.position == .under {
            view.bringSubviewToFront(contentContainerView)
        }

        // 触发状态栏更新
        setNeedsStatusBarAppearanceUpdate()

        lazyCachedViewControllers[configs.defaultCacheKey] = contentViewController

        self.view.addGestureRecognizer(panGestureRecognizer)
        setUpNotifications()
    }

    /// 根据语言UI方向，判断UIView的方向
    private lazy var adjustedDirection = Configs.MenuDirection.left
    private var shouldReverseDirection: Bool {
        guard configs.shouldRespectLanguageDirection else {
            return false
        }
        let attribute = view.semanticContentAttribute
        let layoutDirection = UIView.userInterfaceLayoutDirection(for: attribute)
        return layoutDirection == .rightToLeft
    }
    private func resolveDirection(with view: UIView) {
        if shouldReverseDirection {
            adjustedDirection = (configs.direction == .left ? .right : .left)
        } else {
            adjustedDirection = configs.direction
        }
    }

    open func openMenu(animated: Bool = true, completion: ((Bool) -> Void)? = nil) {
        changeMenuVisibility(visibility: true, animated: animated, completion: completion)
    }

    open func hideMenu(animated: Bool = true, completion: ((Bool) -> Void)? = nil) {
        changeMenuVisibility(visibility: false, animated: animated, completion: completion)
    }

    private func changeMenuVisibility(visibility: Bool, animated: Bool = true,
                                      shouldCallDelegate: Bool = true, shouldChangeStatusBar: Bool = true,
                                      completion: ((Bool) -> Void)? = nil) {
        menuViewController.beginAppearanceTransition(true, animated: true)

        if shouldCallDelegate {
            visibility ? delegate?.sideMenuControllerWillOpenMenu?(self) : delegate?.sideMenuControllerWillHideMenu?(self)
        }

        UIApplication.shared.beginIgnoringInteractionEvents()

        let animationClosure = {
            self.menuContainerView.frame = self.sideMenuFrame(visibility: visibility)
            self.contentContainerView.frame = self.contentFrame(visibility: visibility)
            if self.configs.animation.shouldAddShadowWhenOpenning {
                self.contentContainerOverlay.alpha = visibility ? self.configs.animation.shadowAlpha : 0
            }
        }

        let animationCompletionClosure: (Bool) -> Void = { finish in
            self.menuViewController.endAppearanceTransition()

            if shouldCallDelegate {
                visibility ? self.delegate?.sideMenuControllerDidOpenMenu?(self) : self.delegate?.sideMenuControllerDidHideMneu?(self)
            }

            if !visibility {
                self.contentContainerOverlay.removeFromSuperview()
            } else {
                self.contentContainerView.insertSubview(self.contentContainerOverlay, aboveSubview: self.contentViewController.view)
            }

            completion?(true)

            UIApplication.shared.endIgnoringInteractionEvents()

            self.isMenuOpenning = visibility
        }

        if animated {
            animateMenu(with: visibility,
                        shouldChangeStatusBar: shouldChangeStatusBar,
                        animations: animationClosure,
                        completion: animationCompletionClosure)
        } else {
            setStatusBar(hidden: visibility)
            animationClosure()
            animationCompletionClosure(true)
        }

    }

    private func animateMenu(with visibility: Bool,
                             shouldChangeStatusBar: Bool = true,
                             animations: @escaping () -> Void,
                             completion: ((Bool) -> Void)? = nil) {
        let shouldAnimateStatusBarChange = configs.statusBarBehavior != .hideOnMenu
        if shouldChangeStatusBar && !shouldAnimateStatusBarChange && visibility {
            setStatusBar(hidden: visibility)
        }
        let duration = visibility ? configs.animation.openDuration : configs.animation.hideDuration
        UIView.animate(withDuration: duration,
                       delay: 0,
                       usingSpringWithDamping: configs.animation.dampingRatio,
                       initialSpringVelocity: configs.animation.initialSpringVelocity,
                       options: configs.animation.animationOptions,
                       animations: {
                           if shouldChangeStatusBar && shouldAnimateStatusBarChange {
                               self.setStatusBar(hidden: visibility)
                           }

                           animations()
                       }, completion: { (finished) in
                           if shouldChangeStatusBar && !shouldAnimateStatusBarChange && !visibility {
                               self.setStatusBar(hidden: visibility)
                           }

                           completion?(finished)
                       })
    }


    private lazy var contentContainerOverlay: UIView = {
        let contentContainerOverlay = UIView()
        contentContainerOverlay.bounds = contentContainerView.bounds
        contentContainerOverlay.center = contentContainerView.center
        if !configs.animation.shouldAddShadowWhenOpenning {
            contentContainerOverlay.backgroundColor = .clear
        } else {
            contentContainerOverlay.backgroundColor = .black
            contentContainerOverlay.alpha = 0
        }
        contentContainerOverlay.autoresizingMask = [.flexibleHeight, .flexibleWidth]

        let tapToHideGesture = UITapGestureRecognizer()
        tapToHideGesture.addTarget(self, action: #selector(SideMenuController.handleTapGestureOnContentContainerOverlay(_:)))
        contentContainerOverlay.addGestureRecognizer(tapToHideGesture)

        contentContainerOverlay.accessibilityIdentifier = "ContentShadowOverlay"
        return contentContainerOverlay
    }()

    @objc private func handleTapGestureOnContentContainerOverlay(_ tap: UITapGestureRecognizer) {
        hideMenu()
    }

    @objc private func handlePanGesture(_ pan: UIPanGestureRecognizer) {
        let menuWidth = configs.menuWidth
        let isLeft = adjustedDirection == .left
        var translation = pan.translation(in: pan.view).x
        let viewToAnimate: UIView
        let viewToAnimate2: UIView?
        var leftBorder: CGFloat
        var rightBorder: CGFloat
        let containerWidth: CGFloat
        switch configs.position {
        case .above:
            viewToAnimate = menuContainerView
            viewToAnimate2 = nil
            containerWidth = viewToAnimate.frame.width
            leftBorder = -containerWidth
            rightBorder = menuWidth - containerWidth
        case .under:
            viewToAnimate = contentContainerView
            viewToAnimate2 = nil
            containerWidth = viewToAnimate.frame.width
            leftBorder = 0
            rightBorder = menuWidth
        case .sideBySide:
            viewToAnimate = contentContainerView
            viewToAnimate2 = menuContainerView
            containerWidth = viewToAnimate.frame.width
            leftBorder = 0
            rightBorder = menuWidth
        }

        if !isLeft {
            swap(&leftBorder, &rightBorder)
            leftBorder *= -1
            rightBorder *= -1
        }

        switch pan.state {
        case .began:
            draggingStartX = viewToAnimate.frame.origin.x
            isDraggingBegan = false
        case .changed:
            let resultX = draggingStartX + translation
            let notReachLeftBorder = (!isLeft && configs.enableRubberEffectWhenPanning) || resultX >= leftBorder
            let notReachRightBorder = (isLeft && configs.enableRubberEffectWhenPanning) || resultX <= rightBorder
            guard notReachLeftBorder && notReachRightBorder else {
                return
            }

            if !isDraggingBegan {
                // Do some setup works in the initial step of validate panning. This can't be done in the `.began` period
                // because we can't know whether its a validate panning
                setStatusBar(hidden: true, animate: true)

                isDraggingBegan = true
            }

            let factor: CGFloat = isLeft ? 1 : -1
            let notReachDesiredBorder = isLeft ? resultX <= rightBorder: resultX >= leftBorder
            if notReachDesiredBorder {
                viewToAnimate.frame.origin.x = resultX
            } else {
                if !isMenuOpenning {
                    translation -= menuWidth * factor
                }
                viewToAnimate.frame.origin.x = (isLeft ? rightBorder : leftBorder) + factor * menuWidth
                    * log10(translation * factor / menuWidth + 1) * 0.5
            }

            if let viewToAnimate2 = viewToAnimate2 {
                viewToAnimate2.frame.origin.x = viewToAnimate.frame.origin.x - containerWidth * factor
            }

            if configs.animation.shouldAddShadowWhenOpenning {
                let shadowPercent = min(menuContainerView.frame.maxX / menuWidth, 1)
                contentContainerOverlay.alpha = self.configs.animation.shadowAlpha * shadowPercent
            }
        case .ended, .cancelled, .failed:
            let offset: CGFloat
            switch configs.position {
            case .above:
                offset = isLeft ? viewToAnimate.frame.maxX : containerWidth - viewToAnimate.frame.minX
            case .under, .sideBySide:
                offset = isLeft ? viewToAnimate.frame.minX : containerWidth - viewToAnimate.frame.maxX
            }
            let offsetPercent = offset / menuWidth
            let decisionPoint: CGFloat = isMenuOpenning ? 0.85 : 0.15
            if offsetPercent > decisionPoint {
                // We need to call the delegates, change the status bar only when the menu was previous hidden
                changeMenuVisibility(visibility: true, shouldCallDelegate: !isMenuOpenning, shouldChangeStatusBar: !isMenuOpenning)
            } else {
                changeMenuVisibility(visibility: false, shouldCallDelegate: isMenuOpenning, shouldChangeStatusBar: true)
            }
        default:
            break
        }
    }

    // MARK: Notification

    private func setUpNotifications() {
        NotificationCenter.default
            .addObserver(self,
                         selector: #selector(SideMenuController.appDidEnteredBackground),
                         name: UIApplication.didEnterBackgroundNotification,
                         object: nil)
    }

    private func unregisterNotifications() {
        // swiftlint:disable:next notification_center_detachment
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func appDidEnteredBackground() {
        if configs.hideMenuWhenEnteringBackground {
            hideMenu(animated: false)
        }
    }

    // MARK: Status Bar

    private func setStatusBar(hidden: Bool, animate: Bool = false) {
        // UIKit provides `setNeedsStatusBarAppearanceUpdate` and couple of methods to animate the status bar changes.
        // The problem with this approach is it will hide the status bar and it's underlying space completely, as a result,
        // the navigation bar will go up as we don't expect.
        // So we need to manipulate the windows of status bar manually.

        let behavior = self.configs.statusBarBehavior
        guard let sbw = UIWindow.sb, sbw.isStatusBarHidden(with: behavior) != hidden else {
            return
        }

        if animate && behavior != .hideOnMenu {
            UIView.animate(withDuration: 0.4, animations: {
                sbw.setStatusBarHidden(hidden, with: behavior)
            })
        } else {
            sbw.setStatusBarHidden(hidden, with: behavior)
        }

        if behavior == .hideOnMenu {
            if !hidden {
                statusBarScreenShotView?.removeFromSuperview()
                statusBarScreenShotView = nil
            } else if statusBarScreenShotView == nil, let newStatusBarScreenShot = statusBarScreenShot() {
                statusBarScreenShotView = newStatusBarScreenShot
                contentContainerView.insertSubview(newStatusBarScreenShot, aboveSubview: contentViewController.view)
            }
        }
    }

    private func statusBarScreenShot() -> UIView? {
        let statusBarFrame = UIApplication.shared.statusBarFrame
        let screenshot = UIScreen.main.snapshotView(afterScreenUpdates: false)
        screenshot.frame = statusBarFrame
        screenshot.contentMode = .top
        screenshot.clipsToBounds = true
        return screenshot
    }

    open override var childForStatusBarStyle: UIViewController? {
        // Forward to the content view controller
        return contentViewController
    }

    open override var childForStatusBarHidden: UIViewController? {
        return contentViewController
    }

    // MARK: Caching

    /// Caches the closure that generate the view controller with identifier.
    ///
    /// It's useful when you want to configure the caching relation without instantiating the view controller immediately.
    ///
    /// - Parameters:
    ///   - viewControllerGenerator: The closure that generate the view controller. It will only executed when needed.
    ///   - identifier: Identifier used to change content view controller
    open func cache(viewControllerGenerator: @escaping () -> UIViewController?, with identifier: String) {
        lazyCachedViewControllerGenerators[identifier] = viewControllerGenerator
    }

    /// Caches the view controller with identifier.
    ///
    /// - Parameters:
    ///   - viewController: the view controller to cache
    ///   - identifier: the identifier
    open func cache(viewController: UIViewController, with identifier: String) {
        lazyCachedViewControllers[identifier] = viewController
    }

    /// Changes the content view controller to the cached one with given `identifier`.
    ///
    /// - Parameter identifier: the identifier that associates with a cache view controller or generator.
    open func setContentViewController(with identifier: String,
                                       animated: Bool = false,
                                       completion: (() -> Void)? = nil) {
        if let viewController = lazyCachedViewControllers[identifier] {
            setContentViewController(to: viewController, animated: animated, completion: completion)
        } else if let viewController = lazyCachedViewControllerGenerators[identifier]?() {
            lazyCachedViewControllerGenerators[identifier] = nil
            lazyCachedViewControllers[identifier] = viewController
            setContentViewController(to: viewController, animated: animated, completion: completion)
        } else {
            fatalError("[SideMenu] View controller associated with \(identifier) not found!")
        }
    }

    open func setContentViewController(to viewController: UIViewController,
                                       animated: Bool = false,
                                       completion: (() -> Void)? = nil) {
        guard contentViewController !== viewController && isViewLoaded else {
            completion?()
            return
        }

        if animated {
            delegate?.sideMenuController?(self, willShow: viewController, animated: animated)

            addChild(viewController)

            viewController.view.frame = view.bounds
            viewController.view.translatesAutoresizingMaskIntoConstraints = true
            viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

            let animatorFromDelegate = delegate?.sideMenuController?(self,
                                                                     animationControllerFrom: contentViewController,
                                                                     to: viewController)

            #if DEBUG
                if animatorFromDelegate == nil {
                    // swiftlint:disable:next line_length
                    print("[SideMenu] `setContentViewController` is called with animated while the delegate method return nil, fall back to the fade animation.")
                }
            #endif

            let animator = animatorFromDelegate ?? BasicTransitionAnimator()

            let transitionContext = SideMenuController.TransitionContext(with: contentViewController,
                                                                         toViewController: viewController)
            transitionContext.isAnimated = true
            transitionContext.isInteractive = false
            transitionContext.completion = { finish in
                self.unload(self.contentViewController)

                self.shouldCallSwitchingDelegate = false
                // It's tricky here.
                // `contentViewController` setter won't trigger due to the `viewController` already is added to the hierarchy.
                // `shouldCallSwitchingDelegate` also prevent the delegate from been calling.
                self.contentViewController = viewController
                self.shouldCallSwitchingDelegate = true

                self.delegate?.sideMenuController?(self, didShow: viewController, animated: animated)

                viewController.didMove(toParent: self)

                completion?()
            }
            animator.animateTransition(using: transitionContext)

        } else {
            contentViewController = viewController
            completion?()
        }
    }

    /// Return the identifier of current content view controller.
    ///
    /// - Returns: if not exist, returns nil.
    open func currentCacheIdentifier() -> String? {
        guard let index = lazyCachedViewControllers.values.index(of: contentViewController) else {
            return nil
        }
        return lazyCachedViewControllers.keys[index]
    }

    /// Clears cached view controller or generators with identifier.
    ///
    /// - Parameter identifier: the identifier that associates with a cache view controller or generator.
    open func clearCache(with identifier: String) {
        lazyCachedViewControllerGenerators[identifier] = nil
        lazyCachedViewControllers[identifier] = nil
    }

    // MARK: - Helper Methods

    private func sideMenuFrame(visibility: Bool) -> CGRect {
        let position = configs.position
        switch position {
        case .above, .sideBySide:
            var baseFrame = view.frame
            if visibility {
                //拼接起来
                baseFrame.origin.x = configs.menuWidth - baseFrame.width
            } else {
                baseFrame.origin.x = -baseFrame.width
            }
            let factor: CGFloat = adjustedDirection == .left ? 1 : -1
            baseFrame.origin.x *= factor
            return baseFrame
        case .under:
            return view.frame
        }
    }

    private func contentFrame(visibility: Bool) -> CGRect {
        let position = configs.position
        switch position {
        case .above:
            return view.frame
        case .under, .sideBySide:
            var baseFrame = view.frame
            if visibility {
                let factor: CGFloat = adjustedDirection == .left ? 1 : -1
                baseFrame.origin.x = configs.menuWidth * factor
            } else {
                baseFrame.origin.x = 0
            }
            return baseFrame
        }
    }

    // MARK: Orientation

    open override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return configs.supportedOrientations
    }

    open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        hideMenu(animated: false, completion: { _ in
            // Temporally hide the menu container view for smooth animation
            self.menuContainerView.isHidden = true
            coordinator.animate(alongsideTransition: { (_) in
                self.contentContainerView.frame = self.contentFrame(visibility: self.isMenuOpenning)
            }, completion: { (_) in
                self.menuContainerView.isHidden = false
                self.menuContainerView.frame = self.sideMenuFrame(visibility: self.isMenuOpenning)
            })
        })

        super.viewWillTransition(to: size, with: coordinator)
    }
}

// MARK: UIGestureRecognizerDelegate

extension SideMenuController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard configs.enablePanGesture else {
            return false
        }

        if isViewControllerInsideNavigationStack(for: touch.view) {
            return false
        }

        if touch.view is UISlider {
            return false
        }

        // If the view is scrollable in horizon direciton, don't receive the touch
        if let scrollView = touch.view as? UIScrollView, scrollView.frame.width > scrollView.contentSize.width {
            return false
        }

        return true
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let velocity = panGestureRecognizer.velocity(in: view)
        return isValidateHorizontalMovement(for: velocity)
    }

    private func isViewControllerInsideNavigationStack(for view: UIView?) -> Bool {
        guard let view = view,
            let viewController = view.parentViewController,
            !(viewController is UINavigationController),
            let navigationController = viewController.navigationController else {
                return false
        }

        if let index = navigationController.viewControllers.index(of: viewController) {
            return index > 0
        }
        return false
    }

    private func isValidateHorizontalMovement(for velocity: CGPoint) -> Bool {
        if isMenuOpenning {
            return true
        }

        let direction = configs.direction
        var factor: CGFloat = direction == .left ? 1 : -1
        factor *= shouldReverseDirection ? -1 : 1
        guard velocity.x * factor > 0 else {
            return false
        }
        return abs(velocity.y / velocity.x) < 0.25
    }
}
