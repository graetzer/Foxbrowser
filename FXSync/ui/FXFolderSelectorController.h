//
//  FXFolderSelectorController.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 05.10.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FXSyncItem;
@interface FXFolderSelectorController : UITableViewController
@property (nonatomic, strong) FXSyncItem *bookmark;
@end

@interface FXFolderSelectorCell : UITableViewCell

@end