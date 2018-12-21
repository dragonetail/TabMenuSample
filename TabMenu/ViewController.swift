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
        return label
    }()
    
    // 初始化逻辑
    override open var accessibilityIdentifier: String {
        return "LeftTabMenuViewController"
    }
    
    override func setupAndComposeView() {
        self.view.backgroundColor = UIColor.white
        self.view.isMultipleTouchEnabled = true
        
        [label].forEach {
            view.addSubview($0)
        }
    }
    
    override func setupConstraints() {
        label.autoCenterInSuperview()
    }
}
