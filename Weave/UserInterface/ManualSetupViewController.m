/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is Firefox Home.
 *
 * The Initial Developer of the Original Code is the Mozilla Foundation.
 *
 * Portions created by the Initial Developer are Copyright (C) 2010
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *
 *  Stefan Arentz <stefan@arentz.ca>
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

#import "ManualSetupViewController.h"
#import "WeaveService.h"
#import "Stockboy.h"

#import "GAI.h"

@implementation ManualSetupViewController {
    __weak UITextField *_activeField;
}

#define UsernameTextFieldTag 1
#define PasswordTextFieldTag 2
#define SyncKeyTextFieldTag 3
#define CustomServerTextFieldTag 4
@synthesize spinnerView = _spinnerView;
@synthesize spinner = _spinner;
@synthesize usernameLabel = _usernameLabel;
@synthesize usernameTextField = _usernameTextField;
@synthesize passwordLabel = _passwordLabel;
@synthesize passwordTextField = _passwordTextField;
@synthesize syncKeyLabel = _syncKeyLabel;
@synthesize syncKeyTextField = _syncKeyTextField;
@synthesize customServerLabel = _customServerLabel;
@synthesize customServerTextField = _customServerTextField;
@synthesize customServerSwitchLabel = _customServerSwitchLabel;
@synthesize customServerSwitch = _customServerSwitch;
@synthesize cautionLabel = _cautionLabel;

- (void) startLoginSpinner
{
	[_spinner startAnimating];
	_spinnerView.hidden = NO;
	self.navigationItem.leftBarButtonItem.enabled = NO;
}

- (void) stopLoginSpinner
{
	_spinnerView.hidden = YES;
	[_spinner stopAnimating];
	self.navigationItem.leftBarButtonItem.enabled = YES;
}

- (void) authorize: (NSDictionary*)authDict
{
	@autoreleasepool {
        _newCryptoManager = nil;
        
        //any sort of auth failure just means we catch it here and make them reenter the password
        @try
        {
            _newCryptoManager = [[CryptoUtils alloc ] initWithAccountName:authDict[@"user"]
                                                                 password: authDict[@"pass"] andPassphrase:authDict[@"secret"]];
            if (_newCryptoManager) {
                [self performSelectorOnMainThread:@selector(dismissLoginScreen) withObject:nil waitUntilDone:YES];
            } else  {
                @throw [NSException exceptionWithName:@"CryptoInitException" reason:@"unspecified failure" userInfo:nil];
            }
        }
        
        @catch (NSException *e)
        {
            //I don't need to take different actions for different bad outcomes, at least in this case,
            // because they all mean "failed to log in".  So I just report them.  In other situations,
            // I might certainly need to do different things for different error conditions
            [self performSelectorOnMainThread:@selector(authFailed:) withObject:[e reason] waitUntilDone:YES];
            NSLog(@"Failed to initialize CryptoManager");
            [[GAI sharedInstance].defaultTracker sendException:YES withDescription:@"Failed to initialize CryptoManager"];
        }
        
        @finally
        {
            //stop the spinner, regardless
            [self performSelectorOnMainThread:@selector(stopLoginSpinner) withObject:nil waitUntilDone:YES];
        }
    }
}

- (void) authFailed:(NSString*)message
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Login Failure", @"unable to login")
		message:message delegate: self cancelButtonTitle: NSLocalizedString(@"OK", @"ok") otherButtonTitles: nil];
	[alert show];
    [CryptoUtils deletePrivateKeys];
    
    [[GAI sharedInstance].defaultTracker sendEventWithCategory:@"Setup"
                                                    withAction:@"Manual"
                                                     withLabel:@"Fail"
                                                     withValue:nil];
}
  
/**
 * This is called when we have succesfully logged in. Call back to the delegate.
 */
  
- (void) dismissLoginScreen
{
	[CryptoUtils assignManager:_newCryptoManager];

	//The user has now logged in successfully at least once, so set the flag to prevent
	// showing the Welcome page from now on

	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:kWeaveShowedFirstRunPage];
    [[NSUserDefaults standardUserDefaults] synchronize];
	[Stockboy restock];

	[_delegate manualSetupViewControllerDidLogin: self];
    
    [[GAI sharedInstance].defaultTracker sendEventWithCategory:@"Setup"
                                                    withAction:@"Manual"
                                                     withLabel:@"Success"
                                                     withValue:nil];
}

#pragma mark - Keyboard 

