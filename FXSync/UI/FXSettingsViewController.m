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

@implementation FXSettingsViewController {
    NSTimer *_timer;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedString(@"Settings", @"Settings");
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                          target:self
                                                                                          action:@selector(_cancel)];
    [self _refresh];
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
