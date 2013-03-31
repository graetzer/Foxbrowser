//
//  SGActionSheetController.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 30.03.13.
//  Copyright (c) 2013 Simon Peter Grätzer. All rights reserved.
//

#import <UIKit/UIKit.h>

@class TSPopoverController;

@interface SGActionSheetController : UITableViewController
@property (nonatomic, strong) TSPopoverController *popover;

- (void)showWithTouch:(UIEvent*)senderEvent;
- (void)showWithCell:(UITableViewCell*)senderCell;
- (void)showWithRect:(CGRect)senderRect;

- (void)dismissWithClickedButtonIndex:(NSInteger)buttonIndex animated:(BOOL)animated;

- (void)addTitle:(NSString *)title callback:(void (^)(void))callback;

@end
