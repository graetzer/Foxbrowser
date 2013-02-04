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

#import "NSURL+IFUnicodeURL.h"
#import "BookmarkPage.h"
#import "WeaveService.h"
#import "Store.h"
#import "SGBrowserViewController.h"

@implementation BookmarkPage

-(void) setParent:(NSString *)parent
{
  parentid = parent;
}

- (void)viewDidLoad {
  [super viewDidLoad];
    self.title = NSLocalizedString(@"Bookmarks", @"Bookmarks");
  self.view.autoresizesSubviews = YES;
  self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  self.contentSizeForViewInPopover = CGSizeMake(320., 660.);
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                              target:self
                                                                                               action:@selector(dismiss:)];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self.tableView
                                             selector:@selector(reloadData)
                                                 name:kWeaveDataRefreshNotification
                                               object:nil];
}


- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self.tableView];
}

- (void) refresh
{
  [self.tableView reloadData];
}

- (NSUInteger)supportedInterfaceOrientations {
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskAllButUpsideDown;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad || toInterfaceOrientation == UIInterfaceOrientationPortrait;
}

- (IBAction)dismiss:(id)sender {
    [self.parentViewController dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
  if (parentid == nil)  //top level bookmarks
  {
    topLevelBookmarks = [NSMutableArray arrayWithCapacity:4];
    
    [topLevelBookmarks addObject: [[Store getStore] getBookmarksWithParent:@"toolbar"]];
    [topLevelBookmarks addObject: [[Store getStore] getBookmarksWithParent:@"menu"]];
    [topLevelBookmarks addObject: [[Store getStore] getBookmarksWithParent:@"mobile"]];
    [topLevelBookmarks addObject: [[Store getStore] getBookmarksWithParent:@"unfiled"]];
    
    return 4;    
  }
  else //bookmark sub-directory
  {
    bookmarks = [[Store getStore] getBookmarksWithParent:parentid];
    
    return 1;
  }

}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
  if (parentid == nil)
  {
    switch (section) {
      case 0:
        if ([topLevelBookmarks[0] count]) return NSLocalizedString(@"Bookmarks Toolbar", @"bookmarks toolbar");
        return nil;
      case 1:
        if ([topLevelBookmarks[1] count]) return NSLocalizedString(@"Bookmarks Menu", @"bookmarks menu");
        return nil;
      case 2:
        if ([topLevelBookmarks[2] count]) return NSLocalizedString(@"Mobile Bookmarks", @"mobile bookmarks");
        return nil;        
      case 3:
        if ([topLevelBookmarks[3] count]) return NSLocalizedString(@"Unsorted Bookmarks", @"unsorted bookmarks");
        return nil;
        
      default:
        return nil;
    }
  }
  return nil;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
  if (parentid == nil)
  {
    return [topLevelBookmarks[section] count];

  }
  else {
    return [bookmarks count];
  }

}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
  //NOTE: I'm now sharinf table view cells across the app
  static NSString *CellIdentifier = @"URL_CELL";
  
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
  if (cell == nil) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
  }
  
  NSDictionary* bookmarkItem = nil;
  if (parentid == nil)
  {
    bookmarkItem = topLevelBookmarks[indexPath.section][indexPath.row];
  }
  else 
  {
    bookmarkItem = bookmarks[indexPath.row];
  }
  
  cell.textLabel.text = bookmarkItem[@"title"];
  cell.detailTextLabel.text = bookmarkItem[@"url"]?bookmarkItem[@"url"]:nil;
  cell.accessoryType = UITableViewCellAccessoryNone;

  if ([bookmarkItem[@"type"] isEqualToString:@"folder"])
  {
    cell.imageView.image = [UIImage imageNamed:@"folder.png"];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
  }
  else 
  {
    //default
    cell.imageView.image = [UIImage imageNamed:bookmarkItem[@"icon"]];
  }
  
  return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	NSDictionary* bookmarkItem = nil;
	if (parentid == nil) {
		bookmarkItem = topLevelBookmarks[indexPath.section][indexPath.row];
	} else  {
		bookmarkItem = bookmarks[indexPath.row];
	}

	UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];

	if ([bookmarkItem[@"type"] isEqualToString:@"folder"])
	{
		BookmarkPage *newPage = [[BookmarkPage alloc] initWithNibName:nil bundle:nil];
        newPage.browser = self.browser;
		newPage.navigationItem.title = bookmarkItem[@"title"];
		[newPage setParent:bookmarkItem[@"id"]];

		[self.navigationController pushViewController: newPage animated:YES];
	}
	else  //bookmark
	{
		if ([weaveService canConnectToInternet])
		{
            [self.browser handleURLString: cell.detailTextLabel.text title: cell.textLabel.text];
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
                [self.parentViewController dismissViewControllerAnimated:YES completion:NULL];
		}
		else 
		{
			//no connectivity, put up alert
			NSDictionary* errInfo = @{@"title": NSLocalizedString(@"Cannot Load Page", @"unable to load page"), 
				@"message": NSLocalizedString(@"No internet connection available", "no internet connection")};
			[weaveService performSelectorOnMainThread:@selector(reportErrorWithInfo:) withObject:errInfo waitUntilDone:NO];      
		}
	}

	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end

