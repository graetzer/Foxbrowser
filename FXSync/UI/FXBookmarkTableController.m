//
//  FXBookmarkTableController.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 02.10.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import "FXBookmarkTableController.h"
#import "FXBookmarkEditController.h"

#import "FXSyncStore.h"
#import "FXSyncStock.h"

@implementation FXBookmarkTableController

- (void)viewDidLoad {
    [super viewDidLoad];
    if (self.title == nil) {
        if (_parentFolder != nil) {
            self.title = [_parentFolder title];
        } else {
            self.title = NSLocalizedStringFromTable(@"Bookmarks", @"FXSync", @"Bookmarks");
        }
    }
    
    if (![_parentFolder.syncId isEqualToString:@"history"]) {
        self.tableView.allowsSelectionDuringEditing = YES;
    }
    self.clearsSelectionOnViewWillAppear = NO;
    [self _updateToolbar:self.editing animated:NO];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                               target:self
                                                                                               action:@selector(_dismiss:)];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_refresh)
                                                 name:kFXDataChangedNotification
                                               object:nil];
    [self _refresh];
    if (_parentFolder != nil) {
        [self.navigationController setToolbarHidden:NO animated:YES];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setToolbarHidden:YES animated:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    
    if (self.navigationItem.rightBarButtonItem != nil) {
        self.navigationItem.rightBarButtonItem.enabled = !editing;
    }
    [self _updateToolbar:editing animated:animated];
}

#pragma mark - Helpers

- (void)_refresh {
    if (_parentFolder == nil) {
        _bookmarks = [[FXSyncStock sharedInstance] topBookmarkFolders];
    } else if ([_parentFolder.syncId length]
               && ![_parentFolder.collection isEqualToString:kFXHistoryCollectionKey]) {
        _bookmarks = [[FXSyncStock sharedInstance] bookmarksWithParentFolder:_parentFolder];
    }
    [self.tableView reloadData];
}

/*! Update the toolbar depending on the state */
- (void)_updateToolbar:(BOOL)editing animated:(BOOL)animated {
    // Do not show on topmost level
    if (_parentFolder != nil) {
        UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                               target:nil action:nil];
        UIBarButtonItem *folder = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringFromTable(@"New Folder",
                                                                                                    @"FXSync", @"Create a new folder")
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:self
                                                                  action:@selector(_addFolder:)];
        
        // You can't add folders in the user's history
        if (editing && ![_parentFolder.syncId isEqualToString:@"history"]) {
            [self setToolbarItems:@[folder, space, self.editButtonItem] animated:animated];
        } else {
            [self setToolbarItems:@[space, self.editButtonItem] animated:animated];
        }
    }
}

- (IBAction)_dismiss:(id)sender {
    [self.parentViewController dismissViewControllerAnimated:YES completion:NULL];
}

- (IBAction)_addFolder:(id)sender {
    if (_parentFolder != nil) {
        FXBookmarkEditController *edit = [FXBookmarkEditController new];
        edit.bookmark = [[FXSyncStock sharedInstance] newFolderWithParent:_parentFolder];
        [self.navigationController pushViewController:edit animated:YES];
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return _parentFolder == nil ? 2 : 1;
    
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (_parentFolder == nil && section == 0) {
        return 1;
    } else {
        return [_bookmarks count];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"URL_CELL";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    // Let's see if we display the top most folders, and need to show the history
    if (_parentFolder == nil && indexPath.section == 0) {
        NSString *title = NSLocalizedStringFromTable(@"History", @"FXSync", @"History");
        cell.textLabel.text = title;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.imageView.image = [UIImage imageNamed:@"history"];
        return cell;
    } else {
        FXSyncItem *item = _bookmarks[indexPath.row];
        cell.textLabel.text = [item title];
        
        // Just in case we display an history item
        if ([item.collection isEqualToString:kFXHistoryCollectionKey]) {
            cell.imageView.image = [UIImage imageNamed:@"history"];
            if ([cell.textLabel.text length] == 0) {
                cell.textLabel.text = [item histUri];
            }
        } else {// A bookmark record
            // In any other case the bookmark has a type field
            // We should have a corresponding image for that
            cell.imageView.image = [UIImage imageNamed:[item type]];
            
            if ([[item type] isEqualToString:@"folder"]) {
                cell.detailTextLabel.text = nil;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            } else {
                cell.detailTextLabel.text = [item bmkUri];
                cell.accessoryType = UITableViewCellAccessoryNone;
            }

        }
        return cell;
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return _parentFolder != nil;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath {
    // Make sure we are not removing top level objects
    if (editingStyle == UITableViewCellEditingStyleDelete
        && _parentFolder != nil) {
        
        FXSyncItem *item = _bookmarks[indexPath.row];
        if ([_parentFolder.syncId isEqualToString:@"history"]) {
            [[FXSyncStock sharedInstance] deleteHistoryItem:item];
            _bookmarks = [FXSyncStock sharedInstance].history;
        } else {
            
            [[FXSyncStock sharedInstance] deleteBookmark:item];
            NSMutableArray *arr = [_bookmarks mutableCopy];
            [arr removeObjectAtIndex:indexPath.row];
            _bookmarks = arr;
        }
        
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (_parentFolder == nil && indexPath.section == 0) {
        FXBookmarkTableController *table = [FXBookmarkTableController new];
        table.title = NSLocalizedStringFromTable(@"History", @"FXSync", @"History Label");
        // Workaround, so that this is treated as subfolder
        table.parentFolder = [FXSyncItem new];
        table.parentFolder.collection = kFXHistoryCollectionKey;
        table.bookmarks = [FXSyncStock sharedInstance].history;
        [self.navigationController pushViewController:table animated:YES];
    
    } else {
        FXSyncItem *item = _bookmarks[indexPath.row];
        
        if (self.editing) {
            // Editing shouldn't be possible on the top level
            if (_parentFolder != nil) {
                FXBookmarkEditController *edit = [FXBookmarkEditController new];
                edit.bookmark = item;
                [self.navigationController pushViewController:edit animated:YES];
            }
            
        } else if ([[item type] isEqual:@"folder"]) {
            FXBookmarkTableController *table = [FXBookmarkTableController new];
            table.parentFolder = item;
            [self.navigationController pushViewController:table animated:YES];
            
        }
//        else if ([[item type] isEqual:@"livemark"]) {
//            // TODO
//        }
        else {
            NSString *uri = [item urlString];
            if ([uri length] > 0) {
                NSString *title = [item title] ? [item title] : @"";
                [[NSNotificationCenter defaultCenter] postNotificationName:kFXOpenURLNotification
                                                                    object:self
                                                                  userInfo:@{@"title":title, @"uri":uri}];
                
                if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
                    [self.parentViewController dismissViewControllerAnimated:YES completion:NULL];
                }
                [tableView deselectRowAtIndexPath:indexPath animated:YES];
            }
            
        }
    }
}

@end
