//
//  SGToolbarView.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 07.10.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import "SGToolbarView.h"
#import "FXSyncStock.h"

#import "FXLoginViewController.h"
#import "FXSettingsViewController.h"
#import "FXBookmarkTableController.h"

#import "FXBookmarkEditController.h"
#import "SGBrowserViewController.h"
#import "SGSearchViewController.h"
#import "SGSearchField.h"

#import "KxMenu.h"

@implementation SGToolbarView

- (instancetype)initWithFrame:(CGRect)frame browserDelegate:(SGBrowserViewController *)browser; {
    if (self = [super initWithFrame:frame]) {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.backgroundColor = kSGBrowserBarColor;
        _browser = browser;
        
        [KxMenu setTintColor:kSGBrowserBarColor];
        
        __strong UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        btn.backgroundColor = [UIColor clearColor];
        btn.showsTouchWhenHighlighted = YES;
        [btn setImage:[UIImage imageNamed:@"left"] forState:UIControlStateNormal];
        [btn addTarget:_browser action:@selector(goBack) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:btn];
        _backButton = btn;
        
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        btn.backgroundColor = [UIColor clearColor];
        btn.showsTouchWhenHighlighted = YES;
        [btn setImage:[UIImage imageNamed:@"right"] forState:UIControlStateNormal];
        [btn addTarget:_browser action:@selector(goForward) forControlEvents:UIControlEventTouchUpInside];
        btn.enabled = self.browser.canGoForward;
        [self addSubview:btn];
        _forwardButton = btn;
        
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        btn.backgroundColor = [UIColor clearColor];
        btn.showsTouchWhenHighlighted = YES;
        [btn setImage:[UIImage imageNamed:@"grip"] forState:UIControlStateNormal];
        [btn setImage:[UIImage imageNamed:@"grip-pressed"] forState:UIControlStateHighlighted];
        [btn addTarget:self action:@selector(showBrowserMenu:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:btn];
        _menuButton = btn;
        
        __strong SGSearchField *field = [[SGSearchField alloc] initWithFrame:CGRectMake(0, 0, 200., 30.)];
        field.delegate = self;
        [field.stopItem addTarget:self.browser action:@selector(stop) forControlEvents:UIControlEventTouchUpInside];
        [field.reloadItem addTarget:self.browser action:@selector(reload) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:field];
        _searchField = field;
        
        __strong SGSearchViewController *searchC = [[SGSearchViewController alloc] initWithStyle:UITableViewStylePlain];
        searchC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        searchC.delegate = self;
        _searchController = searchC;
        
        __strong UIProgressView *progressV = [[UIProgressView alloc] initWithFrame:CGRectMake(0, 0, 100, 3)];
        progressV.progressViewStyle = UIProgressViewStyleBar;
        [self addSubview:progressV];
        _progressView = progressV;
        
        _bookmarks = [[UINavigationController alloc] initWithRootViewController:[FXBookmarkTableController new]];
    }
    return self;
}

- (IBAction)showBrowserMenu:(id)sender; {
    UIView *sv = sender;
    
    
    NSMutableArray *menuItems = [NSMutableArray arrayWithCapacity:5];
    [menuItems addObject:[KxMenuItem menuItem:NSLocalizedString(@"Bookmarks", @"Bookmarks")
                                        image:[UIImage imageNamed:@"bookmark"]
                                       target:self
                                       action:@selector(_showBookmarks)]];
    NSURL *url = [_browser URL];
    if (url) {
        [menuItems addObject:[KxMenuItem menuItem:NSLocalizedString(@"Share Page",
                                                                    @"Share url of page")
                                            image:[UIImage imageNamed:@"system"]
                                           target:self
                                           action:@selector(_showSharingUI)]];
        
        [menuItems addObject:[KxMenuItem menuItem:NSLocalizedString(@"Bookmark Page",
                                                                    @"add a new bookmark")
                                            image:[UIImage imageNamed:@"favourite"]
                                           target:self
                                           action:@selector(_addBookmark)]];
        
    }
    [menuItems addObject:[KxMenuItem menuItem:NSLocalizedString(@"Settings", @"Settings")
                                        image:[UIImage imageNamed:@"settings"]
                                       target:self
                                       action:@selector(_showSettings)]];

    
    CGRect rect = [_browser.view convertRect:sv.bounds fromView:sv];
    rect.size.height -= 10;
    [KxMenu showMenuInView:_browser.view
                  fromRect:rect
                 menuItems:menuItems];
}

- (void)_showBookmarks {
    [self presentMenuController:_bookmarks completion:NULL];
}

- (void)_addBookmark {
    NSURL *url = [_browser URL];
    NSString *title = [[_browser selectedViewController] title];
    if (url) {
        if (!title) {
            title = NSLocalizedString(@"Untitled", @"Untitled bookmark");
        }
        
        
        [self presentMenuController:_bookmarks completion:^{
            FXBookmarkEditController *edit = [FXBookmarkEditController new];
            edit.bookmark = [[FXSyncStock sharedInstance] bookmarkWithTitle:title url:url];
            [_bookmarks pushViewController:edit animated:YES];
        }];
    }
    
}

- (void)_showSharingUI {
    NSURL *url = [self.browser URL];
    
    if (url) {
        UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[url]
                                                                                 applicationActivities:nil];
        activityVC.completionHandler = ^(NSString *activityType, BOOL completed) {
            if (completed) {
                [appDelegate.tracker send:[[GAIDictionaryBuilder createSocialWithNetwork:activityType
                                                                                  action:@"Share URL"
                                                                                  target:url.absoluteString] build]];
            }
        };
        [self presentMenuController:activityVC completion:NULL];
        
    }
}

- (void)_showSettings {
    BOOL syncReady = [[FXSyncStock sharedInstance] hasUserCredentials];
    if (!syncReady) {
        FXLoginViewController* login = [FXLoginViewController new];
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:login];
        navController.modalPresentationStyle = UIModalPresentationFormSheet;
        navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
        [_browser presentViewController:navController animated:YES completion:NULL];
    } else {
        FXSettingsViewController *settings = [FXSettingsViewController new];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settings];
        nav.modalPresentationStyle = UIModalPresentationFormSheet;
        [_browser presentViewController:nav animated:YES completion:NULL];
    }
}
//
//- (void)_openExternal {
//    NSURL *url = [self.browser URL];
//    if (url) {
//        [[UIApplication sharedApplication] openURL:url];
//    }
//}

- (void)updateInterface {
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

- (void)presentSearchController; {}
- (void)presentMenuController:(UIViewController *)vc completion:(void(^)(void))completion;{}
- (void)dismissPresented; {
    [KxMenu dismissMenu];
}

#pragma mark - SGURLBarDelegate

- (NSString *)text {
    return _searchField.text;
}

- (void)finishSearch:(NSString *)searchString title:(NSString *)title {
    [self.browser handleURLString:searchString title:title];
    
    // Conduct the search. In this case, simply report the search term used.
    [self dismissPresented];
    [_searchField resignFirstResponder];
}

- (void)finishPageSearch:(NSString *)searchString {
    [self dismissPresented];
    [_searchField resignFirstResponder];
    [_browser findInPage:searchString];
}

- (void)userScrolledSuggestions {
    if ([_searchField isFirstResponder]
        && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [_searchField resignFirstResponder];
    }
}

@end
