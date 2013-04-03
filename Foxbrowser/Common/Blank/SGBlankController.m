//
//  SGLatestViewController.m
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

#import "SGBlankController.h"
#import "SGTabsViewController.h"
#import "UIViewController+SGBrowserViewController.h"
#import "TabBrowserController.h"
#import "SGBottomView.h"

@implementation SGBlankController

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (UIView *)rotatingFooterView {
    return self.bottomView;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    self.scrollView.contentSize = CGSizeMake(self.scrollView.bounds.size.width + SG_TAB_WIDTH, self.scrollView.bounds.size.height);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"Untitled", @"Untitled tab");
    self.view.backgroundColor = [UIColor whiteColor];
    
    NSArray *titles = @[NSLocalizedString(@"Most popular", @"Most popular websites"),
    NSLocalizedString(@"Other devices", @"Tabs of other devices")];
    NSArray *images = @[[UIImage imageNamed:@"dialpad"], [UIImage imageNamed:@"monitor"]];
    
    SGBottomView *bottomView = [[SGBottomView alloc] initWithTitles:titles images:images];
    CGRect rect = bottomView.frame;
    rect.origin.y = self.view.bounds.size.height - bottomView.frame.size.height;
    rect.size.width = self.view.frame.size.width;
    bottomView.frame = rect;
    bottomView.container = self;
    [self.view addSubview:bottomView];
    _bottomView = bottomView;
    
    CGRect scrollFrame = CGRectMake(0, 0, self.view.bounds.size.width,
                                  self.view.bounds.size.height - bottomView.frame.size.height);
    
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:scrollFrame];
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scrollView.backgroundColor = [UIColor clearColor];
    scrollView.scrollsToTop = NO;
    scrollView.bounces = NO;
    scrollView.pagingEnabled = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone;
    scrollView.decelerationRate = UIScrollViewDecelerationRateFast;
    scrollView.showsHorizontalScrollIndicator = NO;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.delegate = self;
    [self.view addSubview:scrollView];
    self.scrollView = scrollView;
    
    SGPreviewPanel *previewPanel = [[SGPreviewPanel alloc] initWithFrame:scrollFrame];
    previewPanel.delegate = self;
    
    [scrollView addSubview:previewPanel];
    _previewPanel = previewPanel;
    
    TabBrowserController *tabBrowser = [[TabBrowserController alloc] initWithStyle:UITableViewStylePlain];
    [self addChildViewController:tabBrowser];
    tabBrowser.view.frame = CGRectMake(self.view.bounds.size.width, 0, SG_TAB_WIDTH, self.view.bounds.size.height);
    tabBrowser.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleLeftMargin;
    [self.scrollView addSubview:tabBrowser.view];
    [tabBrowser didMoveToParentViewController:self];
    self.tabBrowser = tabBrowser;
}

- (void)viewWillAppear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refresh)
                                                 name:kWeaveDataRefreshNotification
                                               object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidAppear:(BOOL)animated {
    self.scrollView.contentSize = CGSizeMake(self.scrollView.bounds.size.width + SG_TAB_WIDTH, self.scrollView.bounds.size.height);
    [self.browserViewController updateChrome];
}

- (void)willMoveToParentViewController:(UIViewController *)parent {
    if (parent == nil) {
        [self.tabBrowser willMoveToParentViewController:nil];
        [self.tabBrowser removeFromParentViewController];
        self.tabBrowser = nil;
    }
}

- (void)refresh {
    [self.previewPanel refresh];
}

#pragma mark - SGPreviewPanelDelegate
- (void)openNewTab:(SGPreviewTile *)tile {
    if (tile.url)
        [self.browserViewController addTabWithURLRequest:[NSMutableURLRequest requestWithURL:tile.url]
                                                   title:tile.label.text];
}

- (void)open:(SGPreviewTile *)tile {
    if (tile.url)
        [self.browserViewController openURLRequest:[NSMutableURLRequest requestWithURL:tile.url]
                                             title:tile.label.text];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    self.bottomView.markerPosititon = scrollView.contentOffset.x/SG_TAB_WIDTH;
}

@end
