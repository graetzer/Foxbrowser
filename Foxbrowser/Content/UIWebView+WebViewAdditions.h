//
//  UIWebView+WebViewAdditions.h
//  Foxbrowser
//
//  Created by simon on 03.07.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface UIWebView (WebViewAdditions)
+ (NSArray *)fileTypes;

- (CGSize)windowSize;
- (CGPoint)scrollOffset;

- (NSString *)title;
- (NSString *)location;

- (void)disableContextMenu;
- (void)clearContent;

- (UIImage *)screenshot;
- (void)saveScreenTo:(NSString *)path;
+ (NSString *)screenshotPath;
+ (NSString *)pathForURL:(NSURL *)url;

- (NSDictionary *)tagsForPosition:(CGPoint)pt;

@end

BOOL IsNativeAppURLWithoutChoice(NSURL* link);
BOOL IsNativeAppURL(NSURL* url);
BOOL IsSafariURL(NSURL* url);
BOOL IsBlockedURL(NSURL* url);