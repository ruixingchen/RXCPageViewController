//
//  RXCPageView.swift
//  RXCPageViewController
//
//  Created by ruixingchen on 2020/3/4.
//  Copyright © 2020 ruixingchen. All rights reserved.
//

import UIKit

public protocol RXCPageViewDelegate: AnyObject {
    ///开始和结束跳跃是为了通知到代理, 让其屏蔽部分操作用的, 注意目前这两个方法不会成对调用, didEndJumping可能会调用多次
    func pageView(willBeginJumping pageView: RXCPageView)
    ///开始和结束跳跃是为了通知到代理, 让其屏蔽部分操作用的, 注意目前这两个方法不会成对调用, didEndJumping可能会调用多次
    func pageView(didEndJumping pageView: RXCPageView)
    func pageView(_ pageView: RXCPageView, didShowViewAt page: Int)
    func pageView(_ pageView: RXCPageView, didHideViewAt page: Int)
    func pageView(_ pageView: RXCPageView, didScrollWith event: RXCPageView.ScrollEvent)

}

public extension RXCPageView {

    struct ScrollEvent {
        ///这个滚动事件是否是跳跃事件
        var jumping: Bool
        var animated: Bool
        var toPage: Int
        var fromPage: Int
        var progress: CGFloat
    }

}

open class RXCPageView: UIView, UIScrollViewDelegate {

    public typealias ViewClosure = () -> UIView

    open lazy var scrollView: UIScrollView = self.initScrollView()
    ///获取View的closure, 避免了初始化的时候立刻初始化这个view
    open var viewClosures: [ViewClosure] {
        didSet {
            self.reloadViews()
        }
    }
    open var viewClosuresForJumping: [ViewClosure]?

    open var currentPage: Int = 0
    open var lastContentOffset: CGFloat = 0
    open var lastVisibleVirtualPage: [Int] = []

    open var jumping: Bool = false

    public let delegates: NSPointerArray = NSPointerArray.init(options: .weakMemory)

    public init(frame: CGRect, viewClosures: [ViewClosure], page: Int) {
        self.viewClosures = viewClosures
        super.init(frame: frame)
        self.currentPage = page
        self.initSetup()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open func initScrollView() -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = self
        if #available(iOS 13, *) {
            scrollView.backgroundColor = UIColor.systemBackground
        } else {
            scrollView.backgroundColor = UIColor.white
        }

