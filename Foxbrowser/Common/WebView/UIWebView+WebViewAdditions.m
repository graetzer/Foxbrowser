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
#import "NSURL+IFUnicodeURL.h"
#import "UIImage+Scaling.h"


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
    NSString *path = [[NSBundle mainBundle] pathForResource:@"JSTools" ofType:@"js"];
    NSString *jsCode = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    [self stringByEvaluatingJavaScriptFromString:jsCode];
    [self stringByEvaluatingJavaScriptFromString:@"function FoxbrowserToolsLoaded() {return \"YES\";}"];
}

- (BOOL)JSToolsLoaded {
    NSString *val = [self stringByEvaluatingJavaScriptFromString:@"FoxbrowserToolsLoaded()"];
    return [val isEqualToString:@"YES"];
}

- (void)disableContextMenu {
    [self stringByEvaluatingJavaScriptFromString:@"document.body.style.webkitTouchCallout='none';"];
}

- (void)modifyLinkTargets {
    [self stringByEvaluatingJavaScriptFromString:@"FoxbrowserModifyLinkTargets()"];
}

- (void)modifyOpen {
    [self stringByEvaluatingJavaScriptFromString:@"FoxbrowserModifyOpen()"];
}

- (void)clearContent {
    [self stringByEvaluatingJavaScriptFromString:@"document.documentElement.innerHTML = ''"];
}

- (void)enableDoNotTrack {
    [self stringByEvaluatingJavaScriptFromString:@"document.navigator.doNotTrack = '1';"];
}

#pragma mark - Tag stuff

- (NSDictionary *)tagsForPosition:(CGPoint)pt {
    // get the Tags at the touch location
    NSString *tagString = [self stringByEvaluatingJavaScriptFromString:
                      [NSString stringWithFormat:@"FoxbrowserGetHTMLElementsAtPoint(%i,%i);",(NSInteger)pt.x,(NSInteger)pt.y]];
    
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
