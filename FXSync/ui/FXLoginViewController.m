//
//  FXLoginViewController.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 02.10.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import "FXLoginViewController.h"
#import "FXSyncStock.h"
#import "FXHelpViewController.h"
#import "DejalActivityView.h"

@implementation FXLoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedString(@"Sync Login", @"Firefox sync login title");
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Help", nil)
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(_showHelp)];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                          target:self
                                                                                          action:@selector(_cancel:)];

}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _scrollView.contentSize = _contentView.frame.size;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    _scrollView.contentSize = _contentView.frame.size;
}

/*! Set the delegate to nil because the scrollview delegate gets weird scroll values */
#ifdef __IPHONE_8_0
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:NULL completion:^(id<UIViewControllerTransitionCoordinator> handler) {
        _scrollView.contentSize = _contentView.frame.size;
    }];
}
#endif

#pragma mark - Other

- (IBAction)startLogin:(id)sender {
    [self _tryLogin];
}

- (IBAction)_cancel:(id)sender {
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (IBAction)_showHelp {
    FXHelpViewController *help = [FXHelpViewController new];
    [self.navigationController pushViewController:help animated:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == _emailField) {
        [_passwordField becomeFirstResponder];
    } else if (textField == _passwordField) {
        [self _tryLogin];
    }
    return YES;
}

- (void)_tryLogin {
    NSString *email = _emailField.text;
    NSRegularExpression *regex = [NSRegularExpression
                                  regularExpressionWithPattern:@"\\w+@[a-zA-Z_]+?\\.[a-zA-Z]{2,6}"
                                  options:NSRegularExpressionCaseInsensitive
                                  error:NULL];
    NSUInteger matches  = [regex numberOfMatchesInString:email
                                                 options:0
                                                   range:NSMakeRange(0, [email length])];
    if (matches != 1) {
        [self _showWarning:NSLocalizedString(@"Please enter the email address for your account",
                                             @"Invalid email warning")];
        return;
    }
    
    NSString *pass = _passwordField.text;
    if ([pass length] == 0) {
        [self _showWarning:NSLocalizedString(@"Please enter a password",
                                             @"User did not enter password warning")];
        return;
    }

    [DejalBezelActivityView activityViewForView:self.view
                                      withLabel:NSLocalizedString(@"loading...", "loading...")];
    self.navigationItem.leftBarButtonItem.enabled = NO;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    
    [[FXSyncStock sharedInstance]
     loginEmail:email
     password:pass
     completion:^(BOOL success) {
         if (success) {
             [[FXSyncStock sharedInstance] restock];
             [self _cancel:self];
         } else {
             self.navigationItem.leftBarButtonItem.enabled = YES;
             self.navigationItem.rightBarButtonItem.enabled = YES;
             [self _showWarning:NSLocalizedString(@"Login Failure",
                                                  @"unable to login")];
         }
     }];
}

- (void)_showWarning:(NSString *)warn {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Warning", )
                                                    message:warn
                                                   delegate:nil
                                          cancelButtonTitle:NSLocalizedString(@"OK", @"ok")
                                          otherButtonTitles:nil];
    [alert show];
}

@end
