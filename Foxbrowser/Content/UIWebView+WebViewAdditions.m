//
//  UIWebView+WebViewAdditions.m
//  Foxbrowser
//
//  Created by simon on 03.07.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import "UIWebView+WebViewAdditions.h"
#import "NSURL+IFUnicodeURL.h"
#import "UIImage+Scaling.h"

@implementation UIWebView (WebViewAdditions)

// Filetypes supported by a webview
+ (NSArray *)fileTypes {
    return @[ @"xls", @"key.zip", @"numbers.zip", @"pdf", @"ppt", @"doc" ];
}

- (CGSize)windowSize
{
    CGSize size;
    size.width = [[self stringByEvaluatingJavaScriptFromString:@"window.innerWidth"] integerValue];
    size.height = [[self stringByEvaluatingJavaScriptFromString:@"window.innerHeight"] integerValue];
    return size;
}

- (CGPoint)scrollOffset
{
    CGPoint pt;
    pt.x = [[self stringByEvaluatingJavaScriptFromString:@"window.pageXOffset"] integerValue];
    pt.y = [[self stringByEvaluatingJavaScriptFromString:@"window.pageYOffset"] integerValue];
    return pt;
}

- (NSString *)title {
    NSString *htmlTitle = [self stringByEvaluatingJavaScriptFromString:@"document.title"];
    if (!htmlTitle.length) {
        htmlTitle = self.request.URL.absoluteString;
        NSString *ext = [htmlTitle pathExtension];
        if ([[UIWebView fileTypes] containsObject:ext]) {
            htmlTitle = [htmlTitle lastPathComponent];
        }
    }
    return htmlTitle;
}

- (NSString *)location {
    return [self stringByEvaluatingJavaScriptFromString:@"window.location.toString()"];;
}

- (void)clearContent {
    [self stringByEvaluatingJavaScriptFromString:@"document.documentElement.innerHTML = ''"];
}

- (void)disableContextMenu {
    [self stringByEvaluatingJavaScriptFromString:@"document.body.style.webkitTouchCallout='none';"];
}

#pragma mark - Screenshot stuff

- (UIImage *)screenshot {
    UIImage *viewImage = nil;
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, YES, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (self.layer && ctx) {
        [self.layer renderInContext:ctx];
        viewImage = UIGraphicsGetImageFromCurrentImageContext();
    }
    UIGraphicsEndImageContext();
    return viewImage;
}

- (void)saveScreenTo:(NSString *)path {
    UIImage *screen = [self screenshot];
    if (screen.size.height > screen.size.width) {
        screen = [screen cutImageToSize:CGSizeMake(screen.size.width, screen.size.height)];
    }
    
    screen = [screen scaleProportionalToSize:CGSizeMake(220., 185.)];
    if (screen) {
        NSData *data = UIImagePNGRepresentation(screen);
        [data writeToFile:path atomically:NO];
#ifdef DEBUG
        NSLog(@"Write screenshot to: %@", path);
#endif
    }
}

+ (NSString *)screenshotPath {
    NSString* path = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    return [path stringByAppendingPathComponent:@"Screenshots"];
}

+ (NSString *)pathForURL:(NSURL *)url {
    NSString* path = [self screenshotPath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:NULL];
    }
    
    return [[path stringByAppendingPathComponent:url.host] stringByAppendingPathExtension:@"png"];
}

#pragma mark - Tag stuff

- (NSDictionary *)tagsForPosition:(CGPoint)pt {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"JSTools" ofType:@"js"];
    NSString *jsCode = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    [self stringByEvaluatingJavaScriptFromString:jsCode];
    
    // get the Tags at the touch location
    NSString *tagString = [self stringByEvaluatingJavaScriptFromString:
                      [NSString stringWithFormat:@"MyAppGetHTMLElementsAtPoint(%i,%i);",(NSInteger)pt.x,(NSInteger)pt.y]];
    
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithCapacity:2];
    NSArray *tags = [tagString componentsSeparatedByString:@","];
    for (NSString *tag in tags) {
        NSRange start = [tag rangeOfString:@"["];
        if (start.location != NSNotFound) {
            NSString *tagname = [tag substringToIndex:start.location];
            NSRange end = [tag rangeOfString:@"]"];
            NSString *urlString = [tag substringWithRange:NSMakeRange(start.location + 1, end.location - start.location - 1)];
            [info setObject:urlString forKey:tagname];
        }
    }
    
    return info;
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
                
				// Disabled this case. We now simply trigger on itunes.apple.com or phobos.apple.com. The worst thing
				// that can happen is that Safari is launched. We can live with that.
                
                //			if ([[url host] isEqualToString: @"phobos.apple.com"] || [[url host] isEqualToString: @"itunes.apple.com"])
                //			{
                //				if ([[url path] isEqualToString: @"/WebObjects/MZStore.woa/wa/viewSoftware"])
                //				{
                //					[[UIApplication sharedApplication] openURL: url];
                //					return NO;
                //				}
                //			}
                
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
				// Try to recognize Google Maps URLs. We are a bit relaxed with google urls because it seems that iOS also
				// recogizes maps.google.nl. Apple says ditu.google.com is also valid but I have never seen that used.
				return NO;
                
				if ([[url host] hasPrefix: @"maps.google."] || [[url host] hasPrefix: @"ditu.google."])
				{
					if ([[url path] isEqualToString: @"/maps"] || [[url path] isEqualToString: @"/local"] || [[url path] isEqualToString: @"/m"])
					{
						return YES;
					}
				}
                
				// Try to recognize YouTube URLs
				
				if ([[url host] isEqualToString: @"www.youtube.com"])
				{
					if ([[url path] isEqualToString: @"/watch"] || [[url path] hasPrefix: @"/v/"])
					{
						return YES;
					}
				}
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