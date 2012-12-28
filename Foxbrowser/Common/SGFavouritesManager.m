//
//  SGScreenshotManager.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 27.12.12.
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

#import "SGFavouritesManager.h"
#import "UIImage+Scaling.h"
#import "SGWebViewController.h"
#import "Store.h"

#define TILES_MAX 8

@implementation SGFavouritesManager {
    NSMutableDictionary *_favourites;
    
    NSMutableArray *_blocked;
}

+ (SGFavouritesManager *)sharedManager {
    static SGFavouritesManager *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[SGFavouritesManager alloc] init];
    });
    return sharedInstance;
}

- (id)init {
    if (self = [super init]) {
        _blocked = [NSMutableArray arrayWithContentsOfFile:[self blacklistFilePath]];
        if (!_blocked)
            _blocked = [NSMutableArray arrayWithCapacity:10];
    }
    return self;
}

#pragma mark Favourites stuff
- (NSArray *)favourites {
    if (!_favourites) {
        [self fillFavourites];
    }
    return _favourites.allKeys;
}

- (NSURL *)blockURL:(NSURL *)url {
    [_blocked addObject:url.absoluteString];
    [_favourites removeObjectForKey:url];
    [_blocked writeToFile:[self blacklistFilePath] atomically:NO];
    
    return nil;
}

- (void)resetFavourites {
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:[self blacklistFilePath] error:NULL];
    [fm removeItemAtPath:[self screenshotPath] error:NULL];
}

#pragma mark Screenshot stuff
- (void)webViewDidFinishLoad:(SGWebViewController *)webController; {
    NSURL *url = webController.location;
    if (![_favourites objectForKey:url])
        return;
    
    NSString *path = [self pathForURL:url];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:path]) {
        NSDictionary *attr = [fm attributesOfItemAtPath:path error:NULL];
        NSDate *modDate = [attr objectForKey:NSFileModificationDate];
        if ([modDate compare:[NSDate dateWithTimeIntervalSinceNow:-60*60*24*3]] == NSOrderedDescending)
            return;
    }
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        
        UIImage *screen = [self imageWithView:webController.webView];
        if (screen.size.height > screen.size.width)
            screen = [screen cutImageToSize:CGSizeMake(screen.size.width, screen.size.height)];
        
        CGFloat scale = [UIScreen mainScreen].scale;
        screen = [screen scaleProportionalToSize:CGSizeMake(scale*kSGPanelWidth, scale*kSGPanelHeigth)];
        if (screen) {
            NSData *data = UIImagePNGRepresentation(screen);
            [data writeToFile:path atomically:NO];
        }
        
    });
}

- (UIImage *)imageWithURL:(NSURL *)url {
    NSString *path = [self pathForURL:url];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if ([fm fileExistsAtPath:path]) {
        return [UIImage imageWithContentsOfFile:path];
    } else {
        NSDictionary *attr = @{NSFileModificationDate : [NSDate distantPast]};
        [fm createFileAtPath:path contents:[NSData data] attributes:attr];
        return nil;
    }
}

- (NSString *)titleWithURL:(NSURL *)url {
    return _favourites[url];
}

#pragma mark  - Utility

- (void)fillFavourites {
    NSArray *history = [[Store getStore] getHistory];
    
    NSUInteger i = _favourites.count;
    while (_favourites.count < TILES_MAX && i < history.count) {
        NSDictionary *item = history[i];
        i++;
        
        NSString *urlS = [item objectForKey:@"url"];
        NSURL *url = [NSURL URLWithString:urlS];
        
        if (_favourites[url] || [_blocked containsObject:urlS])
            continue;
        
        _favourites[url] = [item objectForKey:@"title"];
    }

}

- (UIImage *)imageWithView:(UIView *)view {
    UIImage *viewImage = nil;
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, YES, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (view.layer && ctx) {
        [view.layer renderInContext:ctx];
        viewImage = UIGraphicsGetImageFromCurrentImageContext();
    }
    UIGraphicsEndImageContext();
    return viewImage;
}

- (NSString *)screenshotPath {
    NSString* path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    return [path stringByAppendingPathComponent:@"Screenshots"];
}

- (NSString *)pathForURL:(NSURL *)url {
    NSString* path = [self screenshotPath];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path])
        [fm createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:NULL];
    
    return [[path stringByAppendingPathComponent:url.host] stringByAppendingPathExtension:@"png"];
}

- (NSString *)blacklistFilePath {
    NSString* path = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    path = [path stringByAppendingPathComponent:@"blacklist.plist"];
    return path;
}

@end
