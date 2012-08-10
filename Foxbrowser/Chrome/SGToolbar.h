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

#import "SGURLBarController.h"


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
- (NSString *)location;

- (BOOL)canStopOrReload;
- (void)handleURLInput:(NSString*)input;
- (void)handleURLInput:(NSString*)input withTitle:(NSString *)title;
@end


@class SGURLBarController, SGProgressCircleView, SGSearchBar;
@interface SGToolbar : UIToolbar <UISearchBarDelegate, UIPopoverControllerDelegate, 
UIActionSheetDelegate, MFMailComposeViewControllerDelegate, SGURLBarDelegate> {
    UIColor *_bottomColor;
}

@property (nonatomic, weak) id<SGToolbarDelegate> delegate;

@property (nonatomic, strong) SGSearchBar *searchBar;
@property (nonatomic, strong) SGProgressCircleView *progressView;

@property (nonatomic, strong) UIPopoverController *popoverController;
@property (nonatomic, strong) UIActionSheet *actionSheet;
@property (nonatomic, strong) SGURLBarController *urlBarViewController;

- (id)initWithFrame:(CGRect)frame delegate:(id<SGToolbarDelegate>)delegate;
- (void)updateChrome;

@end
