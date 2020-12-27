//
//  HHScanViewController.m
//  HHScan
//
//  Created by Henry on 2020/12/13.
//

#import "HHScanViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import "HHScanModel.h"
#import "HHScanManager.h"
#import "HHScanTool.h"
#import "UIButton+HHImagePosition.h"

/** 扫描内容的 W 值 */
#define scanBorderW 0.9 * self.view.frame.size.width
/** 扫描内容的 x 值 */
#define scanBorderX 0.5 * (1 - 0.9) * self.view.frame.size.width
/** 扫描内容的 Y 值 */
#define scanBorderY 0.2 * self.view.frame.size.height

@interface HHScanViewController () <HHScanManagerDelegate>
{
    NSMutableArray <HHScanModel*> * _layerArr;
    BOOL hasEntered; // 首次进入，addTimer那不执行startsession操作，不然容易和初始化的start重复导致多次start
}

@property (nonatomic, strong) UIImageView *scanningline;
@property (nonatomic, strong) NSTimer *timer;
/** 扫描线动画时间，默认 0.02s */
@property (nonatomic, assign) NSTimeInterval animationTimeInterval;

@property (nonatomic, strong) HHScanManager *manager;

@property (nonatomic, strong) UILabel *tipLabel;
@property (nonatomic, strong) UIButton *flashlightBtn;
@property (nonatomic, assign) BOOL isSelectedFlashlightBtn;

@property (nonatomic, strong) UIButton *backBtn;

@property (nonatomic, strong) UIButton *photoBtn;
@property (nonatomic, strong) UIButton *myCodeBtn;

@end

@implementation HHScanViewController

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self addTimer];
    [_manager resetSampleBufferDelegate];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self removeTimer];
    [_manager cancelSampleBufferDelegate];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    
    //前后台监听
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];

    [self initData];
    [self initUI];

    [HHScanTool videoAuthorization:self block:^(NSString * _Nonnull result) {
        [self setupScanning];
    }];
}

// 前台
- (void)didBecomeActive {
    [self addTimer];
}

// 后台
- (void)didEnterBackground {
    [self removeTimer];
}

- (void)initData {
    self.animationTimeInterval = 0.02;
    _layerArr = [[NSMutableArray alloc] init];
}

- (void)initUI {
    [self.view addSubview:self.backBtn];
    [self.view addSubview:self.tipLabel];
    self.showPhoto = YES;
    self.showMyCode = YES;
}

- (void)setupScanning {
    self.manager = [HHScanManager sharedManager];
    NSArray *arr = @[AVMetadataObjectTypeQRCode, AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode128Code];
    // AVCaptureSessionPreset1920x1080 推荐使用，对于小型的二维码读取率较高
    [_manager setupSessionPreset:AVCaptureSessionPreset1920x1080 metadataObjectTypes:arr currentController:self];
    _manager.delegate = self;
}

#pragma mark - HHScanManagerDelegate

- (void)scanManager:(HHScanManager *)scanManager didOutputMetadataObjects:(NSArray *)metadataObjects {
    NSLog(@"metadataObjects: %@", metadataObjects);
    if (metadataObjects != nil && metadataObjects.count > 0) {
        [self removeTimer];
        [scanManager playSound];
        
        UIView *maskView = [self getMaskViewWithTips:metadataObjects.count > 1];
        maskView.alpha = 0;
        [self.view addSubview:maskView];
        [UIView animateWithDuration:0.6 animations:^{
            maskView.alpha = 1;
        }];
        
        HHScanModel *barInfo = [[HHScanModel alloc] init];
        barInfo.codeView = maskView;
        barInfo.codeString = @"";
        [_layerArr addObject:barInfo];
        
        [metadataObjects enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            
            AVMetadataMachineReadableCodeObject *code = [scanManager getCodeObject:obj];
            
            UIButton *codeBtn = [self getCodeButtonWith:code.bounds withIcon:metadataObjects.count > 1];
            codeBtn.tag = idx+1;
            [self.view addSubview:codeBtn];
            
            HHScanModel *barInfo = [[HHScanModel alloc] init];
            barInfo.codeView = codeBtn;
            barInfo.codeString = code.stringValue;
            [_layerArr addObject:barInfo];
            
        }];
        
        _backBtn.hidden = YES;

        if (metadataObjects.count == 1) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                HHScanModel *barInfo = self->_layerArr[1];
                NSLog(@"%@",barInfo.codeString);
                [self processWithResult:barInfo.codeString];
            });
        }
    } else {
        NSLog(@"暂未识别出扫描的二维码");
    }

}

