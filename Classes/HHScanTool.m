//
//  HHScanTool.m
//  HHScan
//
//  Created by Henry on 2020/12/22.
//

#import "HHScanTool.h"
#import <Photos/PHPhotoLibrary.h>

@implementation HHScanTool

/// 打开手电筒
+ (void)openFlashlight {
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error = nil;
    if ([captureDevice hasTorch]) {
        BOOL locked = [captureDevice lockForConfiguration:&error];
        if (locked) {
            captureDevice.torchMode = AVCaptureTorchModeOn;
            [captureDevice unlockForConfiguration];
        }
    }
}

/// 关闭手电筒
+ (void)closeFlashlight {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if ([device hasTorch]) {
        [device lockForConfiguration:nil];
        [device setTorchMode: AVCaptureTorchModeOff];
        [device unlockForConfiguration];
    }
}

+ (AVCaptureVideoOrientation)videoOrientation {
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    switch (orientation) {
        case UIDeviceOrientationPortrait: {
            return AVCaptureVideoOrientationPortrait;
        }
            break;
        case UIDeviceOrientationLandscapeRight : {
            return AVCaptureVideoOrientationLandscapeLeft;
        }
            break;
        case UIDeviceOrientationLandscapeLeft: {
            return AVCaptureVideoOrientationLandscapeRight;
            
        }
            break;
        case UIDeviceOrientationPortraitUpsideDown: {
            return AVCaptureVideoOrientationPortraitUpsideDown;
            
        }
            break;
        default:
            return AVCaptureVideoOrientationPortrait;
            break;
    }
    
    return AVCaptureVideoOrientationPortrait;
}

+ (void)alert:(NSString *)title vc:(UIViewController *)vc {
    UIAlertController *alertC = [UIAlertController alertControllerWithTitle:@"提示" message:@"由于系统原因, 无法访问相机" preferredStyle:(UIAlertControllerStyleAlert)];
    UIAlertAction *alertA = [UIAlertAction actionWithTitle:@"确定" style:(UIAlertActionStyleDefault) handler:^(UIAlertAction * _Nonnull action) {
        
    }];
    [alertC addAction:alertA];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [vc presentViewController:alertC animated:YES completion:nil];
    });

}

+ (NSString *)cameraMessageTip {
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    NSString *app_Name = [infoDict objectForKey:@"CFBundleDisplayName"];
    if (app_Name == nil) {
        app_Name = [infoDict objectForKey:@"CFBundleName"];
    }
    NSString *messageString = [NSString stringWithFormat:@"[前往：设置 - 隐私 - 相机 - %@] 允许应用访问", app_Name];
    return messageString;
}

+ (NSString *)photoMessageTip {
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    NSString *app_Name = [infoDict objectForKey:@"CFBundleDisplayName"];
    if (app_Name == nil) {
        app_Name = [infoDict objectForKey:@"CFBundleName"];
    }
    NSString *messageString = [NSString stringWithFormat:@"[前往：设置 - 隐私 - 照片 - %@] 允许应用访问", app_Name];
    return messageString;
}

+ (void)videoAuthorization:(UIViewController *)vc block:(void (^)(NSString * _Nonnull))block {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (!device) {
        // 未检测到您的摄像头, 请在真机上测试
        [HHScanTool alert:@"未检测到您的摄像头, 请在真机上测试" vc:vc];
        return;
    }
    
    // 判断授权状态
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (authStatus == AVAuthorizationStatusRestricted) {
        [HHScanTool alert:@"由于系统原因, 无法访问相机" vc:vc];
    } else if (authStatus == AVAuthorizationStatusDenied) { // 用户拒绝当前应用访问相机
        [HHScanTool alert:[HHScanTool cameraMessageTip] vc:vc];
    } else if (authStatus == AVAuthorizationStatusAuthorized) { // 用户允许当前应用访问相机
        block(@"");
    } else if (authStatus == AVAuthorizationStatusNotDetermined) {
        // 用户还没有做出选择
        // 弹框请求用户授权
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            if (granted) {
                // 这里是在block里面操作UI，因此需要回到主线程里面去才能操作UI
                dispatch_async(dispatch_get_main_queue(), ^{
                   // 回到主线程里面就不会出现延时几秒之后才执行UI操作
                   // do you work
                   block(@"");
                });
            } else {
                // 拒绝
            }
        }];
    }
}

+ (void)photoAuthorization:(UIViewController *)vc block:(void (^)(NSString * _Nonnull))block {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (!device) {
        [HHScanTool alert:@"无相册" vc:vc];
        return;
    }
    
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusNotDetermined) { // 用户还没有做出选择
        // 弹框请求用户授权
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            if (status == PHAuthorizationStatusAuthorized) { // 用户第一次同意了访问相册权限
                dispatch_sync(dispatch_get_main_queue(), ^{
                    block(@"");
                });
            } else { // 用户第一次拒绝了访问相机权限
                
            }
        }];
    } else if (status == PHAuthorizationStatusAuthorized) { // 用户允许当前应用访问相册
        block(@"");
    } else if (status == PHAuthorizationStatusDenied) { // 用户拒绝当前应用访问相册
        [HHScanTool photoMessageTip];
    } else if (status == PHAuthorizationStatusRestricted) {
        [HHScanTool alert:@"由于系统原因, 无法访问相册" vc:vc];
    }

}


+ (void)recognizeImage:(UIImage *)image block:(void (^)(NSString * _Nullable))block {
    // 创建 CIDetector，并设定识别类型：CIDetectorTypeQRCode
    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:@{CIDetectorAccuracy: CIDetectorAccuracyHigh}];
    // 获取识别结果
    NSArray *features = [detector featuresInImage:[CIImage imageWithCGImage:image.CGImage]];
    
    if (features.count == 0) {
        if (block) {
            block(nil);
        }
    } else {
        CIQRCodeFeature *feature = features.firstObject;
        NSString *resultStr = feature.messageString;
        
        if (block) {
            block(resultStr);
        }
    }

}

@end
