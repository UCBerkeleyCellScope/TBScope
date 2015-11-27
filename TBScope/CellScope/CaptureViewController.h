//
//  CaptureViewController.h
//  CellScope
//
//  Created by Frankie Myers on 11/7/13.
//  Copyright (c) 2013 UC Berkeley Fletcher Lab. All rights reserved.
//
//  Includes functionality for both manual and automatic image capture. If manual mode is specified in the settings, a full set of controls will be presented for moving the stage/focus, adjusting illumination, and taking photos (up to the maximum number of photos specified in the settings). If automatic mode is specified, this view automatically takes pictures across the full slide, autofocusing and autoexposing as it goes. It displays a progress bar indicating scan progress.

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <ImageIO/ImageIO.h>
#import "TBScopeData.h"
#import "TBScopeHardware.h"

#import "CameraScrollView.h"
#import "AnalysisViewController.h"

@interface CaptureViewController : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate, TBScopeHardwareDelegate>


@property (strong,nonatomic) Slides* currentSlide;


@property (weak, nonatomic) IBOutlet CameraScrollView* previewView;
@property (weak, nonatomic) IBOutlet UIButton* snapButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem* analyzeButton;
@property (weak, nonatomic) IBOutlet UINavigationItem* navItem;

@property (strong, nonatomic) NSTimer* holdTimer;


@property (weak, nonatomic) IBOutlet UIButton *bfButton;
@property (weak, nonatomic) IBOutlet UIButton *flButton;

@property (weak, nonatomic) IBOutlet UIView *controlPanelView;
@property (weak, nonatomic) IBOutlet UIButton *leftButton;
@property (weak, nonatomic) IBOutlet UIButton *downButton;
@property (weak, nonatomic) IBOutlet UIButton *rightButton;
@property (weak, nonatomic) IBOutlet UIButton *upButton;
@property (weak, nonatomic) IBOutlet UIButton *autoFocusButton;
@property (weak, nonatomic) IBOutlet UIButton *autoScanButton;
@property (weak, nonatomic) IBOutlet UILabel *scanStatusLabel;
@property (weak, nonatomic) IBOutlet UIButton *abortButton;
@property (weak, nonatomic) IBOutlet UIButton *refocusButton;

@property (weak, nonatomic) IBOutlet UISlider *intensitySlider;
@property (weak, nonatomic) IBOutlet UILabel *intensityLabel;

@property (weak, nonatomic) IBOutlet UIButton *manualScanFocusUp;
@property (weak, nonatomic) IBOutlet UIButton *manualScanFocusOk;
@property (weak, nonatomic) IBOutlet UIButton *manualScanFocusDown;
@property (weak, nonatomic) IBOutlet UIButton *moveHomeButton;
@property (weak, nonatomic) IBOutlet UIButton *moveCenterButton;
@property (weak, nonatomic) IBOutlet UIButton *setCenterButton;

@property (weak, nonatomic) IBOutlet UILabel *coordinateLabel;

@property (weak, nonatomic) IBOutlet UIButton *fastSlowButton;

@property (weak, nonatomic) IBOutlet UIProgressView *autoScanProgressBar;

@property (nonatomic) int currentField;

//TODO: this should all go in microscope automation model class
@property (nonatomic) CSStageDirection currentDirection; //TODO: handle backlashing
@property (nonatomic) CSStageSpeed currentSpeed;

- (IBAction)didPressCapture:(id)sender;

- (void)saveImageCallback;

- (IBAction)didTouchDownStageButton:(id)sender;
- (IBAction)didTouchUpStageButton:(id)sender;

- (IBAction)didPressAutoFocus:(id)sender;
- (IBAction)didPressAutoScan:(id)sender;
- (IBAction)didPressStressTest:(id)sender;

- (IBAction)didPressAbort:(id)sender;
- (IBAction)didPressManualFocus:(id)sender;
- (IBAction)didPressFastSlow:(id)sender;

- (IBAction)didPressManualFocusOk:(id)sender;

- (IBAction)didPressMoveHome:(id)sender;
- (IBAction)didPressMoveCenter:(id)sender;
- (IBAction)didPressSetCenter:(id)sender;

- (void) updateCoordinateLabel;

- (void) autoscanWithCols:(int)numCols
                     Rows:(int)numRows
       stepsBetweenFields:(long)stepsBetween
            focusInterval:(int)focusInterval
              bfIntensity:(int)bfIntensity
              flIntensity:(int)flIntensity;


@end
