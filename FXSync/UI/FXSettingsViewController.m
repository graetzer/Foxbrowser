//
//  FXSettingsViewController.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 02.10.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import "FXSettingsViewController.h"
#import "FXSyncStock.h"

#import "GAI.h"

@implementation FXSettingsViewController {
    NSTimer *_timer;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedStringFromTable(@"Settings", @"FXSync", @"Settings");
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                          target:self
                                                                                          action:@selector(_cancel)];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringFromTable(@"Sign Out", @"FXSync", @"perform sign out")
                                                                             style:UIBarButtonItemStyleBordered
                                                                            target:self
                                                                            action:@selector(_logout)];
    [self _refresh];
    
    _syncButton.layer.borderColor = [UIColor whiteColor].CGColor;
    _syncButton.layer.borderWidth = 1.0;
    _syncButton.layer.cornerRadius = 10;
    
    _clearButton.layer.borderColor = [UIColor whiteColor].CGColor;
    _clearButton.layer.borderWidth = 1.0;
    _clearButton.layer.cornerRadius = 10;
    
    id<GAITracker> tracker = [[GAI sharedInstance] defaultTracker];
    [tracker set:kGAIScreenName value:@"SettingsView"];
    [appDelegate.tracker send:[[GAIDictionaryBuilder createAppView] build]];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                              target:self
                                            selector:@selector(_refresh)
                                            userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_timer invalidate];
    _timer = nil;
}

- (void)_refresh {
    FXSyncStock *st = [FXSyncStock sharedInstance];
    if ([st.syncEngine isSyncRunning]) {
        [_activityIndicator startAnimating];
        _syncButton.enabled = NO;
    } else {
        [_activityIndicator stopAnimating];
        _syncButton.enabled = YES;
    }
    
    
    NSString *m = NSLocalizedStringFromTable(@"Logged in as", @"FXSync", @"Start of sentence");
    _userLabel.text = [m stringByAppendingFormat:@": %@", st.user];
    m = NSLocalizedStringFromTable(@"Bookmarks", @"FXSync", @"Bookmarks");
    _bookmarksLabel.text = [m stringByAppendingFormat:@": %ld", (unsigned long)[st.bookmarks count]];
    m = NSLocalizedStringFromTable(@"History", @"FXSync", @"History Label");
    _historyLabel.text = [m stringByAppendingFormat:@": %ld", (unsigned long)[st.history count]];
}

- (void)_cancel {
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)_logout {
    NSString *msg = NSLocalizedStringFromTable(@"Signing out will erase your Firefox Sync information from this device, but will require signing in and a full refresh next time.",
                                               @"FXSync", "Signout");
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Warning", @"FXSync", )
                                                    message:msg
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedStringFromTable(@"Cancel", @"FXSync", )
                                          otherButtonTitles:NSLocalizedStringFromTable(@"OK", @"FXSync", @"ok"), nil];
    [alert show];
}

- (IBAction)startSync:(id)sender {
    [[FXSyncStock sharedInstance] restock];
    [_activityIndicator startAnimating];
}

- (IBAction)clearHistory:(id)sender {
    [[FXSyncStock sharedInstance] clearHistory];
}

- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex > 0) {
        [[FXSyncStock sharedInstance] logout];
        [self dismissViewControllerAnimated:YES completion:NULL];
        
        [appDelegate.tracker send:[[GAIDictionaryBuilder createEventWithCategory:@"Settings"
                                                                          action:@"Logout"
                                                                           label:nil
                                                                           value:nil] build]];
    }
}
@end
