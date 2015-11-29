//
//  LoadSampleViewController.m
//  TBScope
//
//  Created by Frankie Myers on 11/10/13.
//  Copyright (c) 2013 UC Berkeley Fletcher Lab. All rights reserved.
//

#import "LoadSampleViewController.h"

@implementation LoadSampleViewController

@synthesize currentSlide,moviePlayer,videoView;

- (void) viewWillAppear:(BOOL)animated
{
    //localization
    self.navigationItem.title = NSLocalizedString(@"Load Sample Slide", nil);
    self.promptLabel.text = NSLocalizedString(@"Load the slide as shown below:", nil);
    [self.directionsLabel setText:NSLocalizedString(@"Wait for loading tray to come to a stop before inserting slide. Insert slide with sputum side up and gently push into machine. Click next. Slide will automatically load into position for image capture.", nil)];
    
    [TBScopeData CSLog:@"Load slide screen presented" inCategory:@"USER"];
}

- (void) viewDidAppear:(BOOL)animated
{
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DoAutoLoadSlide"]  && [self isMovingToParentViewController])
    {
        [self performSegueWithIdentifier:@"ScanSlideSegue" sender:self];
    }
    else
    {
        NSString *url   =   [[NSBundle mainBundle] pathForResource:@"slideloading" ofType:@"mp4"];
        
        moviePlayer = [[MPMoviePlayerController alloc] initWithContentURL:[NSURL fileURLWithPath:url]];
        
        moviePlayer.fullscreen = NO;
        moviePlayer.allowsAirPlay = NO;
        moviePlayer.controlStyle = MPMovieControlStyleNone;
        moviePlayer.scalingMode = MPMovieScalingModeAspectFill;
        moviePlayer.repeatMode = MPMovieRepeatModeOne;
        
        [moviePlayer.view setFrame:videoView.bounds];
        [videoView addSubview:moviePlayer.view];
        
        [moviePlayer play];

        //home z
        [[TBScopeHardware sharedHardware] moveToPosition:CSStagePositionZHome];
        
        //extend the tray
        [[TBScopeHardware sharedHardware] moveToPosition:CSStagePositionLoading];
        
        //draw tray in
        [[TBScopeHardware sharedHardware] moveToPosition:CSStagePositionHome];


    }


}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    CaptureViewController* cvc = (CaptureViewController*)[segue destinationViewController];
    cvc.currentSlide = self.currentSlide;
}

@end
