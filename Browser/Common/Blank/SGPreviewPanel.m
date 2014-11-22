//
//  SGPreviewPanel.m
//  Foxbrowser
//
//  Created by simon on 13.07.12.
//  Copyright (c) 2012-2014 Simon Peter Grätzer. All rights reserved.
//

#import "SGPreviewPanel.h"
#import "SGFavouritesManager.h"
#import "FXSyncItem.h"
#import "NSStringPunycodeAdditions.h"

@implementation SGPreviewTile

- (id)initWithItem:(FXSyncItem *)item frame:(CGRect)frame {
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
    if (self = [super initWithFrame:frame]) {
        _item = item;
        
        _label = [[UILabel alloc] initWithFrame:CGRectMake(0, frame.size.height - font.lineHeight,
                                                           frame.size.width, font.lineHeight)];
        _label.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin;
        _label.backgroundColor = [UIColor clearColor];
        _label.font = font;
        _label.textColor = [UIColor darkTextColor];
        _label.text = [_item title];
        [self addSubview:_label];
        
        UIImage *image = [fm imageWithURL:url];
        frame.size.height -= _label.frame.size.height + 5;
        _imageView = [[UIImageView alloc] initWithFrame:frame];
        _imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _imageView.layer.borderColor = [UIColor grayColor].CGColor;
        _imageView.layer.borderWidth = 1.f;
        _imageView.backgroundColor = [UIColor clearColor];
        if (image == nil) {
            _imageView.image = [UIImage imageNamed:@"default_thumbnail"];
            _imageView.contentMode = UIViewContentModeScaleToFill;
        } else {
            _imageView.image = image;
            _imageView.contentMode = UIViewContentModeScaleAspectFit;
        }
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

- (void)_layout {
    if (_tiles.count == 0) return;
    
    CGSize s = self.bounds.size;
    CGSize tileSize = CGSizeMake(120, 80);
    CGFloat marginX = 10, marginY = 10;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        tileSize = CGSizeMake(270, 180);
        marginX = 20;
        marginY = 20;
    }
    NSInteger columns = s.width / (tileSize.width+marginX);
    NSInteger lines = s.height / (tileSize.height+marginY);
    CGFloat paddingX = (s.width - columns * (tileSize.width+marginX))/2;
    CGFloat paddingY = (s.height - lines * (tileSize.height+marginY))/2;
    
    for (NSUInteger i = 0; i < _tiles.count; i++) {
        NSUInteger line = i / columns;
        NSUInteger column = i % columns;
        
        if (line == lines-1 && column == 0) {
            NSInteger leftOver = [_tiles count] - i;
            paddingX = (s.width - leftOver * (tileSize.width+marginX))/2;
        }
        
        SGPreviewTile *tile = _tiles[i];
        CGRect frame;
        frame.origin.x = column*(tileSize.width + marginX) + paddingX;
        frame.origin.y = line*(tileSize.height + marginY) + paddingY;
        frame.size = tileSize;
        tile.frame = frame;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self _layout];
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
        CGRect frame = CGRectZero;
        frame.size = CGSizeMake(100, 75);//[self _tileSize];
        SGPreviewTile *tile = [[SGPreviewTile alloc] initWithItem:item frame:frame];
        if (tile != nil) {
            tile.center = CGPointMake(self.bounds.size.width + tile.bounds.size.width, self.bounds.size.height/2);
            
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_handleTap:)];
            tap.delegate  = self;
            [tile addGestureRecognizer:tap];
            UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                                    action:@selector(_handleLongPress:)];
            longPress.delegate = self;
            [tile addGestureRecognizer:longPress];
            
            [self addSubview:tile];
            [_tiles addObject:tile];
        }
    }
}

#pragma mark - Tap Handling, context menu
- (IBAction)_handleTap:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        if ([recognizer.view isKindOfClass:[SGPreviewTile class]]) {
            SGPreviewTile *panel = (SGPreviewTile*)recognizer.view;
            [self.delegate open:panel.item];
        }
    }
}

- (IBAction)_handleLongPress:(UILongPressGestureRecognizer *)recognizer {
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
                               [self _layout];
                           }
                           completion:^(BOOL finished) {
                           }];
        }
        default:
            break;
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
       shouldReceiveTouch:(UITouch *)touch {
    return YES;
}

@end