//
//  SGPreviewPanel.h
//  Foxbrowser
//
//  Created by simon on 13.07.12.
//
//
//  Copyright (c) 2012 Simon Peter Grätzer
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
#import <QuartzCore/QuartzCore.h>

@interface SGPreviewTile : UIView

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) NSDictionary *info;

- (id)initWithImage:(UIImage *)image title:(NSString *)title;

@end

@protocol SGPanelDelegate <NSObject>

- (void)openNewTab:(SGPreviewTile *)tile;
- (void)open:(SGPreviewTile *)tile;

@end

@interface SGPreviewPanel : UIView <UIGestureRecognizerDelegate, UIActionSheetDelegate>

@property (weak, nonatomic) id<SGPanelDelegate> delegate;

+ (SGPreviewPanel *)instance;
+ (NSString *)blacklistFilePath;

- (void)layout;
- (void)refresh;
@end