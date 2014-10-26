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

- (void)clearAll;
- (void)clearCollection:(NSString *)cName older:(NSTimeInterval)cutoff;
//- (void)deletCollection:(NSString *)collection;

/*! Sorted by sortindex, pass something negative into limit for unlimited */
- (void)loadCollection:(NSString *)cName
              callback:(void(^)(NSMutableArray *))callback;
- (void)loadSyncId:(NSString *)syncId
  fromCollection:(NSString *)cName
        callback:(void(^)(FXSyncItem *))block;

- (NSArray *)changedItemsForCollection:(NSString *)collection;

/*! Should be the last time this collection was synced */
- (NSTimeInterval)syncTimeForCollection:(NSString *)collection;
- (void)setSyncTime:(NSTimeInterval)modified forCollection:(NSString *)collection;
@end
