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

#import "GAI.h"

@implementation FXLoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedStringFromTable(@"Sync Login", @"FXSync", @"Firefox sync login title");
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringFromTable(@"Help", @"FXSync", )
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(_showHelp)];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                          target:self
                                                                                          action:@selector(_cancel:)];
    
    [appDelegate.tracker set:kGAIScreenName value:@"LoginView"];
    [appDelegate.tracker send:[[GAIDictionaryBuilder createAppView] build]];
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
    [_emailField resignFirstResponder];
    [_passwordField resignFirstResponder];
    [self _tryLogin];
}

- (IBAction)_cancel:(id)sender {
    [self dismissViewControllerAnimated:YES completion:NULL];
    if (sender != self) {
        id<GAITracker> tracker = [[GAI sharedInstance] defaultTracker];
        [tracker send:[[GAIDictionaryBuilder createEventWithCategory:@"Sync"
                                                              action:@"Cancel"
                                                               label:@"Cancel"
                                                               value:nil] build]];
    }
}

- (IBAction)_showHelp {
    FXHelpViewController *help = [FXHelpViewController new];
    [self.navigationController pushViewController:help animated:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == _emailField) {
        [_passwordField becomeFirstResponder];
    } else if (textField == _passwordField) {
        [textField resignFirstResponder];
        [self _tryLogin];
    }
    return YES;
}

- (void)_tryLogin {
    NSString *email = _emailField.text;
    if ([email length] == 0) {
        [self _showWarning:NSLocalizedStringFromTable(@"Please enter the email address for your account",
                                                      @"FXSync", @"Invalid email warning")];
        return;
    }
    
    NSString *pass = _passwordField.text;
    if ([pass length] == 0) {
        [self _showWarning:NSLocalizedStringFromTable(@"Please enter a password",
                                                      @"FXSync", @"User did not enter password warning")];
        return;
    }

    [DejalBezelActivityView activityViewForView:self.view
                                      withLabel:NSLocalizedStringFromTable(@"Authorizing", @"FXSync", "Authorizing")];
    self.navigationItem.leftBarButtonItem.enabled = NO;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    
    [[FXSyncStock sharedInstance] loginEmail:email password:pass completion:^(BOOL success) {
         [DejalBezelActivityView removeViewAnimated:YES];
         
         if (success) {
             [[FXSyncStock sharedInstance] restock];
             [self _cancel:self];
             
             [appDelegate.tracker send:[[GAIDictionaryBuilder createEventWithCategory:@"Sync"
                                                                               action:@"Login"
                                                                                label:@"Success"
                                                                                value:nil] build]];
         } else {
             self.navigationItem.leftBarButtonItem.enabled = YES;
             self.navigationItem.rightBarButtonItem.enabled = YES;
             
             NSMutableString *warn = [NSLocalizedStringFromTable(@"Login Failure", @"FXSync", @"unable to login") mutableCopy];
             if (![self _validateEmail:email]) {
                 [warn appendString:@"\n"];
                 [warn appendString:NSLocalizedStringFromTable(@"Please enter the email address for your account",
                                                              @"FXSync", @"Invalid email warning")];
             }
             [self _showWarning:warn];
             
             id<GAITracker> tracker = [[GAI sharedInstance] defaultTracker];
             [tracker send:[[GAIDictionaryBuilder createEventWithCategory:@"Sync"
                                                                   action:@"Login"
                                                                    label:@"Failure"
                                                                    value:nil] build]];
         }
     }];
}

- (void)_showWarning:(NSString *)warn {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Warning", @"FXSync", )
                                                    message:warn
                                                   delegate:nil
                                          cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"FXSync", @"ok")
                                          otherButtonTitles:nil];
    [alert show];
}

- (BOOL)_validateEmail:(NSString *)email {
    if (!email || [email length] < 2) return NO;
    NSRegularExpression *regex = [NSRegularExpression
                                  regularExpressionWithPattern:@"[A-Z0-9a-z\\._%+-]+@([A-Za-z0-9-]+\\.)+[A-Za-z]{2,4}"
                                  options:NSRegularExpressionCaseInsensitive
                                  error:NULL];
    // Crashes if email is nil
    NSUInteger matches = [regex numberOfMatchesInString:email
                                                options:0
                                                  range:NSMakeRange(0, [email length])];
    return matches > 0;
}

@end
