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

@property (nonatomic, weak) IBOutlet NSArrayController *contentController;
@property (nonatomic, weak) IBOutlet NSTableView *tableView;
@property (nonatomic, weak) IBOutlet NSButton *deleteButton;
@property (nonatomic, weak) IBOutlet NSButton *reloadButton;
@property (nonatomic, weak) IBOutlet NSSearchField *searchField;

@property (nonatomic, strong) NSMutableArray *profiles;
@property (nonatomic, strong) NSArray *sortDescriptors;
@property (nonatomic, strong) NSPredicate *searchPredicateTemplate;

- (void)loadProfiles;
- (void)reloadAllProfiles;
- (NSURL *)getLibraryDirectoryURL;
- (NSDictionary *)parseMobileProvisionFileAtURL:(NSURL *)fileURL;

- (IBAction)didTapDeleteButton:(id)sender;
- (IBAction)didTapReloadButton:(id)sender;
- (IBAction)didChangeSearchKeywods:(id)sender;

@end


@implementation PMWindowController

- (instancetype)initWithWindowNibName:(NSString *)windowNibName {
    self = [super initWithWindowNibName:windowNibName];
    
    if (self) {
        _profiles = [NSMutableArray array];
        _searchPredicateTemplate = [NSPredicate predicateWithFormat:
                                    @"(name contains[cd] $searchString) or "
                                    "(appName contains[cd] $searchString) or "
                                    "(bundleIdentifier contains[cd] $searchString)"];
    }
    
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    [_deleteButton setEnabled:NO];
    
    [_contentController addObserver:self
                         forKeyPath:@"selectedObjects"
                            options:0
                            context:nil];
    
    [self reloadAllProfiles];
}

#pragma mark - Observables

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSString *,id> *)change
                       context:(void *)context {
    
    if (object == _contentController) {
        NSArray *selectedObjects = [_contentController selectedObjects];
        
        [_deleteButton setEnabled:(selectedObjects.count > 0)];
    }
}

#pragma mark - Sorting

- (NSArray *)sortDescriptors {
    return _tableView.sortDescriptors;
}

#pragma mark - Loading

- (void)reloadAllProfiles {
    [_reloadButton setEnabled:NO];
    
    [_contentController removeObjects:_contentController.arrangedObjects];
    
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
    
    NSMutableArray *profiles = [NSMutableArray array];
    
    for (NSURL *fileURL in enumerator) {
        NSString *fileName;
        
        [fileURL getResourceValue:&fileName forKey:NSURLNameKey error:NULL];
        
        NSDictionary *profileData = [self parseMobileProvisionFileAtURL:fileURL];
        PMProfile *profile = [[PMProfile alloc] initWithProvisionInfo:profileData
                                                              fileURL:fileURL];
        
        [profiles addObject:profile];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [_contentController addObjects:profiles];

        [_tableView setSortDescriptors:@[[_tableView.tableColumns[0] sortDescriptorPrototype]]];
        
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

- (void)didChangeSearchKeywods:(id)sender {
    NSString *searchString = [_searchField stringValue];
    NSPredicate *predicate = nil;
    
    if (searchString.length > 0) {
        predicate = [_searchPredicateTemplate
                     predicateWithSubstitutionVariables:@{@"searchString": searchString}];
    }
    
    [_contentController setFilterPredicate:predicate];
}

- (void)didTapDeleteButton:(id)sender {
    NSArray *selectedObjects = [_contentController selectedObjects];

    if (selectedObjects.count == 0) {
        return;
    }
    
    for (PMProfile *profile in selectedObjects) {
        if ([[NSFileManager defaultManager] removeItemAtURL:profile.fileURL error:nil]) {
            [_contentController removeObject:profile];
        } else {
            // TODO: Show error
            NSLog(@">>> FAILED TO DELETE: %@", profile.bundleIdentifier);
        }
    }
    
    [_deleteButton setEnabled:NO];
}

- (void)didTapReloadButton:(id)sender {
    [self reloadAllProfiles];
}

@end
