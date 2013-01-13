//
//  SGTabTopView.m
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

#import "SGTabsToolbar.h"
#import "SGTabDefines.h"
#import "BookmarkPage.h"
#import "SGAppDelegate.h"
#import "SGTabsViewController.h"
#import "SGProgressCircleView.h"
#import "SGSearchField.h"
#import "SGBrowserViewController.h"

#import "SettingsController.h"
#import "WelcomePage.h"

@interface SGTabsToolbar ()
@property (nonatomic, strong) UIButton *forwardItem;
@property (nonatomic, strong) UIButton *backItem;
@property (nonatomic, strong) UIButton *bookmarksItem;
@property (nonatomic, strong) UIButton *systemItem;

@end

@implementation SGTabsToolbar

- (id)initWithFrame:(CGRect)frame browser:(SGBrowserViewController *)browser;
{
    self = [super initWithFrame:frame];
    if (self) {
        _browser = browser;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _bottomColor = kTabColor;
        
        CGRect btnRect = CGRectMake(0, 0, 30, 30);

        self.backItem = [UIButton buttonWithType:UIButtonTypeCustom];
        self.backItem.frame = btnRect;
        self.backItem.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        self.backItem.backgroundColor = [UIColor clearColor];
        self.backItem.showsTouchWhenHighlighted = YES;
        [self.backItem setImage:[UIImage imageNamed:@"left"] forState:UIControlStateNormal];
        [self.backItem addTarget:self.browser action:@selector(goBack) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.backItem];
        
        self.forwardItem = [UIButton buttonWithType:UIButtonTypeCustom];
        self.forwardItem.frame = btnRect;
        self.forwardItem.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        self.forwardItem.backgroundColor = [UIColor clearColor];
        self.forwardItem.showsTouchWhenHighlighted = YES;
        [self.forwardItem setImage:[UIImage imageNamed:@"right"] forState:UIControlStateNormal];
        [self.forwardItem addTarget:self.browser action:@selector(goForward) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.forwardItem];
        
        self.bookmarksItem = [UIButton buttonWithType:UIButtonTypeCustom];
        self.bookmarksItem.frame = btnRect;
        self.bookmarksItem.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        self.bookmarksItem.backgroundColor = [UIColor clearColor];
        self.bookmarksItem.showsTouchWhenHighlighted = YES;
        [self.bookmarksItem setImage:[UIImage imageNamed:@"bookmark"] forState:UIControlStateNormal];
        [self.bookmarksItem addTarget:self action:@selector(showLibrary:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.bookmarksItem];
        
        self.systemItem = [UIButton buttonWithType:UIButtonTypeCustom];
        self.systemItem.frame = btnRect;
        self.systemItem.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        self.systemItem.backgroundColor = [UIColor clearColor];
        self.systemItem.showsTouchWhenHighlighted = YES;
        [self.systemItem setImage:[UIImage imageNamed:@"system"] forState:UIControlStateNormal];
        [self.systemItem addTarget:self action:@selector(showOptions:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.systemItem];
        
        self.progressView = [[SGProgressCircleView alloc] init];
        [self addSubview:self.progressView];
        
        self.searchField = [[SGSearchField alloc] initWithDelegate:self];
        [self.searchField.stopItem addTarget:self.browser action:@selector(stop) forControlEvents:UIControlEventTouchUpInside];
        [self.searchField.reloadItem addTarget:self.browser action:@selector(reload) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.searchField];
        
        self.searchController = [[SGSearchViewController alloc] initWithStyle:UITableViewStylePlain];
        self.searchController.delegate = self;
                
        [self updateChrome];
    }
    return self;
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

- (void)layoutSubviews {
    CGFloat diff = 5.;
    CGFloat length = 40.;
    
    CGRect btnR = CGRectMake(diff, (self.bounds.size.height - length)/2, length, length);
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
    org.origin.y = (self.bounds.size.height - org.size.height)/2;
    self.searchField.frame = org;
    
    btnR.origin.x = org.origin.x - diff - length;
    self.progressView.frame = btnR;
}

#pragma mark - Libary

- (IBAction)showLibrary:(UIButton *)sender {
    [self destroyPopovers];
    
    if (!self.bookmarks) {
        BookmarkPage *bookmarksPage = [BookmarkPage new];
        bookmarksPage.browser = self.browser;
        self.bookmarks = [[UINavigationController alloc] initWithRootViewController:bookmarksPage];
    }
    
    self.popoverController = [[UIPopoverController alloc] initWithContentViewController:self.bookmarks];
    self.popoverController.delegate = self;
    [self.popoverController presentPopoverFromRect:sender.frame
                                            inView:self
                          permittedArrowDirections:UIPopoverArrowDirectionAny
                                          animated:YES];
}

- (IBAction)showOptions:(UIButton *)sender {
    [self destroyPopovers];
    
    if (!NSClassFromString(@"SLComposeViewController")) {
        self.actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:
                            NSLocalizedString(@"Tweet", @"Tweet the current url"),
                            NSLocalizedString(@"Email URL", nil),
                            NSLocalizedString(@"View in Safari", @"launch safari to display the url"),
                            NSLocalizedString(@"Settings", nil), nil];
    } else {
        self.actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:
                            NSLocalizedString(@"Facebook", @"Post the current url"),
                            NSLocalizedString(@"Tweet", @"Tweet the current url"),
                            NSLocalizedString(@"Email URL", nil),
                            NSLocalizedString(@"View in Safari", @"launch safari to display the url"),
                            NSLocalizedString(@"Settings", nil), nil];
    }
    
    [self.actionSheet showFromRect:sender.frame inView:self animated:YES];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    [self destroyPopovers];
    NSURL *url = [self.browser URL];
    
    if (!NSClassFromString(@"SLComposeViewController")) {
        buttonIndex++;
    } else if (buttonIndex == 0) {// Post on facebook
        if (url && [SLComposeViewController isAvailableForServiceType:SLServiceTypeFacebook]) {
            SLComposeViewController *composeVC = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeFacebook];
            [composeVC addURL:url];
            [self.browser presentModalViewController:composeVC animated:YES];
        }
    }
    
    if (buttonIndex == 1) {// Send a tweet
        if (url && [TWTweetComposeViewController canSendTweet]) {
            TWTweetComposeViewController *tw = [[TWTweetComposeViewController alloc] init];
            [tw addURL:url];
            [self.browser presentModalViewController:tw animated:YES];
        }
    }
    
    if (buttonIndex == 2) {// Send a mail
        if (url && [MFMailComposeViewController canSendMail]) {
            MFMailComposeViewController *mail = [[MFMailComposeViewController alloc] init];
            mail.mailComposeDelegate = self;
            [mail setSubject:NSLocalizedString(@"Sending you a link", nil)];
            NSString *text = [NSString stringWithFormat:@"%@\n %@", NSLocalizedString(@"Here is that site we talked about:", nil), url];
            [mail setMessageBody:text isHTML:NO];
            [self.browser presentModalViewController:mail animated:YES];
        }
    }
    
    if (buttonIndex == 3) {// Open in mobile safari
        [[UIApplication sharedApplication] openURL:url];
    }
    
    if (buttonIndex == 4) {// Show settings or welcome page
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
            [self.browser presentModalViewController:nav animated:YES];
        }
    }
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error
{
    switch (result)
    {
        case MFMailComposeResultCancelled:
            DLog(@"Mail cancelled: you cancelled the operation and no email message was queued.");
            break;
        case MFMailComposeResultSaved:
            DLog(@"Mail saved: you saved the email message in the drafts folder.");
            break;
        case MFMailComposeResultSent:
            DLog(@"Mail send: the email message is queued in the outbox. It is ready to send.");
            break;
        case MFMailComposeResultFailed:
            DLog(@"Mail failed: the email message was not saved or queued, possibly due to an error.");
            break;
        default:
            DLog(@"Mail not sent.");
            break;
    }
    
    // Remove the mail view
    [self.browser dismissModalViewControllerAnimated:YES];
}

