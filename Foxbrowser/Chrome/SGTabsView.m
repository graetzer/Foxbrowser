//
//  SGTabsView.m
//  SGTabs
//
//  Created by simon on 07.06.12.
//
//
//  Copyright (c) 2012 Simon Grätzer
//  
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "SGTabsView.h"
#import "SGTabView.h"
#import "SGTabsViewController.h"
#import "SGTabDefines.h"

@interface SGTabsView ()
- (CGFloat)tabWidth:(NSUInteger)count;
@end

@implementation SGTabsView
@synthesize tabs = _tabs, tabsController, selected = _selected;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.autoresizesSubviews = YES;
    }
    return self;
}

- (NSMutableArray *)tabs {
    if (!_tabs) {
        _tabs = [[NSMutableArray alloc] initWithCapacity:[self.tabsController maxCount]];
    }
    return _tabs;
}

- (void)layoutSubviews{
    [self resizeTabs];
}

#pragma mark - Tab operations
- (void)addTab:(NSString *)title {
    CGFloat width = [self tabWidth:self.tabs.count+1];
    
    // Float the subview in from rigth
    CGRect frame = CGRectMake(self.bounds.size.width, 0, width, self.bounds.size.height - kTabsBottomMargin);
    SGTabView *newTab = [[SGTabView alloc] initWithFrame:frame title:title];
    
    // Setup gesture recognizers
    UITapGestureRecognizer *tapG = [[UITapGestureRecognizer alloc] initWithTarget:self 
                                                                           action:@selector(handleTap:)];
    tapG.numberOfTapsRequired = 1;
    tapG.numberOfTouchesRequired = 1;
    tapG.delegate = self;
    [newTab addGestureRecognizer:tapG];
    
    UIPanGestureRecognizer *panG = [[UIPanGestureRecognizer alloc] initWithTarget:self 
                                                                           action:@selector(handlePan:)];
    panG.delegate = self;
    [newTab addGestureRecognizer:panG];
    
    // Setup close button
    UIControlEvents event = [[UIDevice currentDevice].systemVersion doubleValue] < 6 ? UIControlEventTouchCancel : UIControlEventTouchUpInside;
    [newTab.closeButton addTarget:self action:@selector(handleRemove:) forControlEvents:event];
    
    // Add the tab
    [self.tabs addObject:newTab];
    
    [self addSubview:newTab];
    for (int i = 0; i < self.tabs.count; i++) {
        SGTabView *tab = [self.tabs objectAtIndex:i];
        // By setting the real position after the view is added, we create a float from rigth transition
        tab.frame = CGRectMake(width*i, 0, width, self.bounds.size.height - kTabsBottomMargin);
        [tab setNeedsDisplay];
    }
    [self bringSubviewToFront:[self.tabs objectAtIndex:self.selected]];
}

- (void)removeTab:(NSUInteger)index {
    SGTabView *oldTab = [self.tabs objectAtIndex:index];
    if (oldTab) {
        [self.tabs removeObjectAtIndex:index];
        [oldTab removeFromSuperview];
        [self resizeTabs];
    }
}

- (void)setSelected:(NSUInteger)selected {
    _selected = selected;
    for (int i = 0; i < self.tabs.count; i++) {
        SGTabView *tab = [self.tabs objectAtIndex:i];
        if (i == selected) {
            if ([self.tabsController.delegate respondsToSelector:@selector(canRemoveTab:)]) {
                tab.closeButton.hidden = ![self.tabsController.delegate canRemoveTab:[self.tabsController.tabContents objectAtIndex:i]];
            } else {
                tab.closeButton.hidden = NO;
            }
            
            tab.selected = YES;
            [tab setNeedsLayout];
            [self bringSubviewToFront:tab];
        } else {
            tab.closeButton.hidden = YES;
            tab.selected = NO;
            [tab setNeedsLayout];
        }
        [tab setNeedsDisplay];
    }
}

#pragma mark - Helpers
- (CGFloat)tabWidth:(NSUInteger)count {
    if (count > 0)
        return self.bounds.size.width/count;
    else
        return self.bounds.size.width;
}


- (void)resizeTabs {
    CGFloat width = [self tabWidth:self.tabs.count];
    for (int i = 0; i < self.tabs.count; i++) {
        SGTabView *tab = [self.tabs objectAtIndex:i];
        tab.frame = CGRectMake(width*i, 0, width, self.bounds.size.height - kTabsBottomMargin);
    }
}
                                    
#pragma mark - Actions

- (IBAction)handleRemove:(id)sender {
    UIView *v = sender;
    NSUInteger index = [self.tabs indexOfObject:v.superview];
    if (index != NSNotFound) {
        [self.tabsController removeIndex:index];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return NO;
}

- (void)handleTap:(UITapGestureRecognizer *)sender { 
    if (sender.state == UIGestureRecognizerStateEnded) {
        SGTabView *tab = (SGTabView *)sender.view;
        [self.tabsController showIndex:[self.tabs indexOfObject:tab]];
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)sender {
    SGTabView *panTab = (SGTabView *)sender.view;
    NSUInteger panPosition = [self.tabs indexOfObject:panTab];
    
    if (sender.state == UIGestureRecognizerStateBegan) {
        [self.tabsController showIndex:panPosition];
    } else if (sender.state == UIGestureRecognizerStateChanged) {
        CGPoint position = [sender translationInView:self];
        CGPoint center = CGPointMake(sender.view.center.x + position.x, sender.view.center.y);
        
        // Don't move the tab out of the view
        if (center.x < self.bounds.size.width && center.x > 0) {
            sender.view.center = center;
            [sender setTranslation:CGPointZero inView:self];
            
            CGFloat width = [self tabWidth:self.tabs.count];
            // If more than half the tab width is moved, switch the positions
            if (abs(center.x - width*panPosition - width/2) > width/2) {
                NSUInteger nextPos = position.x > 0 ? panPosition+1 : panPosition-1;
                if (nextPos >= self.tabs.count)
                    return;
                
                SGTabView *next = [self.tabs objectAtIndex:nextPos];
                if (next) {
                    if (_selected == panPosition)
                        _selected = nextPos;
                    [self.tabs exchangeObjectAtIndex:panPosition withObjectAtIndex:nextPos];
                    [self.tabsController.tabContents exchangeObjectAtIndex:panPosition withObjectAtIndex:nextPos];
                    
                    [UIView animateWithDuration:0.5 animations:^{// Move the item on the old position of the panTab
                        next.frame = CGRectMake(width*panPosition, 0, width, self.bounds.size.height - kTabsBottomMargin);
                    }];
                }
            }
        }
        
    } else if (sender.state == UIGestureRecognizerStateEnded) {
        CGPoint velocity = [sender velocityInView:self];
        [UIView animateWithDuration:0.5 animations:^{
            // Let's give it 0.025 secnonds more
            panTab.center = CGPointMake(panTab.center.x + velocity.x*0.025, panTab.center.y);
            [self resizeTabs];
        }];
    }
}

@end
