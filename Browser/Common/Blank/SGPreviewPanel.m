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
#import "FXSyncItem.h"
#import "NSStringPunycodeAdditions.h"

@implementation SGPreviewTile

- (id)initWithItem:(FXSyncItem *)item {
    NSString *urlS = [item urlString];
    NSURL *url = [NSURL URLWithUnicodeString:urlS];
    if (url == nil) return nil;
    
    UIFont *font;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        font = [UIFont fontWithName:@"HelveticaNeue" size:12];
    } else {
        font = [UIFont fontWithName:@"HelveticaNeue-Light" size:15];
    }
    
    SGFavouritesManager *fm = [SGFavouritesManager sharedManager];
    CGSize size = [fm imageSize];
    if (self = [super initWithFrame:CGRectMake(0, 0, size.width, size.height + 5 + font.lineHeight)]) {
        _item = item;
        
        _label = [[UILabel alloc] initWithFrame:CGRectMake(0, size.height + 5, size.width, font.lineHeight)];
        _label.backgroundColor = [UIColor clearColor];
        _label.font = font;
        _label.textColor = [UIColor darkTextColor];
        _label.text = [_item title];
        [self addSubview:_label];
        
        UIImage *image = [fm imageWithURL:url];

        _imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
        
        _imageView.backgroundColor = [UIColor clearColor];
        if (image == nil) {
            _imageView.image = [UIImage imageNamed:@"default_thumbnail"];
            _imageView.contentMode = UIViewContentModeScaleToFill;
        } else {
            _imageView.image = image;
            _imageView.contentMode = UIViewContentModeScaleAspectFit;
        }
        
        _imageView.layer.borderColor = [UIColor grayColor].CGColor;
        _imageView.layer.borderWidth = 1.f;
        [self addSubview:_imageView];
    }
    return self;
}

@end


@implementation SGPreviewPanel {
    __weak SGPreviewTile *_selected;
    NSMutableArray *_tiles;
}

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    return self;
}

- (void)layout {
    if (_tiles.count == 0) return;
    
    SGPreviewTile *tile = _tiles[0];
    CGRect b = self.bounds;
    CGSize tileSize = tile.frame.size;
    
    NSUInteger columns, lines;
    if (b.size.width > b.size.height) {
        columns = b.size.width/tileSize.width;
        lines = MAX((_tiles.count + (columns-1)) / columns, 1);
    } else {
        lines = b.size.height/tileSize.height;
        columns = MAX((_tiles.count + (lines-1)) / lines, 1);
    }
    
    CGFloat paddingX = (b.size.width - columns*tileSize.width)/(columns + 1);
    CGFloat paddingY = (b.size.height - lines*tileSize.height)/(lines + 1);
    
    for (NSUInteger i = 0; i < _tiles.count; i++) {
        NSUInteger line = i / columns;
        NSUInteger column = i % columns;
        
        SGPreviewTile *tile = _tiles[i];
        CGRect frame = tile.frame;
        frame.origin.x = column*(tileSize.width + paddingX) + paddingX;
        frame.origin.y = line*(tileSize.height + paddingY) + paddingY;
        tile.frame = frame;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self layout];
}

- (void)willMoveToWindow:(UIWindow *)newWindow {
    [super willMoveToWindow:newWindow];
    if (newWindow) {
        if (_tiles.count < [SGFavouritesManager sharedManager].maxFavs) {
            [self refresh];
        }
    }
}

- (void)refresh {
    for (SGPreviewTile *tile in _tiles) {
        [tile removeFromSuperview];
    }
    [_tiles removeAllObjects];
    
    SGFavouritesManager *favsMngr = [SGFavouritesManager sharedManager];
    _tiles = [NSMutableArray arrayWithCapacity:favsMngr.maxFavs];
    
    NSArray *favs = [favsMngr favourites];
    for (FXSyncItem *item in favs) {
        [self addTileWithItem:item];
    }
}

- (void)addTileWithItem:(FXSyncItem *)item {
    if (item != nil) {
        SGPreviewTile *tile = [[SGPreviewTile alloc] initWithItem:item];
        if (tile != nil) {
            tile.center = CGPointMake(self.bounds.size.width + tile.bounds.size.width, self.bounds.size.height/2);
            
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
            tap.delegate  = self;
            [tile addGestureRecognizer:tap];
            UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                                    action:@selector(handleLongPress:)];
            longPress.delegate = self;
            [tile addGestureRecognizer:longPress];
            
            [self addSubview:tile];
            [_tiles addObject:tile];
        }
    }
}

#pragma mark - Tap Handling, context menu
- (IBAction)handleTap:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        if ([recognizer.view isKindOfClass:[SGPreviewTile class]]) {
            SGPreviewTile *panel = (SGPreviewTile*)recognizer.view;
            [self.delegate open:panel.item];
        }
    }
}

- (IBAction)handleLongPress:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        if ([recognizer.view isKindOfClass:[SGPreviewTile class]]) {
            _selected = (SGPreviewTile*)recognizer.view;
            NSString *cancel = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone ? NSLocalizedString(@"Cancel", @"cancel") : nil;
            
            NSString *title = [_selected.item title];
            if ([title length] == 0) {
                title = [_selected.item urlString];
            }
            
            UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:title
                                                               delegate:self
                                                      cancelButtonTitle:cancel
                                                 destructiveButtonTitle:NSLocalizedString(@"Remove", @"Remove from page")
                                                      otherButtonTitles:
                                    NSLocalizedString(@"Open", @"Open a link"),
                                    NSLocalizedString(@"Open in a new Tab", nil),nil];
            
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                [sheet showFromRect:recognizer.view.frame inView:self animated:YES];
            } else {
                [sheet showInView:self.window.rootViewController.view];
            }
        }
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    switch (buttonIndex) {
        case 1:
            [self.delegate open:_selected.item];
            break;
            
        case 2:
            [self.delegate openNewTab:_selected.item];
            break;
            
        case 0: {
            FXSyncItem *next = [[SGFavouritesManager sharedManager] blockItem:_selected.item];
            [_tiles removeObject:_selected];
            
           [UIView transitionWithView:self
                             duration:0.3
                              options:UIViewAnimationOptionAllowAnimatedContent
                           animations:^{
                               [_selected removeFromSuperview];
                               [self addTileWithItem:next];
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