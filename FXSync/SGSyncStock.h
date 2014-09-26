//
//  SGSyncStock.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 24.09.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
 * Should work as specified in https://docs.services.mozilla.com/sync/objectformats.html
 */
@interface SGSyncStock : NSObject

@property (readonly, strong, nonatomic) NSArray *history;
@property (readonly, strong, nonatomic) NSArray *bookmarks;
@property (readonly, strong, nonatomic) NSArray *tabs;

- (void)restock;

@end
