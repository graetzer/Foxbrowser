//
//  UIWebView+WebViewAdditions.h
//  Foxbrowser
//
//  Created by simon on 03.07.12.
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

@interface UIWebView (WebViewAdditions)
+ (NSArray *)fileTypes;

- (CGSize)windowSize;
- (CGPoint)scrollOffset;

- (void)showPlaceholder:(NSString *)message title:(NSString *)title;
- (BOOL)isEmpty;
- (NSString *)title;
- (NSString *)location;
- (void)setLocationHash:(NSString *)location;

- (void)loadJSTools;
- (BOOL)JSToolsLoaded;
- (void)disableTouchCallout;
- (void)clearContent;

- (NSInteger)highlightOccurencesOfString:(NSString*)str;
- (void)removeHighlights;
- (void)showNextHighlight;
- (void)showLastHighlight;

- (NSDictionary *)tagsForPosition:(CGPoint)pt;

@end
BOOL IsNativeAppURLWithoutChoice(NSURL* url);