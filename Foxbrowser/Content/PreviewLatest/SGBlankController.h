//
//  SGLatestViewController.h
//  Foxbrowser
//
//  Created by simon on 13.07.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SGPreviewPanel.h"

#define SG_TAB_WIDTH 320.0

@class SGPanelContainer, TabBrowserController, SGBottomView, SGBlankView;
@interface SGBlankController : UIViewController <UIScrollViewDelegate, SGPanelDelegate>

@property (readonly, nonatomic) SGBlankView *blankView;

@property (strong, nonatomic) TabBrowserController *tabBrowser;
@end

@interface SGBlankView : UIView <UIScrollViewDelegate>
@property (strong, nonatomic) UIScrollView *scrollView;
@property (strong, nonatomic) SGPreviewPanel *previewPanel;
@property (strong, nonatomic) SGBottomView *bottomView;
@property (strong, nonatomic) UIView *tabBrowserView;

@end