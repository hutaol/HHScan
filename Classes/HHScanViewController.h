//
//  HHScanViewController.h
//  HHScan
//
//  Created by Henry on 2020/12/13.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^ScanResultBlock)(NSString *scanResult);

@interface HHScanViewController : UIViewController

@property (nonatomic, copy) ScanResultBlock resultBlock;

@property (nonatomic, assign) BOOL showPhoto;
@property (nonatomic, assign) BOOL showMyCode;

/// 去相册
- (void)onClickPhoto;
/// 去我的二维码
- (void)onClickMyCode;

@end

NS_ASSUME_NONNULL_END