- (void) keyboardDidShow:(NSNotification*)notification
{
    CGSize kbSize = [notification.userInfo[UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;

    // If active text field is hidden by keyboard, scroll it so it's visible
    // Your application might not need or want this behavior.
    CGRect aRect = self.view.frame;
    aRect.size.height -= MIN(kbSize.height, kbSize.width);
    if (!CGRectContainsPoint(aRect, _activeField.frame.origin) ) {
        CGPoint scrollPoint = CGPointMake(0.0, _activeField.frame.origin.y -
                                          aRect.size.height + _activeField.frame.size.height);
        [self.scrollView setContentOffset:scrollPoint animated:YES];
    }
}

- (void) keyboardDidHide: (NSNotification*) notification {
    [self.scrollView setContentOffset:CGPointMake(0, 0) animated:YES];
    //self.scrollView.contentInset = UIEdgeInsetsZero;
    //self.scrollView.scrollIndicatorInsets = UIEdgeInsetsZero;
}

#pragma mark - Locales

- (void)viewDidLoad {
	[super viewDidLoad];
    
    self.title = NSLocalizedString(@"Enter your Sync account information", @"Enter your Sync account information");
	
    self.usernameLabel.text = NSLocalizedString(@"Account", @"Account");
    self.usernameTextField.placeholder = NSLocalizedString(@"Required", @"Required");
    
    self.passwordLabel.text = NSLocalizedString(@"Password", @"Password");
    self.passwordTextField.placeholder = NSLocalizedString(@"Required", @"Required");
    
    self.syncKeyLabel.text = NSLocalizedString(@"Sync Key", @"Sync Key");
    self.syncKeyTextField.placeholder = NSLocalizedString(@"Required", @"Required");
    
    self.customServerLabel.text = NSLocalizedString(@"Server URL", @"Server URL");
    self.customServerTextField.placeholder = NSLocalizedString(@"Required", @"Required");
    [self.customServerTextField addTarget: self action: @selector(customServerTextFieldChangedValue:) forControlEvents: UIControlEventValueChanged];
    
    self.customServerSwitchLabel.text = NSLocalizedString(@"Use Custom Server", @"Use Custom Server");
    [self.customServerSwitch addTarget: self action: @selector(customServerSwitchChangedValue:) forControlEvents: UIControlEventValueChanged];
    
	self.cautionLabel.text = NSLocalizedString(@"Caution: use at own risk", @"Caution: use at own risk");
}

- (void)viewDidUnload {
    [self setUsernameTextField:nil];
    [self setPasswordTextField:nil];
    [self setSyncKeyTextField:nil];
    [self setCustomServerTextField:nil];
    [self setCustomServerSwitch:nil];
    [self setUsernameLabel:nil];
    [self setPasswordLabel:nil];
    [self setSyncKeyLabel:nil];
    [self setCustomServerLabel:nil];
    [self setCustomServerSwitchLabel:nil];
    [self setCautionLabel:nil];
    [self setSpinnerView:nil];
    [self setSpinner:nil];
    [self setScrollView:nil];
    [super viewDidUnload];
}

- (void) viewDidAppear:(BOOL)animated
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidShow:)
		name:UIKeyboardDidShowNotification object:nil];
		
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidHide:)
		name:UIKeyboardWillHideNotification object:nil];
    
    [[GAI sharedInstance].defaultTracker sendView:@"ManualSetupViewController"];
}

- (void) viewDidDisappear:(BOOL)animated
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad || toInterfaceOrientation == UIInterfaceOrientationPortrait;
}

#pragma mark -

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    _activeField = textField;
}

- (void) textFieldDidEndEditing:(UITextField *)textField
{
	if (textField == [self usernameTextField]) {
		_username = [textField.text copy];
	}
	
	if (textField == [self passwordTextField]) {
		_password = [textField.text copy];
	}
	
	if (textField == [self syncKeyTextField]) {
		_secret = [textField.text copy];
	}
	
	if (textField == [self customServerTextField]) {
		_customServerURL = [textField.text copy];
	}
}

- (BOOL) textFieldShouldReturn: (UITextField*) textField {
    [textField resignFirstResponder];
    return YES;

//	NSLog(@"LOGGING IN WITH THE FOLLOWING:");
//	
//	NSLog(@" _username            = %@", _username);
//	NSLog(@" _password            = %@", _password);
//	NSLog(@" _secret              = %@", _secret);
//	NSLog(@" _customServerEnabled = %d", _customServerEnabled);
//	NSLog(@" _customServerURL     = %@", _customServerURL);

}

#pragma mark -

- (IBAction)login:(id)sender {
    if (!_username.length || !_password.length || !_secret.length
        || (_customServerEnabled && !_customServerURL.length))
        return;
    
    //do we have an internet connection?
	if (![weaveService canConnectToInternet])
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Login Failure", @"unable to login")
                                                        message: NSLocalizedString(@"No internet connection available", "no internet connection") delegate: self
                                              cancelButtonTitle: NSLocalizedString(@"OK", @"ok") otherButtonTitles: nil];
		[alert show];
	}
    
	//start spinner
	[self startLoginSpinner];
    
	// If we got a custom server then we configure it right away
	
	if (_customServerEnabled && [_customServerURL length] != 0) {
		[[NSUserDefaults standardUserDefaults] setBool: YES forKey: @"useCustomServer"];
		[[NSUserDefaults standardUserDefaults] setObject: _customServerURL forKey: @"customServerURL"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	} else {
		[[NSUserDefaults standardUserDefaults] setBool: NO forKey: @"useCustomServer"];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"customServerURL"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
    
	//we require the username to be lowercase, so we do it here on the way out
	NSDictionary* authDict = @{@"user": [[self usernameTextField].text lowercaseString],
                              @"pass": [self passwordTextField].text,
                              @"secret": [self syncKeyTextField].text};
    
	NSThread* authorizer = [[NSThread alloc] initWithTarget:self selector:@selector(authorize:) object:authDict];
	[authorizer start];

}

- (IBAction)customServerSwitchChangedValue: (UISwitch*)sender {
	if (sender.on) {
		[self customServerTextField].placeholder = NSLocalizedString(@"Required", @"Required");
	} else {
		[self customServerTextField].placeholder = nil;
	}
	
	_customServerEnabled = sender.on;
}

@end