- (void)scanManager:(HHScanManager *)scanManager brightnessValue:(CGFloat)brightnessValue {
    if (brightnessValue < - 1) {
        [self.view addSubview:self.flashlightBtn];
    } else {
        if (self.isSelectedFlashlightBtn == NO) {
            [self removeFlashlightBtn];
        }
    }
}

#pragma mark - action
// 关闭扫描页面
- (void)close {
    if ([_manager isRunning]) {
        [_manager stopRunning];
    }
    if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

// 取消扫码结果
- (void)cancel {
    if ([_manager isRunning]) {
        [_manager stopRunning];
    }
    [_layerArr enumerateObjectsUsingBlock:^(HHScanModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj.codeView removeFromSuperview];
    }];
    [_layerArr removeAllObjects];
    if (![_manager isRunning]) {
        [self addTimer];
    }
    _backBtn.hidden = NO;
}

//点击扫描到的二维码跳转
- (void)clickCurrentCode:(UIButton *)btn {
    HHScanModel *barInfo = _layerArr[btn.tag];
    NSLog(@"%@", barInfo.codeString);
    [self processWithResult:barInfo.codeString];
}

- (void)processWithResult:(NSString *)resultStr {
    if (self.resultBlock) {
        self.resultBlock(resultStr);
    }
    
    if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (CAKeyframeAnimation *)getAnimation {
    CAKeyframeAnimation * ani = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
    ani.duration = 2.5;
    ani.removedOnCompletion = NO;
    ani.repeatCount = HUGE_VALF;
    ani.fillMode = kCAFillModeForwards;
    ani.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    NSValue *value1 = [NSNumber numberWithFloat:1.0];
    NSValue *value2 = [NSNumber numberWithFloat:0.8];
    ani.values = @[value1, value2, value1, value2, value1, value1, value1, value1];
    return ani;
}

- (UIButton *)getCodeButtonWith:(CGRect)bounds withIcon:(BOOL)icon {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = bounds;
    btn.backgroundColor = [UIColor colorWithRed:54/255.0 green:85/255.0 blue:230/255.0 alpha:1.0];
    [btn addTarget:self action:@selector(clickCurrentCode:) forControlEvents:UIControlEventTouchUpInside];
    
    if (icon) {
        [btn setImage:[UIImage imageNamed:@"HHScan.bundle/scan_right"] forState:UIControlStateNormal];
        [btn.layer addAnimation:[self getAnimation] forKey:@"scale-layer"];
    }
    
    CGRect rect = btn.frame;
    CGPoint center = btn.center;
    rect.size.width = 40;
    rect.size.height = 40;
    btn.frame = rect;
    btn.center = center;
    btn.layer.cornerRadius = 20;
    btn.clipsToBounds = YES;
    btn.layer.borderColor = [UIColor whiteColor].CGColor;
    btn.layer.borderWidth = 3;
    return btn;
}

- (UIView *)getMaskViewWithTips:(BOOL)showTips {
    UIView *maskView = [[UIView alloc] initWithFrame:self.view.bounds];
    maskView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.6];

    if (showTips) {
        UIButton *cancel = [UIButton buttonWithType:UIButtonTypeCustom];
        cancel.frame = CGRectMake(15, 20, 50, 44);
        [cancel setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [cancel setTitle:@"取消" forState:UIControlStateNormal];
        [cancel addTarget:self action:@selector(cancel) forControlEvents:UIControlEventTouchUpInside];
        [maskView addSubview:cancel];
        
        UILabel *tipsLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, self.view.bounds.size.height-64-50, self.view.bounds.size.width-40, 50)];
        tipsLabel.text = @"轻触小蓝点，选中识别二维码";
        tipsLabel.font  = [UIFont boldSystemFontOfSize:14];
        tipsLabel.textAlignment = NSTextAlignmentCenter;
        tipsLabel.textColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:0.6];
        [maskView addSubview:tipsLabel];
    }
    
    return maskView;
}


