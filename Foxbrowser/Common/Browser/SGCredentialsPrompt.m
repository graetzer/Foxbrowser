//
//  SGCredentialsPrompt.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 20.08.12.
//
//
//  Copyright (c) 2012 Simon Peter Grätzer
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

#import "SGCredentialsPrompt.h"

@implementation SGCredentialsPrompt

- (id)initWithChallenge:(NSURLAuthenticationChallenge *)challenge delegate:(id<UIAlertViewDelegate>)delegate; {
    self = [super initWithTitle:NSLocalizedString(@"Authorizing", @"Authorizing")
																  message:@"\n \n \n \n \n"
																 delegate:delegate
														cancelButtonTitle:NSLocalizedString(@"Cancel", @"cancel")
														otherButtonTitles:NSLocalizedString(@"OK", @"ok"), nil];
    if (!self) return self;
    
    self.challenge = challenge;
    
	self.usernameField                    = [[UITextField alloc] initWithFrame:CGRectMake(12.0, 55.0, 260.0, 25.0)];
	self.usernameField.placeholder        = NSLocalizedString(@"Account", @"Account");
	self.usernameField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.usernameField.autocapitalizationType = UITextAutocapitalizationTypeNone;
	self.usernameField.delegate           = self;
    self.usernameField.borderStyle        = UITextBorderStyleBezel;
	[self.usernameField  setBackgroundColor:[UIColor whiteColor]];
    [self addSubview:self.usernameField];
	
	self.passwordField = [[UITextField alloc] initWithFrame:CGRectMake(12.0, 90.0, 260.0, 25.0)];
	self.passwordField.placeholder        = NSLocalizedString(@"Password", @"Password");
	self.passwordField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.passwordField.autocapitalizationType = UITextAutocapitalizationTypeNone;
 	self.passwordField.delegate           = self;
    self.passwordField.borderStyle        = UITextBorderStyleBezel;
	[self.passwordField setSecureTextEntry:YES];
	[self.passwordField setBackgroundColor:[UIColor whiteColor]];
    [self addSubview:self.passwordField];
	
	self.rememberCredentials                       = [[UISegmentedControl alloc] initWithItems:
                                                      @[NSLocalizedString(@"Don't save", @"Don't save"),
                                                      NSLocalizedString(@"Temporary", @"Temporary"),
                                                      NSLocalizedString(@"Permanent", @"Permanent")]];
	self.rememberCredentials.tintColor             = [UIColor colorWithRed:78.0/255.0 green:87.0/255.0 blue:121.0/255.0 alpha:0.0];
	self.rememberCredentials.frame                 = CGRectMake(12.0, 120.0, 260.0, 35.0);
    [self.rememberCredentials addTarget:self action:@selector(persistenceChanged:) forControlEvents:UIControlEventValueChanged];
    
    _persistence = [[NSUserDefaults standardUserDefaults] integerForKey:@"credentialPersitence"];
    
	switch (_persistence) {
		case NSURLCredentialPersistenceNone:
			self.rememberCredentials.selectedSegmentIndex  = 0;
			break;
		case NSURLCredentialPersistenceForSession:
			self.rememberCredentials.selectedSegmentIndex  = 1;
			break;
		case NSURLCredentialPersistencePermanent:
			self.rememberCredentials.selectedSegmentIndex  = 2;
			break;
		default:
			self.rememberCredentials.selectedSegmentIndex  = 1;
			break;
	}
	self.rememberCredentials.segmentedControlStyle = UISegmentedControlStyleBar;
	[self addSubview: self.rememberCredentials];
    
    if (challenge.proposedCredential) {
        self.usernameField.text = challenge.proposedCredential.user;
        if (challenge.previousFailureCount == 0) {
            self.passwordField.text = challenge.proposedCredential.password;
        }
    }
	
	// Enable for IPhone
//    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
//        CGAffineTransform transform = CGAffineTransformMakeTranslation(0.0, 80.0);
//        [self setTransform:transform];
//    }
    return self;
}

- (IBAction)persistenceChanged:(id)sender {
    switch (self.rememberCredentials.selectedSegmentIndex) {
        case 0:
            _persistence = NSURLCredentialPersistenceNone;
            break;
        case 1:
            _persistence = NSURLCredentialPersistenceForSession;
            break;
        case 2:
            _persistence = NSURLCredentialPersistencePermanent;
            break;
        default:
            _persistence = NSURLCredentialPersistenceForSession;
            break;
    }
    [[NSUserDefaults standardUserDefaults] setInteger:_persistence forKey:@"credentialPersitence"];
}

- (void)show {
    [super show];
    [self.usernameField  performSelector:@selector(becomeFirstResponder)
                              withObject:nil
                              afterDelay:0.1];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField{
	[self.delegate dismissWithClickedButtonIndex:1 animated:YES];
	return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField{
	return NO;
}

@end
