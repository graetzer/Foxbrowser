//
//  FXSyncItem.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 20.06.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, FFSyncItemType) {
    FFSyncBookmarkItem,
    FFSyncTabItem,
    FFSyncHistoryItem,
    FFSyncPasswordItem,
    FFSyncSettingsItem
};

@interface FXSyncItem : NSObject

@property (nonatomic, strong) NSString *syncId;
@property (nonatomic, assign) NSTimeInterval modified;
@property (nonatomic, assign) NSInteger sortindex;

/*! Setting this invalidates jsonPayload */
@property (nonatomic, strong) NSData *payload;
/*! JSON version of payload, uses mutable containers */
@property (strong, nonatomic, readonly) NSDictionary *jsonPayload;

@property (nonatomic, strong) NSString *collection;

- (void)save;

/*
*/
@end
