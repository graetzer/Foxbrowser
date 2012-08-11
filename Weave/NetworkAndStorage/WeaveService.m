//
//  SGWeaveService.m
//  Foxbrowser
//
//  Created by simon on 13.07.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import "WeaveService.h"
#import "Stockboy.h"
#import "Store.h"
#import "UIWebView+WebViewAdditions.h"
#import "NSURL+IFUnicodeURL.h"

NSString *kWeaveDataRefreshNotification = @"kWeaveDataRefreshNotification";
NSString *kWeaveSyncStatusChangedNotification = @"SyncStatusChanged";
NSString *kWeaveMessageKey = @"Message";
NSString *kWeaveShowedFirstRunPage = @"showedFirstRunPage";

@implementation WeaveOperations

+ (NSURL *)parseURLString:(NSString *)input {
    NSString *destination;
    
    BOOL hasSpace = ([input rangeOfString:@" "].location != NSNotFound);
    BOOL hasDot = ([input rangeOfString:@"."].location != NSNotFound);
    BOOL hasScheme = ([input rangeOfString:@"://"].location != NSNotFound);
    
    if (hasDot && !hasSpace) { 
        if (hasScheme) {
            destination = input;
        } else {
            destination = [NSString stringWithFormat:@"http://%@", input];
        }
    } else  {
        NSString *google = [Stockboy getURIForKey:@"Google URL"];
        destination = [NSString stringWithFormat:google, [self urlEncode:input]];
    }
    return [NSURL URLWithUnicodeString:destination];// TODO 
}

+ (NSString *)urlEncode:(NSString *)string {
	return (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,
                                                               (__bridge CFStringRef)string,
                                                               NULL,
                                                               (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ",
                                                               CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
}

+ (BOOL)handleURLInternal:(NSURL *)url; {
    // We don't want to render some URLs like for example file URLs. Note that file URLs do not
    // actually go through this method. It seems that at least on iOS 4 the UIWebView does not
    // load them at all. But just to be on the safe side we do the check.
    
    if (IsBlockedURL(url)) {
        return NO;
    }
    
    // When an application implements this UIWebView delegate method, it loses automatic handling of
    // 'special' urls. Like mailto: or app store links. We try to compensate for that here.
    if (IsNativeAppURLWithoutChoice(url)) {
        [[UIApplication sharedApplication] openURL:url];
        return NO;
    }
    
    // If the link is to a native app and we have turned that on, let the OS open the link
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey: @"useNativeApps"] && IsNativeAppURL(url)) {
        [[UIApplication sharedApplication] openURL:url];
        return NO;
    }
    
    return YES;
}

+ (void)addHistoryURL:(NSURL *)url title:(NSString *)title {
    NSString *urlText = url.absoluteString;
    
    // Check if this history entry already exists
    NSDictionary *existing = nil;
    for (NSDictionary *entry in [[Store getStore] getHistory]) {
        if ([urlText isEqualToString:[entry objectForKey:@"url"]]) {
            existing = entry;
        }
    }
    
    NSDictionary *historyEntry = nil;
    if (existing) {// There is a differnce between the two dictionary formats
        NSInteger sortIndex = [[existing objectForKey:@"sortindex"] integerValue];
        historyEntry = @{ @"id" : [existing objectForKey:@"id"],
        @"histUri" : [existing objectForKey:@"url"],
        @"title" : [existing objectForKey:@"title"],
        @"modified" : @([[NSDate date] timeIntervalSince1970]),
        @"sortindex" : @(sortIndex + 100)};
    } else {
        historyEntry = @{ @"id" : [NSString stringWithFormat:@"abc%i", url.hash],// No idea about this
        @"histUri" : urlText,
        @"title" : title,
        @"modified" : @([[NSDate date] timeIntervalSince1970]),
        @"sortindex" : @100};// Choosen without further information
    }
    
    [[Store getStore] updateHistoryAdding:@[historyEntry] andRemoving:nil fullRefresh:NO];
}

@end


/**
 * Returns TRUE for links that MUST be opened with a native application.
 */

BOOL IsNativeAppURLWithoutChoice(NSURL* url)
{
	if (url != nil)
	{
        
        // Basic case where it is a link to one of the native apps that is the only handler.
        
        static NSSet* nativeSchemes = nil;
        if (nativeSchemes == nil)
        {
            nativeSchemes = [NSSet setWithObjects: @"mailto", @"tel", @"sms", @"itms", nil];
        }
        
        if ([nativeSchemes containsObject: [url scheme]])
        {
            return YES;
        }
        
        // Special case for handling links to the app store. See  http://developer.apple.com/library/ios/#qa/qa2008/qa1629.html
        // and http://developer.apple.com/library/ios/#qa/qa2008/qa1633.html for more info. Note that we do this even is
        // Use Native Apps is turned off. I think that is the right choice here since there is no web alternative for the
        // store.
        
        else if ([[url scheme] isEqual:@"http"] || [[url scheme] isEqual:@"https"])
        {
            if ([[url host] isEqualToString: @"itunes.com"])
            {
                if ([[url path] hasPrefix: @"/apps/"])
                {
                    return YES;
                }
            }
            else if ([[url host] isEqualToString: @"phobos.apple.com"] || [[url host] isEqualToString: @"itunes.apple.com"])
            {
                return YES;
            }
        }
	}
	
	return NO;
}

/**
 * Returns TRUE is the url is one that can be opened with a native application.
 */

BOOL IsNativeAppURL(NSURL* url)
{
	if (url != nil)
	{
        if ([url.scheme isEqualToString: @"http"] || [url.scheme isEqualToString: @"https"])
        {
            return NO;// Don't check for youtube or maps, on iOS 6 they aren't installed anymore
        } else if([[UIApplication sharedApplication] canOpenURL:url]) {
            return YES;
        }
	}
	return NO;
}

/**
 * Returns TRUE is the url is one that should be opened in Safari. These are HTTP URLs that we do not
 * recogize as URLs to native applications.
 */

BOOL IsSafariURL(NSURL* url)
{
	return (url != nil) && IsNativeAppURL(url) == NO && ([url.scheme isEqualToString: @"http"] || [url.scheme isEqualToString: @"https"]);
}

/**
 * Returns TRUE if the url is one that should not be opened at all. Currently just used to
 * prevent file:// and javascript: URLs.
 */

BOOL IsBlockedURL(NSURL* url)
{
	return [url.scheme isEqualToString: @"file"] || [url.scheme isEqualToString: @"javascript"];
}