//
//  SGTabTopView.h
//  SGTabs
//
//  Created by simon on 07.06.12.
//  Copyright (c) 2012-2014 Simon Peter Grätzer. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

#import "SGToolbarView.h"

@interface SGTabsToolbar : SGToolbarView <UIPopoverControllerDelegate>


@property (strong, nonatomic, readonly) UIPopoverController *popoverController;

- (instancetype)initWithFrame:(CGRect)frame browserDelegate:(SGBrowserViewController *)browser;
- (void)updateInterface;
@end
