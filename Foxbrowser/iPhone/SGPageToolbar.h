//
//  SGPageToolbar.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 17.12.12.
//
//
//  Copyright (c) 2012 Simon Grätzer
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

@class SGSearchField, SGSearchViewController, SGPageViewController;

@interface SGPageToolbar : UIView <UITextFieldDelegate, UIActionSheetDelegate,
SGSearchDelegate, SGShareViewDelegate>
@property (readonly, nonatomic) SGSearchField *searchField;
@property (readonly, nonatomic) SGSearchViewController *searchController;

@property (readonly, nonatomic) UIButton *backButton;
@property (readonly, nonatomic) UIButton *forwardButton;
@property (readonly, nonatomic) UIButton *optionsButton;
@property (readonly, nonatomic) UIButton *tabsButton;
@property (readonly, nonatomic) UIButton *cancelButton;

@property (strong, nonatomic) UINavigationController *bookmarks;
@property (strong, nonatomic) UIActionSheet *actionSheet;
@property (weak, nonatomic) SGPageViewController *browser;

- (id)initWithFrame:(CGRect)frame browser:(SGPageViewController *)browser;
- (void)updateChrome;
@end
