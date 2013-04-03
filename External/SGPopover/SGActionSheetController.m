//
//  SGActionSheetController.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 30.03.13.
//  Copyright (c) 2013 Simon Peter Grätzer. All rights reserved.
//

#import "SGActionSheetController.h"

#import "SGPopoverController.h"

@implementation SGActionSheetController {
    NSMutableArray *_titles;
    NSMutableArray *_callbacks;
}

- (id)init {
    if (self = [super initWithStyle:UITableViewStylePlain]) {
        _titles = [[NSMutableArray alloc] initWithCapacity:5];
        _callbacks = [[NSMutableArray alloc] initWithCapacity:5];
    }
    return self;
}

- (void)loadView {
    [super loadView];
    self.view.frame = CGRectMake(0, 0, 200, 250);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = nil;
    self.tableView.rowHeight = 50;
}

- (void)showWithTouch:(UIEvent*)senderEvent {
    self.popover = [[TSPopoverController alloc] initWithContentViewController:self];
    self.popover.popoverBaseColor = [UIColor whiteColor];
    self.popover.cornerRadius = 5;
    [self.popover showPopoverWithTouch:senderEvent];
}

- (void)showWithCell:(UITableViewCell*)senderCell {
    self.popover = [[TSPopoverController alloc] initWithContentViewController:self];
    self.popover.popoverBaseColor = [UIColor whiteColor];
    self.popover.cornerRadius = 5;
    [self.popover showPopoverWithCell:senderCell];
}

- (void)showWithRect:(CGRect)senderRect {
    self.popover = [[TSPopoverController alloc] initWithContentViewController:self];
    self.popover.popoverBaseColor = [UIColor whiteColor];
    self.popover.cornerRadius = 5;
    [self.popover showPopoverWithRect:senderRect];
}

- (void)dismissWithClickedButtonIndex:(NSInteger)buttonIndex animated:(BOOL)animated {
    void (^callback)(void);
    callback = _callbacks[buttonIndex];
    if (callback) {
        callback();
    }
    
    [self.popover dismissPopoverAnimated:animated];
    self.popover = nil;
}

- (void)addTitle:(NSString *)title callback:(void (^)(void))callback {
    [_titles addObject:title];
    [_callbacks addObject:[callback copy]];
    
    if ([self isViewLoaded]) {
        [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:_titles.count-1 inSection:0]]
                              withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _titles.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *Identifier = @"Default";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:Identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:Identifier];
        cell.textLabel.font = [UIFont systemFontOfSize:16];
    }
    cell.textLabel.text = _titles[indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self dismissWithClickedButtonIndex:indexPath.row animated:YES];
}

@end
