//
//  UIWebView+WebViewAdditions.h
//  Foxbrowser
//
//  Created by simon on 03.07.12.
//  Copyright (c) 2012-2014 Simon Peter Grätzer. All rights reserved.
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