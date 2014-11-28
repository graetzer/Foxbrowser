//
//  FXSyncStore.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 14.06.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import <Foundation/Foundation.h>


@class FXSyncItem;

@interface FXSyncStore : NSObject
+ (instancetype) sharedInstance;

/*! Asynchronously saves item to db, does not change any values */
- (void)saveItem:(FXSyncItem *)item;
- (void)deleteItem:(FXSyncItem *)item;

- (void)clearMetadata;
- (void)clearData;
- (void)clearCollection:(NSString *)cName older:(NSTimeInterval)cutoff;
//- (void)deletCollection:(NSString *)collection;

/*! Sorted by sortindex, pass something negative into limit for unlimited */
- (void)loadCollection:(NSString *)cName
                 limit:(NSUInteger)limit
              callback:(void(^)(NSMutableArray *))callback;
- (void)loadSyncId:(NSString *)syncId
  fromCollection:(NSString *)cName
        callback:(void(^)(FXSyncItem *))block;

- (NSArray *)changedItemsForCollection:(NSString *)collection;

/*! Should be the last time this collection was synced */
- (NSTimeInterval)syncTimeForCollection:(NSString *)collection;
- (void)setSyncTime:(NSTimeInterval)modified forCollection:(NSString *)collection;
@end

FOUNDATION_EXPORT NSString *const kFXTabsCollectionKey;
FOUNDATION_EXPORT NSString *const kFXBookmarksCollectionKey;
FOUNDATION_EXPORT NSString *const kFXHistoryCollectionKey;
FOUNDATION_EXPORT NSString *const kFXPasswordsCollectionKey;
FOUNDATION_EXPORT NSString *const kFXPrefsCollectionKey;
FOUNDATION_EXPORT NSString *const kFXFormsCollectionKey;
FOUNDATION_EXPORT NSString *const kFXClientsCollectionKey;

FOUNDATION_EXPORT NSString *const kFXSyncStoreException;