//
//  SGSearchBar.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 10.08.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import "SGSearchBar.h"

@implementation SGSearchBar

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.placeholder = NSLocalizedString(@"Enter URL or search query here", nil);
        self.keyboardType = UIKeyboardTypeASCIICapable;
        self.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }
    return self;
}

- (UIView *)inputAccessoryView {
    if (!_inputAccessory) {
        _inputAccessory = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.superview.bounds.size.width, 44.)];
        _inputAccessory.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        UIBarButtonItem *btn, *flex, *fix;
        flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                             target:nil action:nil];
        fix = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                                            target:nil action:nil];
        fix.width = 10;
        
        NSArray *titles = @[@":", @"/", @"-", @".com", @".net"];
        NSMutableArray *buttons = [NSMutableArray arrayWithCapacity:titles.count];
        [buttons addObject:flex];
        for (NSString *title in titles) {
            btn = [[UIBarButtonItem alloc] initWithTitle:title
                                                  style:UIBarButtonItemStyleBordered
                                                 target:self
                                                 action:@selector(addText:)];
            btn.width = 40.;
            [buttons addObject:btn];
            [buttons addObject:fix];
        }
        [buttons addObject:flex];
        _inputAccessory.items = buttons;
    }
    return _inputAccessory;
}

- (IBAction)addText:(UIBarButtonItem *)sender {
    self.text = [self.text stringByAppendingString:sender.title];
}

@end
