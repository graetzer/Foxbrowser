//
//  SGTabsView.m
//  SGTabs
//
//  Created by simon on 07.06.12.
//  Copyright (c) 2012-2014 Simon Peter Grätzer. All rights reserved.
//

#import "SGTabsView.h"
#import "SGTabView.h"
#import "SGTabsViewController.h"
#import "SGTabDefines.h"
#import "SGAddButton.h"

@implementation SGTabsView
@dynamic selected;

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor blackColor];
        self.opaque = NO;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.autoresizesSubviews = YES;
        
        _tabs = [[NSMutableArray alloc] initWithCapacity:[_tabsController maxCount]];
        CGFloat w = self.bounds.size.width;
        __strong SGAddButton *addButton = [[SGAddButton alloc] initWithFrame:CGRectMake(w - kAddButtonWidth, 0,
                                                                                        kAddButtonWidth, kTabsHeigth)];
        [self addSubview:addButton];
        _addButton = addButton;
        _addButton.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        [_addButton.button addTarget:_tabsController action:@selector(addTab)
                    forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (void)layoutSubviews{
    [super layoutSubviews];
    [self _layout];
}

#pragma mark - Tab operations
- (NSUInteger)addTab:(UIViewController *)viewController {
    CGFloat tabW = [self _tabWidth:_tabs.count+1];
    
    // Float the subview in
    CGSize b = self.bounds.size;
    CGFloat x = MIN(tabW * _tabs.count, b.width-tabW-kAddButtonWidth);
    CGRect frame = CGRectMake(x, 35, tabW + 2*kCornerRadius, b.height);
    SGTabView *newTab = [[SGTabView alloc] initWithFrame:frame];
    newTab.viewController = viewController;
    newTab.closeButton.hidden = YES;
    
    // Setup gesture recognizers
    UITapGestureRecognizer *tapG = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    tapG.numberOfTapsRequired = 1;
    tapG.numberOfTouchesRequired = 1;
    tapG.delegate = self;
    [newTab addGestureRecognizer:tapG];
    
    UIPanGestureRecognizer *panG = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    panG.delegate = self;
    [newTab addGestureRecognizer:panG];
    
    // Setup close button
    if (NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_6_0) {
        [newTab.closeButton addTarget:self action:@selector(_handleRemove:)
                     forControlEvents:UIControlEventTouchCancel];
    } else {
        [newTab.closeButton addTarget:self action:@selector(_handleRemove:)
                     forControlEvents:UIControlEventTouchUpInside];
    }
    newTab.selected = _tabs.count == 0;
    // Add the tab
    [_tabs addObject:newTab];
    [self addSubview:newTab];
    [self _layout];
    [self bringSubviewToFront:_tabs[self.selected]];
    
    return _tabs.count - 1;
}

- (void)removeTab:(NSUInteger)index {
    SGTabView *oldTab = _tabs[index];
    [oldTab removeFromSuperview];
    [_tabs removeObjectAtIndex:index];
    [self _layout];
}

- (NSUInteger)indexOfViewController:(UIViewController *)controller {
    for (NSUInteger i = 0; i < _tabs.count; i++) {
        SGTabView *tab = _tabs[i];
        if (tab.viewController == controller) return i;
    }
    return NSNotFound;
}

- (UIViewController *)viewControllerAtIndex:(NSUInteger)index {
    return [_tabs[index] viewController];
}

- (NSUInteger)selected {
    for (NSUInteger i = 0; i < _tabs.count; i++) {
        if (((SGTabView *)_tabs[i]).selected) return i;
    }
    return 0;
}

- (void)setSelected:(NSUInteger)selected {
    if (selected >= _tabs.count) return;
    
    for (int i = 0; i < _tabs.count; i++) {
        SGTabView *tab = (_tabs)[i];
        if (i == selected) {
            tab.closeButton.hidden = ![_tabsController canRemoveTab:tab.viewController];
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
- (CGFloat)_tabWidth:(NSUInteger)count {
    CGFloat w = self.bounds.size.width - 3*kCornerRadius - kAddButtonWidth;
    CGFloat tab = w/4;
    if (tab * count > w) {
        tab = w/count;
    }
    return tab;
}


- (void)_layout {
    CGFloat width = [self _tabWidth:_tabs.count];
    for (int i = 0; i < _tabs.count; i++) {
        SGTabView *tab = (_tabs)[i];
        tab.frame = CGRectMake(width*i, 0,
                               width + 2*kCornerRadius, self.bounds.size.height);
    }
    
    CGRect f = _addButton.frame;
    f.origin.x = width * _tabs.count + 2*kCornerRadius;
    _addButton.frame = f;
}
                                    
#pragma mark - Actions

- (IBAction)_handleRemove:(id)sender {
    UIView *v = sender;
    NSUInteger index = [_tabs indexOfObject:v.superview];
    if (index != NSNotFound) {
        [_tabsController removeIndex:index];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return NO;
}

- (void)handleTap:(UITapGestureRecognizer *)sender { 
    if (sender.state == UIGestureRecognizerStateEnded) {
        SGTabView *tab = (SGTabView *)sender.view;
        _tabsController.selectedIndex = [_tabs indexOfObject:tab];
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)sender {
    SGTabView *panTab = (SGTabView *)sender.view;
    NSUInteger panPosition = [_tabs indexOfObject:panTab];
    
    switch (sender.state) {
        case UIGestureRecognizerStateBegan: {
            _tabsController.selectedIndex = panPosition;
        }
            break;
            
        case UIGestureRecognizerStateChanged:{
            CGPoint position = [sender translationInView:self];
            CGPoint center = CGPointMake(sender.view.center.x + position.x, sender.view.center.y);
            CGSize b = self.bounds.size;
            
            // Don't move the tab out of the view
            if (center.x < _addButton.frame.origin.x && center.x > 0) {
                sender.view.center = center;
                [sender setTranslation:CGPointZero inView:self];
                
                CGFloat width = [self _tabWidth:_tabs.count];
                CGFloat offset = center.x - (width*panPosition) - width/2;
                if (abs(offset) > width/2) {// If more than half the tab width is moved, switch the positions
                    NSUInteger nextPos = offset > 0 ? panPosition+1 : panPosition-1;
                    
                    if (nextPos < _tabs.count) {
                        SGTabView *next = _tabs[nextPos];
                        [_tabs exchangeObjectAtIndex:panPosition withObjectAtIndex:nextPos];
                        
                        [UIView animateWithDuration:0.5
                                         animations:^{// Move the item on the old position of the panTab
                                             next.frame = CGRectMake(width*panPosition , 0,
                                                                     width + 2*kCornerRadius, b.height);
                                         }
                                         completion:NULL];
                    }
                }
            }
        }
            break;
            
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateEnded:{
            CGPoint velocity = [sender velocityInView:self];
            [UIView animateWithDuration:0.5 animations:^{
                // Let's give it 0.025 secnonds more
                panTab.center = CGPointMake(panTab.center.x + velocity.x*0.025, panTab.center.y);
                [self _layout];
            }];
        }
            
        default:break;
    }
}

@end
