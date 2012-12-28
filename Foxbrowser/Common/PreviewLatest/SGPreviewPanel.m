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

#import "SGDimensions.h"
#import "SGPreviewPanel.h"
#import "SGFavouritesManager.h"
#import "Store.h"

#define PADDING 25.
#define TILES_MAX 8

const CGFloat kSGPanelWidth = 220.;
const CGFloat kSGPanelHeigth = 185.;

@implementation SGPreviewTile

- (id)initWithImage:(UIImage *)image title:(NSString *)title {
    CGRect frame = CGRectMake(0, 0, kSGPanelWidth, kSGPanelHeigth);
    
    if (self = [super initWithFrame:frame]) {
        UIFont *font = [UIFont fontWithName:@"HelveticaNeue-Light" size:16.0];
        CGSize size = [title sizeWithFont:font forWidth:frame.size.width lineBreakMode:UILineBreakModeTailTruncation];
        CGRect lFrame = CGRectMake(0, frame.size.height - size.height, size.width, size.height);
        self.label = [[UILabel alloc] initWithFrame:lFrame];
        self.label.backgroundColor = [UIColor clearColor];
        self.label.font = font;
        self.label.textColor = [UIColor darkTextColor];
        self.label.text = title;
        [self addSubview:self.label];
        
        lFrame = CGRectMake(0, 0, frame.size.width, frame.size.height - size.height - 10.);
        self.imageView = [[UIImageView alloc] initWithFrame:lFrame];
        self.imageView.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1.];
        self.imageView.image = image;
        self.imageView.layer.borderColor = [UIColor grayColor].CGColor;
        self.imageView.layer.borderWidth = 1.f;
        [self addSubview:self.imageView];
        
        self.opaque = YES;

    }
    return self;
}

@end

@interface SGPreviewPanel ()
@property (weak, nonatomic) SGPreviewTile *selected;
@property (strong, nonatomic) NSMutableArray *tiles;
@end

@implementation SGPreviewPanel

static SGPreviewPanel *_singletone;
+ (SGPreviewPanel *)instance {
    if (!_singletone) {
        _singletone = [[SGPreviewPanel alloc] initWithFrame:CGRectZero];
    }
    return _singletone;
}

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self refresh];
    }
    return self;
}

- (void)layout {
    UIInterfaceOrientation orientation;
    // Some bug related to whatever
    if (self.bounds.size.width > self.bounds.size.height) {
        orientation = UIInterfaceOrientationLandscapeLeft;
    } else {
        orientation = UIInterfaceOrientationPortrait;
    }
    
    NSUInteger columns = UIInterfaceOrientationIsPortrait(orientation) ? 2 : 4;
    NSUInteger lines = UIInterfaceOrientationIsPortrait(orientation) ? 4 : 2;
    
    CGFloat startX = (self.bounds.size.width - columns*(kSGPanelWidth + PADDING) + PADDING)/2;
    CGFloat startY = (self.bounds.size.height - lines*(kSGPanelHeigth + PADDING) + PADDING)/2;
    
    NSUInteger i = 0;
    for (SGPreviewTile *tile in self.tiles) {
        NSUInteger line = i / columns;
        NSUInteger column = i % columns;
        CGRect frame = tile.frame;
        frame.origin.x = column*(kSGPanelWidth + PADDING) + startX;
        frame.origin.y = line*(kSGPanelHeigth + PADDING) + startY;
        tile.frame = frame;
        i++;
    }
}

- (void)layoutSubviews {
    [self layout];
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
    if (newSuperview) {
        if (self.tiles.count < TILES_MAX) {
            [self refresh];
        }
    }
}

- (void)refresh {
    for (SGPreviewTile *tile in self.tiles) {
        tile.label = nil;
        tile.imageView = nil;
        [tile removeFromSuperview];
    }
    [self.tiles removeAllObjects];
    self.tiles = [NSMutableArray arrayWithCapacity:TILES_MAX];
    
    SGFavouritesManager *favsMngr = [SGFavouritesManager sharedManager];
    
    NSArray *favs = [favsMngr favourites];
    for (NSDictionary *item in favs) {
        NSString *title = [item objectForKey:@"title"];
        NSString *urlS = [item objectForKey:@"url"];
        NSURL *url = [NSURL URLWithString:urlS];
        UIImage *image = [favsMngr imageWithURL:url];
        
        
        SGPreviewTile *tile = [[SGPreviewTile alloc] initWithImage:image title:title];
        tile.url = url;
        tile.center = CGPointMake(self.bounds.size.width + tile.bounds.size.width, self.bounds.size.height/2);
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        tap.delegate  = self;
        [tile addGestureRecognizer:tap];
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        longPress.delegate = self;
        [tile addGestureRecognizer:longPress];
        
        [self addSubview:tile];
        [self.tiles addObject:tile];
    }
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
                                                      cancelButtonTitle:nil
                                                 destructiveButtonTitle:nil
                                                      otherButtonTitles:
                                    NSLocalizedString(@"Open", @"Open a link"),
                                    NSLocalizedString(@"Open in a new Tab", nil),
                                    NSLocalizedString(@"Remove", @"Remove from page"), nil];
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
                [sheet showFromRect:recognizer.view.frame inView:self animated:YES];
            else
                [sheet showInView:self.window];
        }
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    switch (buttonIndex) {
        case 0:
            [self.delegate open:self.selected];
            break;
            
        case 1:
            [self.delegate openNewTab:self.selected];
            break;
            
        case 2:
        {
            [[SGFavouritesManager sharedManager] blockURL:self.selected.url];
            [self.tiles removeObject:self.selected];
            
           [UIView transitionWithView:self
                             duration:0.3
                              options:UIViewAnimationOptionAllowAnimatedContent
                           animations:^{
                               [self.selected removeFromSuperview];
                               [self refresh];
                               [self layoutSubviews];
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