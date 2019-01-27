//
//  LeftTabMenuViewController.swift
//  PhotoSaver
//
//  Created by dragonetail on 2018/12/20.
//  Copyright © 2018 dragonetail. All rights reserved.
//
import UIKit
import SwiftBaseBootstrap
import PureLayout

class LeftTabMenuViewController: BaseViewControllerWithAutolayout {
    lazy var leftTabMenuView: LeftTabMenuView = {
        let leftTabMenuView = LeftTabMenuView().autoLayout("LeftTabMenuView")
        return leftTabMenuView
    }()

    // 初始化逻辑
    override open var accessibilityIdentifier: String {
        return "LeftTabMenuViewController"
    }

    override func setupAndComposeView() {
        [leftTabMenuView].forEach {
            self.view.addSubview($0)
        }
    }

    override func setupConstraints() {
        //self.view.autoSetDimension(.width, toSize: 280)
    }
}
