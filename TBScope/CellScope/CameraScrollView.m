//
//  CameraScrollView.m
//  CellScope
//
//  Created by Frankie Myers on 11/7/13.
//  Copyright (c) 2013 UC Berkeley Fletcher Lab. All rights reserved.
//

#import "CameraScrollView.h"
#import "TBScopeCamera.h"
#import "TBScopeHardware.h"

@implementation CameraScrollView

@synthesize previewLayerView;
@synthesize imageRotation;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        [self setBouncesZoom:NO];
        [self setBounces:NO];
        [self setScrollEnabled:YES];
        [self setMaximumZoomScale:10.0];
        
        [self setShowsHorizontalScrollIndicator:YES];
        [self setShowsVerticalScrollIndicator:YES];
        [self setIndicatorStyle:UIScrollViewIndicatorStyleWhite];
        
        //[[TBScopeCamera sharedCamera] setExposureLock:NO];
        //[[TBScopeCamera sharedCamera] setFocusLock:NO];
    }
    return self;
}

- (void)setUpPreview
{
    [[TBScopeCamera sharedCamera] setUpCamera];

    // Setup image preview layer
    CGRect frame = CGRectMake(0, 0, 2592, 1936); //TODO: grab the resolution from the camera?
    previewLayerView = [[UIView alloc] initWithFrame:frame];
    CALayer *viewLayer = previewLayerView.layer;
    AVCaptureVideoPreviewLayer *captureVideoPreviewLayer = [[TBScopeCamera sharedCamera] captureVideoPreviewLayer];
    captureVideoPreviewLayer.frame = viewLayer.bounds;
    captureVideoPreviewLayer.orientation = AVCaptureVideoOrientationLandscapeLeft;
    [viewLayer addSublayer:captureVideoPreviewLayer];
    [self addSubview:previewLayerView];
    [self setContentSize:frame.size];
    [self setDelegate:self];
    [self zoomExtents];
    
    // If we're debugging, add a label to display image quality metrics
    self.imageQualityLabel = [[UILabel alloc] init];
    [self addSubview:self.imageQualityLabel];
    [self.imageQualityLabel setBounds:CGRectMake(0,0,500,500)];
    [self.imageQualityLabel setCenter:CGPointMake(400, 80)];
    self.imageQualityLabel.textColor = [UIColor whiteColor];
    self.imageQualityLabel.font = [UIFont fontWithName:@"Courier" size:14.0];
    [self bringSubviewToFront:self.imageQualityLabel];
    self.imageQualityLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.imageQualityLabel.numberOfLines = 0;
    self.imageQualityLabel.hidden = ![[NSUserDefaults standardUserDefaults] boolForKey:@"DebugMode"];

    int WINDOW_HEIGHT = 705;
    int BUTTON_LEFT = 112;
    int BUTTON_BOTTOM = 10;
    int BUTTON_WIDTH = 150;
    int BUTTON_HEIGHT = 50;
    int BUTTON_MARGIN_RIGHT = 10;

    // If we're debugging add a button for testing drift
    self.testDriftButton = [[UIButton alloc] init];
    [self addSubview:self.testDriftButton];
    [self.testDriftButton setBounds:CGRectMake(0, 0, BUTTON_WIDTH, BUTTON_HEIGHT)];
    [self.testDriftButton setCenter:CGPointMake(BUTTON_LEFT+BUTTON_WIDTH/2.0, WINDOW_HEIGHT-BUTTON_BOTTOM-BUTTON_HEIGHT/2.0)];
    [self.testDriftButton setTitle:@"Test Drift" forState:UIControlStateNormal];
    [self.testDriftButton setBackgroundColor:[UIColor blueColor]];
    [self.testDriftButton addTarget:self action:@selector(testDrift:) forControlEvents:UIControlEventTouchUpInside];
    [self bringSubviewToFront:self.testDriftButton];
    self.testDriftButton.hidden = ![[NSUserDefaults standardUserDefaults] boolForKey:@"DebugMode"];
    
    // If we're debugging add button for testing backlash
    self.testBacklashButton = [[UIButton alloc] init];
    [self addSubview:self.testBacklashButton];
    [self.testBacklashButton setBounds:CGRectMake(0, 0, BUTTON_WIDTH, BUTTON_HEIGHT)];
    [self.testBacklashButton setCenter:CGPointMake(BUTTON_LEFT+BUTTON_WIDTH*3.0/2.0+BUTTON_MARGIN_RIGHT, WINDOW_HEIGHT-BUTTON_BOTTOM-BUTTON_HEIGHT/2.0)];
    [self.testBacklashButton setTitle:@"Test Backlash" forState:UIControlStateNormal];
    [self.testBacklashButton setBackgroundColor:[UIColor blueColor]];
    [self.testBacklashButton addTarget:self action:@selector(testBacklash:) forControlEvents:UIControlEventTouchUpInside];
    [self bringSubviewToFront:self.testBacklashButton];
    self.testBacklashButton.hidden = ![[NSUserDefaults standardUserDefaults] boolForKey:@"DebugMode"];
    
    //TODO: are these necessary?
    [previewLayerView setNeedsDisplay];
    [self setNeedsDisplay];

    // Listen for ImageQuality updates
    __weak CameraScrollView *weakSelf = self;
    [[NSNotificationCenter defaultCenter] addObserverForName:@"ImageQualityReportReceived"
              object:nil
               queue:[NSOperationQueue mainQueue]
          usingBlock:^(NSNotification *notification) {
              NSValue *iqAsObject = notification.userInfo[@"ImageQuality"];
              ImageQuality iq;
              [iqAsObject getValue:&iq];
              NSString *text = [NSString stringWithFormat:@"\n"
                  "sharpness:  %@ (%3.3f)\n"
                  "contrast:   %@ (%3.3f)\n"
                  "boundryScr: %@ (%3.3f)\n"
                  "isBoundary:  %@\n"
                  "isEmpty:     %@\n\n",
                  [@"" stringByPaddingToLength:(int)MIN(80, (MAX(0.0f, iq.tenengrad3)/14.375)) withString: @"|" startingAtIndex:0],
                  iq.tenengrad3,
                  [@"" stringByPaddingToLength:(int)MIN(80, (MAX(0.0f, iq.greenContrast)/0.0875)) withString: @"|" startingAtIndex:0],
                  iq.greenContrast,
                  [@"" stringByPaddingToLength:(int)MIN(80, (MAX(0.0f, iq.boundaryScore)/10.0)) withString: @"|" startingAtIndex:0],
                  iq.boundaryScore,
                  iq.isBoundary?@"YES":@"NO",
                  iq.isEmpty?@"YES":@"NO"
              ];
              dispatch_async(dispatch_get_main_queue(), ^{
                  // NSLog(@"Image quality report: %@", text);
                  [weakSelf.imageQualityLabel setText:text];
              });
          }
    ];
}

