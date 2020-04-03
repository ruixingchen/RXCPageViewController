//
// Created by ruixingchen on 2020/4/2.
// Copyright (c) 2020 ruixingchen. All rights reserved.
//

import UIKit

public protocol TitleScrollTopBarCell where Self: UICollectionViewCell {

    func setHighlight(progress: CGFloat, style: Any?, animationDuration: TimeInterval)
    func bind(_ item: TopBarItem?, style: TitleScrollTopBarStyle, userInfo: [AnyHashable: Any]?)

}

extension TitleScrollTopBar {

    open class Cell: UICollectionViewCell, TitleScrollTopBarCell {

        let label: UILabel = UILabel()

        var item: TopBarItem?
        var style: TitleScrollTopBarStyle?

        public override init(frame: CGRect) {
            super.init(frame: frame)
            self.initSetup()
        }

        public required init?(coder: NSCoder) {
            super.init(coder: coder)
            self.initSetup()
        }

        func initSetup() {
            self.backgroundColor = nil
            self.contentView.backgroundColor = nil
            self.contentView.addSubview(self.label)
        }

        open func bind(_ item: TopBarItem?, style: TitleScrollTopBarStyle, userInfo: [AnyHashable: Any]?) {
            self.style = style
            self.label.font = style.cell_font
            self.label.text = item?.title
        }

        open func setHighlight(progress: CGFloat, style: Any?, animationDuration: TimeInterval) {
            guard let style: TitleScrollTopBarStyle = style as? TitleScrollTopBarStyle else {
                self.label.textColor = UIColor.black
                return
            }
            
            let updateClosure: () -> Void = {
                if progress <= 0 {
                    self.label.textColor = style.cell_textColor
                } else if progress >= 1 {
                    self.label.textColor = style.cell_textHighlightColor
                } else {
                    //计算中间的颜色
                    var fromR:CGFloat=0, fromG:CGFloat=0, fromB:CGFloat=0, fromA:CGFloat=0
                    style.cell_textColor.getRed(&fromR, green: &fromG, blue: &fromB, alpha: &fromA)
                    var toR:CGFloat=0, toG:CGFloat=0, toB:CGFloat=0, toA:CGFloat=0
                    style.cell_textHighlightColor.getRed(&toR, green: &toG, blue: &toB, alpha: &toA)
                    let color = UIColor(red: fromR+(toR-fromR)*progress, green: fromG+(toG-fromG)*progress, blue: fromB+(toB-fromB)*progress, alpha: fromA+(toA-fromA)*progress)
                    self.label.textColor = color
                }
            }
            if animationDuration > 0 {
                UIView.transition(with: self.label, duration: animationDuration,options: .transitionCrossDissolve, animations: updateClosure)
            }else {
                updateClosure()
            }

        }

        open override func prepareForReuse() {
            super.prepareForReuse()
            self.label.textColor = self.style?.cell_textColor
            self.label.font = self.style?.cell_font
            self.label.text = nil
        }

        open override var intrinsicContentSize: CGSize {
            let labelSize: CGSize = self.label.intrinsicContentSize
            var width: CGFloat = labelSize.width + (self.style?.cellContentHorizontalInset ?? 0)*2
            if width < 32 {
                width = 32
            }
            let height: CGFloat = labelSize.height
            return CGSize(width: width, height: height)
        }

        open override func sizeThatFits(_ size: CGSize) -> CGSize {
            return self.intrinsicContentSize
        }

        open override func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
            return self.intrinsicContentSize
        }

        open override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
            return self.intrinsicContentSize
        }

        open override func layoutSubviews() {
            super.layoutSubviews()
            let size: CGSize = self.label.intrinsicContentSize
            let x: CGFloat = self.contentView.bounds.midX - size.width/2
            let y: CGFloat = self.contentView.bounds.midY - size.height/2
            self.label.frame = CGRect(x: x, y: y, width: size.width, height: size.height)
        }
    }

}