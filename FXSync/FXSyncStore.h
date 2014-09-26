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

- (void)deletCollection:(NSString *)collection;

/*! Sorted by sortindex */
- (void)loadCollection:(NSString *)cName
                 limit:(int)limit
              callback:(void(^)(NSArray *))callback;

- (NSArray *)modifiedItems:(NSString *)collection;

- (NSTimeInterval)lastModifiedForCollection:(NSString *)collection;
- (void)setLastModifiedForCollection:(NSString *)collection  modified:(NSTimeInterval)modified;
@end
