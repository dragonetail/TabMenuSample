//
//  LeftTabMenuView.swift
//  TabMenu
//
//  Created by dragonetail on 2019/1/27.
//  Copyright © 2019 dragonetail. All rights reserved.
//

import Foundation
import SwiftBaseBootstrap
import PureLayout

class LeftTabMenuView: BaseViewWithAutolayout{
    lazy var label: UILabel = {
        let label = UILabel().autoLayout("label")
        label.text = "Hi~"
        label.textColor = UIColor.white
        label.backgroundColor = UIColor.yellow
        return label
    }()
    
    lazy var testButton: UIButton = {
        var button: UIButton = UIButton(frame: .zero).autoLayout("testButton")
        button.addTarget(self, action: #selector(self.testButtonTapped), for: .touchUpInside)
        button.setTitleColor(UIColor.blue, for: .normal)
        button.titleLabel?.font = UIFont.init(name: "Helvetica", size: 16)
        button.setTitle("菜单", for: .normal)
        
        button.extRoundBorder()
        
        return button
    }()
    @objc func testButtonTapped() {
        print("testButtonTapped...")
    }
    
    override func setupAndComposeView() {
        self.backgroundColor = UIColor.black
        self.isMultipleTouchEnabled = true
        
        [label, testButton].forEach {
            self.addSubview($0)
        }
    }
    
    override func setupConstraints() {
        self.autoPinEdgesToSuperviewEdges()
        
        label.autoCenterInSuperview()
        
        testButton.autoAlignAxis(.vertical, toSameAxisOf: self)
        testButton.autoPinEdge(.top, to: .bottom, of: label, withOffset: 30)
    }
    
    
}
