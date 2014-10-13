//
//  FXSettingsViewController.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 02.10.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FXSettingsViewController : UIViewController
@property (weak, nonatomic) IBOutlet UIButton *syncButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
- (IBAction)startSync:(id)sender;

@end
