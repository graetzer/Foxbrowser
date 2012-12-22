//
//  SGSearchBar.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 10.08.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, SGSearchFieldState) {
    SGSearchFieldStateDisabled = 1,
    SGSearchFieldStateReload = 1<<2,
    SGSearchFieldStateStop = 1<<3
};

@interface SGSearchField : UITextField

- (id)initWithDelegate:(id<UITextFieldDelegate>)delegate;

@property (readonly, nonatomic) UIButton *reloadItem;
@property (readonly, nonatomic) UIButton *stopItem;

@property (assign, nonatomic) SGSearchFieldState state;

@end