        scrollView.isPagingEnabled = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        #if (DEBUG || debug)
        scrollView.showsHorizontalScrollIndicator = true
        #endif
        scrollView.scrollsToTop = false
        scrollView.isMultipleTouchEnabled = false
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.contentInsetAdjustmentBehavior = .never
        return scrollView
    }

    open func initSetup() {
        self.addSubview(self.scrollView)
        self.scrollView.delegate = self
        self.scrollView.addObserver(self, forKeyPath: #keyPath(UIScrollView.contentOffset), options: [.new, .old], context: nil)
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        self.scrollView.frame = self.bounds
        self.reloadViews()
    }

    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(UIScrollView.contentOffset) && (object as? UIScrollView) == self.scrollView {
            guard let newValue = change?[.newKey] as? CGPoint else {
                return
            }
            let oldValue = change?[.oldKey] as? CGPoint
            if oldValue == nil || newValue != oldValue {
                self.scrollViewContentOffsetDidChnage()
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    func reloadViews() {
        let page: Int = self.currentPage
        self.scrollView.contentSize = CGSize(width: self.scrollView.bounds.width * CGFloat(self.viewClosures.count), height: self.scrollView.bounds.height)
        self.scroll(to: page, animated: false, allowJump: false)
        self.finishJumping()
    }

    func enumerateDelegate(closure: (RXCPageViewDelegate) -> Void) {
        self.delegates.compact()
        for i: Any in self.delegates.allObjects {
            if let delegate: RXCPageViewDelegate = i as? RXCPageViewDelegate {
                closure(delegate)
            }
        }
    }

    //MARK: - 工具方法

    open func frame(for page: Int, viewPortSize: CGSize) -> CGRect {
        return CGRect(x: CGFloat(page) * viewPortSize.width, y: 0, width: viewPortSize.width, height: viewPortSize.height)
    }

    open func offset(for page: Int, viewPortSize: CGSize) -> CGPoint {
        let point: CGPoint = CGPoint(x: CGFloat(page) * viewPortSize.width, y: 0)
        return point
    }

    ///returns the index of visible pages, now every page has to fill the width, so it returns two pages at most
    ///warning, the page is virtual, means the min page is -1 and the max page is self.views.count
    ///if viewPortSize.width equals to 0, will return an empty array
    open func visibleVirtualPages(offset: CGFloat, viewPortSize: CGSize) -> [Int] {
        let offset: CGFloat = self.scrollView.contentOffset.x
        let viewWidth: CGFloat = self.viewPortSize.width
        if viewWidth == 0 {
            return []
        } else if offset < 0 {
            return [-1, 0]
        } else {
            let pages: [Int]
            let leftPage: Int = Int(offset / viewWidth)
            if self.isFullPage(offset: offset, viewPortSize: viewPortSize) {
                pages = [leftPage]
            } else {
                pages = [leftPage, leftPage + 1]
            }
            return pages
        }
    }

    ///just like the name says
    open func isPageVisible(_ page: Int, offset: CGFloat, viewPortSize: CGSize) -> Bool {
        return self.visibleVirtualPages(offset: offset, viewPortSize: viewPortSize).contains(page)
    }

    /// returns the four part size if two pages visible
    ///
    /// - Parameter _offset: the offset, nil for current offset
    /// - Returns: if two pages visible, returns the four part size, if one page visible, current page is left page
    open func viewPartSizeState(offset: CGFloat, viewPortSize: CGSize) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
        let viewWidth: CGFloat = viewPortSize.width
        let left_left: CGFloat
        if offset < 0 {
            left_left = viewWidth + offset
        } else {
            left_left = fmod(offset, viewWidth)
        }
        let left_right: CGFloat = viewWidth - left_left
        let right_left: CGFloat
        let right_right: CGFloat
        if self.isFullPage(offset: offset, viewPortSize: viewPortSize) {
            right_left = 0
            right_right = 0
        } else {
            right_left = left_left
            right_right = left_right
        }
        return (left_left, left_right, right_left, right_right)
    }

    ///is there only one page visible?
    open func isFullPage(offset: CGFloat, viewPortSize: CGSize) -> Bool {
        return fmod(offset, viewPortSize.width).isEqual(to: 0.0)
    }

    ///calculate current page from offset
    open func calculateCurrentVirtualPage(offset: CGFloat, viewPortSize: CGSize) -> Int {
        let pageWidth: CGFloat = viewPortSize.width
        if pageWidth == 0 {
            return 0
        }
        let offset: CGFloat = self.scrollView.contentOffset.x
        let ll: CGFloat = self.viewPartSizeState(offset: offset, viewPortSize: viewPortSize).0

        var page: Int
        if offset < 0 {
            page = ll > pageWidth / 2 ? 0 : -1
        } else {
            page = Int(offset / pageWidth)
            if ll > pageWidth / 2 {
                page += 1
            }
        }
        return page
    }

    var viewPortSize: CGSize {
        return self.scrollView.bounds.size
    }

    ///获取某一页的View, 这个方法没有安全措施, 自己确保page的合法性
    open func view(at page: Int) -> UIView {
        if let jumpingArray: [ViewClosure] = self.viewClosuresForJumping {
            return jumpingArray[page]()
        } else {
            return self.viewClosures[page]()
        }
    }

    ///计算滑动的进度
    open func swipeProgress(offset:CGFloat, fromPage:Int, toPage:Int)->CGFloat {
        let viewPortSize: CGSize = self.viewPortSize
        let fromPageFrame: CGRect = self.frame(for: fromPage, viewPortSize: viewPortSize)
        var fromPageMinX: CGFloat = fromPageFrame.minX
        let toPageFrame: CGRect = self.frame(for: toPage, viewPortSize: viewPortSize)
        var toPageMinX: CGFloat = toPageFrame.minX
        fromPageMinX += 1000000
        toPageMinX += 1000000
        let offset: CGFloat = offset + 1000000
        let progress: CGFloat = (offset-fromPageMinX)/(toPageMinX - fromPageMinX)
        return progress
    }

    ///生成滚动事件
    open func makeScrollEvent(offset: CGFloat, lastOffset: CGFloat) -> ScrollEvent {
        let viewPortSize: CGSize = self.viewPortSize
        if offset >= lastOffset  {
            //手指向左, 目标page + 1
            let fromPage = lastOffset/viewPortSize.width < 0 ? -1 : Int(lastOffset/viewPortSize.width)
            let toPage: Int = fromPage + 1
            let progress: CGFloat = self.swipeProgress(offset: offset, fromPage: fromPage, toPage: toPage)
            #if (debug || DEBUG)
            print("生成滚动事件, 向左拖拽, form \(fromPage) to \(toPage) @ \(String.init(format: "%.2f", progress))")
            #endif
            return ScrollEvent(jumping: false, animated: true, toPage: toPage, fromPage: fromPage, progress: progress)
        }else {
            //手指向右, 目标page-1
            let fromPage = Int(ceil(lastOffset/viewPortSize.width))
            let toPage: Int = fromPage - 1
            let progress: CGFloat = self.swipeProgress(offset: offset, fromPage: fromPage, toPage: toPage)
            #if (debug || DEBUG)
            print("生成滚动事件, 向右拖拽, form \(fromPage) to \(toPage) @ \(String.init(format: "%.2f", progress))")
            #endif
            return ScrollEvent(jumping: false, animated: true, toPage: toPage, fromPage: fromPage, progress: progress)
        }
    }

    //MARK: - 跳转

    open func scroll(to page: Int, animated: Bool, allowJump: Bool) {
        guard page >= 0 && page < self.viewClosures.count else {
            assertionFailure("page out of index, will not take any actions")
            return
        }
        #if (debug || DEBUG)
        print("滚动到\(page)页, animated:\(animated)")
        #endif
        var animated: Bool = animated
        if page == self.currentPage {
            animated = false
        }

        if !animated || !allowJump || abs(page - self.currentPage) <= 1 {
            let fromPage: Int = self.currentPage
            let targetOffset: CGPoint = self.offset(for: page, viewPortSize: self.viewPortSize)
            self.startJumping()
            self.scrollView.setContentOffset(targetOffset, animated: animated)
            //self.scrollViewDidScroll(self.scrollView)
            let event = ScrollEvent(jumping: true, animated: animated, toPage: page, fromPage: fromPage, progress: 1.0)
            self.enumerateDelegate(closure: { $0.pageView(self, didScrollWith: event) })
            if !animated {
                ///如果不动画的话, 立刻调用结束jumping
                self.finishJumping()
            }
        } else {
            self.startJumping()
            let fromPage: Int = self.currentPage
            self.viewClosuresForJumping = self.viewClosures
            let tmpPage: Int
            if self.currentPage < page {
                ///目标在右侧
                tmpPage = page - 1
            } else if self.currentPage > page {
                tmpPage = page + 1
            } else {
                tmpPage = page
            }
            self.viewClosuresForJumping?[tmpPage] = self.viewClosures[self.currentPage]
            self.scrollView.setContentOffset(self.offset(for: tmpPage, viewPortSize: self.viewPortSize), animated: false)
            self.scrollView.setContentOffset(self.offset(for: page, viewPortSize: self.viewPortSize), animated: animated)
            if !animated {
                ///如果不动画的话, 立刻调用结束jumping
                self.finishJumping()
            }
            //生成scrollEvent
            let event = ScrollEvent(jumping: true, animated: animated, toPage: page, fromPage: fromPage, progress: 1.0)
            self.enumerateDelegate(closure: { $0.pageView(self, didScrollWith: event) })
        }
    }

    open func showView(at page: Int) {
        let pageView: UIView = self.view(at: page)
        let frame: CGRect = self.frame(for: page, viewPortSize: self.viewPortSize)
        pageView.frame = frame
        if pageView.superview == nil {
            self.scrollView.addSubview(pageView)
        }
        pageView.isHidden = false
        self.enumerateDelegate(closure: { $0.pageView(self, didShowViewAt: page) })
    }

    open func hideView(at page: Int) {
        ///we do not want to break the responder chain, so just hide the view
        let pageView: UIView = self.view(at: page)
        pageView.isHidden = true
        self.enumerateDelegate(closure: { $0.pageView(self, didShowViewAt: page) })
    }

    open func startJumping() {
        self.jumping = true
        self.isUserInteractionEnabled = false
        ///force break touching
        self.scrollView.panGestureRecognizer.isEnabled = false
        self.scrollView.panGestureRecognizer.isEnabled = true
        self.enumerateDelegate(closure: {$0.pageView(willBeginJumping: self)})
    }

    ///完成跳跃
    open func finishJumping() {
        let previousJumping: Bool = self.jumping
        self.jumping = false
        self.viewClosuresForJumping = nil
        self.isUserInteractionEnabled = true
        self.lastContentOffset = self.scrollView.contentOffset.x
        self.lastVisibleVirtualPage = self.visibleVirtualPages(offset: self.scrollView.contentOffset.x, viewPortSize: self.viewPortSize)
        self.currentPage = self.calculateCurrentVirtualPage(offset: self.scrollView.contentOffset.x, viewPortSize: self.viewPortSize)
        if previousJumping {
            self.enumerateDelegate(closure: { $0.pageView(didEndJumping: self) })
        }
    }

    open func scrollViewContentOffsetDidChnage() {
        ///当处于jumping的时候无需进行通知

        let offset: CGFloat = scrollView.contentOffset.x
        #if (debug || DEBUG)
        //print("contentOffset变化:\(offset)")
        #endif
        var event: ScrollEvent?
        if !self.jumping {
            #if (debug || DEBUG)
            print("触发滑动:\(offset), last:\(self.lastContentOffset)")
            #endif
            event = self.makeScrollEvent(offset: offset, lastOffset: self.lastContentOffset)
        }
        self.lastContentOffset = offset
        self.currentPage = self.calculateCurrentVirtualPage(offset: offset, viewPortSize: self.viewPortSize)

        //开始更新本地View
        let visiblePages: [Int] = self.visibleVirtualPages(offset: offset, viewPortSize: self.viewPortSize)
        let lastVisiblePages: [Int] = self.lastVisibleVirtualPage

        if visiblePages != lastVisiblePages {
            //页面没有变化则无需更新页面
            #if (debug || DEBUG)
            print("当前可见:\(visiblePages), 上次可见:\(lastVisiblePages)")
            #endif
            for i: Int in lastVisiblePages {
                if !visiblePages.contains(i) && (0..<self.viewClosures.count).contains(i) {
                    self.hideView(at: i)
                }
            }
            for i: Int in visiblePages {
                if !lastVisiblePages.contains(i) && (0..<self.viewClosures.count).contains(i) {
                    self.showView(at: i)
                }
            }
            self.lastVisibleVirtualPage = visiblePages
        }

        if !self.jumping {
            if let _event: ScrollEvent = event {
                ///非jump的情况下通知代理滚动事件
                self.enumerateDelegate(closure: { $0.pageView(self, didScrollWith: _event) })
            }
        }
    }

    //MARK: UIScrollViewDelegate

    open func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.finishJumping()
    }

    open func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        self.finishJumping()
    }

    open func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            self.finishJumping()
        }
    }

}
