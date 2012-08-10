//
//  SGPreviewPanel.m
//  Foxbrowser
//
//  Created by simon on 13.07.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import "SGDimensions.h"
#import "SGPreviewPanel.h"
#import "UIWebView+WebViewAdditions.h"
#import "Store.h"

#define PADDING 25.
#define PANEL_MAX 8

const CGFloat kSGPanelWidth = 220.;
const CGFloat kSGPanelHeigth = 185.;

@implementation SGPreviewTile
@synthesize imageButton, label, info;

/*
 Helvetica-LightOblique,
 Helvetica,
 Helvetica-Oblique,
 Helvetica-BoldOblique,
 Helvetica-Bold,
 Helvetica-Light

 */

- (id)initWithImage:(UIImage *)image title:(NSString *)title {
    CGRect frame = CGRectMake(0, 0, kSGPanelWidth, kSGPanelHeigth);
    
    if (self = [super initWithFrame:frame]) {
        UIFont *font = [UIFont fontWithName:@"Helvetica-Light" size:16.0];
        CGSize size = [title sizeWithFont:font forWidth:frame.size.width lineBreakMode:UILineBreakModeTailTruncation];
        CGRect lFrame = CGRectMake(0, frame.size.height - size.height, size.width, size.height);
        self.label = [[UILabel alloc] initWithFrame:lFrame];
        self.label.backgroundColor = [UIColor clearColor];
        self.label.font = font;
        self.label.textColor = [UIColor darkTextColor];
        self.label.text = title;
        [self addSubview:self.label];
        
        lFrame = CGRectMake(0, 0, frame.size.width, frame.size.height - size.height - 10.);
        self.imageButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.imageButton.frame = lFrame;
        self.imageButton.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1.];
        [self.imageButton setImage:image forState:UIControlStateNormal];
        self.imageButton.layer.borderColor = [UIColor grayColor].CGColor;
        self.imageButton.layer.borderWidth = 1.f;
        [self addSubview:self.imageButton];
        
        self.opaque = YES;

    }
    return self;
}

@end

static const NSString *blockedFile = @"blocked.plist";

@interface SGPreviewPanel ()
@property (weak, nonatomic) SGPreviewTile *selected;
@property (strong, nonatomic) NSMutableArray *tiles;
@property (strong, nonatomic) NSMutableArray *blacklist;
@end

@implementation SGPreviewPanel

static SGPreviewPanel *_singletone;
+ (SGPreviewPanel *)instance {
    if (!_singletone) {
        _singletone = [[SGPreviewPanel alloc] initWithFrame:CGRectZero];
    }
    return _singletone;
}

+ (NSString *)blacklistFilePath {
    NSString* path = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    path = [path stringByAppendingPathComponent:@"blacklist.plist"];
    return path;
}

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self refresh];
    }
    return self;
}

- (void)layoutSubviews {
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

- (BOOL)tilesContainID:(id)ID {
    for (SGPreviewTile *tile in self.tiles) {
        if (tile.info && [[tile.info objectForKey:@"id"] isEqual:ID]) {
            return YES;
        }
    }
    return NO;
}

- (void)addMissingTiles {
    NSArray *history = [[Store getStore] getHistory];
    
    NSUInteger i = self.tiles.count;
    while (self.tiles.count < PANEL_MAX && i < history.count) {
        NSDictionary *item = [history objectAtIndex:i];
        i++;
        id ID = [item objectForKey:@"id"];
        if ([self tilesContainID:ID] || [self.blacklist containsObject:ID]) {
            continue;
        }

        NSString *title = [item objectForKey:@"title"];
        NSString *urlS = [item objectForKey:@"url"];
        UIImage *image = [self imageForURLString:urlS];
        SGPreviewTile *tile = [[SGPreviewTile alloc] initWithImage:image title:title];
        tile.info = item;
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

- (void)refresh {
    self.blacklist = [NSMutableArray arrayWithContentsOfFile:[SGPreviewPanel blacklistFilePath]];
    if (!self.blacklist)
        self.blacklist = [NSMutableArray new];
    
    for (SGPreviewTile *tile in self.tiles) {
        tile.label = nil;
        tile.imageButton = nil;
        [tile removeFromSuperview];
    }
    [self.tiles removeAllObjects];
    self.tiles = [NSMutableArray arrayWithCapacity:PANEL_MAX];
    [self addMissingTiles];
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
            UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil
                                                               delegate:self
                                                      cancelButtonTitle:nil
                                                 destructiveButtonTitle:nil
                                                      otherButtonTitles:
                                    NSLocalizedString(@"Open", @"Open a link"),
                                    NSLocalizedString(@"Open in a new Tab", nil),
                                    NSLocalizedString(@"Remove", @"Remove from page"), nil];
            [sheet showFromRect:recognizer.view.frame inView:self animated:YES];
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
            NSDictionary *item = self.selected.info;
            [self.blacklist addObject:[item objectForKey:@"id"]];
            [self.tiles removeObject:self.selected];
            
           [UIView transitionWithView:self
                             duration:0.3
                              options:UIViewAnimationOptionAllowAnimatedContent
                           animations:^{
                               [self.selected removeFromSuperview];
                               [self addMissingTiles];
                               [self layoutSubviews];
                           }
                           completion:^(BOOL finished) {
                               [self.blacklist writeToFile:[SGPreviewPanel blacklistFilePath] atomically:NO];
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

- (UIImage *)imageForURLString:(NSString *)urlS {
    NSURL *url = [NSURL URLWithString:urlS];
    NSString *path = [UIWebView pathForURL:url];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return [UIImage imageWithContentsOfFile:path];
    } else {
        NSDictionary *attr = [NSDictionary dictionaryWithObjectsAndKeys:NSFileModificationDate, [NSDate distantPast], nil];
        [[NSFileManager defaultManager] createFileAtPath:path contents:[NSData data] attributes:attr];
        return nil;
    }
}

@end