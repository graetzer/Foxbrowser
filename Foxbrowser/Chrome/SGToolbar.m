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

#import "SGToolbar.h"
#import "SGTabDefines.h"
#import "BookmarkPage.h"
#import "SGAppDelegate.h"
#import "SGTabsViewController.h"
#import "SGProgressCircleView.h"
#import "SettingsController.h"

@interface SGToolbar ()
@property (nonatomic, strong) UIBarButtonItem *forwardItem;
@property (nonatomic, strong) UIBarButtonItem *backItem;
@property (nonatomic, strong) UIBarButtonItem *reloadItem;
@property (nonatomic, strong) UIBarButtonItem *stopItem;
@property (nonatomic, strong) UIBarButtonItem *progressItem;
@property (nonatomic, strong) UIBarButtonItem *searchItem;
@property (nonatomic, strong) UIBarButtonItem *bookmarksItem;
@property (nonatomic, strong) UIBarButtonItem *fixed;
@property (nonatomic, strong) UIBarButtonItem *flexible;
@property (nonatomic, strong) UIBarButtonItem *sytemItem;

@end

@implementation SGToolbar
@synthesize delegate = _myDelegate;

- (id)initWithFrame:(CGRect)frame delegate:(id<SGToolbarDelegate>)delegate
{
    self = [super initWithFrame:frame];
    if (self) {
        self.delegate = delegate;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _bottomColor = kTabColor;
        
        self.backItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"left"] 
                                                         style:UIBarButtonItemStylePlain 
                                                        target:self.delegate 
                                                        action:@selector(goBack)];
        
        self.forwardItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"right"] 
                                                       style:UIBarButtonItemStylePlain 
                                                      target:self.delegate 
                                                      action:@selector(goForward)];
        
        self.progressView = [[SGProgressCircleView alloc] init];
        self.progressItem = [[UIBarButtonItem alloc] initWithCustomView:self.progressView];
        
        self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0.0, 0.0, 503.0, 0.0)];
        self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.searchBar.delegate = self;
        self.searchBar.placeholder = NSLocalizedString(@"Enter URL or search query here", nil);
        self.searchBar.keyboardType = UIKeyboardTypeASCIICapable;
        self.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.searchItem = [[UIBarButtonItem alloc] initWithCustomView:_searchBar];
        
        self.bookmarksItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemBookmarks
                                                                                       target:self 
                                                                                       action:@selector(showLibrary:)];
        self.fixed = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                                                                target:nil 
                                                                                action:nil];
        self.fixed.width = 20.;
        
        self.flexible = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                   target:nil
                                                                   action:nil];

        
        self.sytemItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                                   target:self 
                                                                                   action:@selector(showOptions:)];
        
        self.reloadItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh 
                                                                                     target:self.delegate 
                                                                                     action:@selector(reload)];
        self.stopItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop
                                                                      target:self.delegate
                                                                      action:@selector(stop)];
        
        self.items = [NSArray arrayWithObjects:_backItem, _fixed, _forwardItem, _bookmarksItem,
                      _fixed, _sytemItem, _flexible, _searchItem, _reloadItem, nil];
        
        self.urlBarViewController = [[SGURLBarController alloc] initWithStyle:UITableViewStylePlain];
        self.urlBarViewController.delegate = self;
        
        [self updateChrome];
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGPoint topCenter = CGPointMake(CGRectGetMidX(self.bounds), 0.0f);
    CGPoint bottomCenter = CGPointMake(CGRectGetMidX(self.bounds), self.bounds.size.height);
    CGFloat locations[2] = { 0.00, 0.95};
    
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

#pragma mark - Libary

- (IBAction)showLibrary:(UIBarButtonItem *)sender {
    if (self.popoverController) {
        [self.popoverController dismissPopoverAnimated:YES];
        self.popoverController = nil;
        return;
    }
    [self dismissPopovers];
    
    BookmarkPage *bookmarks = [BookmarkPage new];
    bookmarks.delegate = self.delegate;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:bookmarks];
    self.popoverController = [[UIPopoverController alloc] initWithContentViewController:nav];
    self.popoverController.delegate = self;
    [self.popoverController presentPopoverFromBarButtonItem:sender
                                   permittedArrowDirections:UIPopoverArrowDirectionAny
                                                   animated:YES];
}

- (IBAction)showOptions:(UIBarButtonItem *)sender {
    if (self.actionSheet) {
        [self.actionSheet dismissWithClickedButtonIndex:-1 animated:YES];
        self.actionSheet = nil;
        return;
    }
    [self dismissPopovers];
    
    self.actionSheet = [[UIActionSheet alloc] initWithTitle:nil 
                            delegate:self
                            cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                            destructiveButtonTitle:nil
                            otherButtonTitles:
                            NSLocalizedString(@"View in Safari", @"launch safari to display the url"),
                            NSLocalizedString(@"Email URL", nil),
                            NSLocalizedString(@"Tweet", @"Tweet the current url"),
                            NSLocalizedString(@"Settings", nil), nil];
    [self.actionSheet showFromBarButtonItem:sender animated:YES];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    NSURL *url = [self.delegate URL];

    switch (buttonIndex) {
        case 0:
            [[UIApplication sharedApplication] openURL:url];
            break;
        case 1:
            if ([MFMailComposeViewController canSendMail]) {
                MFMailComposeViewController *mail = [[MFMailComposeViewController alloc] init];
                mail.mailComposeDelegate = self;
                [mail setSubject:NSLocalizedString(@"Sending you a link", nil)];
                NSString *text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"Here is that site we talked about:", nil), url.absoluteString];
                [mail setMessageBody:text isHTML:NO];
                [appDelegate.tabsController presentModalViewController:mail animated:YES];
            }
            break;
            
        case 2:
            if ([TWTweetComposeViewController canSendTweet]) {
                TWTweetComposeViewController *tw = [[TWTweetComposeViewController alloc] init];
                [tw addURL:url];
                [appDelegate.tabsController presentModalViewController:tw animated:YES];
            }
            break;
            
        case 3:
            {
                SettingsController *settings = [SettingsController new];
                UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settings];
                nav.modalPresentationStyle = UIModalPresentationFormSheet;
                [appDelegate.tabsController presentModalViewController:nav animated:YES];
            }
            
            break;
            
        default:
            break;
    }
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error
{
    switch (result)
    {
        case MFMailComposeResultCancelled:
            NSLog(@"Mail cancelled: you cancelled the operation and no email message was queued.");
            break;
        case MFMailComposeResultSaved:
            NSLog(@"Mail saved: you saved the email message in the drafts folder.");
            break;
        case MFMailComposeResultSent:
            NSLog(@"Mail send: the email message is queued in the outbox. It is ready to send.");
            break;
        case MFMailComposeResultFailed:
            NSLog(@"Mail failed: the email message was not saved or queued, possibly due to an error.");
            break;
        default:
            NSLog(@"Mail not sent.");
            break;
    }
    
    // Remove the mail view
    [appDelegate.tabsController dismissModalViewControllerAnimated:YES];
}

