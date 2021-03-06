//
//  AppDelegate.h
//  CellScope
//
//  Created by UC Berkeley Fletcher Lab on 8/19/12.
//  Copyright (c) 2012 UC Berkeley Fletcher Lab. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LoginViewController.h"
#include "ClassifierGlobals.h"
#import "Users.h"
#import "Slides.h"
#import "Images.h"


@interface CSAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) dispatch_block_t expirationHandler;
@property (assign, nonatomic) BOOL background;
@property (assign, nonatomic) BOOL jobExpired;

- (void)keepAlive;
//- (NSURL *)applicationDocumentsDirectory;

@end
