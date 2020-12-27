//
//  HHScanManager.m
//  HHScan
//
//  Created by Henry on 2020/12/22.
//

#import "HHScanManager.h"
#import "HHScanTool.h"

@interface HHScanManager () <AVCaptureMetadataOutputObjectsDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *videoPreviewLayer;

@end

@implementation HHScanManager

static HHScanManager *_instance;

+ (instancetype)sharedManager {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[HHScanManager alloc] init];
    });
    return _instance;
}

- (void)setupSessionPreset:(NSString *)sessionPreset metadataObjectTypes:(NSArray *)metadataObjectTypes currentController:(UIViewController *)currentController {
    
    if (sessionPreset == nil) {
        @throw [NSException exceptionWithName:@"HHScan" reason:@"setupSessionPreset:metadataObjectTypes:currentController: 方法中的 sessionPreset 参数不能为空" userInfo:nil];
    }
    
    if (metadataObjectTypes == nil) {
        @throw [NSException exceptionWithName:@"HHScan" reason:@"setupSessionPreset:metadataObjectTypes:currentController: 方法中的 metadataObjectTypes 参数不能为空" userInfo:nil];
    }
    
    if (currentController == nil) {
        @throw [NSException exceptionWithName:@"HHScan" reason:@"setupSessionPreset:metadataObjectTypes:currentController: 方法中的 currentController 参数不能为空" userInfo:nil];
    }
    
    // 1、获取摄像设备
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    // 2、创建摄像设备输入流
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
    
    // 3、创建元数据输出流
    AVCaptureMetadataOutput *metadataOutput = [[AVCaptureMetadataOutput alloc] init];
    [metadataOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    
    // 3(1)、创建摄像数据输出流
    self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [_videoDataOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    // 设置扫描范围（每一个取值0～1，以屏幕右上角为坐标原点）
    // 注：微信二维码的扫描范围是整个屏幕，这里并没有做处理（可不用设置）;
    // 如需限制扫描框范围，打开下一句注释代码并进行相应调整
//    metadataOutput.rectOfInterest = CGRectMake(0.05, 0.2, 0.7, 0.6);
    
    // 4、创建会话对象
    _session = [[AVCaptureSession alloc] init];
    // 会话采集率: AVCaptureSessionPresetHigh
    _session.sessionPreset = sessionPreset;
    
    // 5、添加元数据输出流到会话对象
    [_session addOutput:metadataOutput];
    // 5(1)添加摄像输出流到会话对象；与 3(1) 构成识了别光线强弱
    [_session addOutput:_videoDataOutput];

    // 6、添加摄像设备输入流到会话对象
    [_session addInput:deviceInput];

    // 7、设置数据输出类型，需要将数据输出添加到会话后，才能指定元数据类型，否则会报错
    // 设置扫码支持的编码格式(如下设置条形码和二维码兼容)
    // @[AVMetadataObjectTypeQRCode, AVMetadataObjectTypeEAN13Code,  AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode128Code]
    metadataOutput.metadataObjectTypes = metadataObjectTypes;
    
    // 8、实例化预览图层, 传递_session是为了告诉图层将来显示什么内容
    _videoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:_session];
    // 保持纵横比；填充层边界
    _videoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    _videoPreviewLayer.frame = currentController.view.bounds;
    _videoPreviewLayer.connection.videoOrientation = [HHScanTool videoOrientation];

    [currentController.view.layer insertSublayer:_videoPreviewLayer atIndex:0];
    
    // 9、启动会话
    [_session startRunning];
}

- (void)startRunning {
    [_session startRunning];
}

- (void)stopRunning {
    [_session stopRunning];
}

- (BOOL)isRunning {
    return _session && _session.running;
}

- (void)updateVideoPreview:(CGRect)frame {
    _videoPreviewLayer.frame = frame;
}

- (void)updateVideoOrientation {
    _videoPreviewLayer.connection.videoOrientation = [HHScanTool videoOrientation];
}

- (void)setVideoOrientation:(AVCaptureVideoOrientation)videoOrientation {
    _videoPreviewLayer.connection.videoOrientation = videoOrientation;
}

- (AVMetadataMachineReadableCodeObject *)getCodeObject:(id)obj {
    AVMetadataMachineReadableCodeObject *code = (AVMetadataMachineReadableCodeObject *)
    [_videoPreviewLayer transformedMetadataObjectForMetadataObject:obj];
    return code;
}

- (void)playSound {
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *impactLight = [[UIImpactFeedbackGenerator alloc]initWithStyle:UIImpactFeedbackStyleLight];
        [impactLight impactOccurred];
    } else {
        AudioServicesPlaySystemSound(1519);//私有api
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);//震动太大
    }
}

- (void)playSoundName:(NSString *)name {
    NSString *audioFile = [[NSBundle mainBundle] pathForResource:name ofType:nil];
    NSURL *fileUrl = [NSURL fileURLWithPath:audioFile];
    
    SystemSoundID soundID = 0;
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)(fileUrl), &soundID);
    AudioServicesAddSystemSoundCompletion(soundID, NULL, NULL, hhScanSoundCompleteCallback, NULL);
    AudioServicesPlaySystemSound(soundID); // 播放音效
}

void hhScanSoundCompleteCallback(SystemSoundID soundID, void *clientData){

}

- (void)videoPreviewLayerRemoveFromSuperlayer {
    [_videoPreviewLayer removeFromSuperlayer];
}

- (void)resetSampleBufferDelegate {
    [_videoDataOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
}

- (void)cancelSampleBufferDelegate {
    [_videoDataOutput setSampleBufferDelegate:nil queue:dispatch_get_main_queue()];
}

#pragma mark - AVCaptureMetadataOutputObjectsDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    NSLog(@"metadataObjects: %@", metadataObjects);
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(scanManager:didOutputMetadataObjects:)]) {
        [self.delegate scanManager:self didOutputMetadataObjects:metadataObjects];
    }
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate的方法

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    // 这个方法会时时调用，但内存很稳定
    CFDictionaryRef metadataDict = CMCopyDictionaryOfAttachments(NULL,sampleBuffer, kCMAttachmentMode_ShouldPropagate);
    NSDictionary *metadata = [[NSMutableDictionary alloc] initWithDictionary:(__bridge NSDictionary*)metadataDict];
    CFRelease(metadataDict);
    NSDictionary *exifMetadata = [[metadata objectForKey:(NSString *)kCGImagePropertyExifDictionary] mutableCopy];
    float brightnessValue = [[exifMetadata objectForKey:(NSString *)kCGImagePropertyExifBrightnessValue] floatValue];
        
    if (self.delegate && [self.delegate respondsToSelector:@selector(scanManager:brightnessValue:)]) {
        [self.delegate scanManager:self brightnessValue:brightnessValue];
    }
}


@end
