//
//  SGCredentialsPrompt.h
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

#import <UIKit/UIKit.h>

@interface SGCredentialsPrompt : UIAlertView <UITextFieldDelegate>
@property (strong, nonatomic) UITextField *usernameField;
@property (strong, nonatomic) UITextField *passwordField;
@property (strong, nonatomic) UISegmentedControl* rememberCredentials;
@property (strong, nonatomic) NSURLAuthenticationChallenge *challenge;
@property (assign, nonatomic) NSURLCredentialPersistence persistence;

- (id)initWithChallenge:(NSURLAuthenticationChallenge *)challenge delegate:(id<UIAlertViewDelegate>)delegate;
@end