- (void)updateChrome {
    if (![self.searchField isFirstResponder])
            self.searchField.text = [self.browser URL].absoluteString;
        
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

- (void)createPopover {
    if (!self.popoverController) // create the popover if not already open
    {
        self.popoverController = [[UIPopoverController alloc] initWithContentViewController:self.searchController];
        self.popoverController.delegate = self;
        
        // Ensure the popover is not dismissed if the user taps in the search bar.
        self.popoverController.passthroughViews = @[self, self.searchField];
    }
}

- (void)destroyPopovers {
    if (self.popoverController) {
        [self.popoverController dismissPopoverAnimated:YES];
        self.popoverController = nil;
    }
    if (self.popoverController) {
        [self.popoverController dismissPopoverAnimated:YES];
        self.popoverController = nil;
    }
    if (self.actionSheet) {
        [self.actionSheet dismissWithClickedButtonIndex:-1 animated:YES];
        self.actionSheet = nil;
    }
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    [self createPopover];
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
    [self destroyPopovers];
    
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
    [self destroyPopovers];
    [self.searchField resignFirstResponder];
}

#pragma mark - UIPopoverControllerDelegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    
    // Remove focus from the search bar without committing the search.
    [self resignFirstResponder];
    self.popoverController = nil;
}

@end
