//
//  AppDelegate.m
//  ProfileManager
//
//  Created by Taylan Pince on 2015-10-01.
//  Copyright © 2015 Hipo. All rights reserved.
//

#import "AppDelegate.h"

#import "PMWindowController.h"


@interface AppDelegate ()

@property (nonatomic, strong) PMWindowController *mainWindowController;

@end


@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    _mainWindowController = [[PMWindowController alloc] initWithWindowNibName:@"PMWindowController"];
    
    [_mainWindowController showWindow:nil];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
