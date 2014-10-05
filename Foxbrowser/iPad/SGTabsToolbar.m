//
//  SGTabTopView.m
//  SGTabs
//
//  Created by simon on 07.06.12.
//
//
//  Copyright (c) 2012-2013 Simon Peter Grätzer
//


#import "SGTabsToolbar.h"
#import "SGTabDefines.h"
#import "SGAppDelegate.h"
#import "SGTabsViewController.h"
#import "SGSearchField.h"
#import "SGBrowserViewController.h"
#import "SettingsController.h"
#import "WelcomePage.h"
#import "BookmarkPage.h"
#import "GAI.h"

@implementation SGTabsToolbar

- (id)initWithFrame:(CGRect)frame browser:(SGBrowserViewController *)browser {
    
    if (self = [super initWithFrame:frame]) {
        _browser = browser;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.backgroundColor = kSGBrowserBarColor;
        
        CGRect btnRect = CGRectMake(0, 0, 30, 30);
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = btnRect;
        btn.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        btn.backgroundColor = [UIColor clearColor];
        btn.showsTouchWhenHighlighted = YES;
        [btn setImage:[UIImage imageNamed:@"left"] forState:UIControlStateNormal];
        [btn addTarget:self.browser action:@selector(goBack) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:btn];
        _backItem = btn;
        
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = btnRect;
        btn.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        btn.backgroundColor = [UIColor clearColor];
        btn.showsTouchWhenHighlighted = YES;
        [btn setImage:[UIImage imageNamed:@"right"] forState:UIControlStateNormal];
        [btn addTarget:self.browser action:@selector(goForward) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:btn];
        _forwardItem = btn;
        
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = btnRect;
        btn.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        btn.backgroundColor = [UIColor clearColor];
        btn.showsTouchWhenHighlighted = YES;
        [btn setImage:[UIImage imageNamed:@"grip"] forState:UIControlStateNormal];
        [btn setImage:[UIImage imageNamed:@"grip-pressed"] forState:UIControlStateHighlighted];
        [btn addTarget:self action:@selector(showOptions:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:btn];
        _systemItem = btn;
        
        __strong SGSearchField* search = [[SGSearchField alloc] initWithFrame:CGRectMake(0, 0, 200., 30.)];
        search.delegate = self;
        [search.stopItem addTarget:self.browser action:@selector(stop) forControlEvents:UIControlEventTouchUpInside];
        [search.reloadItem addTarget:self.browser action:@selector(reload) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:search];
        _searchField = search;
        
        __strong SGSearchViewController *searchC = [[SGSearchViewController alloc] initWithStyle:UITableViewStylePlain];
        searchC.delegate = self;
        _searchController = searchC;
        
        __strong UIProgressView *progressV = [[UIProgressView alloc] initWithFrame:CGRectMake(0, 0, 100, 3)];
        progressV.progressViewStyle = UIProgressViewStyleBar;
        [self addSubview:progressV];
        _progressView = progressV;
        
        [self updateInterface];
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(ctx, 1.0);
    CGContextSetStrokeColorWithColor(ctx, UIColorFromHEX(0xA9A9A9).CGColor);
    CGContextMoveToPoint(ctx, 0, self.bounds.size.height);
    CGContextAddLineToPoint(ctx, self.bounds.size.width, self.bounds.size.height);
    CGContextStrokePath(ctx);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat diff = 5.;
    CGFloat length = 40.;
    
    CGRect btnR = CGRectMake(diff, (self.bounds.size.height - length)/2, length, length);
    _backItem.frame = btnR;
    
    btnR.origin.x += length + diff;
    _forwardItem.frame = btnR;
    
    CGRect org = _searchField.frame;
    org.size.width = self.bounds.size.width - (btnR.origin.x + 3*diff + 2*length);
    org.origin.x = btnR.origin.x + length + diff;
    org.origin.y = (self.bounds.size.height - org.size.height)/2;
    _searchField.frame = org;
    
    btnR.origin.x = CGRectGetMaxX(org) + diff;
    _systemItem.frame = btnR;
    
    CGRect b = self.bounds;
    _progressView.frame = CGRectMake(0, b.size.height-3, b.size.width, 3);
}

#pragma mark - Libary

- (IBAction)showOptions:(UIButton *)sender {
    [self _destroyOverlays];
    
    _actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                               delegate:self
                                      cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                 destructiveButtonTitle:nil
                                      otherButtonTitles:
                    NSLocalizedString(@"Notifications", @"Notifications"),
                    NSLocalizedString(@"Share Page", @"Share url of page"),
                    NSLocalizedString(@"View in Safari", @"launch safari to display the url"),
                    // NSLocalizedString(@"Settings", nil),
                    nil];
    [self.actionSheet showFromRect:sender.frame inView:self animated:YES];
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    NSURL *url = [self.browser URL];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (buttonIndex == 0) {
            if (!_bookmarks) {
                _bookmarks = [[UINavigationController alloc] initWithRootViewController:[BookmarkPage new]];
            }
            _popoverController = [[UIPopoverController alloc] initWithContentViewController:_bookmarks];
            _popoverController.delegate = self;
            [_popoverController presentPopoverFromRect:_systemItem.frame
                                                inView:self
                              permittedArrowDirections:UIPopoverArrowDirectionAny
                                              animated:YES];
        } else if (buttonIndex == 1 && url != nil) {
            UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[url]
                                                                                     applicationActivities:nil];
            activityVC.completionHandler = ^(NSString *activityType, BOOL completed) {
                if (completed) {
                    [appDelegate.tracker send:[[GAIDictionaryBuilder createSocialWithNetwork:activityType
                                                                                      action:@"Share URL"
                                                                                      target:url.absoluteString] build]];
                }
            };
            
            _popoverController = [[UIPopoverController alloc] initWithContentViewController:activityVC];
            _popoverController.delegate = self;
            [_popoverController presentPopoverFromRect:_systemItem.frame
                                                inView:self
                              permittedArrowDirections:UIPopoverArrowDirectionAny
                                              animated:YES];
        } else if (buttonIndex == 2) {// Open in mobile safari
            [[UIApplication sharedApplication] openURL:url];
        }
    });
}

