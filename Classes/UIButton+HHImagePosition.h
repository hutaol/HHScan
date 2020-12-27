//
//  UIButton+HHImagePosition.h
//  HHScan
//
//  Created by Henry on 2020/12/24.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, HHImagePosition) {
    HHImagePositionLeft = 0,              // 图片在左，文字在右，默认
    HHImagePositionRight = 1,             // 图片在右，文字在左
    HHImagePositionTop = 2,               // 图片在上，文字在下
    HHImagePositionBottom = 3,            // 图片在下，文字在上
};

@interface UIButton (HHImagePosition)

/// 利用 UIButton 的 titleEdgeInsets 和 imageEdgeInsets 来实现文字和图片的自由排列
/// 注意：这个方法需要在设置图片和文字之后才可以调用，且 button 的大小要大于 图片大小+文字大小+spacing
/// @param postion HHImagePosition
/// @param spacing 图片和文字的间隔
- (void)hh_setImagePosition:(HHImagePosition)postion spacing:(CGFloat)spacing;

@end

NS_ASSUME_NONNULL_END
