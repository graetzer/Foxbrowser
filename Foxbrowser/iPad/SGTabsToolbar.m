//
//  SGTabTopView.m
//  SGTabs
//
//  Created by simon on 07.06.12.
//
//
//  Copyright (c) 2012-2013 Simon Peter Grätzer
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

#import "SGTabsToolbar.h"
#import "SGTabDefines.h"
#import "SGAppDelegate.h"
#import "SGTabsViewController.h"
#import "SGProgressCircleView.h"
#import "SGSearchField.h"
#import "SGBrowserViewController.h"
#import "SGActivityView.h"

#import "BookmarkPage.h"
#import "SettingsController.h"
#import "WelcomePage.h"

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
        [btn setImage:[UIImage imageNamed:@"bookmark"] forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(showLibrary:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:btn];
        _bookmarksItem = btn;
        
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = btnRect;
        btn.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        btn.backgroundColor = [UIColor clearColor];
        btn.showsTouchWhenHighlighted = YES;
        [btn setImage:[UIImage imageNamed:@"system"] forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(showOptions:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:btn];
        _systemItem = btn;
        
        __strong SGProgressCircleView *progView = [[SGProgressCircleView alloc] init];
        [self addSubview:progView];
        _progressView = progView;
        
        __strong SGSearchField* search = [[SGSearchField alloc] initWithFrame:CGRectMake(0, 0, 200., 30.)];
        search.delegate = self;
        [search.stopItem addTarget:self.browser action:@selector(stop) forControlEvents:UIControlEventTouchUpInside];
        [search.reloadItem addTarget:self.browser action:@selector(reload) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:search];
        _searchField = search;
        
        __strong SGSearchViewController *searchC = [[SGSearchViewController alloc] initWithStyle:UITableViewStylePlain];
        searchC.delegate = self;
        _searchController = searchC;
                
        [self updateInterface];
    }
    return self;
}

//- (void)drawRect:(CGRect)rect {
//    CGContextRef context = UIGraphicsGetCurrentContext();
//    CGPoint topCenter = CGPointMake(CGRectGetMidX(self.bounds), 0.0f);
//    CGPoint bottomCenter = CGPointMake(CGRectGetMidX(self.bounds), self.bounds.size.height);
//    CGFloat locations[2] = { 0.00, 1.0};
//    
//    CGFloat redEnd, greenEnd, blueEnd, alphaEnd;
//    [_bottomColor getRed:&redEnd green:&greenEnd blue:&blueEnd alpha:&alphaEnd];
//    //Two colour components, the start and end colour both set to opaque. Red Green Blue Alpha
//    CGFloat components[8] = { 244./255., 245./255., 247./255., 1.0, redEnd, greenEnd, blueEnd, 1.0};
//    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
//    
//    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorspace, components, locations, 2);
//    CGContextDrawLinearGradient(context, gradient, topCenter, bottomCenter, 0);
//    CGGradientRelease(gradient);
//    CGColorSpaceRelease(colorspace);
//}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat diff = 5.;
    CGFloat length = 40.;
    CGFloat topOffset = 0;
    if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) {
        topOffset = self.browser.topLayoutGuide.length;
    }
    
    CGRect btnR = CGRectMake(diff, (self.bounds.size.height - length + topOffset)/2, length, length);
    self.backItem.frame = btnR;
    
    btnR.origin.x += length + diff;
    self.forwardItem.frame = btnR;
    
    btnR.origin.x += length + 2*diff;
    self.bookmarksItem.frame = btnR;
    
    btnR.origin.x += length + diff;
    self.systemItem.frame = btnR;
    
    CGRect org = self.searchField.frame;
    org.size.width = self.bounds.size.width - (btnR.origin.x + 2*length + 3*diff);
    org.origin.x = self.bounds.size.width - 2*diff - org.size.width;
    org.origin.y = (self.bounds.size.height - org.size.height + topOffset)/2;
    self.searchField.frame = org;
    
    btnR.origin.x = org.origin.x - diff - length;
    self.progressView.frame = btnR;
}

