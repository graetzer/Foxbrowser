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
    NSMutableArray *_history;
}

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
        
        [self _prefetchCollection:kFXBookmarksCollectionKey];
        [self _prefetchCollection:kFXHistoryCollectionKey]; 
        [self _prefetchCollection:kFXTabsCollectionKey];
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
                                            
                                            dispatch_async(dispatch_get_main_queue(), ^{
                                                [[NSNotificationCenter defaultCenter]
                                                 postNotificationName:kFXDataChangedNotification
                                                 object:self];
                                            });
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
    [UICKeyChainStore setData:data forKey:@"accountCreds"];
    
    data = [NSKeyedArchiver archivedDataWithRootObject:
            _syncEngine.userAuth.accountKeys];
        [UICKeyChainStore setData:data forKey:@"accountKeys"];

    data = [NSKeyedArchiver archivedDataWithRootObject:
            _syncEngine.metaglobal];
    [UICKeyChainStore setData:data forKey:@"metaglobal"];
}

#pragma mark - Properties;

- (NSArray *)history {
    return _history;
}

- (NSArray *)bookmarks {
    return _bookmarks;
}

#pragma mark - FXSyncEngineDelegate

- (void)syncEngine:(FXSyncEngine *)engine didLoadCollection:(NSString *)cName {
    [self _prefetchCollection:cName];
}

- (void)syncEngine:(FXSyncEngine *)engine didFailWithError:(NSError *)error {
    
    NSString *alert = [error localizedDescription];
    NSString *reason = [error localizedFailureReason];
    if ([reason length] > 0) {
        alert = [alert stringByAppendingFormat:@"\n%@", reason];
    }
    if ([alert length] > 0) {
        [self syncEngine:engine alertWithString:alert];
    }
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
    [_syncEngine reset];
    [UICKeyChainStore removeAllItems];
    _syncEngine.userAuth.accountCreds = nil;
    _syncEngine.userAuth.accountKeys = nil;
}

#pragma mark - History

- (void)deleteHistoryItem:(FXSyncItem *)item; {
    [item deleteItem];
    [_history removeObject:item];
}

- (void)addHistoryURL:(NSURL *)url {
    NSParameterAssert(url);
    
    FXSyncItem *hist;
    NSString *urlS = url.absoluteString;
    for (FXSyncItem *item in _history) {
        if ([[item histUri] isEqualToString:urlS]) {
            hist = item;
            break;
            
        }
    }
    if (hist == nil) {
        hist = [FXSyncItem new];
        hist.syncId = RandomString(12);
        hist.collection = kFXHistoryCollectionKey;
        hist.sortindex = 100;
        hist.jsonPayload = [@{@"id":hist.syncId,
                              @"title":url.host,
                              @"histUri":[NSString stringWithFormat:@"%@", url]} mutableCopy];
        
    }
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    [hist addVisit:now type:2];
    [hist save];
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
    NSArray *result = [self bookmarksWithParent:@"places"];
    if ([result count] > 0) {
        // parentid of menu, mobile and toolbar is 'places'
        return result;
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
    // Mark as deleted
    [bookmark deleteItem];
    [_bookmarks removeObject:bookmark];
}

- (FXSyncItem *)newBookmarkWithTitle:(NSString *)title url:(NSURL *)url; {
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

- (FXSyncItem *)newFolderWithParent:(FXSyncItem *)folder; {
    FXSyncItem *item = [self newBookmarkWithTitle:NSLocalizedString(@"New Folder",
                                                                 @"Create a new folder")
                                           url:[NSURL URLWithString:@"about:blank"]];
    [item setType:@"folder"];
    [item.jsonPayload removeObjectForKey:@"bmkUri"];
    [item save];
    return item;
}

/*! Can be used to determine if an url should be bookmarked  */
- (FXSyncItem *)bookmarkForUrl:(NSURL *)url; {
    NSString *urlS = [NSString stringWithFormat:@"%@", url];
    for (FXSyncItem *item in _bookmarks) {
        if ([[item bmkUri] isEqualToString:urlS]) {
            return item;
        }
    }
    return nil;
}

@end

