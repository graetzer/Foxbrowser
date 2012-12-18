//
//  SGCredentialsPrompt.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 20.08.12.
//  Copyright (c) 2012 Simon Peter Grätzer. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SGCredentialsPrompt : UIAlertView <UITextFieldDelegate>
@property (strong, nonatomic) UITextField *usernameField;
@property (strong, nonatomic) UITextField *passwordField;
@property (strong, nonatomic) UISegmentedControl* rememberCredentials;
@property (strong, nonatomic) NSURLAuthenticationChallenge *challenge;
@property (assign, nonatomic) NSURLCredentialPersistence persistence;

- (id)initWithChallenge:(NSURLAuthenticationChallenge *)challenge delegate:(id<UIAlertViewDelegate>)delegate;
@end
