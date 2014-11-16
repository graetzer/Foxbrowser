//
//  SGPreviewPanel.h
//  Foxbrowser
//
//  Created by simon on 13.07.12.
//  Copyright (c) 2012-2014 Simon Peter Grätzer. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@class FXSyncItem;
@interface SGPreviewTile : UIView

@property (readonly, nonatomic) UIImageView *imageView;
@property (readonly, nonatomic) UILabel *label;
@property (readonly, nonatomic) FXSyncItem *item;

- (id)initWithItem:(FXSyncItem *)item frame:(CGRect)frame;
@end

@protocol SGPanelDelegate <NSObject>

- (void)openNewTab:(FXSyncItem *)item;
- (void)open:(FXSyncItem *)item;

@end

@interface SGPreviewPanel : UIView <UIGestureRecognizerDelegate, UIActionSheetDelegate>

@property (weak, nonatomic) id<SGPanelDelegate> delegate;
- (void)refresh;
@end