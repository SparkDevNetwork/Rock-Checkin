/*
Licensed to the Apache Software Foundation (ASF) under one
or more contributor license agreements.  See the NOTICE file
distributed with this work for additional information
regarding copyright ownership.  The ASF licenses this file
to you under the Apache License, Version 2.0 (the
"License"); you may not use this file except in compliance
with the License.  You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing,
software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, either express or implied.  See the License for the
specific language governing permissions and limitations
under the License.
*/

//
//  CameraViewController.m
//  RockCheckin
//
//  Created by Daniel Hazelbaker on 1/18/20.
//

#import "CameraViewController.h"
#import "MainViewController.h"
#import "UIColor+HexString.h"
#import "ZebraPrint.h"
#import <AVFoundation/AVFoundation.h>

@interface CameraViewController () <AVCaptureMetadataOutputObjectsDelegate>

@property (weak, nonatomic) IBOutlet UIView *cameraView;
@property (weak, nonatomic) IBOutlet UIView *headerView;
@property (weak, nonatomic) IBOutlet UIView *printView;
@property (weak, nonatomic) IBOutlet UILabel *printErrorMessageLabel;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *targetWidthConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *targetHeightConstraint;

@property (strong, nonatomic) AVCaptureDevice *captureDevice;
@property (strong, nonatomic) AVCaptureSession *captureSession;
@property (strong, nonatomic) AVCaptureVideoPreviewLayer *previewLayer;
@property (strong, nonatomic) AVAudioPlayer *shutterSound;

@property (assign, nonatomic) BOOL autoStartCamera;
@property (assign, nonatomic) BOOL handlingSpecialCode;

@end

@implementation CameraViewController

#pragma mark View Controller Methods

/**
 Called when the view has been loaded and all outlets initialized.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //
    // Setup rounded corners on the cancel button.
    //
    self.cancelButton.layer.cornerRadius = 4;
    self.cancelButton.layer.masksToBounds = true;
    self.cancelButton.layer.borderWidth = 1;
    self.cancelButton.layer.borderColor = UIColor.whiteColor.CGColor;
    
    //
    // Set the size of the target overlay to be 66%.
    //
    [self setConstraint:self.targetWidthConstraint multiplier:0.66];
    [self setConstraint:self.targetHeightConstraint multiplier:0.66];
    
    //
    // Set the color of the button text and border.
    //
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *colorString = [defaults stringForKey:@"ui_foreground_color"];
    UIColor *color = [UIColor colorWithHexString:colorString];
    if (color != nil) {
        [self.cancelButton setTitleColor:color forState:UIControlStateNormal];
        self.cancelButton.layer.borderColor = color.CGColor;
    }

    //
    // Set the color of the header background.
    //
    colorString = [defaults stringForKey:@"ui_background_color"];
    color = [UIColor colorWithHexString:colorString];
    if (color != nil) {
        self.headerView.backgroundColor = color;
        self.view.backgroundColor =  color;
    }

    //
    // Do initialization on the camera device.
    //
    [self initializeCapture];
    [self setupCamera];
    
    NSURL *cameraSoundUrl = [NSURL fileURLWithPath:[NSBundle.mainBundle pathForResource:@"Camera" ofType:@"wav"]];
    self.shutterSound = [[AVAudioPlayer alloc] initWithContentsOfURL:cameraSoundUrl error:nil];
    self.shutterSound.volume = 0.5;
    
    [self.view setNeedsLayout];
}


/**
 Called when the view is about to appear on screen.
 
 @param animated Indicates if the view is going to be animated onto the screen.
 */
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self syncPreviewLayer];
}


/**
 Called when the view will transition to a new size, usually in response to a screen rotation.
 
 @param size The new size of the view.
 @param coordinator The transition animation coordinator for this operation.
 */
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        [self syncPreviewLayer];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
    }];
    
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}


/**
 Indicate to the system that we want the status bar to be hidden.
 */
- (BOOL)prefersStatusBarHidden
{
    return YES;
}


#pragma mark Methods

/**
 Modify a constraint's multiplier value by creating a new constraint and replacing the old one.
 
 @param constraint The constraint to be modified.
 @param multiplier The new multiplier value to use.
 @return The new constraint that has replaced the old one.
 */