#pragma mark - - - 添加定时器
- (void)addTimer {
    if (![_manager isRunning] && hasEntered) {
        [_manager startRunning];
    }
    hasEntered = YES;
    CGFloat scanninglineX = 0;
    CGFloat scanninglineY = 0;
    CGFloat scanninglineW = 0;
    CGFloat scanninglineH = 0;
    [self.view addSubview:self.scanningline];
    scanninglineW = scanBorderW;
    scanninglineH = 12;
    scanninglineX = scanBorderX;
    scanninglineY = scanBorderY;
    _scanningline.frame = CGRectMake(scanninglineX, scanninglineY, scanninglineW, scanninglineH);
    _scanningline.hidden = YES;
    self.timer = [NSTimer timerWithTimeInterval:self.animationTimeInterval target:self selector:@selector(beginRefreshUI) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
}

#pragma mark - 移除定时器

- (void)removeTimer {
    if (self.timer) {
        [self.timer invalidate];
        self.timer = nil;
    }
    if (_scanningline) {
        [_scanningline removeFromSuperview];
        _scanningline = nil;
    }
    if ([_manager isRunning]) {
        [_manager stopRunning];
    }
}

#pragma mark - 执行定时器方法

- (void)beginRefreshUI {
    // 防止还没开始执行定时器就扫描到码，导致扫描动画一直进行
    if (![_manager isRunning]) {
        [self removeTimer];
    }
    _scanningline.hidden = NO;
    __block CGRect frame = _scanningline.frame;
    static BOOL flag = YES;
    
    __weak typeof(self) weakSelf = self;

    if (flag) {
        frame.origin.y = scanBorderY;
        flag = NO;
        [UIView animateWithDuration:self.animationTimeInterval animations:^{
            frame.origin.y += 2;
            weakSelf.scanningline.frame = frame;
        } completion:nil];
    } else {
        if (_scanningline.frame.origin.y >= scanBorderY) {
            CGFloat scanContent_MaxY = self.view.frame.size.height - scanBorderY * 2;
            if (_scanningline.frame.origin.y >= scanContent_MaxY - 10) {
                frame.origin.y = scanBorderY;
                weakSelf.scanningline.frame = frame;
                flag = YES;
            } else {
                [UIView animateWithDuration:self.animationTimeInterval animations:^{
                    frame.origin.y += 3;
                    weakSelf.scanningline.frame = frame;
                } completion:nil];
            }
        } else {
            flag = !flag;
        }
    }
}

#pragma mark - set/get

- (UIImageView *)scanningline {
    if (!_scanningline) {
        _scanningline = [[UIImageView alloc] init];
        _scanningline.image = [UIImage imageNamed:@"HHScan.bundle/QRCodeScanningLine"];
    }
    return _scanningline;
}


- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    NSLog(@"viewWillTransitionToSize");
    
    [_manager updateVideoOrientation];
    [_manager updateVideoPreview:CGRectMake(0, 0, size.width, size.height)];
    [self updateUI:size];
}

- (void)updateUI:(CGSize)size {
    self.tipLabel.frame = CGRectMake(20, size.height-200, size.width-40, 50);
    if (self.flashlightBtn.hidden == NO) {
        CGRect flashFrame = self.flashlightBtn.frame;
        flashFrame.origin.x = 0.5 * (size.width - flashFrame.size.width);
        flashFrame.origin.y = size.height-150;
        _flashlightBtn.frame = flashFrame;
    }
    
}

- (void)onClickFlashlight:(UIButton *)button {
    if (button.selected == NO) {
        [HHScanTool openFlashlight];
        self.isSelectedFlashlightBtn = YES;
        button.selected = YES;
    } else {
        [self removeFlashlightBtn];
    }
}

- (void)removeFlashlightBtn {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [HHScanTool closeFlashlight];
        self.isSelectedFlashlightBtn = NO;
        self.flashlightBtn.selected = NO;
        [self.flashlightBtn removeFromSuperview];
    });
}

// 去相册
- (void)onClickPhoto {
    
}

// 去我的二维码
- (void)onClickMyCode {
    
}

#pragma mark - Setters