- (IBAction)testDrift:(id)sender
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        // Total steps is 100,000 = (10 iterations) * (50 slices up + 50 slices down) * (100 steps/slice)
        int NUM_ITERATIONS  = 10;
        int NUM_SLICES      = 50;  // 50 up + 50 down = 100 total
        int STEPS_PER_SLICE = 100;

        id<TBScopeHardwareDriver> sharedHardware = [TBScopeHardware sharedHardware];
        for (int iteration = 0; iteration < NUM_ITERATIONS; iteration++) {
            // 1) Move up K steps
            for (int sliceUp=0; sliceUp < NUM_SLICES; sliceUp++) {
                [sharedHardware moveStageWithDirection:CSStageDirectionFocusUp
                                                 Steps:STEPS_PER_SLICE
                                           StopOnLimit:YES
                                          DisableAfter:YES];
                [sharedHardware waitForStage];
            }

            // 2) Move down K steps
            for (int sliceDown=0; sliceDown < NUM_SLICES; sliceDown++) {
                [sharedHardware moveStageWithDirection:CSStageDirectionFocusDown
                                                 Steps:STEPS_PER_SLICE
                                           StopOnLimit:YES
                                          DisableAfter:YES];
                [sharedHardware waitForStage];
            }

            NSLog(@"Finished drift test iteration %d (out of %d).", iteration+1, NUM_ITERATIONS);
            [NSThread sleepForTimeInterval:1.0];
        }

        NSLog(@"Finished drift test.");
    });
}

- (IBAction)testBacklash:(id)sender
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        int NUM_STEPS = 500;
        id<TBScopeHardwareDriver> sharedHardware = [TBScopeHardware sharedHardware];

        // Move up NUM_STEPS steps
        [sharedHardware moveStageWithDirection:CSStageDirectionFocusUp
                                         Steps:NUM_STEPS
                                   StopOnLimit:YES
                                  DisableAfter:YES];
        [sharedHardware waitForStage];

        // Move down NUM_STEPS steps
        [sharedHardware moveStageWithDirection:CSStageDirectionFocusDown
                                         Steps:NUM_STEPS
                                   StopOnLimit:YES
                                  DisableAfter:YES];
        [sharedHardware waitForStage];

        NSLog(@"Finished backlash test.");
    });
}

- (void)takeDownCamera
{
    [self.previewLayerView removeFromSuperview];
    [self.previewLayerView.layer removeFromSuperlayer];
    self.previewLayerView = nil;
    [[TBScopeCamera sharedCamera] takeDownCamera];
}



- (void) zoomExtents
{
    float horizZoom = self.bounds.size.width / previewLayerView.bounds.size.width;
    float vertZoom = self.bounds.size.height / previewLayerView.bounds.size.height;
    
    float zoomFactor = MIN(horizZoom,vertZoom);
    
    [self setMinimumZoomScale:zoomFactor];
    
    [self setZoomScale:zoomFactor animated:YES];
    
}

- (void) grabImage
{
    [[TBScopeCamera sharedCamera] captureImage];  // TODO: add a completion block instead of processing it up the chain?

    //TODO: now update the field with the captured image and stop preview mode
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return previewLayerView;
}


@end
