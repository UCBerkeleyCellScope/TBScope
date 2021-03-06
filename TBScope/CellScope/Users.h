//
//  Users.h
//  TBScope
//
//  Created by Frankie Myers on 2/18/14.
//  Copyright (c) 2014 UC Berkeley Fletcher Lab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Users : NSManagedObject

@property (nonatomic, retain) NSString * accessLevel;
@property (nonatomic, retain) NSString * password;
@property (nonatomic, retain) NSString * username;

@end
