//
// Created by ruixingchen on 2020/4/2.
// Copyright (c) 2020 ruixingchen. All rights reserved.
//

import UIKit

open class TitleScrollTopBarStyle {

    open var backgroundColor: UIColor = {
        if #available(iOS 13, *) {return UIColor.secondarySystemBackground} else {return UIColor.white}
    }()
    open var sectionInset: UIEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
    open var itemSpacing: CGFloat = 0
    open var height: CGFloat = 36
    open var alwaysBounce: Bool = false

    ///底部的分割线颜色，一般不需要更改
    open var hairlineColor: UIColor = {
        if #available(iOS 13.0, *) {
            return UIColor.separator
        } else {
            return UIColor(red: CGFloat(200)/255.0, green: CGFloat(200)/255.0, blue: CGFloat(204)/255.0, alpha: 1.0)
        }
    }()
    ///底部分割线的高度，默认一个像素
    open var hairlineHeight: CGFloat = 1/UIScreen.main.scale

    ///如果Cell无法占满宽度，则拉伸每个Cell来占满宽度, 否则直接排列
    open var expandCellToFillWidth: Bool = true

    ///底部指示器的颜色
    open var indicatorColor: UIColor = UIColor(red: CGFloat(78)/255, green: CGFloat(138)/255, blue: CGFloat(118)/255, alpha: 1.0)
    open var indicatorCornerRadius: CGFloat = 2.0
    open var indicatorHeight: CGFloat = 4.0
    open var indicatorBottomSpace: CGFloat = 2.0

    ///左右两边的虚拟cell的宽度, 小于0表示和相邻的cell同宽度, 大于1000超出的部分作为绝对宽度, 0-1000之间表示为相邻cell的倍数
    open var virtualCellWidth: CGFloat = 0

    //for default cell style
    open var cell_font: UIFont = UIFont.systemFont(ofSize: 17)
    open var cell_textColor: UIColor = UIColor.black
    open var cell_textHighlightColor: UIColor = UIColor(red: CGFloat(78)/255, green: CGFloat(138)/255, blue: CGFloat(118)/255, alpha: 1.0)
    ///cell的宽度offset, 即左右两边的边距
    open var cellContentHorizontalInset: CGFloat = 16

    ///自定义的Cell类型
    open var cellType: ((TitleScrollTopBarCell&UICollectionViewCell).Type)?
    ///生成自定义的CollectionView
    open var collectionViewMaker:(() -> UICollectionView)?
    ///生成自定义的指示器view
    open var indicatorMaker:(() -> UIView)?
    ///自定义的宽度计算
    open var cellSizeCalculator: ((TopBarItem) -> CGSize)?

    init() {
        if #available(iOS 13, *) {
            self.backgroundColor = UIColor.secondarySystemBackground
            self.hairlineColor = UIColor.separator
        }
    }
}