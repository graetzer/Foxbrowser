//
//  FXSyncStock.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 24.09.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import "FXSyncStock.h"
#import "FXUserAuth.h"
#import "FXSyncEngine.h"
#import "FXSyncStore.h"

NSString *const kFXDataChangedNotification = @"kFXDataChangedNotification";
NSString *const kFXErrorNotification = @"kFXErrorNotification";

@implementation FXSyncStock

+ (instancetype)sharedInstance {
    static FXSyncStock *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[FXSyncStock alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _syncEngine = [FXSyncEngine new];
        _syncEngine.delegate = self;
        _syncEngine.userAuth = [[FXUserAuth alloc] initEmail:@"simon@graetzer.org"
                                                    password:@"foochic923"];
    }
    return self;
}

- (void)_prefetchCollection:(NSString *)cName {
    [[FXSyncStore sharedInstance] loadCollection:cName
                                        callback:^(NSArray *arr) {
                                            if ([kFXBookmarksCollectionKey isEqualToString:cName]) {
                                                _bookmarks = arr;
                                            } else if ([kFXHistoryCollectionKey isEqualToString:cName]) {
                                                _history = arr;
                                            } else if ([kFXTabsCollectionKey isEqualToString:cName]) {
                                                NSPredicate *pred = [NSPredicate predicateWithFormat:@"syncId != %@", _syncEngine.clientID];
                                                _clientTabs = [arr filteredArrayUsingPredicate:pred];
                                            }
                                            
                                            [[NSNotificationCenter defaultCenter]
                                             postNotificationName:kFXDataChangedNotification
                                             object:self];
                                        }];
}

#pragma mar

#pragma mark - FXSyncEngineDelegate

- (void)syncEngine:(FXSyncEngine *)engine didLoadCollection:(NSString *)cName {
    [self _prefetchCollection:cName];
    
}

- (void)syncEngine:(FXSyncEngine *)engine didFailWithError:(NSError *)error {
    
}

- (void)syncEngine:(FXSyncEngine *)engine alertWithString:(NSString *)alert {
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Warning", nil)
                                                        message:alert
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", @"ok")
                                              otherButtonTitles:nil];
    [alertView show];
}

#pragma mark - Methods

- (void)restock {
    [_syncEngine startSync];
}

- (BOOL)hasCredentials {
    return YES;
}

- (void)loginUser:(NSString *)user password:(NSString *)pass completion:(void(^)(void))block {
    
}

- (void)setLocalTabs:(NSArray *)tabs {
    FXSyncItem *item = [FXSyncItem new];
    item.collection = kFXTabsCollectionKey;
    item.syncId = _syncEngine.clientID;
    
    item.jsonPayload = [@{@"id" : item.syncId,
                         @"clientName":_syncEngine.clientName,
                         @"tabs":tabs} mutableCopy];
    [item save];
}

- (NSArray *)localTabs {
    __block NSArray *clients;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [[FXSyncStore sharedInstance] loadCollection:kFXTabsCollectionKey
                                        callback:^(NSArray *arr) {
                                            clients = arr;
                                            dispatch_semaphore_signal(sem);
                                        }];
    // Block until the block execution finishes
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    
    NSString *myID = _syncEngine.clientID;
    for (FXSyncItem *item in clients) {
        if ([item.syncId isEqualToString:myID]) {
            return [item tabs];
        }
    }
    return nil;
}

- (NSArray *)topBookmarkFolders {
    // parentid of menu, mobile and toolbar is 'places'
    return [self bookmarksWithParent:@"places"];
}

- (NSArray *)bookmarksWithParent:(NSString *)parentId {
    NSArray *supportedTypes = @[@"bookmark", @"folder", @"livemark"];
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:20];
    for (FXSyncItem *mark in _bookmarks) {
        if (![mark deleted]
            && [[mark parentid] isEqualToString:parentId]
            && [supportedTypes containsObject:[mark type]]) {
            [result addObject:mark];
        }
    }
    return result;
}

- (NSArray *)bookmarksWithParentFolder:(FXSyncItem *)folder {
    NSArray *children = folder.jsonPayload[@"children"];
    
    NSArray *marks = [self bookmarksWithParent:folder.syncId];
    return [marks sortedArrayUsingComparator:^(id obj1, id obj2) {
        NSInteger idx1 = [children indexOfObject:[obj1 syncId]];
        NSInteger idx2 = [children indexOfObject:[obj2 syncId]];
        return idx2 - idx1 > 0 ? NSOrderedAscending : NSOrderedDescending;
    }];
}

- (void)deleteBookmark:(FXSyncItem *)bookmark; {
    if ([[bookmark type] isEqualToString:@"folder"]) {
        NSArray *children = bookmark.jsonPayload[@"children"];
        for (NSString *syncId in children) {
            [[FXSyncStore sharedInstance] loadItem:syncId
                                    fromCollection:bookmark.collection
                                          callback:^(FXSyncItem *item) {
                                              [self deleteBookmark:item];
                                          }];
        }
    }
    [bookmark deleteItem];
    _bookmarks = nil;
}

@end

