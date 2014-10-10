//
//  SGSearchBar.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 10.08.12.
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


typedef NS_ENUM(NSUInteger, SGSearchFieldState) {
    SGSearchFieldStateDisabled = 1,
    SGSearchFieldStateReload = 1<<2,
    SGSearchFieldStateStop = 1<<3
};

@interface SGSearchField : UITextField


@property (readonly, nonatomic) UIButton *reloadItem;
@property (readonly, nonatomic) UIButton *stopItem;
@property (assign, nonatomic) SGSearchFieldState state;

@end
