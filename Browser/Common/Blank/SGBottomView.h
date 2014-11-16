//
//  SGBlankToolbar.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 30.07.12.
//  Copyright (c) 2012-2014 Simon Peter Grätzer. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SGBlankController;
@interface SGBottomView : UIView
@property (assign, nonatomic) CGFloat markerPosititon;
@property (weak, nonatomic) SGBlankController *container;

- (id)initWithTitles:(NSArray *)titles images:(NSArray *)images;

@end
