//
//  SGPreviewPanel.m
//  Foxbrowser
//
//  Created by simon on 13.07.12.
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

#import "SGPreviewPanel.h"
#import "SGFavouritesManager.h"
#import "Store.h"

@implementation SGPreviewTile

- (id)initWithURL:(NSURL *)url {
    UIFont *font;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        font = [UIFont fontWithName:@"HelveticaNeue" size:12];
    else
        font = [UIFont fontWithName:@"HelveticaNeue-Light" size:15];

    
    SGFavouritesManager *fm = [SGFavouritesManager sharedManager];
    CGSize size = [fm imageSize];
    if (self = [super initWithFrame:CGRectMake(0, 0, size.width, size.height + 5 + font.lineHeight)]) {
        _url = url;
        
        _label = [[UILabel alloc] initWithFrame:CGRectMake(0, size.height + 5, size.width, font.lineHeight)];
        _label.backgroundColor = [UIColor clearColor];
        _label.font = font;
        _label.textColor = [UIColor darkTextColor];
        _label.text = [fm titleWithURL:url];
        [self addSubview:_label];
        
        _imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
        //_imageView.contentMode = UIViewContentModeCenter;
        _imageView.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1.];
        _imageView.image = [fm imageWithURL:url];
        _imageView.layer.borderColor = [UIColor grayColor].CGColor;
        _imageView.layer.borderWidth = 1.f;
        [self addSubview:_imageView];
    }
    return self;
}

@end

@interface SGPreviewPanel ()
@property (weak, nonatomic) SGPreviewTile *selected;
@property (strong, nonatomic) NSMutableArray *tiles;
@end

@implementation SGPreviewPanel

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self refresh];
        [self layout];
    }
    return self;
}

- (void)layout {
    if (self.tiles.count == 0)
        return;
    
    SGPreviewTile *tile = self.tiles[0];
    CGSize tileSize = tile.frame.size;
    
    //NSUInteger columns = self.bounds.size.width/tileSize.width;
    NSUInteger lines = self.bounds.size.height/tileSize.height;
    NSUInteger columns = self.tiles.count / lines;
    
    CGFloat paddingX = (self.bounds.size.width - columns*tileSize.width)/(columns + 1);
    CGFloat paddingY = (self.bounds.size.height - lines*tileSize.height)/(lines + 1);

    for (NSUInteger i = 0; i < self.tiles.count; i++) {
        NSUInteger line = i / columns;
        NSUInteger column = i % columns;
        
        SGPreviewTile *tile = self.tiles[i];
        CGRect frame = tile.frame;
        frame.origin.x = column*(tileSize.width + paddingX) + paddingX;
        frame.origin.y = line*(tileSize.height + paddingY) + paddingY;
        tile.frame = frame;
    }
}

- (void)layoutSubviews {
    [self layout];
}

- (void)willMoveToWindow:(UIWindow *)newWindow {
    if (newWindow) {
        if (self.tiles.count < [SGFavouritesManager sharedManager].maxFavs) {
            [self refresh];
        }
    }
}

- (void)refresh {
    for (SGPreviewTile *tile in self.tiles) {
        [tile removeFromSuperview];
    }
    [self.tiles removeAllObjects];
    
    SGFavouritesManager *favsMngr = [SGFavouritesManager sharedManager];
    self.tiles = [NSMutableArray arrayWithCapacity:favsMngr.maxFavs];
    
    NSArray *favs = [favsMngr favourites];
    for (NSURL *url in favs) {
        [self addTileWithURL:url];
    }
}

- (void)addTileWithURL:(NSURL *)url {
    SGPreviewTile *tile = [[SGPreviewTile alloc] initWithURL:url];
    tile.center = CGPointMake(self.bounds.size.width + tile.bounds.size.width, self.bounds.size.height/2);
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    tap.delegate  = self;
    [tile addGestureRecognizer:tap];
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                            action:@selector(handleLongPress:)];
    longPress.delegate = self;
    [tile addGestureRecognizer:longPress];
    
    [self addSubview:tile];
    [self.tiles addObject:tile];
}

#pragma mark - Tap Handling, context menu
- (IBAction)handleTap:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        if ([recognizer.view isKindOfClass:[SGPreviewTile class]]) {
            SGPreviewTile *panel = (SGPreviewTile*)recognizer.view;
            [self.delegate open:panel];
        }
    }
}

- (IBAction)handleLongPress:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        if ([recognizer.view isKindOfClass:[SGPreviewTile class]]) {
            self.selected = (SGPreviewTile*)recognizer.view;
            UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:self.selected.url.absoluteString
                                                               delegate:self
                                                      cancelButtonTitle:UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone ? NSLocalizedString(@"Cancel", @"cancel") : nil
                                                 destructiveButtonTitle:NSLocalizedString(@"Remove", @"Remove from page")
                                                      otherButtonTitles:
                                    NSLocalizedString(@"Open", @"Open a link"),
                                    NSLocalizedString(@"Open in a new Tab", nil),nil];
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
                [sheet showFromRect:recognizer.view.frame inView:self animated:YES];
            else
                [sheet showInView:self.window];
        }
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    switch (buttonIndex) {
        case 1:
            [self.delegate open:self.selected];
            break;
            
        case 2:
            [self.delegate openNewTab:self.selected];
            break;
            
        case 0:
        {
            NSURL *next = [[SGFavouritesManager sharedManager] blockURL:self.selected.url];
            [self.tiles removeObject:self.selected];
            
           [UIView transitionWithView:self
                             duration:0.3
                              options:UIViewAnimationOptionAllowAnimatedContent
                           animations:^{
                               [self.selected removeFromSuperview];
                               [self addTileWithURL:next];
                               [self layout];
                           }
                           completion:^(BOOL finished) {
                               //[self.blacklist writeToFile:[SGPreviewPanel blacklistFilePath] atomically:NO];
                           }];
        }
        default:
            break;
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    return YES;
}

@end