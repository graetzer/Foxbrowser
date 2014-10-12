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
#include "UICKeyChainStore.h"

NSString *const kFXDataChangedNotification = @"kFXDataChangedNotification";
NSString *const kFXErrorNotification = @"kFXErrorNotification";

@implementation FXSyncStock {
    NSMutableArray *_bookmarks;
}
@synthesize history = _history, clientTabs = _clientTabs;

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
        _syncEngine.userAuth = [FXUserAuth new];
        [self _unarchiveKeys];
    }
    return self;
}

- (void)_prefetchCollection:(NSString *)cName {
    [[FXSyncStore sharedInstance] loadCollection:cName
                                        callback:^(NSMutableArray *arr) {
                                            if ([kFXBookmarksCollectionKey isEqualToString:cName]) {
                                                _bookmarks = arr;
                                            } else if ([kFXHistoryCollectionKey isEqualToString:cName]) {
                                                _history = arr;
                                            } else if ([kFXTabsCollectionKey isEqualToString:cName]) {
                                                NSPredicate *pred = [NSPredicate predicateWithFormat:
                                                                     @"syncId != %@", _syncEngine.clientID];
                                                _clientTabs = [arr filteredArrayUsingPredicate:pred];
                                            }
                                            
                                            [[NSNotificationCenter defaultCenter]
                                             postNotificationName:kFXDataChangedNotification
                                             object:self];
                                        }];
}

- (void)_unarchiveKeys {
    NSData *data = [UICKeyChainStore dataForKey:@"accountCreds"];
    if (data != nil) {
        _syncEngine.userAuth.accountCreds = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        
        data = [UICKeyChainStore dataForKey:@"accountKeys"];
        if (data != nil) {
            _syncEngine.userAuth.accountKeys = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        }
    }
}

- (void)_archiveKeys {
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:
                    _syncEngine.userAuth.accountCreds];
    if (data != nil) {
        [UICKeyChainStore setData:data forKey:@"accountCreds"];
        
        data = [NSKeyedArchiver archivedDataWithRootObject:
                _syncEngine.userAuth.accountKeys];
        if (data != nil) {
            [UICKeyChainStore setData:data forKey:@"accountKeys"];
        }
    }
}

#pragma mark - Properties;

- (NSArray *)bookmarks {
    if (_bookmarks == nil) {
        [self _prefetchCollection:kFXBookmarksCollectionKey];
    }
    return _bookmarks;
}

- (NSArray *)history {
    if (_history == nil) {
        [self _prefetchCollection:kFXHistoryCollectionKey];
    }
    return _history;
}

- (NSArray *)clientTabs {
    if (_clientTabs == nil) {
        [self _prefetchCollection:kFXTabsCollectionKey];
    }
    return _clientTabs;
}

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
    if ([self hasUserCredentials]) {
        [_syncEngine startSync];
    }
}

- (BOOL)hasUserCredentials {
    return _syncEngine.userAuth != nil
    && _syncEngine.userAuth.accountCreds != nil
    && _syncEngine.userAuth.accountKeys != nil;
}

- (void)loginEmail:(NSString *)email
         password:(NSString *)pass
       completion:(void(^)(BOOL))block {
    NSParameterAssert(email && pass && block);
    
    [_syncEngine.userAuth signInFetchKeysEmail:email
                                      password:pass
                           completion:^(BOOL success) {
                               if (success) {
                                   [self _archiveKeys];
                               }
                               block(success);
                           }];
}

- (void)logout {
    
}

#pragma mark - Tabs

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

#pragma mark - Bookmarks

- (NSArray *)topBookmarkFolders {
    if ([_bookmarks count] > 0) {
        // parentid of menu, mobile and toolbar is 'places'
        return [self bookmarksWithParent:@"places"];
    } else {
        // Workaround for 
        FXSyncItem *toolbar = [FXSyncItem new];
        toolbar.syncId = @"toolbar";
        toolbar.jsonPayload = [NSMutableDictionary new];
        [toolbar setType:@"folder"];
        [toolbar setTitle:NSLocalizedString(@"Bookmarks Toolbar", @"bookmarks toolbar")];
        
        FXSyncItem *unfiled = [FXSyncItem new];
        unfiled.syncId = @"unfiled";
        unfiled.jsonPayload = [NSMutableDictionary new];
        [unfiled setType:@"folder"];
        [unfiled setTitle:NSLocalizedString(@"Unsorted Bookmarks", @"unsorted bookmarks")];
        
        return @[toolbar, unfiled];
    }
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
            [[FXSyncStore sharedInstance] loadSyncId:syncId
                                      fromCollection:bookmark.collection
                                            callback:^(FXSyncItem *item) {
                                              [self deleteBookmark:item];
                                            }];
        }
    }
    [bookmark deleteItem];
    [_bookmarks removeObject:bookmark];
}

- (FXSyncItem *)bookmarkWithTitle:(NSString *)title url:(NSURL *)url; {
    NSParameterAssert(title && url);
    
    FXSyncItem *item = [FXSyncItem new];
    item.syncId = RandomString(12);
    item.collection = kFXBookmarksCollectionKey;
    item.sortindex = 100;
    item.jsonPayload = [@{@"id":item.syncId,
                          @"title":title,
                          @"bmkUri":[NSString stringWithFormat:@"%@", url],
                          @"type":@"bookmark",
                          @"parentid":@"unfiled",
                          @"parentName":NSLocalizedString(@"Unsorted Bookmarks",
                                                          @"unsorted bookmarks")
                          } mutableCopy];
    [item save];
    [_bookmarks addObject:item];
    
    // Add it to the chikdren subarray
    [[FXSyncStore sharedInstance] loadSyncId:@"unfiled"
                              fromCollection:kFXBookmarksCollectionKey
                                    callback:^(FXSyncItem *unfiled) {
                                        [unfiled addChild:item.syncId];
                                    }];
    
    return item;
}

- (FXSyncItem *)folderWithParent:(FXSyncItem *)folder; {
    FXSyncItem *item = [self bookmarkWithTitle:NSLocalizedString(@"New Folder",
                                                                 @"Create a new folder")
                                           url:[NSURL URLWithString:@"about:blank"]];
    [item setType:@"folder"];
    [item.jsonPayload removeObjectForKey:@"bmkUri"];
    [item save];
    return item;
}

@end