- (void)dismissPopovers {
    if (self.popoverController) {
        [self.popoverController dismissPopoverAnimated:YES];
        self.popoverController = nil;
    }
    if (self.actionSheet) {
        [self.actionSheet dismissWithClickedButtonIndex:-1 animated:YES];
        self.actionSheet = nil;
    }
}

#pragma mark -
#pragma mark Search bar delegate methods

- (void)showPopover {
    if (!self.popoverController) // create the popover if not already open
    {
        // Create a navigation controller to contain the recent searches controller,
        // and create the popover controller to contain the navigation controller.
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:self.urlBarViewController];
        
        UIPopoverController *popover = [[UIPopoverController alloc] initWithContentViewController:navigationController];
        self.popoverController = popover;
        self.popoverController.delegate = self;
        
        // Ensure the popover is not dismissed if the user taps in the search bar.
        popover.passthroughViews = [NSArray arrayWithObject:self.searchBar];
        
        // Display the search results controller popover.
        [self.popoverController presentPopoverFromRect:[self.searchBar bounds]
                                                inView:self.searchBar
                              permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    }
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)aSearchBar {
//    if (aSearchBar.text.length > 0) {
//        [self showPopover];
//        [self.urlBarViewController filterResultsUsingString:aSearchBar.text];
//    }
     [self dismissPopovers];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)aSearchBar {
    
    // If the user finishes editing text in the search bar by, for example:
    // tapping away rather than selecting from the recents list, then just dismiss the popover
    [self dismissPopovers];
    
    if ([self.delegate respondsToSelector:@selector(location)]) {
        self.searchBar.text = [self.delegate location];
    }
    [aSearchBar resignFirstResponder];
}


- (void)searchBar:(UISearchBar *)aSearchBar textDidChange:(NSString *)searchText {
    if (searchText.length > 0) {
        [self showPopover];
    } else {
        [self dismissPopovers];
    }
    
    // When the search string changes, filter the recents list accordingly.
    [self.urlBarViewController filterResultsUsingString:searchText];
}


- (void)searchBarSearchButtonClicked:(UISearchBar *)aSearchBar {
    
    // When the search button is tapped, add the search term to recents and conduct the search.
    NSString *searchString = [self.searchBar text];
    //[self.urlBarViewController addToRecentSearches:searchString]; TODO change history
    [self finishSearchWithString:searchString];
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    
    // Remove focus from the search bar without committing the search.
    [self.searchBar resignFirstResponder];
    self.popoverController = nil;
}

- (void)finishSearchWithString:(NSString *)searchString {
    
    // Conduct the search. In this case, simply report the search term used.
    [self.popoverController dismissPopoverAnimated:YES];
    self.popoverController = nil;
    [self.searchBar resignFirstResponder];
    
    [self.delegate handleURLInput:searchString];
}

- (void)updateChrome {
    if (![self.searchBar isFirstResponder] && [self.delegate respondsToSelector:@selector(location)]) {
            self.searchBar.text = [self.delegate location];
    }
    self.forwardItem.enabled = [self.delegate canGoForward];
    self.backItem.enabled = [self.delegate canGoBack];
    
    if ([self.delegate respondsToSelector:@selector(canStopOrReload)]) {
        BOOL canStopOrReload = [self.delegate canStopOrReload];
        if (canStopOrReload) {
            if ([self.delegate isLoading]) {
                self.reloadItem.enabled = NO;
                self.stopItem.enabled = YES;
                [self setItems:[NSArray arrayWithObjects:_backItem, _fixed, _forwardItem, _bookmarksItem,
                              _fixed, _sytemItem, _progressItem, _searchItem, _stopItem, nil] animated:NO];
            } else {
                self.reloadItem.enabled = YES;
                self.stopItem.enabled = NO;
                [self setItems:[NSArray arrayWithObjects:_backItem, _fixed, _forwardItem, _bookmarksItem,
                 _fixed, _sytemItem, _flexible, _searchItem, _reloadItem, nil] animated:NO];
            }
        } else {
            self.reloadItem.enabled = NO;
            self.stopItem.enabled = NO;
            [self setItems:[NSArray arrayWithObjects:_backItem, _fixed, _forwardItem, _bookmarksItem,
                          _fixed, _sytemItem, _flexible, _searchItem, _reloadItem, nil] animated:NO];
        }
        
    }
}

@end
