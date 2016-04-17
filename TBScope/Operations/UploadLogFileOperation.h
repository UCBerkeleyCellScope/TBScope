//
//  UploadLogFileOperation.h
//  TBScope
//
//  Created by Jason Ardell on 4/2/16.
//  Copyright © 2016 UC Berkeley Fletcher Lab. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UploadLogFileOperation : NSOperation
@property (atomic, assign) BOOL _executing;
@property (atomic, assign) BOOL _finished;
@end
