//
//  PMProfile.h
//  ProfileManager
//
//  Created by Taylan Pince on 2015-10-01.
//  Copyright © 2015 Hipo. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface PMProfile : NSObject

@property (nonatomic, strong, readonly) NSString *name;
@property (nonatomic, strong, readonly) NSString *teamName;
@property (nonatomic, strong, readonly) NSString *appName;
@property (nonatomic, strong, readonly) NSString *bundleIdentifier;
@property (nonatomic, strong, readonly) NSString *teamIdentifier;
@property (nonatomic, strong, readonly) NSDate *creationDate;
@property (nonatomic, strong, readonly) NSURL *fileURL;

- (instancetype)initWithProvisionInfo:(NSDictionary *)provisionInfo
                              fileURL:(NSURL *)fileURL;

@end
