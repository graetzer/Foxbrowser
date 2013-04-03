//
//  TSPopoverPopoverView.h
//
//  Created by Saito Takashi on 5/10/12.
//  Copyright (c) 2012 synetics ltd. All rights reserved.
//
// https://github.com/takashisite/TSPopover
//

#import <UIKit/UIKit.h>
#import "SGPopoverController.h"

@interface SGPopoverView : UIView

@property (nonatomic) int cornerRadius;
@property (nonatomic) CGPoint arrowPoint;
@property (nonatomic) BOOL isGradient;
@property (nonatomic, strong) UIColor *baseColor;
@property (nonatomic) SGPopoverArrowDirection arrowDirection;



@end
