//
//  DDAlertPrompt.m
//  DDAlertPrompt (Released under MIT License)
//
//  Created by digdog on 10/27/10.
//  Copyright 2010 Ching-Lan 'digdog' HUANG. http://digdog.tumblr.com
//
//  Permission is hereby granted, free of charge, to any person obtaining
//  a copy of this software and associated documentation files (the
//  "Software"), to deal in the Software without restriction, including
//  without limitation the rights to use, copy, modify, merge, publish,
//  distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to
//  the following conditions:
//   
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//   
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
//  LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
//  OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
//  WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "DDAlertPrompt.h"
#import <QuartzCore/QuartzCore.h>

@interface DDAlertPrompt () 
@property(nonatomic, retain) UITableView *tableView;
@property(nonatomic, retain) UITextField *plainTextField;
@property(nonatomic, retain) UITextField *secretTextField;
- (void)orientationDidChange:(NSNotification *)notification;
@end


@implementation DDAlertPrompt

@synthesize tableView = tableView_;
@synthesize plainTextField = plainTextField_;
@synthesize secretTextField = secretTextField_;

/*
-(BOOL)_needsKeyboard {
	// Private API hack by @0xced (Cedric Luthi) for possible keyboard responder issue: http://twitter.com/0xced/status/29067229352
	return [UIDevice instancesRespondToSelector:@selector(isMultitaskingSupported)];
}
*/

- (id)initWithTitle:(NSString *)title delegate:(id /*<UIAlertViewDelegate>*/)delegate cancelButtonTitle:(NSString *)cancelButtonTitle otherButtonTitle:(NSString *)otherButtonTitles {

	if ((self = [super initWithTitle:title message:@"\n\n\n" delegate:delegate cancelButtonTitle:cancelButtonTitle otherButtonTitles:otherButtonTitles, nil])) {
		// FIXME: This is a workaround. By uncomment below, UITextFields in tableview will show characters when typing (possible keyboard reponder issue).
		[self addSubview:self.plainTextField];

		tableView_ = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
		tableView_.delegate = self;
		tableView_.dataSource = self;		
		tableView_.scrollEnabled = NO;
		tableView_.opaque = NO;
		tableView_.layer.cornerRadius = 3.0f;
		tableView_.editing = YES;
		tableView_.rowHeight = 28.0f;
		[self addSubview:tableView_];
								
			}
	return self;
}

- (void)didMoveToSuperview {
    if (self.superview) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationDidChange:) name:UIDeviceOrientationDidChangeNotification object:nil];
		[[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    } else {
        [tableView_ setDataSource:nil];
        [tableView_ setDelegate:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
        [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    }
}

#pragma mark layout

- (void)layoutSubviews {
	// We assume keyboard is on.
	if ([[UIDevice currentDevice] isGeneratingDeviceOrientationNotifications]) {
        self.tableView.frame = CGRectMake(12.0f, 51.0f, 260.0f, 56.0f);	
//		if (UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation])) {
//			//self.center = CGPointMake(160.0f, (460.0f - 216.0f)/2 + 12.0f);
//			self.tableView.frame = CGRectMake(12.0f, 51.0f, 260.0f, 56.0f);		
//		} else {
//			//self.center = CGPointMake(240.0f, (300.0f - 162.0f)/2 + 12.0f);
//			self.tableView.frame = CGRectMake(12.0f, 35.0f, 260.0f, 56.0f);		
//		}
	}
}

- (void)orientationDidChange:(NSNotification *)notification {
	[self setNeedsLayout];
}

#pragma mark Accessors

- (UITextField *)plainTextField {

	if (!plainTextField_) {
		plainTextField_ = [[UITextField alloc] initWithFrame:CGRectMake(5.0f, 0.0f, 255.0f, 28.0f)];
		plainTextField_.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
		plainTextField_.clearButtonMode = UITextFieldViewModeWhileEditing;
		plainTextField_.placeholder = NSLocalizedString(@"Account", @"Account");
        plainTextField_.spellCheckingType = UITextSpellCheckingTypeNo;
	}
	return plainTextField_;
}

- (UITextField *)secretTextField {
	
	if (!secretTextField_) {
		secretTextField_ = [[UITextField alloc] initWithFrame:CGRectMake(5.0f, 0.0f, 255.0f, 28.0f)];
		secretTextField_.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
		secretTextField_.secureTextEntry = YES;
		secretTextField_.clearButtonMode = UITextFieldViewModeWhileEditing;
		secretTextField_.placeholder = NSLocalizedString(@"Password", @"Password");
        secretTextField_.spellCheckingType = UITextSpellCheckingTypeNo;
	}
	return secretTextField_;
}

#pragma mark UITableViewDataSource & UITableViewDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

	static NSString *AlertPromptCellIdentifier = @"DDAlertPromptCell";

    UITableViewCell *cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:AlertPromptCellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:AlertPromptCellIdentifier];
    }
	
	if (![cell.contentView.subviews count]) {
		if (indexPath.row) {
			[cell.contentView addSubview:self.secretTextField];			
		} else {
			[cell.contentView addSubview:self.plainTextField];
		}		
	}
    return cell;	
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleNone;
}

@end
