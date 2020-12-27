//
//  HHScanTool.h
//  HHScan
//
//  Created by Henry on 2020/12/22.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HHScanTool : NSObject

/// 打开手电筒
+ (void)openFlashlight;
/// 关闭手电筒
+ (void)closeFlashlight;

/// 根据设备方向调整视频方向
+ (AVCaptureVideoOrientation)videoOrientation;

+ (void)alert:(NSString *)title vc:(UIViewController *)vc;

+ (NSString *)cameraMessageTip;

+ (void)videoAuthorization:(UIViewController *)vc block:(void (^)(NSString *result))block;

+ (void)photoAuthorization:(UIViewController *)vc block:(void (^)(NSString *result))block;


/// 识别图片二维码
+ (void)recognizeImage:(UIImage *)image block:(void(^)(NSString * _Nullable str))block;

@end

NS_ASSUME_NONNULL_END
