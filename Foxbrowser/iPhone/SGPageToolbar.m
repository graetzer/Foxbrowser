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

#import "BookmarkPage.h"
#import "SettingsController.h"
#import "WelcomePage.h"
#import "SGNavViewController.h"

@implementation SGPageToolbar {
    UIColor *_bottomColor;
    BOOL _searchBarVisible;
}

- (id)initWithFrame:(CGRect)frame browser:(SGPageViewController *)browser;
{
    self = [super initWithFrame:frame];
    if (self) {
        _browser = browser;
        _bottomColor = kTabColor;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        
        CGRect btnRect = CGRectMake(0, 0, 30, 30);
        _backButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _backButton.frame = btnRect;
        _backButton.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        _backButton.backgroundColor = [UIColor clearColor];
        _backButton.showsTouchWhenHighlighted = YES;
        [_backButton setImage:[UIImage imageNamed:@"left"] forState:UIControlStateNormal];
        [_backButton addTarget:self.browser action:@selector(goBack) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_backButton];
        
        _forwardButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _forwardButton.frame = btnRect;
        _forwardButton.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        _forwardButton.backgroundColor = [UIColor clearColor];
        _forwardButton.showsTouchWhenHighlighted = YES;
        [_forwardButton setImage:[UIImage imageNamed:@"right"] forState:UIControlStateNormal];
        [_forwardButton addTarget:self.browser action:@selector(goForward) forControlEvents:UIControlEventTouchUpInside];
        _forwardButton.hidden = !self.browser.canGoForward;
        [self addSubview:_forwardButton];
        
        btnRect = CGRectMake(0, (frame.size.height - 36)/2, 36, 36);
        btnRect.origin.x = frame.size.width - 80;
        _optionsButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _optionsButton.frame = btnRect;
        _optionsButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        _optionsButton.backgroundColor = [UIColor clearColor];
        [_optionsButton setImage:[UIImage imageNamed:@"grip"] forState:UIControlStateNormal];
        [_optionsButton setImage:[UIImage imageNamed:@"grip-pressed"] forState:UIControlStateHighlighted];
        [_optionsButton addTarget:self action:@selector(showOptions:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_optionsButton];
        
        btnRect.origin.x = frame.size.width - 40;
        _tabsButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _tabsButton.frame = btnRect;
        _tabsButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        _tabsButton.backgroundColor = [UIColor clearColor];
        _tabsButton.titleEdgeInsets = UIEdgeInsetsMake(5, 5, 0, 0);
        _tabsButton.titleLabel.font = [UIFont systemFontOfSize:12.5];
        [_tabsButton setBackgroundImage:[UIImage imageNamed:@"expose"] forState:UIControlStateNormal];
        [_tabsButton setBackgroundImage:[UIImage imageNamed:@"expose-pressed"] forState:UIControlStateHighlighted];
        [_tabsButton setTitle:@"0" forState:UIControlStateNormal];
        [_tabsButton setTitleColor:UIColorFromHEX(0x2E2E2E) forState:UIControlStateNormal];
        [_tabsButton addTarget:self action:@selector(pressedTabsButton:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_tabsButton];
        
        btnRect = CGRectMake(0, (frame.size.height - 36)/2, 77, 36);
        btnRect.origin.x = frame.size.width - 80;
        _cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _cancelButton.frame = btnRect;
        _cancelButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        _cancelButton.backgroundColor = [UIColor clearColor];
        _cancelButton.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:15];
        [_cancelButton setTitle:NSLocalizedString(@"Cancel", @"Cancel") forState:UIControlStateNormal];
        [_cancelButton setTitleColor:UIColorFromHEX(0x2E2E2E) forState:UIControlStateNormal];
        [_cancelButton addTarget:self action:@selector(cancelSearchButton:) forControlEvents:UIControlEventTouchUpInside];
        _cancelButton.hidden = YES;
        [self addSubview:_cancelButton];
        
        _searchField = [[SGSearchField alloc] initWithDelegate:self];
        [self.searchField.stopItem addTarget:self.browser action:@selector(stop) forControlEvents:UIControlEventTouchUpInside];
        [self.searchField.reloadItem addTarget:self.browser action:@selector(reload) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_searchField];
        
        _searchController = [SGSearchViewController new];
        _searchController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        _searchController.delegate = self;
    }
    return self;
}

- (void)layoutSubviews {
    const CGFloat margin = 5;
    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;
    
    CGFloat posX = margin;
    _backButton.frame = CGRectMake(posX, (height - _backButton.frame.size.height)/2,
                                   _backButton.frame.size.width, _backButton.frame.size.height);
    posX += _backButton.frame.size.width + margin;
    
    _forwardButton.frame = CGRectMake(posX, (height - _forwardButton.frame.size.height)/2,
                                      _forwardButton.frame.size.width, _forwardButton.frame.size.height);
    
    if (!_forwardButton.hidden)
        posX += _forwardButton.frame.size.width + margin;
    
    CGFloat searchWidth = width - posX - _tabsButton.frame.size.width - _optionsButton.frame.size.width - 3*margin;
    _searchField.frame = CGRectMake(posX, (height - _searchField.frame.size.height)/2,
                                    searchWidth, _searchField.frame.size.height);
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGPoint topCenter = CGPointMake(CGRectGetMidX(self.bounds), 0.0f);
    CGPoint bottomCenter = CGPointMake(CGRectGetMidX(self.bounds), self.bounds.size.height);
    CGFloat locations[2] = { 0.00, 1.0};
    
    CGFloat redEnd, greenEnd, blueEnd, alphaEnd;
    [_bottomColor getRed:&redEnd green:&greenEnd blue:&blueEnd alpha:&alphaEnd];
    //Two colour components, the start and end colour both set to opaque. Red Green Blue Alpha
    CGFloat components[8] = { 244./255., 245./255., 247./255., 1.0, redEnd, greenEnd, blueEnd, 1.0};
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorspace, components, locations, 2);
    CGContextDrawLinearGradient(context, gradient, topCenter, bottomCenter, 0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorspace);
}

