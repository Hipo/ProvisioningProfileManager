//
//  PMProfile.m
//  ProfileManager
//
//  Created by Taylan Pince on 2015-10-01.
//  Copyright © 2015 Hipo. All rights reserved.
//

#import "PMProfile.h"


@implementation PMProfile

- (instancetype)initWithProvisionInfo:(NSDictionary *)provisionInfo
                              fileURL:(NSURL *)fileURL {

    self = [super init];
    
    if (self == nil) {
        return nil;
    }
    
    _fileURL = [fileURL copy];
    _name = provisionInfo[@"Name"];
    _teamName = provisionInfo[@"TeamName"];
    _appName = provisionInfo[@"AppIDName"];
    _creationDate = provisionInfo[@"CreationDate"];
    _formattedCreationDate = [NSDateFormatter localizedStringFromDate:_creationDate
                                                            dateStyle:NSDateFormatterMediumStyle
                                                            timeStyle:NSDateFormatterNoStyle];

    NSString *appIdentifier = provisionInfo[@"Entitlements"][@"application-identifier"];
    
    if (appIdentifier) {
        NSArray *appIdentifierParts = [appIdentifier componentsSeparatedByString:@"."];
        
        appIdentifier = [[appIdentifierParts subarrayWithRange:NSMakeRange(1, appIdentifierParts.count - 1)]
                         componentsJoinedByString:@"."];
        
        _bundleIdentifier = appIdentifier;
    }
    
    _teamIdentifier = provisionInfo[@"Entitlements"][@"com.apple.developer.team-identifier"];
    
    return self;
}

@end
