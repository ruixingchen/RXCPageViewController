//
// Created by ruixingchen on 2020/4/1.
// Copyright (c) 2020 ruixingchen. All rights reserved.
//

import UIKit

open class RXCTopBarPageController: UIViewController, TitleScrollTopBarDataSource, RXCPageViewDelegate {

    open lazy var pageTopBar: UIView? = self.initPageTopBar()
    open lazy var pageView:RXCPageView = self.initPageView()

    open var viewControllers:[UIViewController]
    open var page:Int

    open func initPageTopBar() -> UIView? {
        let style: TitleScrollTopBarStyle = TitleScrollTopBarStyle()
        let bar: TitleScrollTopBar = TitleScrollTopBar(style: style)
        bar.dataSource = self
        return bar
    }

    open func initPageView()->RXCPageView {
        let viewClosures:[RXCPageView.ViewClosure] = self.viewControllers.map { (controller: UIViewController) -> RXCPageView.ViewClosure in
            return {[unowned self] () in
                return controller.view
            }
        }
        let view: RXCPageView = RXCPageView(frame: CGRect.zero, viewClosures: viewClosures, page: self.page)
        return view
    }

    public init(viewControllers:[UIViewController], page:Int) {
        self.viewControllers = viewControllers
        self.page = page
        super.init(nibName: nil, bundle: nil)
        self.viewControllers.forEach { (controller: UIViewController) in
            self.addChild(controller)
        }
    }

    public required init?(coder: NSCoder) {
        fatalError()
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubview(self.pageView)
        self.pageView.delegates.addPointer(Unmanaged.passUnretained(self).toOpaque())
        if let bar: UIView = self.pageTopBar {
            self.view.addSubview(bar)
        }
    }

    open override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.layoutPageTopBar()
        self.layoutPageView()
        if let bar: UIView = self.pageTopBar {
            self.view.bringSubviewToFront(bar)
        }
    }

    open func layoutPageView() {
        self.pageView.frame = self.view.bounds
    }

    open func layoutPageTopBar() {
        guard let bar: UIView = self.pageTopBar else {
            return
        }
        let size: CGSize = bar.sizeThatFits(self.view.bounds.size)
        let x: CGFloat = self.view.bounds.midX - size.width / 2
        let safeAreaTop: CGFloat = self.view.safeAreaInsets.top - self.additionalSafeAreaInsets.top
        let y: CGFloat = safeAreaTop
        bar.frame = CGRect(x: x, y: y, width: size.width, height: size.height)
        if self.additionalSafeAreaInsets.top != bar.frame.maxY - safeAreaTop {
            self.additionalSafeAreaInsets.top = bar.frame.height
        }
    }

    //MARK: - TitleScrollTopBarDataSource
    public func titleScrollTopBarNumberOfItems(_ topBar: TitleScrollTopBar) -> Int {
        return self.viewControllers.count
    }

    public func titleScrollTopBar(_ topBar: TitleScrollTopBar, itemForPageAt page: Int) -> TopBarItem {
        let item = TopBarItem()
        item.title = self.viewControllers[page].title
        return item
    }

    public func titleScrollTopBar(_ topBar: TitleScrollTopBar, didTapItemAt page: Int) {
        //滚动到对应的界面
        self.pageView.scroll(to: page, animated: true, allowJump: true)
    }

    //MARK: - RXCPageViewDelegate
    public func pageView(willBeginJumping pageView: RXCPageView) {
        (self.pageTopBar as? RXCPageViewDelegate)?.pageView(willBeginJumping: pageView)
        self.view.isUserInteractionEnabled = false
    }

    public func pageView(didEndJumping pageView: RXCPageView) {
        (self.pageTopBar as? RXCPageViewDelegate)?.pageView(didEndJumping: pageView)
        self.view.isUserInteractionEnabled = true
    }

    public func pageView(_ pageView: RXCPageView, didShowViewAt page: Int) {
        (self.pageTopBar as? RXCPageViewDelegate)?.pageView(pageView, didShowViewAt: page)
    }

    public func pageView(_ pageView: RXCPageView, didHideViewAt page: Int) {
        (self.pageTopBar as? RXCPageViewDelegate)?.pageView(pageView, didHideViewAt: page)
    }

    public func pageView(_ pageView: RXCPageView, didScrollWith event: RXCPageView.ScrollEvent) {
        (self.pageTopBar as? RXCPageViewDelegate)?.pageView(pageView, didScrollWith: event)
    }
}
