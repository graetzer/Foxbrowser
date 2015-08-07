//
//  ZPAlertView.m
//  AlertWithCompletion
//
//  Created by Zacharias Pasternack on 10/11/10.
//  Copyright 2010-2013 Fat Apps, LLC. All rights reserved.
//


#import "FillrAlertView.h"


@implementation FillrAlertView


@synthesize willPresentBlock;
@synthesize didPresentBlock;
@synthesize didCancelBlock;
@synthesize clickedButtonBlock;
@synthesize willDismissBlock;
@synthesize didDismissBlock;


- (void)show
{
	self.delegate = self;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationChangeStatus:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationChangeStatus:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    
	[super show];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    // This trick only works in iOS 6 and below
    if (self.showInVertical) {
        int buttonCount = 0;
        UIButton *button1;
        UIButton *button2;
        
        // first, iterate over all subviews to find the two buttons;
        // those buttons are actually UIAlertButtons, but this is a subclass of UIButton
        for (UIView *view in self.subviews) {
            if ([view isKindOfClass:[UIButton class]]) {
                ++buttonCount;
                if (buttonCount == 1) {
                    button1 = (UIButton *)view;
                } else if (buttonCount == 2) {
                    button2 = (UIButton *)view;
                }
            }
        }
        
        // make sure that button1 is as wide as both buttons initially are together
        button1.frame = CGRectMake(button1.frame.origin.x, button1.frame.origin.y, CGRectGetMaxX(button2.frame) - button1.frame.origin.x, button1.frame.size.height);
        
        // make sure that button2 is moved to the next line,
        // as wide as button1, and set to the same x-position as button1
        button2.frame = CGRectMake(button1.frame.origin.x, CGRectGetMaxY(button1.frame) + 10, button1.frame.size.width, button2.frame.size.height);
        
        // now increase the height of the (alert) view to make it look nice
        // (I know that magic numbers are not nice...)
        self.bounds = CGRectMake(0, 0, self.bounds.size.width, CGRectGetMaxY(button2.frame) + 15);
    }
}

- (void)applicationChangeStatus:(NSNotification *)notification
{
    [super dismissWithClickedButtonIndex:[self cancelButtonIndex] animated:NO];
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
}


- (void) willPresentAlertView:(UIAlertView *)alertView
{
	if( self.willPresentBlock != nil ) {
		self.willPresentBlock();
	}
}


- (void) didPresentAlertView:(UIAlertView *)alertView
{
	if( self.didPresentBlock != nil ) {
		self.didPresentBlock();
	}
}


- (void) alertViewCancel:(UIAlertView *)alertView
{
	if( self.didCancelBlock != nil ) {
		self.didCancelBlock();
	}
}


- (void) alertView:(UIAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if( self.clickedButtonBlock != nil ) {
		self.clickedButtonBlock(buttonIndex);
	}
}


- (void) alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex
{
	if( self.willDismissBlock != nil ) {
		self.willDismissBlock(buttonIndex);
	}
}


- (void) alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	if( self.didDismissBlock != nil ) {
		self.didDismissBlock(buttonIndex);
	}
}

+ (void)showSingleOptionAlertWithTitile:(NSString *)title andMessage:(NSString *)message andConfirmText:(NSString *)confirmText {
    FillrAlertView *alertView = [[FillrAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:confirmText otherButtonTitles:nil];
    [alertView show];
}

@end
