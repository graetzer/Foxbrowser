//
//  SGPopoverController.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 01.04.13.
//  Copyright (c) 2013 Simon Peter Grätzer. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_OPTIONS(NSUInteger, SGPopoverArrowDirection) {
    SGPopoverArrowDirectionUp = 1UL << 0,
    SGPopoverArrowDirectionDown = 1UL << 1,
    SGPopoverArrowDirectionLeft = 1UL << 2,
    SGPopoverArrowDirectionRight = 1UL << 3,
    SGPopoverArrowDirectionAny = SGPopoverArrowDirectionUp | SGPopoverArrowDirectionDown |
    SGPopoverArrowDirectionLeft | SGPopoverArrowDirectionRight,
    SGPopoverArrowDirectionUnknown = NSUIntegerMax
};


@interface SGPopoverController : NSObject

/* The view controller provided becomes the content view controller for the UIPopoverController. This is the designated initializer for UIPopoverController.
 */
- (id)initWithContentViewController:(UIViewController *)viewController;

@property (nonatomic, assign) id <UIPopoverControllerDelegate> delegate;

/* The content view controller is the `UIViewController` instance in charge of the content view of the displayed popover. This property can be changed while the popover is displayed to allow different view controllers in the same popover session.
 */
@property (nonatomic, retain) UIViewController *contentViewController;
- (void)setContentViewController:(UIViewController *)viewController animated:(BOOL)animated;

/* This property allows direction manipulation of the content size of the popover. Changing the property directly is equivalent to animated=YES. The content size is limited to a minimum width of 320 and a maximum width of 600.
 */
@property (nonatomic) CGSize popoverContentSize;
- (void)setPopoverContentSize:(CGSize)size animated:(BOOL)animated;

/* Returns whether the popover is visible (presented) or not.
 */
@property (nonatomic, readonly, getter=isPopoverVisible) BOOL popoverVisible;

/* Returns the direction the arrow is pointing on a presented popover. Before presentation, this returns UIPopoverArrowDirectionUnknown.
 */
@property (nonatomic, readonly) UIPopoverArrowDirection popoverArrowDirection;

/* By default, a popover disallows interaction with any view outside of the popover while the popover is presented. This property allows the specification of an array of UIView instances which the user is allowed to interact with while the popover is up.
 */
@property (nonatomic, copy) NSArray *passthroughViews;

/* -presentPopoverFromRect:inView:permittedArrowDirections:animated: allows you to present a popover from a rect in a particular view. `arrowDirections` is a bitfield which specifies what arrow directions are allowed when laying out the popover; for most uses, `UIPopoverArrowDirectionAny` is sufficient.
 */
- (void)presentPopoverFromRect:(CGRect)rect inView:(UIView *)view permittedArrowDirections:(UIPopoverArrowDirection)arrowDirections animated:(BOOL)animated;

/* Like the above, but is a convenience for presentation from a `UIBarButtonItem` instance. arrowDirection limited to UIPopoverArrowDirectionUp/Down
 */
- (void)presentPopoverFromBarButtonItem:(UIBarButtonItem *)item permittedArrowDirections:(UIPopoverArrowDirection)arrowDirections animated:(BOOL)animated;

/* Called to dismiss the popover programmatically. The delegate methods for "should" and "did" dismiss are not called when the popover is dismissed in this way.
 */
- (void)dismissPopoverAnimated:(BOOL)animated;

/* Clients may wish to change the available area for popover display. The default implementation of this method always returns insets which define 10 points from the edges of the display, and presentation of popovers always accounts for the status bar. The rectangle being inset is always expressed in terms of the current device orientation; (0, 0) is always in the upper-left of the device. This may require insets to change on device rotation.
 */
@property (nonatomic, readwrite) UIEdgeInsets popoverLayoutMargins NS_AVAILABLE_IOS(5_0);

@end
