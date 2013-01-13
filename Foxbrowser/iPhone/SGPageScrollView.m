//
//  SGPageScrollView.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 05.01.13.
//  Copyright (c) 2013 Simon Peter Grätzer. All rights reserved.
//

#import "SGPageScrollView.h"

@implementation SGPageScrollView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.autoresizingMask = (UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight);
        self.clipsToBounds = YES;
        self.backgroundColor = [UIColor clearColor];
        self.pagingEnabled = YES;
        self.showsHorizontalScrollIndicator = NO;
        self.showsVerticalScrollIndicator = NO;
        self.scrollsToTop = NO;
        self.delaysContentTouches = NO;
    }
    return self;
}

@end
