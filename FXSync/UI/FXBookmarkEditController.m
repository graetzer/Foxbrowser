//
//  FXBookmarkEditController.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 02.10.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import "FXBookmarkEditController.h"
#import "FXFolderSelectorController.h"
#import "FXSyncStock.h"

#define TAG_OFFSET 232314

@implementation FXBookmarkEditController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.tableView registerClass:[UITableViewHeaderFooterView class] forHeaderFooterViewReuseIdentifier:@"HeaderIdentifier"];
//    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
//                                                                                           target:self
//                                                                                           action:@selector(_saveData)];
    if ([[_bookmark type] isEqualToString:@"folder"]) {
        self.title = NSLocalizedString(@"Edit Folder", @"Edit Bookmark Folder");
    } else {
        self.title = NSLocalizedString(@"Edit", @"Edit something");
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_bookmark save];
}

#pragma mark - UITableViewDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ([[_bookmark type] isEqualToString:@"folder"]) {
        return 1;
    } else if ([[_bookmark type] isEqualToString:@"bookmark"]) {
        return section == 0 ? 2 : 1;
    } else if ([[_bookmark type] isEqualToString:@"livemark"]) {
        return section == 0 ? 3 : 1;
    }
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 40;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    static NSString *headerReuseIdentifier = @"HeaderIdentifier";
    
    UITableViewHeaderFooterView *header = [tableView dequeueReusableHeaderFooterViewWithIdentifier:headerReuseIdentifier];
    
    if (section == 0) {
        header.textLabel.text = NSLocalizedString(@"Information",
                                                  @"Information");
    } else if (section == 1) {
        header.textLabel.text = NSLocalizedString(@"Containing Folder",
                                                  @"Location of Bookmark");
    }
    
    return header;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        static NSString *CellIdentifier = @"FIELD_CELL";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                          reuseIdentifier:CellIdentifier];
        }
        
        UITextField *field = (UITextField *)[cell viewWithTag:indexPath.row + TAG_OFFSET];
        if (field == nil) {
            CGRect frame = CGRectInset(cell.contentView.bounds, 20, 0);
            field = [[UITextField alloc] initWithFrame:frame];
            field.tag = indexPath.row + TAG_OFFSET;
            field.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
            [cell.contentView addSubview:field];
        }
        
        cell.accessoryType = UITableViewCellAccessoryNone;
        if (indexPath.row == 0) {
            field.placeholder = NSLocalizedString(@"Name", @"Name of the Bookmark");
            field.text = [_bookmark title];
        } else {
            if ([[_bookmark type] isEqualToString:@"bookmark"] && indexPath.row == 1) {
                field.placeholder = NSLocalizedString(@"Website URL", @"URL of Bookmark");
                field.text = [_bookmark bmkUri];
            } else if ([[_bookmark type] isEqualToString:@"livemark"]) {
                if (indexPath.row == 1) {// Feed-Url
                    field.placeholder = NSLocalizedString(@"Feed-URL", @"URL of RSS Feed");
                    field.text = [_bookmark feedUri];
                } else if (indexPath.row == 2) {//Website-URL
                    field.autocorrectionType = UITextAutocorrectionTypeNo;
                    field.spellCheckingType = UITextSpellCheckingTypeNo;
                    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
                    field.placeholder = NSLocalizedString(@"Website URL", @"URL of Bookmark");
                    field.text = [_bookmark siteUri];
                }
            }
        }
        return cell;
    } else  {// if (indexPath.section == 1)
        static NSString *CellIdentifier = @"FOLDER_CELL";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                          reuseIdentifier:CellIdentifier];
        }
        cell.textLabel.text = [_bookmark parentName];
        cell.imageView.image = [UIImage imageNamed:@"folder"];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    FXFolderSelectorController *chooser = [FXFolderSelectorController new];
    chooser.bookmark = _bookmark;
    [self.navigationController pushViewController:chooser animated:YES];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    NSUInteger row = textField.tag - TAG_OFFSET;
    
    // First one should always be the title
    if (row == 0) {
        [_bookmark setTitle:textField.text];
    } else {
        if ([[_bookmark type] isEqualToString:@"folder"]) {
            // Nothing except title field
        } else if ([[_bookmark type] isEqualToString:@"bookmark"] && row == 1) {
            // No textfield except the url
            [_bookmark setBmkUri:textField.text];
        } else if ([[_bookmark type] isEqualToString:@"livemark"]) {
            if (row == 1) {// Feed-Url
                [_bookmark setFeedUri:textField.text];
            } else if (row == 2) {//Website-URL
                [_bookmark setSiteUri:textField.text];
            }
        }
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    return YES;
}

@end
