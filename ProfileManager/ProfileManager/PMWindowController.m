//
//  PMWindowController.m
//  ProfileManager
//
//  Created by Taylan Pince on 2015-10-01.
//  Copyright © 2015 Hipo. All rights reserved.
//

#include <unistd.h>
#include <sys/types.h>
#include <pwd.h>

#import "PMWindowController.h"
#import "PMProfile.h"


static NSString * const PMProfileCellIdentifier = @"PMProfileCell";


@interface PMWindowController () <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, weak) IBOutlet NSTableView *tableView;
@property (nonatomic, weak) IBOutlet NSButton *deleteButton;
@property (nonatomic, weak) IBOutlet NSButton *reloadButton;

@property (nonatomic, strong) NSMutableArray *profiles;

- (void)loadProfiles;
- (void)reloadAllProfiles;
- (NSURL *)getLibraryDirectoryURL;
- (NSDictionary *)parseMobileProvisionFileAtURL:(NSURL *)fileURL;

- (IBAction)didTapDeleteButton:(id)sender;
- (IBAction)didTapReloadButton:(id)sender;

@end


@implementation PMWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    
    [_tableView setDelegate:self];
    [_tableView setDataSource:self];
    
    [_deleteButton setEnabled:NO];
    
    [self reloadAllProfiles];
}

#pragma mark - Table view data source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [_profiles count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    PMProfile *profile = _profiles[row];
    NSInteger columnIndex = [tableView.tableColumns indexOfObject:tableColumn];
    
    switch (columnIndex) {
        case 0:
            return profile.appName;
            break;
        case 1:
            return profile.teamName;
            break;
        case 2:
            return profile.bundleIdentifier;
            break;
        case 3:
            return [NSDateFormatter localizedStringFromDate:profile.creationDate
                                                  dateStyle:NSDateFormatterMediumStyle
                                                  timeStyle:NSDateFormatterNoStyle];
            break;
        default:
            return nil;
            break;
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger selectedRowIndex = [_tableView selectedRow];
    
    [_deleteButton setEnabled:(selectedRowIndex != NSNotFound)];
}

#pragma mark - Loading

- (void)reloadAllProfiles {
    [_reloadButton setEnabled:NO];
    
    [_profiles removeAllObjects];
    
    [_tableView reloadData];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self loadProfiles];
    });
}

- (void)loadProfiles {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *libraryDirectoryURL = [self getLibraryDirectoryURL];
    NSURL *profilesDirectoryURL = [libraryDirectoryURL URLByAppendingPathComponent:@"MobileDevice/Provisioning Profiles"];
    
    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtURL:profilesDirectoryURL
                                          includingPropertiesForKeys:@[NSURLNameKey]
                                                             options:NSDirectoryEnumerationSkipsHiddenFiles
                                                        errorHandler:nil];
    
    _profiles = [NSMutableArray array];
    
    for (NSURL *fileURL in enumerator) {
        NSString *fileName;
        
        [fileURL getResourceValue:&fileName forKey:NSURLNameKey error:NULL];
        
        NSDictionary *profileData = [self parseMobileProvisionFileAtURL:fileURL];
        PMProfile *profile = [[PMProfile alloc] initWithProvisionInfo:profileData
                                                              fileURL:fileURL];
        
        [_profiles addObject:profile];
    }
    
    [_profiles sortUsingComparator:^NSComparisonResult(PMProfile *obj1, PMProfile *obj2) {
        return [obj1.appName caseInsensitiveCompare:obj2.appName];
    }];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [_tableView reloadData];
        
        [_reloadButton setEnabled:YES];
    });
}

#pragma mark - Directory finder

- (NSURL *)getLibraryDirectoryURL {
    struct passwd *pw = getpwuid(getuid());
    
    NSString *realHomeDir = [NSString stringWithUTF8String:pw->pw_dir];
    NSString *documentsPath = [realHomeDir stringByAppendingPathComponent:@"Library"];
    
    return [NSURL fileURLWithPath:documentsPath];
}

#pragma mark - Provision parser

- (NSDictionary *)parseMobileProvisionFileAtURL:(NSURL *)fileURL {
    NSError *fetchError = nil;
    NSString *contents = [NSString stringWithContentsOfURL:fileURL
                                                  encoding:NSISOLatin1StringEncoding
                                                     error:&fetchError];
    
    if (fetchError) {
        NSLog(@"%@", [fetchError localizedDescription]);
        
        return nil;
    }
    
    NSScanner *scanner = [NSScanner scannerWithString:contents];
    
    if (![scanner scanUpToString:@"<plist" intoString:nil]) {
        NSLog(@"CANNOT FIND PLIST!");
        
        return nil;
    }
    
    NSString *plistString;
    
    if (![scanner scanUpToString:@"</plist>" intoString:&plistString]) {
        NSLog(@"CANNOT FIND END OF FILE");
        
        return nil;
    }
    
    plistString = [NSString stringWithFormat:@"%@</plist>", plistString];
    
    NSData *plistData = [plistString dataUsingEncoding:NSISOLatin1StringEncoding];
    
    NSError *parseError = nil;
    NSDictionary *profileData = [NSPropertyListSerialization propertyListWithData:plistData
                                                                          options:NSPropertyListImmutable
                                                                           format:nil
                                                                            error:&parseError];
    
    if (parseError) {
        NSLog(@"%@", [parseError localizedDescription]);
        
        return nil;
    }
    
    return profileData;
}

#pragma mark - Control actions

- (void)didTapDeleteButton:(id)sender {
    NSInteger selectedRowIndex = [_tableView selectedRow];

    if (selectedRowIndex == NSNotFound) {
        return;
    }
    
    PMProfile *profile = _profiles[selectedRowIndex];
    
    if ([[NSFileManager defaultManager] removeItemAtURL:profile.fileURL error:nil]) {
        [_profiles removeObject:profile];
        
        
        [_tableView beginUpdates];
        
        [_tableView removeRowsAtIndexes:[NSIndexSet indexSetWithIndex:selectedRowIndex]
                          withAnimation:NSTableViewAnimationEffectFade];
        
        [_tableView endUpdates];
        
        
        [_deleteButton setEnabled:NO];
    } else {
        // TODO: Show error
        NSLog(@">>> FAILED TO DELETE: %@", profile.bundleIdentifier);
    }
}

- (void)didTapReloadButton:(id)sender {
    [self reloadAllProfiles];
}

@end
