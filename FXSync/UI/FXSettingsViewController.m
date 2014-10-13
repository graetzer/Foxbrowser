//
//  FXSettingsViewController.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 02.10.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import "FXSettingsViewController.h"
#import "FXSyncStock.h"
#import "FXSyncEngine.h"

@implementation FXSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedString(@"Settings", @"Settings");
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                          target:self
                                                                                          action:@selector(_cancel)];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_refresh)
                                                 name:kFXDataChangedNotification
                                               object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)_refresh {
    if ([[FXSyncStock sharedInstance].syncEngine isSyncRunning]) {
        [_activityIndicator startAnimating];
        _syncButton.enabled = NO;
    } else {
        [_activityIndicator stopAnimating];
        _syncButton.enabled = YES;
    }
}

- (void)_cancel {
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (IBAction)startSync:(id)sender {
    [[FXSyncStock sharedInstance] restock];
    [_activityIndicator startAnimating];
}
@end
