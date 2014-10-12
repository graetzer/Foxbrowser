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


@property (readonly, strong, nonatomic) NSArray *history;
@property (readonly, strong, nonatomic) NSArray *clientTabs;
- (NSArray *)bookmarks;

+ (instancetype)sharedInstance;
- (void)restock;

- (BOOL)hasUserCredentials;
- (void)loginEmail:(NSString *)user
          password:(NSString *)pass
        completion:(void(^)(BOOL))block;
- (void)logout;


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
/*! Recursively delete bookmarks, resets the prefetched stuff */
- (void)deleteBookmark:(FXSyncItem *)bookmark;

/*! Create a new bookmark, located in unfiled */
- (FXSyncItem *)bookmarkWithTitle:(NSString *)title url:(NSURL *)url;
- (FXSyncItem *)folderWithParent:(FXSyncItem *)folder;


@end

FOUNDATION_EXPORT NSString *const kFXDataChangedNotification;
FOUNDATION_EXPORT NSString *const kFXErrorNotification;


