//
//  HHScanManager.h
//  HHScan
//
//  Created by Henry on 2020/12/22.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
@class HHScanManager;

NS_ASSUME_NONNULL_BEGIN

@protocol HHScanManagerDelegate <NSObject>

@required
/** 二维码扫描获取数据的回调方法 (metadataObjects: 扫描二维码数据信息) */
- (void)scanManager:(HHScanManager *)scanManager didOutputMetadataObjects:(NSArray *)metadataObjects;

@optional
/** 根据光线强弱值打开手电筒的方法 (brightnessValue: 光线强弱值) */
- (void)scanManager:(HHScanManager *)scanManager brightnessValue:(CGFloat)brightnessValue;

@end

@interface HHScanManager : NSObject

@property (nonatomic, weak) id<HHScanManagerDelegate> delegate;

+ (instancetype)sharedManager;

/// 创建扫描二维码会话对象以及会话采集数据类型和扫码支持的编码格式的设置，必须实现的方法
/// @param sessionPreset  会话采集数据类型
/// @param metadataObjectTypes 扫码支持的编码格式
/// @param currentController HHScanManager所在控制器
- (void)setupSessionPreset:(NSString *)sessionPreset metadataObjectTypes:(NSArray *)metadataObjectTypes currentController:(UIViewController *)currentController;

/// 开启会话对象扫描
- (void)startRunning;
/// 停止会话对象扫描
- (void)stopRunning;

- (BOOL)isRunning;

/// 更新布局
- (void)updateVideoPreview:(CGRect)frame;
/// 根据设备方向调整
- (void)updateVideoOrientation;
/// 设置方向
- (void)setVideoOrientation:(AVCaptureVideoOrientation)videoOrientation;

- (AVMetadataMachineReadableCodeObject *)getCodeObject:(id)obj;

/// 移除 videoPreviewLayer 对象
- (void)videoPreviewLayerRemoveFromSuperlayer;
/// 播放音效
- (void)playSound;
/// 播放音效文件
- (void)playSoundName:(NSString *)name;
/// 重置根据光线强弱值打开手电筒的 delegate 方法
- (void)resetSampleBufferDelegate;
/// 取消根据光线强弱值打开手电筒的 delegate 方法
- (void)cancelSampleBufferDelegate;

@end

NS_ASSUME_NONNULL_END
