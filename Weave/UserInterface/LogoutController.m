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

#import "LogoutController.h"
#import "Store.h"
#import "CryptoUtils.h"
#import "Stockboy.h"
#import "WelcomePage.h"
#import "DejalActivityView.h"
#import "SGAppDelegate.h"
#import "SGBrowserViewController.h"

@implementation LogoutController

//this is the code run by the new thread we make to wait on the stockboy
- (void) waitForStockboy {
    @autoreleasepool {
        [weaveService performSelectorOnMainThread:@selector(changeProgressSpinnersMessage:) withObject:@"stopping" waitUntilDone:YES];
        
        //wait on the stockboy
        NSCondition *syncLock = [Stockboy syncLock];
        [syncLock lock];
        [Stockboy cancel]; //ask him to stop syncing
        while ([Stockboy syncInProgress]) [syncLock wait];
        [syncLock signal];
        [syncLock unlock];
        
        //erase the data
        [weaveService performSelectorOnMainThread:@selector(eraseAllUserData) withObject:nil waitUntilDone:YES];
        [self performSelectorOnMainThread:@selector(loginAgain) withObject:nil waitUntilDone:YES];
    }
}


- (void) loginAgain {
//    NSUInteger c = appDelegate.browserViewController.count;
//    for (NSUInteger i = 0;i < c; i++) {
//        [appDelegate.browserViewController removeIndex:i];
//    }
    [self.parentViewController dismissViewControllerAnimated:YES completion:^{
        [DejalBezelActivityView removeViewAnimated:YES];
        [appDelegate.browserViewController saveCurrentTabs];
        [appDelegate login];
    }];
}

- (IBAction) logout:(id)sender {
    [DejalBezelActivityView activityViewForView:self.view.window withLabel:@""];
    
  //fire the background thread to wait on the stockboy.
  NSThread* loiterer = [[NSThread alloc] initWithTarget:self selector:@selector(waitForStockboy) object:nil];
  [loiterer start];
  
	// Workaround for #602419 - If the wifi is turned off, it acts as if a blank account is signed in
	//
	// This is a workaround for the above code. The problem is that when the user logs out and then exits the
	// app before either the current sync is done and the above waitForStockBoy code has fired, the app will
	// be in a weird state. (We have to wait because there is no cancellation mechanism in the current
	// thread-based networking code)
	//
	// So what we do as a workaround is mark the user as being logged out. Then when the app starts and it
	// sees this flag being set, it will simply reset the app. This is not great because it means that even
	// after the user logs out, his data is still on the device. Ugly but it does the trick for now.
	
	[[NSUserDefaults standardUserDefaults] setBool: YES forKey: @"needsFullReset"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)viewDidLoad {
    self.title = NSLocalizedString(@"Foxbrowser", @"app name");
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad || toInterfaceOrientation == UIInterfaceOrientationPortrait;
}


@end
