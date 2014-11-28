//
//  FXTabsViewController.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 02.10.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import "FXTabsViewController.h"
#import "FXSyncStock.h"

@implementation FXTabsViewController {
    NSArray *_clients;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.clearsSelectionOnViewWillAppear = NO;
    self.title = NSLocalizedStringFromTable(@"Tabs", @"FXSync", @"Tabs");
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_refresh)
                                                 name:kFXDataChangedNotification
                                               object:nil];
    [self _refresh];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)_refresh {
    _clients = [FXSyncStock sharedInstance].clientTabs;
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return MAX(_clients.count, 1);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ([_clients count] > 0) {
        FXSyncItem *client = _clients[section];
        return [client tabs].count;
    } else {
        return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if ([_clients count] > 0) {
        FXSyncItem *client = _clients[section];
        return [client clientName];
    } else {
        return NSLocalizedStringFromTable(@"No open Tabs found", @"FXSync", @"No open Tabs found");
    }
}

//Note: this table cell code is nearly identical to the same method in searchresults and bookmarks,
// but we want to be able to easily make them display differently, so it is replicated
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    //NOTE: I'm now sharing table view cells across the app
    static NSString *CellIdentifier = @"URL_CELL";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    FXSyncItem *client = _clients[indexPath.section];
    NSDictionary* tabItem = [client tabs][indexPath.row];
    
    cell.textLabel.text = tabItem[@"title"];
    cell.detailTextLabel.text = tabItem[@"urlHistory"][0];
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    NSURL *url;
    if (tabItem[@"icon"] != nil
        && (url  = [NSURL URLWithString:tabItem[@"icon"]]) != nil) {
        [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:url]
                                           queue:[NSOperationQueue mainQueue]
                               completionHandler:^(NSURLResponse *resp, NSData *data, NSError *err) {
                                   if (data != nil && err == nil) {
                                       
                                       // Make sure the cell was not reused
                                       if ([cell.textLabel.text isEqualToString:tabItem[@"title"]]) {
                                           UIImage *img = [UIImage imageWithData:data];
                                           cell.imageView.image = img;
                                       }
                                       
                                   }
                               }];
    }
    
    //set it to the default to start
//    cell.imageView.image = [UIImage imageNamed:tabItem[@"icon"]];
    
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
    
    if ([appDelegate canConnectToInternet]) {
        [appDelegate.browserViewController handleURLString:cell.detailTextLabel.text title:cell.textLabel.text];
    } else {
        //no connectivity, put up alert
        NSDictionary* errInfo = @{@"title": NSLocalizedStringFromTable(@"Cannot Load Page", @"FXSync", @"unable to load page"),
                                  @"message": NSLocalizedStringFromTable(@"No internet connection available", @"FXSync", "no internet connection")};
        [appDelegate performSelectorOnMainThread:@selector(reportErrorWithInfo:) withObject:errInfo waitUntilDone:NO];
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
