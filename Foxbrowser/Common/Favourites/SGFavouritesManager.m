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
#import "WeaveService.h"
#import "NSURL+IFUnicodeURL.h"

@implementation SGFavouritesManager {
    NSMutableDictionary *_favourites;
    NSCache *_imageCache;
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
        _favourites = [NSMutableDictionary dictionaryWithCapacity:[self maxFavs]];
        _imageCache = [NSCache new];
        _blocked = [NSMutableArray arrayWithContentsOfFile:[self blacklistFilePath]];
        if (!_blocked)
            _blocked = [NSMutableArray arrayWithCapacity:10];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(refresh)
                                                     name:kWeaveDataRefreshNotification
                                                   object:nil];
    }
    return self;
}

#pragma mark Favourites stuff
- (NSArray *)favourites {
    if (_favourites.count < [self maxFavs]) {
        [self fillFavourites];
    }
    return _favourites.allKeys;
}

- (void)refresh {
    [_favourites removeAllObjects];
    [self fillFavourites];
}

- (NSURL *)blockURL:(NSURL *)url {
    [_blocked addObject:url.absoluteString];
    [_blocked writeToFile:[self blacklistFilePath] atomically:NO];
    [_favourites removeObjectForKey:url];
    
    return [self fillFavourites];
}

- (void)resetFavourites {
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:[self blacklistFilePath] error:NULL];
    [fm removeItemAtPath:[self screenshotPath] error:NULL];
    [_imageCache removeAllObjects];
    
}

- (CGSize)imageSize {
    CGSize size = [UIScreen mainScreen].bounds.size;
    CGFloat scale = 0.23;
    return size.height > size.width ? CGSizeMake(size.height*scale, size.width*scale) :
    CGSizeMake(size.width*scale, size.height*scale);
}

- (NSUInteger)maxFavs {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        return [UIScreen mainScreen].bounds.size.height >= 568 ? 8 : 6;
    return 8;//on the iPad always 8
}

#pragma mark Screenshot stuff
- (void)webViewDidFinishLoad:(SGWebViewController *)webController; {
    NSURL *url = webController.location;
    if (![self containsHost:url.host])
        return;
    
    NSString *path = [self pathForURL:url];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:path]) {
        NSDictionary *attr = [fm attributesOfItemAtPath:path error:NULL];
        NSDate *modDate = attr[NSFileModificationDate];
        if ([modDate compare:[NSDate dateWithTimeIntervalSinceNow:-60*60*24*3]] == NSOrderedDescending)
            return;
    }
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        
        UIImage *screen = [self imageWithView:webController.webView];
        if (screen.size.height > screen.size.width)
            screen = [screen cutImageToSize:CGSizeMake(screen.size.width, screen.size.height)];
        
        //CGFloat scale = [UIScreen mainScreen].scale;
        //CGSize size = CGSizeApplyAffineTransform(self.imageSize, CGAffineTransformMakeScale(scale, scale));
        screen = [screen scaleProportionalToSize:self.imageSize];
        if (screen) {
            NSData *data = UIImagePNGRepresentation(screen);
            [data writeToFile:path atomically:NO];
        }
        
    });
}

- (UIImage *)imageWithURL:(NSURL *)url {
    UIImage *image = [_imageCache objectForKey:url];
    
    if (!image) {
        NSString *path = [self pathForURL:url];
        NSFileManager *fm = [NSFileManager defaultManager];
        
        if ([fm fileExistsAtPath:path]) {
            image = [UIImage imageWithContentsOfFile:path];
            if (image) {
                [_imageCache setObject:image forKey:url];
                return image;
            }
        }
    }
    return image;//[UIImage imageNamed:@"logo"];
}

- (NSString *)titleWithURL:(NSURL *)url {
    return _favourites[url];
}

#pragma mark  - Utility

- (BOOL)containsHost:(NSString *)host {
    for (NSURL *url in _favourites)
        if ([url.host isEqualToString:host])
            return YES;
    
    return NO;
}

- (NSURL *)fillFavourites {
    NSArray *history = [[Store getStore] getHistory];
    
    NSURL *url;
    NSUInteger i = _favourites.count;
    while (_favourites.count < [self maxFavs] && i < history.count) {
        NSDictionary *item = history[i];
        i++;
        
        NSString *urlS = item[@"url"];
        url = [NSURL URLWithUnicodeString:urlS];
        
        if (!url || [self containsHost:url.host] || [_blocked containsObject:url.absoluteString])
            continue;
        
        _favourites[url] = item[@"title"];
    }
    return url;
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
