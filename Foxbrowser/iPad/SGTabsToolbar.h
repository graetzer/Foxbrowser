//
//  SGTabTopView.h
//  SGTabs
//
//  Created by simon on 07.06.12.
//
//
//  Copyright (c) 2012-2013 Simon PEter Grätzer
//  
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <UIKit/UIKit.h>

#import "SGSearchViewController.h"
#import "SGShareView.h"
#import "SGShareView+UIKit.h"

@class SGSearchViewController, SGProgressCircleView, BookmarkPage, SGSearchField, SGBrowserViewController;

@interface SGTabsToolbar : UIView <UITextFieldDelegate, UIPopoverControllerDelegate,
UIActionSheetDelegate, SGSearchDelegate, SGShareViewDelegate> {
    UIColor *_bottomColor;
}

@property (nonatomic, weak, readonly) SGBrowserViewController *browser;

@property (nonatomic, strong) SGSearchField *searchField;
@property (nonatomic, strong) SGSearchViewController *searchController;

@property (nonatomic, strong) SGProgressCircleView *progressView;

@property (nonatomic, strong) UINavigationController *bookmarks;
@property (strong, nonatomic) UIPopoverController *popoverController;
@property (nonatomic, strong) UIActionSheet *actionSheet;

- (id)initWithFrame:(CGRect)frame browser:(SGBrowserViewController *)browser;
- (void)updateChrome;

@end
