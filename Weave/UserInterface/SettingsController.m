/***** BEGIN LICENSE BLOCK *****
 Version: MPL 1.1/GPL 2.0/LGPL 2.1
 
 The contents of this file are subject to the Mozilla Public License Version 
 1.1 (the "License"); you may not use this file except in compliance with 
 the License. You may obtain a copy of the License at 
 http://www.mozilla.org/MPL/
 
 Software distributed under the License is distributed on an "AS IS" basis,
 WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 for the specific language governing rights and limitations under the
 License.
 
 The Original Code is weave-iphone.
 
 The Initial Developer of the Original Code is Mozilla Labs.
 Portions created by the Initial Developer are Copyright (C) 2009
 the Initial Developer. All Rights Reserved.
 
 Contributor(s):
 Anant Narayanan <anant@kix.in>
 Dan Walkowski <dwalkowski@mozilla.com>

 Alternatively, the contents of this file may be used under the terms of either
 the GNU General Public License Version 2 or later (the "GPL"), or the GNU
 Lesser General Public License Version 2.1 or later (the "LGPL"), in which case
 the provisions of the GPL or the LGPL are applicable instead of those above.
 If you wish to allow use of your version of this file only under the terms of
 either the GPL or the LGPL, and not to allow others to use your version of
 this file under the terms of the MPL, indicate your decision by deleting the
 provisions above and replace them with the notice and other provisions
 required by the GPL or the LGPL. If you do not delete the provisions above, a
 recipient may use your version of this file under the terms of any one of the
 MPL, the GPL or the LGPL.
 
	 ***** END LICENSE BLOCK *****/

#import "SettingsController.h"
#import "WeaveService.h"
#import "Store.h"
#import "Stockboy.h"
#import "AboutScreen.h"
#import "KeychainItemWrapper.h"
#import "LogoutController.h"

#import "SGPreviewPanel.h"
#import "UIWebView+WebViewAdditions.h"

@implementation SettingsController

@synthesize contentView;

@synthesize spinner;
@synthesize spinMessage;

@synthesize userName;

@synthesize numTabs;
@synthesize numBmks;
@synthesize numHist;

@synthesize syncButton;

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refresh)
                                                 name:kWeaveDataRefreshNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(syncStatusChanged:)
                                                 name:kWeaveSyncStatusChangedNotification
                                               object:nil];
}


- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) refresh
{
	//clear out the old info
	userName.text = nil;
	numTabs.text = nil;
	numBmks.text = nil;
	numHist.text = nil;

	// The CryptoUtils#getManager only works if we have a network connection. So we take a different approach here
	// and simply directly grab the info that we need without using CryptoUtils. This is ok here since the Settings
	// screen will only show if the user was logged in before and we have credentials stored in the KeyChain.

	KeychainItemWrapper *credentials = [[KeychainItemWrapper alloc] initWithIdentifier:CREDENTIALS_NAME accessGroup:nil];
	if (credentials != nil) {
		userName.text = [credentials objectForKey: (__bridge id) kSecAttrAccount];
	}

	int totalTabs = 0;
	for (NSDictionary* client in [[Store getStore] getTabs]) {
		totalTabs += [[client objectForKey:@"tabs"] count];
	}

	numTabs.text = [NSString stringWithFormat: @"%d", totalTabs];
	numBmks.text = [NSString stringWithFormat: @"%d", [[[Store getStore] getBookmarks] count]];
	numHist.text = [NSString stringWithFormat: @"%d", [[[Store getStore] getHistory] count]];
}

- (void)syncStatusChanged:(NSNotification *)note {
    NSString *message = [note.userInfo objectForKey:kWeaveMessageKey];
    if (message.length) {
        if (self.spinner.hidden)
            [self startSpinnerWithMessage:message];
        else
            [self changeSpinnerMessage:message];
    } else {
        [self stopSpinner];
    }
}

- (void)viewDidLoad 
{
	[super viewDidLoad];

	//magic incantation that fixes resizing on rotate
	self.view.autoresizesSubviews = YES;
	self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    self.title = NSLocalizedString(@"Settings", @"Settings");
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Sign Out", @"de-authenticate") 
                                                                             style:UIBarButtonItemStyleBordered
                                                                            target:self action:@selector(signOut:)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] 
                                              initWithBarButtonSystemItem:UIBarButtonSystemItemCancel 
                                              target:self action:@selector(cancel)];

	[self refresh];
}

- (IBAction) resync:(id)sender
{
	if ([Stockboy syncInProgress])
	{
		[Stockboy cancel];
	}
	else 
	{
		[Stockboy restock];
	}
}

- (IBAction) displayAboutScreen:(id)sender;
{
	AboutScreen* aboutScreen = [AboutScreen new];
	if (aboutScreen != nil) {
		[self.navigationController pushViewController:aboutScreen animated:YES];
	}
}

- (IBAction)resetStartscreen:(id)sender {
    [[NSFileManager defaultManager] removeItemAtPath:[SGPreviewPanel blacklistFilePath] error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[UIWebView screenshotPath] error:NULL];
    [weaveService refreshViews];
}


- (IBAction) signOut:(id)sender
{
	LogoutController* logoutController = [LogoutController new];
	if (logoutController != nil) {
        [self.navigationController pushViewController:logoutController animated:YES];
	}
}


//called on main thread by the stockboy background thread
- (void) startSpinnerWithMessage: (NSString*)msg
{
	//hide the button, show the label, animate the spinner
	[self.spinner startAnimating];
	self.spinMessage.text = msg;
	[self.spinMessage setHidden:NO];

	//and also change the Refresh Button to 'Stop Refresh'
	[syncButton setTitle:NSLocalizedString(@"Stop", @"stop refreshing data") forState:UIControlStateNormal];
	[syncButton setBackgroundImage: [UIImage imageNamed: @"button-stop.png"] forState: UIControlStateNormal];
	[syncButton setBackgroundImage: [UIImage imageNamed: @"button-stop-pressed.png"] forState: UIControlStateHighlighted];
}

- (void) changeSpinnerMessage: (NSString*)msg
{
	self.spinMessage.text = msg;
}

//called on main thread by the stockboy background thread
- (void) stopSpinner
{
	//hide the label, show the button, stop the spinner
	[self.spinner stopAnimating];
	[self.spinMessage setHidden:YES];

	//change the button back to 'Refresh'
	[syncButton setTitle:NSLocalizedString(@"Refresh", @"refresh local data") forState:UIControlStateNormal];
	[syncButton setBackgroundImage: [UIImage imageNamed: @"button-medium-default.png"] forState: UIControlStateNormal];
	[syncButton setBackgroundImage: [UIImage imageNamed: @"button-medium-pressed.png"] forState: UIControlStateHighlighted];
}

- (IBAction) cancel
{
	[self dismissModalViewControllerAnimated: YES];
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	self.contentView = nil;
    self.spinner = nil;
    self.spinMessage = nil;
    self.userName = nil;
    self.numTabs = nil;
    self.numBmks = nil;
    self.numHist = nil;
    self.syncButton = nil;
    [super viewDidUnload];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad || toInterfaceOrientation == UIInterfaceOrientationPortrait;
}

@end
