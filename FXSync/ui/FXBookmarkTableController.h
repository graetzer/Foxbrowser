//
//  FXBookmarkTableController.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 02.10.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FXSyncItem;

/*! Works with https://docs.services.mozilla.com/sync/objectformats.html#bookmarks  */
@interface FXBookmarkTableController : UITableViewController
@property (nonatomic, strong) FXSyncItem *parentFolder;
@property (nonatomic, strong) NSArray *bookmarks;
@end
