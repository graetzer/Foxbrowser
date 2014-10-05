//
//  FXBookmarkEditController.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 02.10.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FXSyncItem;

@interface FXBookmarkEditController : UITableViewController <UITextFieldDelegate>
// https://docs.services.mozilla.com/sync/objectformats.html#bookmarks
@property (nonatomic, strong) FXSyncItem *bookmark;
@end
