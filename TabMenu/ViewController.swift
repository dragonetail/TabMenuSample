//
//  ViewController.swift
//  TabMenu
//
//  Created by dragonetail on 2018/12/20.
//  Copyright © 2018 dragonetail. All rights reserved.
//
import UIKit
import SwiftBaseBootstrap
import PureLayout

class ViewController: BaseViewControllerWithAutolayout {
    lazy var label: UILabel = {
        let label = UILabel()
        label.text = "Hi~"

        label.textColor = UIColor.lobolly

        return label
    }()

    // 初始化逻辑
    override open var accessibilityIdentifier: String {
        return "ViewController"
    }

    override func setupAndComposeView() {
        self.view.autoLayout(accessibilityIdentifier)

        [label].forEach {
            self.view.addSubview($0)
        }
    }

    override func setupConstraints() {
        label.autoCenterInSuperview()
//        label.autoPinEdge(toSuperviewEdge: .top)
//        label.autoPinEdge(toSuperviewEdge: .left)
//        label.autoAlignAxis(.vertical, toSameAxisOf: self.view)
//        label.autoAlignAxis(.horizontal, toSameAxisOf: self.view)
    }
}