- (NSLayoutConstraint *)setConstraint:(NSLayoutConstraint *)constraint multiplier:(CGFloat)multiplier
{
    [NSLayoutConstraint deactivateConstraints:@[constraint]];
    
    __auto_type newConstraint = [NSLayoutConstraint constraintWithItem:constraint.firstItem
                                                             attribute:constraint.firstAttribute
                                                             relatedBy:constraint.relation
                                                                toItem:constraint.secondItem
                                                             attribute:constraint.secondAttribute
                                                            multiplier:multiplier
                                                              constant:constraint.constant];
    
    newConstraint.priority = constraint.priority;
    newConstraint.shouldBeArchived = constraint.shouldBeArchived;
    newConstraint.identifier = constraint.identifier;
    
    [NSLayoutConstraint activateConstraints:@[newConstraint]];
    
    return newConstraint;
}


/**
Start the camera and begin watching for any barcodes.
*/
- (void)start
{
    if (self.captureDevice != nil) {
        self.handlingSpecialCode = NO;
        [self.captureSession startRunning];
    }
    else {
        self.autoStartCamera = YES;
    }
}


/**
Stop the camera and cease watching for barcodes.
*/
- (void)stop
{
    self.autoStartCamera = NO;
    if (self.captureDevice != nil) {
        [self.captureSession stopRunning];
    }
}


/**
 Synchronize the preview layer with our current size and screen orientation.
 */
- (void)syncPreviewLayer
{
    self.previewLayer.frame = self.cameraView.bounds;
    
    if (self.previewLayer.connection != nil && self.previewLayer.connection.isVideoOrientationSupported) {
        switch (UIApplication.sharedApplication.statusBarOrientation) {
            case UIInterfaceOrientationPortrait:
                self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
                break;
                
            case UIInterfaceOrientationLandscapeLeft:
                self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
                break;
                
            case UIInterfaceOrientationLandscapeRight:
                self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
                break;
                
            case UIInterfaceOrientationPortraitUpsideDown:
                self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
                break;
                
            default:
                self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
        }
    }
}


/**
 Initialize the capture session and preview layer.
 */
- (void)initializeCapture
{
    self.captureSession = [AVCaptureSession new];
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.previewLayer.frame = self.cameraView.bounds;
    
    [self.cameraView.layer insertSublayer:self.previewLayer below:self.cameraView.layer.sublayers.firstObject];
}


/**
 Setup the camera and prepare it to gather barcode data.
 */
- (void)setupCamera
{
    [self verifyCameraPermission:^(BOOL success) {
        AVCaptureDevice *device = nil;
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *position = [defaults stringForKey:@"camera_position"];
        float exposure = [defaults floatForKey:@"camera_exposure"];

        //
        // Open either the front or rear camera. Later we may want to add
        // additional options on the rear camera.
        //
        if ([position isEqualToString:@"front"]) {
            __auto_type *discoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionFront];
            if ( discoverySession.devices.count > 0) {
                device = discoverySession.devices.firstObject;
            }
        }
        else {
            __auto_type *discoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
            if ( discoverySession.devices.count > 0) {
                device = discoverySession.devices.firstObject;
            }
        }

        self.captureDevice = device;
        
        if (self.captureDevice != nil) {
            //
            // Add the device to our  capture session.
            //
            [self.captureSession beginConfiguration];
            if (self.captureSession.inputs.count > 0) {
                [self.captureSession removeInput:self.captureSession.inputs.firstObject];
            }
            [self.captureSession addInput:[AVCaptureDeviceInput deviceInputWithDevice:self.captureDevice error:nil]];
            [self.captureSession commitConfiguration];
        }
        
        //
        // Setup the output to monitor the camera for barcodes.
        //
        AVCaptureMetadataOutput *output = [AVCaptureMetadataOutput new];
        [self.captureSession addOutput:output];
        NSMutableArray *codeTypes = [NSMutableArray new];
        if ([output.availableMetadataObjectTypes containsObject:AVMetadataObjectTypeQRCode]) {
            [codeTypes addObject:AVMetadataObjectTypeQRCode];
        }
        if ([output.availableMetadataObjectTypes containsObject:AVMetadataObjectTypeCode128Code]) {
            [codeTypes addObject:AVMetadataObjectTypeCode128Code];
        }
        [output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
        output.metadataObjectTypes = codeTypes;
        
        [self setManualExposureLevel:exposure];
        
        self.previewLayer.session = self.captureSession;
        
        if (self.autoStartCamera) {
            self.autoStartCamera = NO;
            [self start];
        }
    }];
}


/**
 Verify that the user has granted us permission to use the camera.
 
 @param callback The function block that will be called when the user has responded to our request.
 */
- (void)verifyCameraPermission:(void (^)(BOOL))callback
{
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    switch (status) {
        case AVAuthorizationStatusAuthorized:
            callback(YES);
            break;

        case AVAuthorizationStatusNotDetermined:
        {
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo
                                     completionHandler:^(BOOL success) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    callback(success);
                });
            }];
            break;
        }
            
        default:
            callback(NO);
            break;
    }
}


