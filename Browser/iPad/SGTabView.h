//
//  SGTabView.h
//  SGTabs
//
//  Created by simon on 07.06.12.
//  Copyright (c) 2012-2014 Simon Peter Grätzer. All rights reserved.
//


#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>

@interface SGTabView : UIView

@property (readonly, weak, nonatomic) UILabel *titleLabel;
@property (readonly, weak, nonatomic) UIButton *closeButton;
@property (weak, nonatomic) UIViewController *viewController;
@property (assign, nonatomic) BOOL selected;

- (id)initWithFrame:(CGRect)frame;

@end
