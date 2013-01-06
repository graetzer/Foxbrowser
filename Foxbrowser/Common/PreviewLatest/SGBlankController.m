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

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"Untitled", @"Untitled tab");
    
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scrollView.scrollsToTop = NO;
    scrollView.canCancelContentTouches = NO;
    scrollView.bounces = NO;
    scrollView.backgroundColor = [UIColor whiteColor];
    scrollView.delegate = self;
    [self.view addSubview:scrollView];
    self.scrollView = scrollView;
    
    NSArray *titles = @[NSLocalizedString(@"Most popular", @"Most popular websites"),
    NSLocalizedString(@"Other devices", @"Tabs of other devices")];
    NSArray *images = @[[UIImage imageNamed:@"pictures"], [UIImage imageNamed:@"monitor"]];
    
    SGBottomView *bottomView = [[SGBottomView alloc] initWithTitles:titles images:images];
    CGRect rect = bottomView.frame;
    rect.origin.y = self.view.bounds.size.height - bottomView.frame.size.height;
    rect.size.width = self.view.frame.size.width;
    bottomView.frame = rect;
    bottomView.container = self;
    [self.view addSubview:bottomView];
    _bottomView = bottomView;
    
    TabBrowserController *tabBrowser = [[TabBrowserController alloc] initWithStyle:UITableViewStylePlain];
    [self addChildViewController:tabBrowser];
    tabBrowser.view.frame = CGRectMake(self.view.bounds.size.width, 0, SG_TAB_WIDTH, self.view.bounds.size.height);
    tabBrowser.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleLeftMargin;
    [self.scrollView addSubview:tabBrowser.view];
    [tabBrowser didMoveToParentViewController:self];
    self.tabBrowser = tabBrowser;
    
    CGRect panelRect = CGRectMake(0, 0, self.view.bounds.size.width,
                                  self.view.bounds.size.height - bottomView.frame.size.height);
    SGPreviewPanel *previewPanel = [[SGPreviewPanel alloc] initWithFrame:panelRect];
    previewPanel.delegate = self;
    
    [scrollView addSubview:previewPanel];
    _previewPanel = previewPanel;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (UIView *)rotatingFooterView {
    return self.bottomView;
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
    [self.browserViewController updateChrome];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    
    [self.tabBrowser willMoveToParentViewController:nil];
    [self.tabBrowser removeFromParentViewController];
    self.tabBrowser = nil;
}

- (void)refresh {
    [self.previewPanel refresh];
}

#pragma mark - SGPreviewPanelDelegate
- (void)openNewTab:(SGPreviewTile *)tile {
    if (tile.url)
        [self.browserViewController addTabWithURL:tile.url withTitle:tile.label.text];
}

- (void)open:(SGPreviewTile *)tile {
    if (tile.url)
        [self.browserViewController openURL:tile.url title:tile.label.text];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    self.bottomView.markerPosititon = scrollView.contentOffset.x/SG_TAB_WIDTH;
}

//- (void)layoutSubviews {
//    CGSize scrollSize = self.scrollView.frame.size;
//    
//    CGSize tabSize = CGSizeMake(SG_TAB_WIDTH, scrollSize.height);
//    self.tabBrowserView.frame = CGRectMake(scrollSize.width, 0, tabSize.width, scrollSize.height);
//    self.scrollView.contentSize = CGSizeMake(scrollSize.width + tabSize.width, scrollSize.height);
//}

@end