/**
 Set the manual exposure level of the camera based on a calculated value.
 
 @param value The exposure level to use (0.0 - 1.0).
 */
- (void)setManualExposureLevel:(float)value
{
    value = MIN(1, MAX(0, value));

    if ([self.captureDevice lockForConfiguration:nil]) {
        if ([self.captureDevice isExposureModeSupported:AVCaptureExposureModeCustom]) {
            //
            // Set the duration to between 1/320 and 1/60.
            //
            float secondsBase = (240.0 * (1.0f - value)) + 60.0f;
            float seconds = (1.0 / secondsBase);

            //
            // Set the ISO to between 50 and 1600.
            //
            float iso = (1550 * value) + 50.0f;

            //
            // Ensure the duration is within valid range.
            //
            CMTime duration = CMTimeMakeWithSeconds(seconds, 1000*1000*1000);
            if (CMTimeCompare(duration, self.captureDevice.activeFormat.minExposureDuration) == -1) {
                duration = self.captureDevice.activeFormat.minExposureDuration;
            }
            else if (CMTimeCompare(duration, self.captureDevice.activeFormat.maxExposureDuration) == 1) {
                duration = self.captureDevice.activeFormat.maxExposureDuration;
            }

            //
            // Ensure the ISO is within valid range.
            //
            if (iso < self.captureDevice.activeFormat.minISO) {
                iso = self.captureDevice.activeFormat.minISO;
            }
            else if (iso > self.captureDevice.activeFormat.maxISO) {
                iso = self.captureDevice.activeFormat.maxISO;
            }

            [self.captureDevice setExposureModeCustomWithDuration:duration ISO:iso completionHandler:nil];
        }
        [self.captureDevice unlockForConfiguration];
    }
}


/**
 @param code The special code that was scanned.
 */
-  (void)processSpecialCode:(NSString *)code
{
    if (self.handlingSpecialCode) {
        return;
    }
    
    self.handlingSpecialCode = YES;

    //
    // If the code is a PreCheckinLabel code, then display our
    // "working" view and start printing in a background thread.
    //
    if ([code rangeOfString:@"PCL+"].location == 0) {
        NSDate *waitUntil = [NSDate dateWithTimeIntervalSinceNow:3];

        self.printErrorMessageLabel.hidden = YES;
        self.printView.hidden = NO;
            
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self.delegate cameraViewController:self
                          didScanPreCheckInCode:[code substringFromIndex:4]
                              completedCallback:^(NSString *errorMessage) {
                                  double waitForSeconds = [waitUntil timeIntervalSinceNow];
                                  if (waitForSeconds < 0) {
                                      waitForSeconds = 0;
                                  }
                                  
                                  //
                                  // If we got an error message, display it and ensure we wait
                                  // for at least 5 seconds.
                                  //
                                  if (errorMessage != nil) {
                                      dispatch_async(dispatch_get_main_queue(), ^{
                                          self.printErrorMessageLabel.text = errorMessage;
                                          self.printErrorMessageLabel.hidden = NO;
                                      });
                                      waitForSeconds = MAX(waitForSeconds, 5);
                                  }

                                  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(waitForSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                      self.printView.hidden = YES;
                                      self.printErrorMessageLabel.text = @"";
                                      self.printErrorMessageLabel.hidden = YES;
                                      self.handlingSpecialCode = NO;
                                  });
                              }];
        });
    }
    else {
        self.handlingSpecialCode = NO;
    }
}

/**
 Called when the user taps the cancel button.
 
 @param sender The button that send this message.
 */
- (IBAction)btnCancel:(id)sender
{
    [self.delegate cameraViewControllerDidCancel:self];
}


#pragma mark AVCaptureMetadataOutputObjectsDelegate

/**
 Called when the camera has detected one or more barcodes.
 
 @param output The destination of the capture session.
 @param metadataObjects Any barcodes that were detected.
 @param connection The capture connection.
 */
-(void)captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    if (metadataObjects.count == 0 || self.handlingSpecialCode == YES) {
        return;
    }

    //
    // Get the metadata object.
    //
    AVMetadataMachineReadableCodeObject *metadataObj = metadataObjects.firstObject;
    NSString *code = metadataObj.stringValue;

    if (code == nil) {
        return;
    }

    [self.shutterSound play];
    
    if ([code rangeOfString:@"PCL+"].location == 0) {
        [self processSpecialCode:code];
    }
    else if (self.delegate != nil) {
        [self.delegate cameraViewController:self didScanGenericCode:code];
    }
}

@end