#pragma mark - Libary

- (IBAction)showLibrary:(UIButton *)sender {
    [self _destroyOverlays];
    
    if (!self.bookmarks) {
        _bookmarks = [[UINavigationController alloc] initWithRootViewController:[BookmarkPage new]];
    }
    
    _popoverController = [[UIPopoverController alloc] initWithContentViewController:self.bookmarks];
    self.popoverController.delegate = self;
    [self.popoverController presentPopoverFromRect:sender.frame
                                            inView:self
                          permittedArrowDirections:UIPopoverArrowDirectionAny
                                          animated:YES];
}

- (IBAction)showOptions:(UIButton *)sender {
    [self _destroyOverlays];
    
    _actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                               delegate:self
                                      cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                 destructiveButtonTitle:nil
                                      otherButtonTitles:
                        NSLocalizedString(@"Share Page", @"Share url of page"),
                        NSLocalizedString(@"View in Safari", @"launch safari to display the url"),
                        NSLocalizedString(@"Settings", nil), nil];
    [self.actionSheet showFromRect:sender.frame inView:self animated:YES];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    [self _destroyOverlays];
    NSURL *url = [self.browser URL];
    
    if (buttonIndex == 0 && url != nil) {
        SGActivityView *share = [[SGActivityView alloc] initWithActivityItems:@[url] applicationActivities:nil];
        share.completionHandler = ^(NSString *activity, BOOL completed) {
            if (completed) {
                [appDelegate.tracker send:[[GAIDictionaryBuilder createSocialWithNetwork:activity
                                                                                  action:@"Share URL"
                                                                                  target:url.absoluteString] build]];
            }
        };
        [share show];
    }
    
    if (buttonIndex == 1) // Open in mobile safari
        [[UIApplication sharedApplication] openURL:url];
    
    if (buttonIndex == 2) {// Show settings or welcome page
        BOOL showedFirstRunPage = [[NSUserDefaults standardUserDefaults] boolForKey:kWeaveShowedFirstRunPage];
        if (!showedFirstRunPage) {
            WelcomePage* welcomePage = [[WelcomePage alloc] initWithNibName:nil bundle:nil];
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:welcomePage];
            navController.modalPresentationStyle = UIModalPresentationFormSheet;
            [self.browser presentViewController:navController animated:YES completion:NULL];
        } else {
            SettingsController *settings = [SettingsController new];
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settings];
            nav.modalPresentationStyle = UIModalPresentationFormSheet;
            [self.browser presentViewController:nav animated:YES completion:NULL];
        }
    }
}

- (void)updateInterface {
    if (![self.searchField isFirstResponder]) {
            self.searchField.text = [self.browser URL].absoluteString;
    }
    
    self.forwardItem.enabled = [self.browser canGoForward];
    self.backItem.enabled = [self.browser canGoBack];
    
    BOOL canStopOrReload = [self.browser canStopOrReload];
    if (canStopOrReload) {
        if ([self.browser isLoading]) {
            self.searchField.state = SGSearchFieldStateStop;
            self.progressView.hidden = NO;
        } else {
            self.searchField.state = SGSearchFieldStateReload;
            self.progressView.hidden = YES;
        }
    } else {
        self.searchField.state = SGSearchFieldStateDisabled;
        self.progressView.hidden = YES;
    }
}

- (void)_createPopoverOverlay {
    if (!self.popoverController) {// create the popover if not already open
        _popoverController = [[UIPopoverController alloc] initWithContentViewController:self.searchController];
        self.popoverController.delegate = self;
        
        // Ensure the popover is not dismissed if the user taps in the search bar.
        self.popoverController.passthroughViews = @[self, self.searchField];
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
    [self _createPopoverOverlay];
}

- (BOOL)textFieldShouldClear:(UITextField *)textField {
    [self.popoverController dismissPopoverAnimated:YES];
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
