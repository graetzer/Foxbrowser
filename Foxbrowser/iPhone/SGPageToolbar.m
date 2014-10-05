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
#import "SGTabDefines.h"
#import "SGSearchField.h"

#import "FXBookmarkTableController.h"

#import "GAI.h"

@implementation SGPageToolbar {
    BOOL _searchMaskVisible;
}

- (id)initWithFrame:(CGRect)frame browser:(SGPageViewController *)browser {
    self = [super initWithFrame:frame];
    if (self) {
        _browser = browser;
        //_bottomColor = kSGInterfaceColor;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.backgroundColor = kSGBrowserBarColor;
        
        __strong UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        btn.backgroundColor = [UIColor clearColor];
        btn.showsTouchWhenHighlighted = YES;
        [btn setImage:[UIImage imageNamed:@"left"] forState:UIControlStateNormal];
        [btn addTarget:self.browser action:@selector(goBack) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:btn];
        _backButton = btn;
        
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        btn.backgroundColor = [UIColor clearColor];
        btn.showsTouchWhenHighlighted = YES;
        [btn setImage:[UIImage imageNamed:@"right"] forState:UIControlStateNormal];
        [btn addTarget:self.browser action:@selector(goForward) forControlEvents:UIControlEventTouchUpInside];
        btn.enabled = self.browser.canGoForward;
        [self addSubview:btn];
        _forwardButton = btn;
        
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        btn.backgroundColor = [UIColor clearColor];
        [btn setImage:[UIImage imageNamed:@"grip"] forState:UIControlStateNormal];
        [btn setImage:[UIImage imageNamed:@"grip-pressed"] forState:UIControlStateHighlighted];
        [btn addTarget:self action:@selector(_showOptions:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:btn];
        _optionsButton = btn;
        
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
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
        
        __strong UIProgressView *prV = [[UIProgressView alloc] initWithFrame:CGRectMake(0, 0, 100, 3)];
        prV.progressViewStyle = UIProgressViewStyleBar;
        [self addSubview:prV];
        _progressView = prV;
        
        __strong SGSearchField *field = [[SGSearchField alloc] initWithFrame:CGRectMake(0, 0, 200., 30.)];
        field.delegate = self;
        [field.stopItem addTarget:self.browser action:@selector(stop) forControlEvents:UIControlEventTouchUpInside];
        [field.reloadItem addTarget:self.browser action:@selector(reload) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:field];
        _searchField = field;
        
        _searchMaskVisible = NO;
        _searchController = [SGSearchViewController new];
        _searchController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _searchController.delegate = self;
        
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
        _backButton.frame = CGRectMake(posX, (height - buttonSize + topOffset)/2, buttonSize, buttonSize);
        
        posX += buttonSize + margin;
        _forwardButton.frame = CGRectMake(posX, (height - buttonSize + topOffset)/2, buttonSize, buttonSize);
        
        if (_forwardButton.enabled) {
            posX += buttonSize + margin;
        }
    }
    
    _optionsButton.frame = CGRectMake(width - 80, (height - 36 + topOffset)/2, 36, 36);
    _tabsButton.frame = CGRectMake(width - 40, (height - 36 + topOffset)/2, 36, 36);
    _cancelButton.frame = CGRectMake(width - 80, (height - 36 + topOffset)/2, 77, 36);
    
    CGFloat searchWidth = width - posX - _tabsButton.frame.size.width - _optionsButton.frame.size.width - 3*margin;
    _searchField.frame = CGRectMake(posX, (height - _searchField.frame.size.height + topOffset)/2,
                                    searchWidth, _searchField.frame.size.height);
    _progressView.frame = CGRectMake(0, height-3, width, 3);
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
    if (!([_searchField isFirstResponder] || _searchMaskVisible)) {
        _searchField.text = [_browser URL].absoluteString;
    }
    
    NSString *text = [NSString stringWithFormat:@"%lu", (unsigned long)self.browser.count];
    [_tabsButton setTitle:text forState:UIControlStateNormal];
    
    _backButton.enabled = _browser.canGoBack;
    if (_forwardButton.enabled != self.browser.canGoForward) {
        [UIView animateWithDuration:0.2 animations:^{
            _forwardButton.enabled = self.browser.canGoForward;
            [self _layout];
        }];
    }
    
    if ([_browser canStopOrReload]) {
        BOOL loading = [_browser isLoading];
        if (loading) {
            _searchField.state = SGSearchFieldStateStop;
        } else {
            _searchField.state = SGSearchFieldStateReload;
        }
        
        static BOOL loadingOld;
        float p = _progressView.progress;
        NSInteger tag = (NSInteger)[_browser request];
        if (loading && loadingOld) {
            
            // Make sure we haven't changed the website while we are loading
            if (_progressView.tag != tag) {
                _progressView.tag = tag;
                _progressView.progress = 0;
                _progressView.hidden = YES;
            } else if (p < 0.8f) {
                _progressView.hidden = NO;
                [_progressView setProgress:p + 0.2f animated:YES];
            }
            
        } else if (!loading && !loadingOld) {
            if (0.f < p && p < 1.f) {
                _progressView.hidden = NO;
                [_progressView setProgress:1.f animated:YES];
            } else if (p != 0.f) {
                _progressView.hidden = YES;
                _progressView.progress = 0.f;
            }
        }        loadingOld = loading;
        
    } else {
        _searchField.state = SGSearchFieldStateDisabled;
        _progressView.hidden = YES;
    }
    
}

- (void)setSubviewsAlpha:(CGFloat)alpha {
    for (UIView *view in self.subviews) {
        if (view != _progressView) {
            view.alpha = alpha;
        }
    }
}

#pragma mark - IBAction

- (IBAction)_cancelSearchButton:(id)sender {
    [self _dismissSearchController];
    [self.searchField resignFirstResponder];
}

- (IBAction)_pressedTabsButton:(id)sender {
    [self.browser setExposeMode:YES animated:YES];
}

- (IBAction)_showOptions:(UIButton *)sender {
    
    NSArray *titles = @[NSLocalizedString(@"Bookmarks", @"Bookmarks"),
                        NSLocalizedString(@"Share Page", @"Share url of page"),
                        NSLocalizedString(@"View in Safari", @"launch safari to display the url"),
                        NSLocalizedString(@"Settings", nil)];
    PopoverView *pop = [PopoverView showPopoverAtPoint:CGPointMake(CGRectGetMidX(sender.frame), CGRectGetMaxY(sender.frame)-7)
                                                inView:sender.superview
                                       withStringArray:titles
                                              delegate:self];
    pop.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
}

- (void)popoverView:(PopoverView *)popoverView didSelectItemAtIndex:(NSInteger)index {
    [popoverView dismiss:YES];
    
    NSURL *url = [self.browser URL];
    if (index == 0) {
        if (!_bookmarks) {
            _bookmarks = [[UINavigationController alloc] initWithRootViewController:[FXBookmarkTableController new]];
        }
        [_browser presentViewController:_bookmarks animated:YES completion:NULL];
    } else if (index == 1 && url) {
        UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[url]
                                                                                 applicationActivities:nil];
        activityVC.completionHandler = ^(NSString *activityType, BOOL completed) {
            if (completed) {
                [appDelegate.tracker send:[[GAIDictionaryBuilder createSocialWithNetwork:activityType
                                                                                  action:@"Share URL"
                                                                                  target:url.absoluteString] build]];
            }
        };
        [_browser presentViewController:activityVC animated:YES completion:NULL];
    } else if (index == 2) {
        [[UIApplication sharedApplication] openURL:url];
    } else if (index == 3) {
//        BOOL showedFirstRunPage = [[NSUserDefaults standardUserDefaults] boolForKey:kWeaveShowedFirstRunPage];
//        if (!showedFirstRunPage) {
//            WelcomePage* welcomePage = [[WelcomePage alloc] initWithNibName:nil bundle:nil];
//            UINavigationController *navController = [[SGNavViewController alloc] initWithRootViewController:welcomePage];
//            navController.modalPresentationStyle = UIModalPresentationFormSheet;
//            [self.browser presentViewController:navController animated:YES completion:NULL];
//        } else {
//            SettingsController *settings = [SettingsController new];
//            UINavigationController *nav = [[SGNavViewController alloc] initWithRootViewController:settings];
//            nav.modalPresentationStyle = UIModalPresentationFormSheet;
//            [self.browser presentViewController:nav animated:YES completion:NULL];
//        }
    }
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    [self _presentSearchController];
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

- (void)_presentSearchController {
    if (!_searchMaskVisible) {
        _searchMaskVisible = YES;
        self.searchController.view.frame = CGRectMake(0, self.frame.size.height,
                                                      self.frame.size.width, self.superview.bounds.size.height - self.frame.size.height);
        [UIView animateWithDuration:0.25
                         animations:^{
                             [self _layout];
                             _cancelButton.alpha = 1.0;
                             _optionsButton.alpha = 0;
                             _tabsButton.alpha = 0;
                             [self.superview addSubview:self.searchController.view];
                         } completion:^(BOOL finished){
                             _optionsButton.hidden = YES;
                             _tabsButton.hidden = YES;
                             _cancelButton.hidden = NO;
                         }];
    }
}

- (void)_dismissSearchController {
    if (_searchMaskVisible) {
        _searchMaskVisible = NO;
        // If the user finishes editing text in the search bar by, for example:
        // tapping away rather than selecting from the recents list, then just dismiss the popover
        self.searchField.text = [self.browser URL].absoluteString;
        [UIView animateWithDuration:0.25
                         animations:^{
                             [self _layout];
                             _optionsButton.alpha = 1.0;
                             _tabsButton.alpha = 1.0;
                             _cancelButton.alpha = 0;
                             [self.searchController.view removeFromSuperview];
                         } completion:^(BOOL finished){
                             _optionsButton.hidden = NO;
                             _tabsButton.hidden = NO;
                             _cancelButton.hidden = YES;
                         }];
    }
}

#pragma mark - SGSearchControllerDelegate

- (NSString *)text {
    return self.searchField.text;
}

- (void)finishSearch:(NSString *)searchString title:(NSString *)title {
    if (searchString.length > 0)// Conduct the search. In this case, simply report the search term used.
        [self.browser handleURLString:searchString title:title];
    
    [self _dismissSearchController];
    [self.searchField resignFirstResponder];
}

- (void)finishPageSearch:(NSString *)searchString {
    [self _dismissSearchController];
    [self.searchField resignFirstResponder];
    [self.browser findInPage:searchString];
}

- (void)userScrolledSuggestions {
    if ([self.searchField isFirstResponder])
        [self.searchField resignFirstResponder];
}

@end