- (void)updateChrome {
    if (![self.searchField isFirstResponder])
        self.searchField.text = [self.browser URL].absoluteString;
    
    NSString *text = [NSString stringWithFormat:@"%d", self.browser.count];
    [_tabsButton setTitle:text forState:UIControlStateNormal];
    
    self.backButton.enabled = self.browser.canGoBack;
    if (_forwardButton.hidden == self.browser.canGoForward)
        [UIView animateWithDuration:0.2 animations:^{
            _forwardButton.hidden = !self.browser.canGoForward;
            [self layoutSubviews];
        }];
    
    if (self.browser.canStopOrReload) {
        if ([self.browser isLoading]) {
            self.searchField.state = SGSearchFieldStateStop;
            //self.progressView.hidden = NO;
        } else {
            self.searchField.state = SGSearchFieldStateReload;
            //self.progressView.hidden = YES;
        }
    } else {
        self.searchField.state = SGSearchFieldStateDisabled;
        //self.progressView.hidden = YES;
    }
}

#pragma mark - IBAction

- (IBAction)cancelSearchButton:(id)sender {
    [self dismissSearchController];
    [self.searchField resignFirstResponder];
}

- (IBAction)pressedTabsButton:(id)sender {
    self.browser.exposeMode = YES;
}

- (IBAction)showOptions:(UIButton *)sender {
    if (!NSClassFromString(@"SLComposeViewController")) {// iOS <= 5.1
        self.actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:
                            NSLocalizedString(@"Bookmarks", @"Bookmarks"),
                            NSLocalizedString(@"Tweet", @"Tweet the current url"),
                            NSLocalizedString(@"Email URL", nil),
                            NSLocalizedString(@"View in Safari", @"launch safari to display the url"),
                            NSLocalizedString(@"Settings", nil), nil];
    } else {// iOS >= 6.0
        self.actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:
                            NSLocalizedString(@"Bookmarks", @"Bookmarks"),
                            NSLocalizedString(@"Facebook", @"Post the current url"),
                            NSLocalizedString(@"Tweet", @"Tweet the current url"),
                            NSLocalizedString(@"Email URL", nil),
                            NSLocalizedString(@"View in Safari", @"launch safari to display the url"),
                            NSLocalizedString(@"Settings", nil), nil];
    }
    [self.actionSheet showInView:self];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    [self dismissSearchController];
    NSURL *url = [self.browser URL];
    
    if (buttonIndex == 0) {
        if (!self.bookmarks) {
            BookmarkPage *bookmarksPage = [BookmarkPage new];
            bookmarksPage.browser = self.browser;
            self.bookmarks = [[UINavigationController alloc] initWithRootViewController:bookmarksPage];
        }
        [self.browser presentViewController:self.bookmarks animated:YES completion:NULL];
    }
    
    if (!NSClassFromString(@"SLComposeViewController")) {
        buttonIndex++;
    } else if (buttonIndex == 1) {// Post on facebook
        if (url && [SLComposeViewController isAvailableForServiceType:SLServiceTypeFacebook]) {
            SLComposeViewController *composeVC = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeFacebook];
            [composeVC addURL:url];
            [self.browser presentViewController:composeVC animated:YES completion:NULL];
        }
    }
    
    if (buttonIndex == 2) {// Send a tweet
        if (url && [TWTweetComposeViewController canSendTweet]) {
            TWTweetComposeViewController *tw = [[TWTweetComposeViewController alloc] init];
            [tw addURL:url];
            [self.browser presentViewController:tw animated:YES completion:NULL];
        }
    }
    
    if (buttonIndex == 3) {// Send a mail
        if (url && [MFMailComposeViewController canSendMail]) {
            MFMailComposeViewController *mail = [[MFMailComposeViewController alloc] init];
            mail.mailComposeDelegate = self;
            [mail setSubject:NSLocalizedString(@"Sending you a link", nil)];
            NSString *text = [NSString stringWithFormat:@"%@\n %@", NSLocalizedString(@"Here is that site we talked about:", nil), url];
            [mail setMessageBody:text isHTML:NO];
            [self.browser presentViewController:mail animated:YES completion:NULL];
        }
    }
    
    if (buttonIndex == 4) {// Open in mobile safari
        [[UIApplication sharedApplication] openURL:url];
    }
    
    if (buttonIndex == 5) {// Show settings or welcome page
        BOOL showedFirstRunPage = [[NSUserDefaults standardUserDefaults] boolForKey:kWeaveShowedFirstRunPage];
        if (!showedFirstRunPage) {
            WelcomePage* welcomePage = [[WelcomePage alloc] initWithNibName:nil bundle:nil];
            UINavigationController *navController = [[SGNavViewController alloc] initWithRootViewController:welcomePage];
            navController.modalPresentationStyle = UIModalPresentationFormSheet;
            [self.browser presentViewController:navController animated:YES completion:NULL];
        } else {
            SettingsController *settings = [SettingsController new];
            UINavigationController *nav = [[SGNavViewController alloc] initWithRootViewController:settings];
            nav.modalPresentationStyle = UIModalPresentationFormSheet;
            [self.browser presentViewController:nav animated:YES completion:NULL];
        }
    }
}