- (void)setShowPhoto:(BOOL)showPhoto {
    if (showPhoto) {
        [self.view addSubview:self.photoBtn];
    } else {
        [self.photoBtn removeFromSuperview];
    }
}

- (void)setShowMyCode:(BOOL)showMyCode {
    if (showMyCode) {
        [self.view addSubview:self.myCodeBtn];
    } else {
        [self.photoBtn removeFromSuperview];
    }
}

#pragma mark - Getters

- (UILabel *)tipLabel {
    if (!_tipLabel) {
        _tipLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, self.view.frame.size.height-200, self.view.bounds.size.width-40, 50)];
        _tipLabel.text = @"扫二维码/条形";
        _tipLabel.font  = [UIFont boldSystemFontOfSize:15];
        _tipLabel.textAlignment = NSTextAlignmentCenter;
        _tipLabel.textColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:0.7];
    }
    return _tipLabel;
}

#pragma mark - 闪光灯按钮
- (UIButton *)flashlightBtn {
    if (!_flashlightBtn) {
        // 添加闪光灯按钮
        _flashlightBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        CGFloat flashlightBtnW = 100;
        CGFloat flashlightBtnH = 100;
        CGFloat flashlightBtnX = 0.5 * (self.view.frame.size.width - flashlightBtnW);
        CGFloat flashlightBtnY = self.view.frame.size.height-150;
        _flashlightBtn.frame = CGRectMake(flashlightBtnX, flashlightBtnY, flashlightBtnW, flashlightBtnH);
        
        [_flashlightBtn addTarget:self action:@selector(onClickFlashlight:) forControlEvents:UIControlEventTouchUpInside];

        [_flashlightBtn setImage:[UIImage imageNamed:@"HHScan.bundle/flashlight_close"] forState:UIControlStateNormal];
        [_flashlightBtn setImage:[UIImage imageNamed:@"HHScan.bundle/flashlight_open"] forState:UIControlStateSelected];
        [_flashlightBtn setTitle:@"轻触照亮" forState:UIControlStateNormal];
        [_flashlightBtn setTitle:@"轻触关闭" forState:UIControlStateSelected];
        [_flashlightBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [_flashlightBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected];
        _flashlightBtn.titleLabel.font = [UIFont systemFontOfSize:13];
        
        [_flashlightBtn hh_setImagePosition:HHImagePositionTop spacing:5];

    }
    return _flashlightBtn;
}

- (UIButton *)backBtn {
    if (!_backBtn) {
        _backBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _backBtn.frame = CGRectMake(15, 20, 44, 44);
        [_backBtn setImage:[UIImage imageNamed:@"HHScan.bundle/scan_back"] forState:UIControlStateNormal];
        [_backBtn addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    }
    return _backBtn;
}

- (UIButton *)photoBtn {
    if (!_photoBtn) {
        _photoBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _photoBtn.frame = CGRectMake(self.view.frame.size.width - 70, self.view.frame.size.height - 120, 50, 50);
        [_photoBtn setImage:[UIImage imageNamed:@"HHScan.bundle/scan_phone"] forState:UIControlStateNormal];
        [_photoBtn addTarget:self action:@selector(onClickPhoto) forControlEvents:UIControlEventTouchUpInside];
        _photoBtn.layer.cornerRadius = 25;
        _photoBtn.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
        _photoBtn.imageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    return _photoBtn;
}

- (UIButton *)myCodeBtn {
    if (!_myCodeBtn) {
        _myCodeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _myCodeBtn.frame = CGRectMake(20, self.view.frame.size.height - 120, 50, 50);
        [_myCodeBtn setImage:[UIImage imageNamed:@"HHScan.bundle/scan_mycode"] forState:UIControlStateNormal];
        [_myCodeBtn addTarget:self action:@selector(onClickMyCode) forControlEvents:UIControlEventTouchUpInside];
        _myCodeBtn.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
        _myCodeBtn.imageView.contentMode = UIViewContentModeScaleAspectFit;
        _myCodeBtn.layer.cornerRadius = 25;

    }
    return _myCodeBtn;
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (BOOL)shouldAutorotate {
    if (_layerArr.count > 0) {
        return NO;
    }
    return YES;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    NSLog(@"释放了——————————————————————————————————————————-");
}

@end