- (void)updateInterface {
    if (![_searchField isFirstResponder]) {
        _searchField.text = [_browser URL].absoluteString;
    }
    
    _forwardItem.enabled = [_browser canGoForward];
    _backItem.enabled = [_browser canGoBack];
    
    BOOL canStopOrReload = [_browser canStopOrReload];
    if (canStopOrReload) {
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
        }
        //DLog(@"wait_count: %i", wait_count);
        loadingOld = loading;
    } else {
        _searchField.state = SGSearchFieldStateDisabled;
        _progressView.hidden = YES;
    }
}

- (void)_destroyOverlays {
    if (self.popoverController) {
        [self.popoverController dismissPopoverAnimated:YES];
        _popoverController = nil;
    }
    if (self.actionSheet) {
        [self.actionSheet dismissWithClickedButtonIndex:-1 animated:YES];
        _actionSheet = nil;
    }
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    if (!_popoverController) {// create the popover if not already open
        _popoverController = [[UIPopoverController alloc] initWithContentViewController:_searchController];
        _popoverController.delegate = self;
        
        // Ensure the popover is not dismissed if the user taps in the search bar.
        _popoverController.passthroughViews = @[self, self.searchField];
    }
    
    [textField selectAll:self];
}

- (BOOL)textFieldShouldClear:(UITextField *)textField {
    [_popoverController dismissPopoverAnimated:YES];
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *searchText = [textField.text stringByReplacingCharactersInRange:range withString:string];
    if (searchText.length > 0 && !self.popoverController.isPopoverVisible) {
        [self.popoverController presentPopoverFromRect:[self bounds]
                                                inView:self
                              permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    } else if (searchText.length == 0 && self.popoverController.isPopoverVisible) {
        [self.popoverController dismissPopoverAnimated:YES];
    }
    
    // When the search string changes, filter the recents list accordingly.
    if (self.popoverController) {
        [self.searchController filterResultsUsingString:searchText];
    }
    
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    // If the user finishes editing text in the search bar by, for example:
    // tapping away rather than selecting from the recents list, then just dismiss the popover
    [self _destroyOverlays];
    
    if ([self.browser respondsToSelector:@selector(URL)]) {
        self.searchField.text = [self.browser URL].absoluteString;
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    // When the search button is tapped, add the search term to recents and conduct the search.
    NSString *searchString = [textField text];
    [self finishSearch:searchString title:nil];
    return YES;
}

#pragma mark - SGURLBarDelegate

- (NSString *)text {
    return self.searchField.text;
}

- (void)finishSearch:(NSString *)searchString title:(NSString *)title {
    [self.browser handleURLString:searchString title:title];
    
    // Conduct the search. In this case, simply report the search term used.
    [self _destroyOverlays];
    [self.searchField resignFirstResponder];
}

- (void)finishPageSearch:(NSString *)searchString {
    [self _destroyOverlays];
    [self.searchField resignFirstResponder];
    [self.browser findInPage:searchString];
}

#pragma mark - UIPopoverControllerDelegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    // Remove focus from the search bar without committing the search.
    [self resignFirstResponder];
    _popoverController = nil;
}

@end
