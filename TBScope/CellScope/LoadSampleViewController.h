//
//  LoadSampleViewController.h
//  TBScope
//
//  Created by Frankie Myers on 11/10/13.
//  Copyright (c) 2013 UC Berkeley Fletcher Lab. All rights reserved.
//
//  Displays a video instructing the user on how to prepare and insert the sample into the instrument.

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import "TBScopeData.h"
#import "TBScopeHardware.h"

#import "CaptureViewController.h"

#define EJECT_SLIDE 1

@interface LoadSampleViewController : UIViewController

@property (strong, nonatomic) Slides* currentSlide;

@property (weak, nonatomic) IBOutlet UIView *videoView;

@property (nonatomic) BOOL doAnalysis;

@property (strong, nonatomic) MPMoviePlayerController* moviePlayer;

@property (weak, nonatomic) IBOutlet UILabel *promptLabel;
@property (weak, nonatomic) IBOutlet UILabel *directionsLabel;

@end
