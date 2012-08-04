//
//  SGPreviewPanel.h
//  Foxbrowser
//
//  Created by simon on 13.07.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface SGPreviewTile : UIView

@property (nonatomic, strong) UIButton *imageButton;
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) NSDictionary *info;

- (id)initWithImage:(UIImage *)image title:(NSString *)title;

@end

@protocol SGPanelDelegate <NSObject>

- (void)openNewTab:(SGPreviewTile *)tile;
- (void)open:(SGPreviewTile *)tile;

@end

@interface SGPreviewPanel : UIView <UIGestureRecognizerDelegate, UIActionSheetDelegate>

@property (weak, nonatomic) id<SGPanelDelegate> delegate;

+ (SGPreviewPanel *)instance;
+ (NSString *)blacklistFilePath;

- (void)refresh;
@end