//
// Created by ruixingchen on 2020/4/1.
// Copyright (c) 2020 ruixingchen. All rights reserved.
//

import UIKit



public protocol TitleScrollTopBarDataSource: AnyObject {

    func titleScrollTopBarNumberOfItems(_ topBar: TitleScrollTopBar) -> Int
    func titleScrollTopBar(_ topBar: TitleScrollTopBar, itemForPageAt page: Int) -> TopBarItem
    func titleScrollTopBar(_ topBar: TitleScrollTopBar, didTapItemAt page: Int)
}

open class TitleScrollTopBar: UIView, TopBar, RXCPageViewDelegate, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    open var style: TitleScrollTopBarStyle

    open weak var dataSource: TitleScrollTopBarDataSource?

    open lazy var collectionView: UICollectionView = self.initCollectionView(style: self.style)
    open lazy var indicatorView: UIView = self.initIndicatorView(style: self.style)
    open var hairlineView: UIView = UIView()

    open lazy var templateCell: UICollectionViewCell&TitleScrollTopBarCell = self.style.cellType?.init() ?? Cell(frame: CGRect.zero)

    ///记录每个cell的尺寸, 如果为空, 表示使用cell的实际尺寸
    internal var cellSizes:[CGSize] = []

    open var lastScrollEvent:RXCPageView.ScrollEvent?

    public init(style: TitleScrollTopBarStyle) {
        self.style = style
        super.init(frame: CGRect.zero)
        self.initSetup()
    }

    public required init?(coder: NSCoder) {
        self.style = TitleScrollTopBarStyle()
        super.init(coder: coder)
        self.initSetup()
    }

    open func initCollectionView(style: TitleScrollTopBarStyle) -> UICollectionView {
        if let maker: (() -> UICollectionView) = style.collectionViewMaker {
            return maker()
        }
        let flow: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        flow.minimumInteritemSpacing = style.itemSpacing
        flow.minimumLineSpacing = 0
        flow.scrollDirection = .horizontal
        flow.sectionInset = style.sectionInset
        flow.estimatedItemSize = CGSize.zero
        let view: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: flow)
        view.backgroundColor = nil
        view.alwaysBounceHorizontal = style.alwaysBounce
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        if let cell: ((TitleScrollTopBarCell & UICollectionViewCell).Type) = style.cellType {
            view.register(cell, forCellWithReuseIdentifier: "cell")
        } else {
            view.register(Cell.self, forCellWithReuseIdentifier: "cell")
        }
        return view
    }

    open func initIndicatorView(style: TitleScrollTopBarStyle) -> UIView {
        let view: UIView = UIView()
        view.backgroundColor = style.indicatorColor
        view.layer.cornerRadius = style.indicatorCornerRadius
        return view
    }

    open func initSetup() {
        self.backgroundColor = self.style.backgroundColor
        self.addSubview(self.collectionView)
        self.collectionView.addSubview(self.indicatorView)
        self.hairlineView.backgroundColor = self.style.hairlineColor
    }

    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        return CGSize(width: size.width, height: self.style.height)
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        self.layoutCollectionView()
        self.layoutHairlineView()
    }

    open func layoutHairlineView() {
        let x: CGFloat = self.bounds.minX
        let y: CGFloat = self.bounds.maxY - self.style.hairlineHeight
        self.hairlineView.frame = CGRect(x: x, y: y, width: self.bounds.width, height: self.style.hairlineHeight)
    }

    open func layoutCollectionView() {
        let previousFrame: CGRect = self.collectionView.frame
        self.collectionView.frame = self.bounds
        let currentFrame: CGRect = self.collectionView.frame
        if previousFrame.size == currentFrame.size {
            return
        }
        #if (debug || DEBUG)
        print("CollectionView尺寸变化, 开始重新布局, from:\(previousFrame.size) to \(currentFrame.size)")
        #endif
        ///当尺寸发生了变化的时候, 要求collectionView重新加载数据
        self.cellSizes = self.calculateExpandedCellSize()
        self.collectionView.collectionViewLayout.invalidateLayout()
        self.collectionView.layoutIfNeeded()
    }

    open func reloadData() {
        //先计算实际尺寸
        self.cellSizes = self.calculateExpandedCellSize()
        self.collectionView.reloadData()
    }

    //MARK: - 工具方法

    ///计算某个item的实际宽度
    open func size(for item:TopBarItem)->CGSize {
        if let closure: ((TopBarItem) -> CGSize) = self.style.cellSizeCalculator {
            let size: CGSize = closure(item)
            return size
        } else {
            //默认的size计算
            self.templateCell.prepareForReuse()
            self.templateCell.bind(item, style: self.style, userInfo: nil)
            let size: CGSize = self.templateCell.intrinsicContentSize
            return size
        }
    }

    ///返回某个位置的cell的尺寸(如果有扩展尺寸则返回扩展尺寸)
    open func size(forItemAt index:Int)->CGSize {
        guard let item: TopBarItem = self.dataSource?.titleScrollTopBar(self, itemForPageAt: index) else {return CGSize.zero}
        if (0..<self.cellSizes.count).contains(index) {
            return self.cellSizes[index]
        }else {
            return self.size(for: item)
        }
    }

    open func frame(forCellAt index:Int)->CGRect {
        var attributes: UICollectionViewLayoutAttributes? = self.collectionView.collectionViewLayout.layoutAttributesForItem(at: IndexPath(item: index, section: 0))
        if attributes == nil {
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.collectionView.setNeedsLayout()
            self.collectionView.layoutIfNeeded()
        }
        attributes = self.collectionView.collectionViewLayout.layoutAttributesForItem(at: IndexPath(item: index, section: 0))
        return attributes?.frame ?? CGRect.zero
    }

    ///返回某一页的指示器的位置
    open func frame(forIndicatorAt index:Int)->CGRect {
        let itemNum: Int = self.collectionView.numberOfItems(inSection: 0)
        let y: CGFloat = self.collectionView.bounds.maxY - self.style.indicatorHeight
        let width:CGFloat
        let x:CGFloat
        if index < 0 {
            //-1 页, 需要判断情况
            let firstCellFrame: CGRect = self.frame(forCellAt: 0)
            if self.style.virtualCellWidth > 1000 {
                width = self.style.virtualCellWidth - 1000
            }else if self.style.virtualCellWidth < 0 {
                width = firstCellFrame.width
            }else {
                width = firstCellFrame.width*self.style.virtualCellWidth
            }
            x = firstCellFrame.minX - width
        }else if index >= itemNum {
            ///右侧虚拟页
            let lastCellFrame:CGRect
            if itemNum == 0 {
                lastCellFrame = CGRect.zero
            }else {
                lastCellFrame = self.frame(forCellAt: itemNum-1)
            }
            if self.style.virtualCellWidth > 1000 {
                width = self.style.virtualCellWidth - 1000
            }else if self.style.virtualCellWidth < 0 {
                width = lastCellFrame.width
            }else {
                width = lastCellFrame.width*self.style.virtualCellWidth
            }
            x = lastCellFrame.maxX
        }else {
            //中间的部分直接取cell的frame就好
            let cellFrame: CGRect = self.frame(forCellAt: index)
            x = cellFrame.minX
            width = cellFrame.width
        }
        let height: CGFloat = self.style.indicatorHeight
        let frame: CGRect = CGRect(x: x, y: y, width: width, height: height)
        return frame
    }

    ///the offset for making the cell at center
    open func offsetForCenteringCell(at index:Int)->CGFloat {
        let cellFrame:CGRect
        if index < 0 {
            cellFrame = self.frame(forIndicatorAt: index)
        }else if index >= self.collectionView.numberOfItems(inSection: 0) {
            ///右侧的虚拟cell
            cellFrame = self.frame(forIndicatorAt: index)
        }else {
            cellFrame = self.frame(forCellAt: index)
        }
        return cellFrame.midX - self.collectionView.bounds.width/2
    }

    ///根据当前的情况计算每个Cell的实际尺寸
    open func calculateExpandedCellSize()->[CGSize] {
        ///先计算每个cell的size, 之后根据宽度是否铺满来拉伸
        guard self.style.expandCellToFillWidth else {
            //如果设置了无需拉伸, 则直接返回空数组, 让cell使用本身的size即可
            return []
        }
        guard let flow: UICollectionViewFlowLayout = self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout else {
            ///如果采用了自定义布局, 那么需要自己继承后计算expanded size
            return []
        }
        guard let _dataSource: TitleScrollTopBarDataSource = self.dataSource else {return []}
        let num: Int = _dataSource.titleScrollTopBarNumberOfItems(self) ?? 0

        let items:[TopBarItem] = (0..<num).map({_dataSource.titleScrollTopBar(self, itemForPageAt: $0)})
        var sizes: [CGSize] = items.map({self.size(for: $0)})
        let allCellWidth: CGFloat = sizes.map({$0.width}).reduce(0.0, {$0+$1})
        let off: CGFloat = self.collectionView.bounds.width - (allCellWidth + flow.sectionInset.left + flow.sectionInset.right)
        if off <= 0  {
            //内容超出了宽度, 直接返回即可
            return sizes
        }
        ///内容不足, 需要拉伸cell宽度
        //拉伸的逻辑: 按照每个cell的宽度的比例进行拉伸
        let newWidths: [CGFloat] = sizes.map({$0.width}).map({$0 + ($0/allCellWidth)*off})
        newWidths.enumerated().forEach({
            sizes[$0.offset].width = $0.element
        })
        return sizes
    }

    ///当接收到滚动事件的时候, 更新offset让cell居中
    open func updateContentOffsetOnScrollEvent(_ event: RXCPageView.ScrollEvent){
        let legalPageRange: Range<Int> = 0..<self.collectionView.numberOfItems(inSection: 0)
        var fromOffset:CGFloat = self.offsetForCenteringCell(at: event.fromPage)
        var toOffset:CGFloat = self.offsetForCenteringCell(at: event.toPage)
        let min:CGFloat = 0
        let max:CGFloat = self.collectionView.contentSize.width-self.collectionView.bounds.width

        if fromOffset < min {
            fromOffset = min
        }else if fromOffset > max {
            fromOffset = max
        }
        if toOffset < min {
            toOffset = min
        }else if toOffset > max {
            toOffset = max
        }

        if event.jumping {
            self.collectionView.setContentOffset(CGPoint(x: toOffset, y: 0), animated: event.animated)
        }else{
            let targetOffset: CGFloat = fromOffset + (toOffset-fromOffset)*event.progress
            self.collectionView.setContentOffset(CGPoint(x: targetOffset, y: 0), animated: false)
        }
    }

    ///如果event为nil, 表示全部取消高亮状态
    open func updateCellHighlight(event:RXCPageView.ScrollEvent?, cell: UIView, index:Int) {
        guard let event: RXCPageView.ScrollEvent = event else {
            (cell as? TitleScrollTopBarCell)?.setHighlight(progress: 0.0, style: self.style, animationDuration: 0.0)
            return
        }
        if event.jumping {
            if index == event.toPage {
                (cell as? TitleScrollTopBarCell)?.setHighlight(progress: 1.0, style: self.style, animationDuration: event.animated ? 0.25 : 0.0)
            }else {
                (cell as? TitleScrollTopBarCell)?.setHighlight(progress: 0.0, style: self.style, animationDuration: event.animated ? 0.25 : 0.0)
            }
        }else {
            if index == event.toPage {
                (cell as? TitleScrollTopBarCell)?.setHighlight(progress: event.progress, style: self.style, animationDuration: 0.0)
            }else if index == event.fromPage {
                (cell as? TitleScrollTopBarCell)?.setHighlight(progress: 1-event.progress, style: self.style, animationDuration: 0.0)
            }else {
                (cell as? TitleScrollTopBarCell)?.setHighlight(progress: 0.0, style: self.style, animationDuration: 0.0)
            }
        }
    }

    //MARK: - CollectionView

    open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.dataSource?.titleScrollTopBarNumberOfItems(self) ?? 0
    }

    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: UICollectionViewCell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        if let _cell: TitleScrollTopBarCell = cell as? TitleScrollTopBarCell {
            let item: TopBarItem? = self.dataSource?.titleScrollTopBar(self, itemForPageAt: indexPath.item)
            _cell.bind(item, style: self.style, userInfo: nil)
        }
        return cell
    }

    open func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        var size: CGSize = self.size(forItemAt: indexPath.item)
        //这里强制让宽度小于collectionView的高度, 否则可能导致显示有问题
        size.height = collectionView.bounds.height-0.1
        return size
    }

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        self.dataSource?.titleScrollTopBar(self, didTapItemAt: indexPath.item)
    }

    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        ///将要显示的时候, 将当前的cell设置高亮
        self.updateCellHighlight(event: self.lastScrollEvent, cell: cell, index: indexPath.item)
    }

    //MARK: - TopBar

    public func pageView(_ pageView: RXCPageView, didScrollWith event: RXCPageView.ScrollEvent) {
        self.lastScrollEvent = event
        if event.jumping {
            //跳跃的时候, 直接将指示器设置到对应的位置即可, 无需考虑当前位置
            let index: Int = event.toPage
            let frame: CGRect = self.frame(forIndicatorAt: index)
            if event.animated {
                UIView.animate(withDuration: 0.25) { () -> Void in
                    self.indicatorView.frame = frame
                }
            }else {
                self.indicatorView.frame = frame
            }
            ///滚动到居中的位置
        }else {
            //计算
            let fromFrame: CGRect = self.frame(forIndicatorAt: event.fromPage)
            let toFrame: CGRect = self.frame(forIndicatorAt: event.toPage)
            let width: CGFloat = fromFrame.width + event.progress*(toFrame.width-fromFrame.width)
            let centerX: CGFloat = fromFrame.midX + event.progress*(toFrame.midX-fromFrame.midX)
            let x: CGFloat = centerX-width/2
            let frame = CGRect(x: x, y: self.collectionView.bounds.maxY-self.style.indicatorHeight, width: width, height: self.style.indicatorHeight)
            #if (debug || DEBUG)
            print("滚动更新指示器:\(frame)")
            #endif
            self.indicatorView.frame = frame
        }
        //根据滚动位置,将cell居中
        self.updateContentOffsetOnScrollEvent(event)
        for i: IndexPath in self.collectionView.indexPathsForVisibleItems {
            if let cell: UICollectionViewCell = self.collectionView.cellForItem(at: i) {
                self.updateCellHighlight(event: self.lastScrollEvent, cell: cell, index: i.item)
            }
        }
    }

    public func pageView(_ pageView: RXCPageView, didShowViewAt page: Int) {

    }

    public func pageView(_ pageView: RXCPageView, didHideViewAt page: Int) {

    }

    public func pageView(willBeginJumping pageView: RXCPageView) {
        self.isUserInteractionEnabled = false
    }

    public func pageView(didEndJumping pageView: RXCPageView) {
        self.isUserInteractionEnabled = true
    }
}


