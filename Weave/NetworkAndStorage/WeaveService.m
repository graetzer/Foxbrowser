//
//  SGWeaveService.m
//  Foxbrowser
//
//  Created by simon on 13.07.12.
//  Copyright (c) 2012 Cybercon GmbH. All rights reserved.
//

#import "WeaveService.h"
#import "Stockboy.h"
#import "UIWebView+WebViewAdditions.h"
#import "NSURL+IFUnicodeURL.h"

NSString *kWeaveDataRefreshNotification = @"kWeaveDataRefreshNotification";
NSString *kWeaveSyncStatusChangedNotification = @"SyncStatusChanged";
NSString *kWeaveMessageKey = @"Message";

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

@end