//
//  FXSyncStock.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 24.09.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FXSyncEngine.h"
#import "FXSyncItem.h"

/*!
 * Should help with the object formats https://docs.services.mozilla.com/sync/objectformats.html
 * Implements common tasks that do not realy fit into the other parts
 */
@interface FXSyncStock : NSObject <FXSyncEngineDelegate>

@property (readonly, strong, nonatomic) FXSyncEngine *syncEngine;

@property (readonly, strong, nonatomic) NSArray *clientTabs;
- (NSArray *)history;
- (NSArray *)bookmarks;

+ (instancetype)sharedInstance;
- (void)restock;

- (BOOL)hasUserCredentials;
- (void)loginEmail:(NSString *)user
          password:(NSString *)pass
        completion:(void(^)(BOOL))block;
- (void)logout;

// ======= Helper methods to work with history ======

- (void)deleteHistoryItem:(FXSyncItem *)item;
- (void)addHistoryURL:(NSURL *)url;

// ======= Helper methods to work the tabs for the current device ======

/*! Store the tabs for the local client. They will get synced */
- (void)setLocalTabs:(NSArray *)urls;
/*! Blocks until the client data from the db is fetched */
- (NSArray *)localTabs;

// ======= Helper methods to work with the prefetched bookmarks ======

/*! Includes the top folders and fakes one for the unfiled items */
- (NSArray *)topBookmarkFolders;
/*! Get's bookmarks for a specfic parent folder, arbitarily sorted */
- (NSArray *)bookmarksWithParent:(NSString *)parentId;
/*! Get's bookmarks for a specfic parent folder. Prefer this one, because on
 * storageversion 5 the bookmark order is determinded by the childrens array in the parent folder
 */
- (NSArray *)bookmarksWithParentFolder:(FXSyncItem *)folder;
/*! Recursively delete bookmarks */
- (void)deleteBookmark:(FXSyncItem *)bookmark;

/*! Create a new bookmark, located in unfiled */
- (FXSyncItem *)newBookmarkWithTitle:(NSString *)title url:(NSURL *)url;
- (FXSyncItem *)newFolderWithParent:(FXSyncItem *)folder;

/*! Can be used to determine if an url should be bookmarked  */
- (FXSyncItem *)bookmarkForUrl:(NSURL *)url;

@end

FOUNDATION_EXPORT NSString *const kFXDataChangedNotification;
/*! Should open a url, gets a dictionary with the keys title and uri */
FOUNDATION_EXPORT NSString *const kFXOpenURLNotification;
FOUNDATION_EXPORT NSString *const kFXErrorNotification;


