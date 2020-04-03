//
//  ViewController.swift
//  ExampleApp
//
//  Created by ruixingchen on 2020/3/4.
//  Copyright © 2020 ruixingchen. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    lazy var topBarController:RXCTopBarPageController = self.initTopBarController()

    func initTopBarController()->RXCTopBarPageController {
        let vcs: [UIViewController] = (0..<15).map { i -> UIViewController in
            let vc = ColorViewController()
            vc.title = i.description
            return vc
        }
        let page = RXCTopBarPageController(viewControllers: vcs, page: 2)
        return page
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.addChild(self.topBarController)
        self.view.addSubview(self.topBarController.view)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.topBarController.view.frame = self.view.bounds
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.topBarController.view.frame = self.view.bounds
        self.topBarController.view.setNeedsLayout()
    }
}

class ColorViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.init(red: CGFloat.random(in: 0..<1), green: CGFloat.random(in: 0..<1), blue: CGFloat.random(in: 0..<1), alpha: 1.0)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 100
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.textLabel?.text = self.title! + "--" + indexPath.row.description
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        //自动跳页
        var next:UIResponder? = self.view.next
        while next != nil {
            if let pageView: RXCPageView = next as? RXCPageView {
                let page: Int = (0..<pageView.viewClosures.count).randomElement()!
                pageView.scroll(to: page, animated: true, allowJump: true)
                break
            }
            next = next?.next
        }
    }

}
