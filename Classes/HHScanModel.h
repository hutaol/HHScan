//
//  HHScanModel.h
//  HHScan
//
//  Created by Henry on 2020/12/13.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HHScanModel : NSObject

@property (nonatomic, strong) UIView *codeView;
@property (nonatomic, copy) NSString *codeString;

@end

NS_ASSUME_NONNULL_END
