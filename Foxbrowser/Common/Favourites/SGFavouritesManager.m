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
    NSMutableArray *_userFavourites;
    NSMutableArray *_favourites;
    
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
        _favourites = [NSMutableArray arrayWithCapacity:[self maxFavs]];
        _imageCache = [NSCache new];
        _blocked = [NSMutableArray arrayWithContentsOfFile:[self _blacklistFilePath]];
        if (!_blocked) _blocked = [NSMutableArray arrayWithCapacity:10];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(refresh)
                                                     name:kWeaveDataRefreshNotification
                                                   object:nil];
    }
    return self;
}

#pragma mark Favourites stuff
- (NSArray *)favourites {
    if (_favourites.count < [self maxFavs]) [self _fillFavourites];
    return _favourites;
}

- (void)refresh {
    [_favourites removeAllObjects];
    [self _fillFavourites];
}

- (NSDictionary *)blockItem:(NSDictionary *)item; {
    NSString *urlS = item[@"url"];
    [_blocked addObject:urlS];
    [_blocked writeToFile:[self _blacklistFilePath] atomically:NO];
    
    for (NSUInteger i = 0; i < _favourites.count; i++) {
        if ([_favourites[i][@"url"] isEqualToString:urlS])
            [_favourites removeObjectAtIndex:i];
    }
    
    return [self _fillFavourites];
}

- (void)resetFavourites {
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:[self _blacklistFilePath] error:NULL];
    [fm removeItemAtPath:[self _screenshotPath] error:NULL];
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

//- (void)setFavouriteWithURL:(NSURL *)url title:(NSString *)title atIndex:(NSUInteger)index {
//    NSDictionary *item = @{@"url":url.absoluteString, @"title":title, @"index":@(index)};
//    [_userFavourites addObject:item];//wrong
//    
//    // TODO check if index is already occupied
//    [self refresh];
//}

#pragma mark Screenshot stuff
- (void)webViewDidFinishLoad:(SGWebViewController *)webController; {
    NSURL *url = webController.request.URL;
    if (![self _containsHost:url.host]) return;
    
    NSString *path = [self _imagePathForURL:url];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:path]) {
        NSDictionary *attr = [fm attributesOfItemAtPath:path error:NULL];
        NSDate *modDate = attr[NSFileModificationDate];
        if ([modDate compare:[NSDate dateWithTimeIntervalSinceNow:-60*60*24*3]] == NSOrderedDescending)
            return;
    }
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        
        UIImage *screen = [self _imageWithView:webController.webView];
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
    
    if (image == nil) {
        NSString *path = [self _searchImagePathForURL:url];
        image = [UIImage imageWithContentsOfFile:path];
        if (image) {
            [_imageCache setObject:image forKey:url];
        }
    }
    return image;
}

#pragma mark  - Utility

- (BOOL)_containsHost:(NSString *)host {
    for (NSDictionary *item in _favourites) {
        NSString *urlS = item[@"url"];
        if ([urlS rangeOfString:host].location != NSNotFound// avoid costly conversion
            && [[NSURL URLWithUnicodeString:urlS].host isEqualToString:host])
            return YES;
    }
    return NO;
}

- (NSDictionary *)_fillFavourites {
    NSArray *history = [[Store getStore] getHistory];
    NSArray *bookmarks = [[Store getStore] getBookmarks];
    
    NSDictionary *item;
    NSUInteger i = _favourites.count;
    while (_favourites.count < [self maxFavs]) {
        if (i < bookmarks.count) item = bookmarks[i];
        else if (i < history.count) item = history[i];
        else break;
        
        i++;
        
        NSString *urlS = item[@"url"];
        NSURL *url = [NSURL URLWithUnicodeString:urlS];
        
        if (!url || [self _containsHost:url.host] || [_blocked containsObject:url.absoluteString]) {
            item = nil;
            continue;
        }
        
        // We just need url and title.
        [_favourites addObject:@{@"url":item[@"url"], @"title":item[@"title"]}];
    }
    return item;
}

- (UIImage *)_imageWithView:(UIView *)view {
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

- (NSString *)_screenshotPath {
    NSString* path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    return [path stringByAppendingPathComponent:@"Screenshots"];
}

- (NSString *)_imagePathForURL:(NSURL *)url {
    NSString* path = [self _screenshotPath];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path])
        [fm createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:NULL];
    
    return [[path stringByAppendingPathComponent:url.host] stringByAppendingPathExtension:@"png"];
}

- (NSString *)_searchImagePathForURL:(NSURL *)url {
    NSString* path = [self _screenshotPath];
    NSString *name = url.host;
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:NULL];
    NSString *longest;
    for (NSString *file in files) {
        NSString *main = [file stringByDeletingPathExtension];
        if ([main hasSuffix:name] && longest.length < name.length) {
            longest = main;
        }
    }
    if (longest != nil) {
        return [[path stringByAppendingPathComponent:longest] stringByAppendingPathExtension:@"png"];
    }
    return nil;
}

- (NSString *)_blacklistFilePath {
    NSString* path = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    return [path stringByAppendingPathComponent:@"blacklist.plist"];
}

- (NSString *)_userFavouritesPath {
    NSString* path = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    return [path stringByAppendingPathComponent:@"userfavourites.plist"];
}

@end
