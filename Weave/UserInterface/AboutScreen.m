//
//  AboutScreen.m
//  Weave
//
//  Created by Dan Walkowski on 6/24/10.
//  Copyright 2010 ClownWare. All rights reserved.
//

#import "AboutScreen.h"
#import "WeaveService.h"
#import "Stockboy.h"
#import "SGAppDelegate.h"
#import "LogoutController.h"
#import "SGBrowserViewController.h"

@implementation AboutScreen

- (IBAction) termsOfService
{  
  if ([weaveService canConnectToInternet])
  {
      //[[appDelegate settings] dismissModalViewControllerAnimated:NO];

      NSString* destString = [Stockboy getURIForKey:@"TOS URL"];
      [appDelegate.browserViewController handleURLString:destString title:@"Terms of Service"];
      [self.parentViewController dismissViewControllerAnimated:YES completion:NULL];
  }
  else 
  {
    //no connectivity, put up alert
    NSDictionary* errInfo = @{@"title": NSLocalizedString(@"Cannot Load Page", @"unable to load page"), 
                             @"message": NSLocalizedString(@"No internet connection available", "no internet connection")};
    [appDelegate performSelectorOnMainThread:@selector(reportErrorWithInfo:) withObject:errInfo waitUntilDone:NO];      
  }
}

- (IBAction) privacyPolicy
{
  if ([weaveService canConnectToInternet])
  {    
    NSString* destString = [Stockboy getURIForKey:@"PP URL"];
      [appDelegate.browserViewController handleURLString:destString title:@"Privacy policy"];
      [self.parentViewController dismissViewControllerAnimated:YES completion:NULL];
  }
  else {
    //no connectivity, put up alert
    NSDictionary* errInfo = @{@"title": NSLocalizedString(@"Cannot Load Page", @"unable to load page"), 
                             @"message": NSLocalizedString(@"No internet connection available", "no internet connection")};
    [appDelegate performSelectorOnMainThread:@selector(reportErrorWithInfo:) withObject:errInfo waitUntilDone:NO];      
  }  
}

- (IBAction) signOut:(id)sender
{
	LogoutController* logoutController = [LogoutController new];
	if (logoutController != nil) {
        [self.navigationController pushViewController:logoutController animated:YES];
	}
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedString(@"Foxbrowser", @"app name");
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Sign Out", @"de-authenticate")
                                                                              style:UIBarButtonItemStyleDone
                                                                             target:self action:@selector(signOut:)];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad || toInterfaceOrientation == UIInterfaceOrientationPortrait;
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


@end
