//
//  SGLatestViewController.h
//  Foxbrowser
//
//  Created by simon on 13.07.12.
//
//
//  Copyright (c) 2012 Simon Peter Grätzer
//  Copyright (c) 2012-2014 Simon Peter Grätzer. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SGPreviewPanel.h"

#define SG_TAB_WIDTH 320.0

@class FXTabsViewController, SGBottomView;

@interface SGBlankController : UIViewController <UIScrollViewDelegate, UIViewControllerRestoration, SGPanelDelegate>
@property (weak, nonatomic) FXTabsViewController *tabsController;
@property (weak, nonatomic) UIScrollView *scrollView;
@property (weak, nonatomic) SGPreviewPanel *previewPanel;
@property (weak, nonatomic) SGBottomView *bottomView;
@end