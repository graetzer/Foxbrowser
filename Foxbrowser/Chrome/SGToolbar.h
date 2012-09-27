//
//  SGTabTopView.h
//  SGTabs
//
//  Created by simon on 07.06.12.
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
#import <MessageUI/MessageUI.h>
#import <Twitter/Twitter.h>

#import "SGSearchController.h"

@protocol SGToolbarDelegate <NSObject>
- (void)reload;
- (void)stop;

- (BOOL)isLoading;

- (void)goBack; 
- (void)goForward;

- (BOOL)canGoBack;
- (BOOL)canGoForward;

@optional
- (NSURL *)URL;

- (BOOL)canStopOrReload;
- (void)handleURLInput:(NSString*)input title:(NSString *)title;
@end


@class SGSearchController, SGProgressCircleView, BookmarkPage, SGSearchBar;

@interface SGToolbar : UIView <UITextFieldDelegate, UIPopoverControllerDelegate,
UIActionSheetDelegate, MFMailComposeViewControllerDelegate, SGURLBarDelegate> {
    UIColor *_bottomColor;
}

@property (nonatomic, weak) id<SGToolbarDelegate> delegate;

@property (nonatomic, strong) SGSearchBar *searchField;
@property (nonatomic, strong) SGProgressCircleView *progressView;

@property (nonatomic, strong) UINavigationController *bookmarks;
@property (nonatomic, strong) SGSearchController *urlBarViewController;
@property (strong, nonatomic) UIPopoverController *popoverController;
@property (nonatomic, strong) UIActionSheet *actionSheet;

- (id)initWithFrame:(CGRect)frame delegate:(id<SGToolbarDelegate>)delegate;
- (void)updateChrome;

@end
