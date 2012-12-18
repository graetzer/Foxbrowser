//
//  SGBlankToolbar.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 30.07.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SGBlankView;
@interface SGBottomView : UIView
@property (assign, nonatomic) CGFloat markerPosititon;
@property (readonly, nonatomic) UIView *marker;
@property (weak, nonatomic) SGBlankView *container;

@end
