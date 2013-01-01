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
        
        _systemButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _systemButton.frame = btnRect;
        _systemButton.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        _systemButton.backgroundColor = [UIColor clearColor];
        _systemButton.showsTouchWhenHighlighted = YES;
        [_systemButton setImage:[UIImage imageNamed:@"system"] forState:UIControlStateNormal];
        [_systemButton addTarget:self action:@selector(showOptions:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_systemButton];
        
        _tabsButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _tabsButton.frame = CGRectMake(0, 0, 35, 35);
        _tabsButton.backgroundColor = [UIColor clearColor];
        _tabsButton.showsTouchWhenHighlighted = YES;
        [_tabsButton setBackgroundImage:[UIImage imageNamed:@"button-small-default"] forState:UIControlStateNormal];
        [_tabsButton setBackgroundImage:[UIImage imageNamed:@"button-small-pressed"] forState:UIControlStateHighlighted];
        [_tabsButton setTitle:@"0" forState:UIControlStateNormal];
        //[_tabsButton setTitleColor:UIColorFromHEX(0x444444) forState:UIControlStateNormal];
        [_tabsButton addTarget:self action:@selector(pressedTabsButton:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_tabsButton];
        
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
    
    CGFloat searchWidth = width - posX - _tabsButton.frame.size.width - _systemButton.frame.size.width - 3*margin;
    _searchField.frame = CGRectMake(posX, (height - _searchField.frame.size.height)/2,
                                    searchWidth, _searchField.frame.size.height);
    posX += _searchField.frame.size.width + margin;
    
    _systemButton.frame = CGRectMake(posX, (height - _systemButton.frame.size.height)/2,
                                    _systemButton.frame.size.width, _systemButton.frame.size.height);
    
    posX += _systemButton.frame.size.width + margin;

    _tabsButton.frame = CGRectMake(posX, (height - _tabsButton.frame.size.height)/2,
                                   _tabsButton.frame.size.width, _tabsButton.frame.size.height);
    

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

- (IBAction)pressedTabsButton:(id)sender {
    self.browser.exposeMode = YES;
}

- (IBAction)showOptions:(UIButton *)sender {
    
    //BOOL privateMode = [[NSUserDefaults standardUserDefaults] boolForKey:kWeavePrivateMode];
    self.actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                     destructiveButtonTitle:nil
                                          otherButtonTitles:
                        NSLocalizedString(@"View in Safari", @"launch safari to display the url"),
                        NSLocalizedString(@"Email URL", nil),
                        NSLocalizedString(@"Tweet", @"Tweet the current url"),
                        //!privateMode ? NSLocalizedString(@"Enable Private Browsing", nil) : NSLocalizedString(@"Disable Private Browsing", nil) ,
                        NSLocalizedString(@"Settings", nil), nil];
    [self.actionSheet showInView:self];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    NSURL *url = [self.browser URL];
    
    switch (buttonIndex) {
        case 0: // Open in mobile safari
            [[UIApplication sharedApplication] openURL:url];
            break;
        case 1: // Send a mail
            if ([MFMailComposeViewController canSendMail]) {
                MFMailComposeViewController *mail = [[MFMailComposeViewController alloc] init];
                mail.mailComposeDelegate = self;
                [mail setSubject:NSLocalizedString(@"Sending you a link", nil)];
                NSString *text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"Here is that site we talked about:", nil), url.absoluteString];
                [mail setMessageBody:text isHTML:NO];
                [self.browser presentModalViewController:mail animated:YES];
            }
            break;
            
        case 2: // Send a tweet
            if ([TWTweetComposeViewController canSendTweet]) {
                TWTweetComposeViewController *tw = [[TWTweetComposeViewController alloc] init];
                [tw addURL:url];
                [self.browser presentModalViewController:tw animated:YES];
            }
            break;
            
        case 3: // Show settings or welcome page
        {
            BOOL showedFirstRunPage = [[NSUserDefaults standardUserDefaults] boolForKey:kWeaveShowedFirstRunPage];
            if (!showedFirstRunPage)
            {
                WelcomePage* welcomePage = [[WelcomePage alloc] initWithNibName:nil bundle:nil];
                UINavigationController *navController = [[SGNavViewController alloc] initWithRootViewController:welcomePage];
                navController.modalPresentationStyle = UIModalPresentationFormSheet;
                [self.browser presentViewController:navController animated:YES completion:NULL];
            }
            else
            {
                SettingsController *settings = [SettingsController new];
                UINavigationController *nav = [[SGNavViewController alloc] initWithRootViewController:settings];
                nav.modalPresentationStyle = UIModalPresentationFormSheet;
                [self.browser presentModalViewController:nav animated:YES];
            }
            
        }
            
            break;
            
        default:
            break;
    }
}

- (void)mailComposeController:(MFMailComposeViewController*)controller
          didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
    // Remove the mail view
    [self.browser dismissModalViewControllerAnimated:YES];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *searchText = [textField.text stringByReplacingCharactersInRange:range withString:string];
    if (searchText.length > 0 && !_searchBarVisible) {
        [self presentSearchController];
    } else if (searchText.length == 0 && _searchBarVisible) {
        [self dismissSearchController];
    }
    
    // When the search string changes, filter the recents list accordingly.
    if (_searchBarVisible) // TODO
        [self.searchController filterResultsUsingString:searchText];
    
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    // If the user finishes editing text in the search bar by, for example:
    // tapping away rather than selecting from the recents list, then just dismiss the popover
    [self dismissSearchController];
    
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

#pragma mark - SGSearchController

- (void)presentSearchController {
    _searchBarVisible = YES;
    self.searchController.view.frame = CGRectMake(0, self.frame.size.height,
                                         self.frame.size.width, self.superview.bounds.size.height - self.frame.size.height);
    [self.superview addSubview:self.searchController.view];
}

- (void)dismissSearchController {
    _searchBarVisible = NO;
    [self.searchController.view removeFromSuperview];
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
