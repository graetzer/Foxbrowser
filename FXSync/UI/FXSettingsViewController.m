//
//  FXSettingsViewController.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 02.10.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import "FXSettingsViewController.h"

@interface FXSettingsViewController ()

@end

@implementation FXSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedString(@"Settings", @"Settings");
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                          target:self
                                                                                          action:@selector(_cancel:)];
}

- (void)_cancel {
    [self dismissViewControllerAnimated:YES completion:NULL];
}
@end
