//
//  UIWebView+WebViewAdditions.m
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

#import "UIWebView+WebViewAdditions.h"
#import "NSStringPunycodeAdditions.h"
#import "UIImage+Scaling.h"

// Caching the most frequently used javascript code
static NSString *JSTools;
static NSString *JSSearchTools;

@implementation UIWebView (WebViewAdditions)

// Filetypes supported by a webview
+ (NSArray *)fileTypes {
    return @[ @"xls", @"key.zip", @"numbers.zip", @"pdf", @"ppt", @"doc" ];
}

- (CGSize)windowSize {
    CGSize size;
    size.width = [[self stringByEvaluatingJavaScriptFromString:@"window.innerWidth"] integerValue];
    size.height = [[self stringByEvaluatingJavaScriptFromString:@"window.innerHeight"] integerValue];
    return size;
}

- (CGPoint)scrollOffset {
    CGPoint pt;
    pt.x = [[self stringByEvaluatingJavaScriptFromString:@"window.pageXOffset"] integerValue];
    pt.y = [[self stringByEvaluatingJavaScriptFromString:@"window.pageYOffset"] integerValue];
    return pt;
}

- (void)showPlaceholder:(NSString *)message title:(NSString *)title {
    if (!message)
        message = @"";
    if (!title)
        title = @"";
    
    NSString *html = @"<html><head><title>%@</title>"
    "<meta name='viewport' content='width=device-width, initial-scale=1.0, user-scalable=no' /></head><body>"
    "<div style='margin:100px auto;width:18em'>"
    "<p style='color:#c0bfbf;font:bolder 100px HelveticaNeue;text-align:center;margin:20px'>Fx</p>"
    "<p style='color:#969595;font:bolder 17.5px HelveticaNeue;text-align:center'>%@</p> </div></body></html>";//
    NSString *errorPage = [NSString stringWithFormat:html, title, message];
    [self loadHTMLString:errorPage baseURL:[[NSBundle mainBundle] bundleURL]];
}

- (BOOL)isEmpty {
    if ([self.request.URL.scheme hasPrefix:@"http"]) {// If the placeholder is shown, scheme would be file://
        NSString *string = [self stringByEvaluatingJavaScriptFromString:@"document.getElementsByTagName('body')[0].innerHTML"];
        return !string || string.length == 0;
    }
    return YES;
}

- (NSString *)title {
    NSString *htmlTitle = [self stringByEvaluatingJavaScriptFromString:@"document.title"];
    if (!htmlTitle.length) {
        htmlTitle = self.request.URL.absoluteString;
        NSString *ext = [htmlTitle pathExtension];
        if ([[UIWebView fileTypes] containsObject:ext]) {
            htmlTitle = [htmlTitle lastPathComponent];
        } else {
            htmlTitle = [htmlTitle stringByReplacingOccurrencesOfString:@"http://" withString:@""];
            htmlTitle = [htmlTitle stringByReplacingOccurrencesOfString:@"https://" withString:@""];
        }
    }
    return htmlTitle;
}

- (NSString *)location {
    return [self stringByEvaluatingJavaScriptFromString:@"window.location.toString()"];;
}

- (void)setLocationHash:(NSString *)location {
    if (!location)
        location = @"";
    [self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"window.location.hash = '%@'", location]];
}

- (void)loadJSTools {
    if (!JSTools) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"JSTools" ofType:@"js"];
        JSTools = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    }
    
    [self stringByEvaluatingJavaScriptFromString:JSTools];
    [self stringByEvaluatingJavaScriptFromString:@"function FoxbrowserToolsLoaded() {return \"YES\";}"];
}

- (BOOL)JSToolsLoaded {
    NSString *val = [self stringByEvaluatingJavaScriptFromString:@"FoxbrowserToolsLoaded()"];
    return [val isEqualToString:@"YES"];
}

- (void)disableTouchCallout {
    [self stringByEvaluatingJavaScriptFromString:@"document.body.style.webkitTouchCallout='none';"];
}

- (void)clearContent {
    [self stringByEvaluatingJavaScriptFromString:@"document.documentElement.innerHTML = ''"];
}

#pragma mark Search stuff

- (NSInteger)highlightOccurencesOfString:(NSString*)str {
    if (!JSSearchTools) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"JSSearchTools" ofType:@"js"];
        JSSearchTools = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    }
    [self stringByEvaluatingJavaScriptFromString:JSSearchTools];
    
    NSString *startSearch = [NSString stringWithFormat:@"foxbrowser_hilitior_instance.apply('%@');",str];
    NSString *result = [self stringByEvaluatingJavaScriptFromString:startSearch];
    
    return [result integerValue];
}

- (void)showNextHighlight; {
    [self stringByEvaluatingJavaScriptFromString:@"foxbrowser_hilitior_instance.showNext();"];
}

- (void)showLastHighlight; {
    [self stringByEvaluatingJavaScriptFromString:@"foxbrowser_hilitior_instance.showLast();"];
}

- (void)removeHighlights {
    [self stringByEvaluatingJavaScriptFromString:@"foxbrowser_hilitior_instance.remove()"];
}

#pragma mark - Tag stuff

- (NSDictionary *)tagsForPosition:(CGPoint)pt {
    if (![self JSToolsLoaded]) [self loadJSTools];
    
    // get the Tags at the touch location
    NSString *tagString = [self stringByEvaluatingJavaScriptFromString:
                      [NSString stringWithFormat:@"FoxbrowserGetHTMLElementsAtPoint(%li,%li);",(long)pt.x,(long)pt.y]];
    
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithCapacity:2];
    NSArray *tags = [tagString componentsSeparatedByString:@"|&|"];
    for (NSString *tag in tags) {
        NSRange start = [tag rangeOfString:@"["];
        NSRange end = [tag rangeOfString:@"]"];
        if (start.location != NSNotFound && end.location != NSNotFound) {
            NSString *tagname = [tag substringToIndex:start.location];
            NSString *urlString = [tag substringWithRange:NSMakeRange(start.location + 1, end.location - start.location - 1)];
            
            info[tagname] = urlString;
        }
    }
    
    return info;
}

@end

BOOL IsNativeAppURLWithoutChoice(NSURL* url) {
    if (url != nil) {
        
        // Basic case where it is a link to one of the native apps that is the only handler.
        static NSSet* nativeSchemes = nil;
        if (nativeSchemes == nil) {
            nativeSchemes = [NSSet setWithObjects: @"mailto", @"tel", @"sms", @"itms", nil];
        }
        
        if ([nativeSchemes containsObject: [url scheme]]) {
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