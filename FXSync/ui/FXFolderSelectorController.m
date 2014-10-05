//
//  FXFolderTableViewController.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 05.10.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import "FXFolderSelectorController.h"
#import "FXSyncStock.h"

@implementation FXFolderSelectorController {
    NSMutableArray *_folders;
    FXSyncItem *_currentFolder;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _folders = [NSMutableArray arrayWithCapacity:40];
    [self _addFolders:[[FXSyncStock sharedInstance] topBookmarkFolders] depth:0];
}

- (void)_addFolders:(NSArray *)bookmarks depth:(NSUInteger)dp {
    for (FXSyncItem *folder in bookmarks) {
        if ([[folder type] isEqualToString:@"folder"]) {
            [_folders addObject:@{@"depth":@(dp), @"folder":folder}];
            if ([_bookmark.parentid isEqualToString:folder.syncId]) {
                _currentFolder = folder;
            }
            
            NSArray *subs = [[FXSyncStock sharedInstance] bookmarksWithParentFolder:folder];
            [self _addFolders:subs depth:dp+1];
        }
    }
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_folders count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"SELECTOR_CELL";
    
    FXFolderSelectorCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[FXFolderSelectorCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    NSDictionary *info = _folders[indexPath.row];
    FXSyncItem *folder = info[@"folder"];
    cell.textLabel.text = [folder title];
    cell.indentationLevel = [info[@"depth"] integerValue];
    cell.indentationWidth = 20;
    cell.imageView.image = [UIImage imageNamed:@"folder"];
    
    if ([[_bookmark parentid] isEqualToString:folder.syncId]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *info = _folders[indexPath.row];
    FXSyncItem *folder = info[@"folder"];
    
    [_bookmark setParentid:folder.syncId];
    [_bookmark setParentName:[folder title]];
    [_currentFolder.jsonPayload[@"children"] removeObject:_bookmark.syncId];
    [folder.jsonPayload[@"children"] addObject:_bookmark.syncId];
    
    [_bookmark save];
    [_currentFolder save];
    [folder save];
    
    [self.navigationController popViewControllerAnimated:YES];
}

@end

@implementation FXFolderSelectorCell

- (void)layoutSubviews
{
    // Call super
    [super layoutSubviews];
    
    // Update the separator
    self.separatorInset = UIEdgeInsetsMake(0, (self.indentationLevel * self.indentationWidth) + 15, 0, 0);
    
    // Update the frame of the image view
    self.imageView.frame = CGRectMake(self.imageView.frame.origin.x + (self.indentationLevel * self.indentationWidth), self.imageView.frame.origin.y,
                                      self.imageView.frame.size.width, self.imageView.frame.size.height);
    
    // Update the frame of the text label
    self.textLabel.frame = CGRectMake(self.imageView.frame.origin.x + 40, self.textLabel.frame.origin.y,
                                      self.frame.size.width - (self.imageView.frame.origin.x + 60), self.textLabel.frame.size.height);
    
    // Update the frame of the subtitle label
    self.detailTextLabel.frame = CGRectMake(self.imageView.frame.origin.x + 40, self.detailTextLabel.frame.origin.y,
                                            self.frame.size.width - (self.imageView.frame.origin.x + 60), self.detailTextLabel.frame.size.height);
}

@end