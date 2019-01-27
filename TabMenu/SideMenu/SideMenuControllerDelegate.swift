import Foundation
import UIKit

// Delegate Methods
@objc public protocol SideMenuControllerDelegate: class {

    /// 允许定制化非交互视图转换的动画控制。
    /// 参考 `navigationController:animationControllerForOperation:fromViewController:toViewController:`
    @objc optional func sideMenuController(_ sideMenuController: SideMenuController,
                                     animationControllerFrom fromVC: UIViewController,
                                     to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning?

    @objc optional func sideMenuController(_ sideMenuController: SideMenuController, willShow viewController: UIViewController, animated: Bool)
    @objc optional func sideMenuController(_ sideMenuController: SideMenuController, didShow viewController: UIViewController, animated: Bool)

    @objc optional func sideMenuControllerWillOpenMenu(_ sideMenuController: SideMenuController)
    @objc optional func sideMenuControllerDidOpenMenu(_ sideMenuController: SideMenuController)
    @objc optional func sideMenuControllerWillHideMenu(_ sideMenuController: SideMenuController)
    @objc optional func sideMenuControllerDidHideMneu(_ sideMenuController: SideMenuController)
}

