//
//  FXSettingsViewController.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 02.10.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import "FXSettingsViewController.h"
#import "FXSyncStock.h"

@implementation FXSettingsViewController {
    NSTimer *_timer;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedString(@"Settings", @"Settings");
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                          target:self
                                                                                          action:@selector(_cancel)];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Sign Out", @"perform sign out")
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
    
    NSString *m = NSLocalizedString(@"Logged in as", );
    _userLabel.text = [m stringByAppendingFormat:@": %@", st.user];
    m = NSLocalizedString(@"Bookmarks", @"number of bookmarks label");
    _bookmarksLabel.text = [m stringByAppendingFormat:@": %ld", (unsigned long)[st.bookmarks count]];
    m = NSLocalizedString(@"History", @"number of history items label");
    _historyLabel.text = [m stringByAppendingFormat:@": %ld", (unsigned long)[st.history count]];
}

- (void)_cancel {
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)_logout {
    NSString *msg = NSLocalizedString(@"Signing out will erase your Firefox Sync information from this device, but will require signing in and a full refresh next time. ", "Signout");
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Warning", @"")
                                                    message:msg
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                          otherButtonTitles:NSLocalizedString(@"OK", @"ok"), nil];
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
    }
}
@end
