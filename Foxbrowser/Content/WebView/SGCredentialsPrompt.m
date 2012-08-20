//
//  SGCredentialsPrompt.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 20.08.12.
//  Copyright (c) 2012 Simon Peter Grätzer. All rights reserved.
//

#import "SGCredentialsPrompt.h"

@implementation SGCredentialsPrompt

- (id)initWithUsername:(NSString *)username persistence:(NSURLCredentialPersistence)persistence; {
    self = [super initWithTitle:NSLocalizedString(@"Authorizing", @"Authorizing")
																  message:@"\n \n \n \n \n"
																 delegate:self
														cancelButtonTitle:NSLocalizedString(@"Cancel", @"cancel")
														otherButtonTitles:NSLocalizedString(@"OK", @"ok"), nil];
    if (!self) return self;
    
	self.usernameField                    = [[UITextField alloc] initWithFrame:CGRectMake(12.0, 55.0, 260.0, 25.0)];
	self.usernameField.text               = username;
	self.usernameField.placeholder        = NSLocalizedString(@"Account", @"Account");
	self.usernameField.autocorrectionType = UITextAutocorrectionTypeNo;
	self.usernameField.delegate           = self;
	[self.usernameField  setBackgroundColor:[UIColor whiteColor]];
	[self addSubview:self.usernameField];
	
	self.passwordField = [[UITextField alloc] initWithFrame:CGRectMake(12.0, 90.0, 260.0, 25.0)];
	self.passwordField.placeholder        = NSLocalizedString(@"Password", @"Password");
	self.passwordField.autocorrectionType = UITextAutocorrectionTypeNo;
 	self.passwordField.delegate           = self;
	[self.passwordField setSecureTextEntry:YES];
	[self.passwordField setBackgroundColor:[UIColor whiteColor]];
	[self addSubview:self.passwordField];
	
	self.rememberCredentials                       = [[UISegmentedControl alloc] initWithItems:
                                                      @[NSLocalizedString(@"Don't save", @"Don't save"),
                                                      NSLocalizedString(@"Temporary", @"Temporary"),
                                                      NSLocalizedString(@"Permanent", @"Permanent")]];
	self.rememberCredentials.tintColor             = [UIColor colorWithRed:78.0/255.0 green:87.0/255.0 blue:121.0/255.0 alpha:0.0];
	self.rememberCredentials.frame                 = CGRectMake(12.0, 120.0, 260.0, 35.0);
	switch (persistence) {
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
	
	// Enable for IPhone
	// CGAffineTransform transform = CGAffineTransformMakeTranslation(0.0, 80.0);
	// [LoginView setTransform:transform];
    return self;
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