- (void)mailComposeController:(MFMailComposeViewController*)controller
          didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
    // Remove the mail view
    [self.browser dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    [self presentSearchController];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *searchText = [textField.text stringByReplacingCharactersInRange:range withString:string];
    
    // When the search string changes, filter the recents list accordingly.
    if (_searchBarVisible) // TODO
        [self.searchController filterResultsUsingString:searchText];
    
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    // If the user finishes editing text in the search bar by, for example:
    // tapping away rather than selecting from the recents list, then just dismiss the popover
    [self dismissSearchController];
    self.searchField.text = [self.browser URL].absoluteString;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    // When the search button is tapped, add the search term to recents and conduct the search.
    NSString *searchString = [textField text];
    [self finishSearch:searchString title:nil];
    return YES;
}

#pragma mark - SGSearchController

- (void)presentSearchController {
    if (!_searchBarVisible) {
        self.searchController.view.frame = CGRectMake(0, self.frame.size.height,
                                                      self.frame.size.width, self.superview.bounds.size.height - self.frame.size.height);
        [UIView animateWithDuration:0.25
                         animations:^{
                             _cancelButton.alpha = 1.0;
                             _optionsButton.alpha = 0;
                             _tabsButton.alpha = 0;
                             [self.superview addSubview:self.searchController.view];
                         } completion:^(BOOL finished){
                             _searchBarVisible = YES;
                             _optionsButton.hidden = YES;
                             _tabsButton.hidden = YES;
                             _cancelButton.hidden = NO;
                         }];
    }
}

- (void)dismissSearchController {
    if (_searchBarVisible) {
        [UIView animateWithDuration:0.25
                         animations:^{
                             _optionsButton.alpha = 1.0;
                             _tabsButton.alpha = 1.0;
                             _cancelButton.alpha = 0;
                             [self.searchController.view removeFromSuperview];
                         } completion:^(BOOL finished){
                             _optionsButton.hidden = NO;
                             _tabsButton.hidden = NO;
                             _cancelButton.hidden = YES;
                             _searchBarVisible = NO;
                         }];
    }
}

#pragma mark - SGSearchControllerDelegate

- (NSString *)text {
    return self.searchField.text;
}

- (void)finishSearch:(NSString *)searchString title:(NSString *)title {
    if (searchString.length > 0)
        [self.browser handleURLString:searchString title:title];
    
    // Conduct the search. In this case, simply report the search term used.
    [self dismissSearchController];
    [self.searchField resignFirstResponder];
}

@end
