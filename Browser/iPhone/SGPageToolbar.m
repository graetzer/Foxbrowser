//
//  SGPageToolbar.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 17.12.12.
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

#import "SGPageToolbar.h"
#import "SGPageViewController.h"
#import "SGSearchField.h"

#import "GAI.h"

@implementation SGPageToolbar {
    BOOL _searchMaskVisible;
}

- (instancetype)initWithFrame:(CGRect)frame browserDelegate:(SGBrowserViewController *)browser; {
    self = [super initWithFrame:frame browserDelegate:browser];
    if (self) {
        _searchMaskVisible = NO;
        
        __strong UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        btn.backgroundColor = [UIColor clearColor];
        btn.titleEdgeInsets = UIEdgeInsetsMake(6, 5, 0, 0);
        btn.titleLabel.font = [UIFont systemFontOfSize:12.5];
        [btn setBackgroundImage:[UIImage imageNamed:@"expose"] forState:UIControlStateNormal];
        [btn setBackgroundImage:[UIImage imageNamed:@"expose-pressed"] forState:UIControlStateHighlighted];
        [btn setTitle:@"0" forState:UIControlStateNormal];
        [btn setTitleColor:UIColorFromHEX(0x2E2E2E) forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(_pressedTabsButton:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:btn];
        _tabsButton = btn;

        
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        btn.backgroundColor = [UIColor clearColor];
        btn.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:15];
        btn.titleLabel.minimumScaleFactor = 0.5;
        if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) {
            [btn setTitleColor:UIColorFromHEX(0x007FFF) forState:UIControlStateNormal];
        } else {
            [btn setTitleColor:UIColorFromHEX(0x2E2E2E) forState:UIControlStateNormal];
        }
        [btn setTitle:NSLocalizedString(@"Cancel", @"Cancel") forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(_cancelSearchButton:) forControlEvents:UIControlEventTouchUpInside];
        btn.hidden = YES;
        [self addSubview:btn];
        _cancelButton = btn;
        
        [self _layout];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self _layout];
}

- (void)_layout {
    const CGFloat margin = 5;
    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;
    
    CGFloat posX = margin;
    CGFloat topOffset = 0;
    if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) {
        topOffset = [self.browser.topLayoutGuide length];
    }
    
    if (!_searchMaskVisible) {
        CGFloat buttonSize = 30;
        self.backButton.frame = CGRectMake(posX, (height - buttonSize + topOffset)/2,
                                           buttonSize, buttonSize);
        
        posX += buttonSize + margin;
        self.forwardButton.frame = CGRectMake(posX, (height - buttonSize + topOffset)/2,
                                          buttonSize, buttonSize);
        
        if (self.forwardButton.enabled) {
            posX += buttonSize + margin;
        }
    }
    
    self.menuButton.frame = CGRectMake(width - 80, (height - 36 + topOffset)/2, 36, 36);
    _tabsButton.frame = CGRectMake(width - 40, (height - 36 + topOffset)/2, 36, 36);
    _cancelButton.frame = CGRectMake(width - 80, (height - 36 + topOffset)/2, 77, 36);
    
    CGFloat searchWidth = width - posX - self.tabsButton.frame.size.width;
    searchWidth -= self.menuButton.frame.size.width + 3*margin;
    
    self.searchField.frame = CGRectMake(posX, (height - self.searchField.frame.size.height + topOffset)/2,
                                    searchWidth, self.searchField.frame.size.height);
    self.progressView.frame = CGRectMake(0, height-3, width, 3);
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(ctx, 1.0);
    CGContextSetStrokeColorWithColor(ctx, UIColorFromHEX(0xA9A9A9).CGColor);
    CGContextMoveToPoint(ctx, 0, self.bounds.size.height);
    CGContextAddLineToPoint(ctx, self.bounds.size.width, self.bounds.size.height);
    CGContextStrokePath(ctx);
}

- (void)updateInterface {
    [super updateInterface];
    
    if (!([self.searchField isFirstResponder] || _searchMaskVisible)) {
        self.searchField.text = [self.browser URL].absoluteString;
    }
    
    NSString *text = [NSString stringWithFormat:@"%lu", (unsigned long)self.browser.count];
    [_tabsButton setTitle:text forState:UIControlStateNormal];
    
    self.backButton.enabled = self.browser.canGoBack;
    if (self.forwardButton.enabled != self.browser.canGoForward) {
        [UIView animateWithDuration:0.2 animations:^{
            self.forwardButton.enabled = self.browser.canGoForward;
            [self _layout];
        }];
    }
}

- (void)setSubviewsAlpha:(CGFloat)alpha {
    for (UIView *view in self.subviews) {
        if (view != self.progressView) {
            view.alpha = alpha;
        }
    }
}

#pragma mark - IBAction

- (IBAction)_cancelSearchButton:(id)sender {
    [self dismissPresented];
    [self.searchField resignFirstResponder];
}

- (IBAction)_pressedTabsButton:(id)sender {
    SGPageViewController *pageVC = (SGPageViewController *)self.browser;
    [pageVC setExposeMode:YES animated:YES];
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    [self presentSearchController];
    [textField selectAll:self];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *searchText = [textField.text stringByReplacingCharactersInRange:range withString:string];
    
    // When the search string changes, filter the recents list accordingly.
    if (_searchMaskVisible && searchText.length) // TODO
        [self.searchController filterResultsUsingString:searchText];
    
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    // When the search button is tapped, add the search term to recents and conduct the search.
    NSString *searchString = [textField text];
    [self finishSearch:searchString title:nil];
    return YES;
}

#pragma mark - SGSearchController

- (void)presentSearchController; {
    if (!_searchMaskVisible) {
        _searchMaskVisible = YES;
        self.searchController.view.frame = CGRectMake(0, self.frame.size.height,
                                                      self.frame.size.width, self.superview.bounds.size.height - self.frame.size.height);
        [UIView animateWithDuration:0.25
                         animations:^{
                             [self _layout];
                             _cancelButton.alpha = 1.0;
                             self.menuButton.alpha = 0;
                             _tabsButton.alpha = 0;
                             [self.superview addSubview:self.searchController.view];
                         } completion:^(BOOL finished){
                             self.menuButton.hidden = YES;
                             _tabsButton.hidden = YES;
                             _cancelButton.hidden = NO;
                         }];
    }
}

- (void)presentBookmarksCompletion:(void(^)(void))completion; {
    [self.browser presentViewController:self.bookmarks animated:YES completion:completion];
}

- (void)dismissPresented; {
    [super dismissPresented];
    if (_searchMaskVisible) {
        _searchMaskVisible = NO;
        // If the user finishes editing text in the search bar by, for example:
        // tapping away rather than selecting from the recents list, then just dismiss the popover
        self.searchField.text = [self.browser URL].absoluteString;
        [UIView animateWithDuration:0.25
                         animations:^{
                             [self _layout];
                             self.menuButton.alpha = 1.0;
                             _tabsButton.alpha = 1.0;
                             _cancelButton.alpha = 0;
                             [self.searchController.view removeFromSuperview];
                         } completion:^(BOOL finished){
                             self.menuButton.hidden = NO;
                             _tabsButton.hidden = NO;
                             _cancelButton.hidden = YES;
                         }];
    }
}
@end
