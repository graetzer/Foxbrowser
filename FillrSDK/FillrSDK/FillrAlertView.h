//
//  ZPAlertView.h
//  AlertWithCompletion
//
//  Created by Zacharias Pasternack on 10/11/10.
//  Copyright 2010-2013 Fat Apps, LLC. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef void (^WillPresentBlock)(void);
typedef void (^DidPresentBlock)(void);
typedef void (^DidCancelBlock)(void);
typedef void (^ClickedButtonBlock)(NSInteger);
typedef void (^WillDismissBlock)(NSInteger);
typedef void (^DidDismissBlock)(NSInteger);


@interface FillrAlertView : UIAlertView <UIAlertViewDelegate>

@property (nonatomic, assign) BOOL showInVertical;

@property (nonatomic, copy) WillPresentBlock willPresentBlock;
@property (nonatomic, copy) DidPresentBlock didPresentBlock;
@property (nonatomic, copy) DidCancelBlock didCancelBlock;
@property (nonatomic, copy) ClickedButtonBlock clickedButtonBlock;
@property (nonatomic, copy) WillDismissBlock willDismissBlock;	
@property (nonatomic, copy) DidDismissBlock didDismissBlock;

+ (void)showSingleOptionAlertWithTitile:(NSString *)title andMessage:(NSString *)message andConfirmText:(NSString *)confirmText;

@end
