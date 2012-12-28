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
@dynamic blankView;

- (SGBlankView *)blankView {
    return (SGBlankView *)self.view;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)loadView {
    self.view = [[SGBlankView alloc] initWithFrame:CGRectZero];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"New Tab", @"New Tab");
    
    self.tabBrowser = [[TabBrowserController alloc] initWithStyle:UITableViewStylePlain];
    [self addChildViewController:self.tabBrowser];
    self.blankView.tabBrowserView = self.tabBrowser.view;
    [self.blankView.scrollView addSubview:self.tabBrowser.view];
    [self.tabBrowser didMoveToParentViewController:self];
    
    //[self layoutAllViews];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    //[self layoutAllViews];
    //[self.blankView.previewPanel layout];
}

- (UIView *)rotatingFooterView {
    return self.blankView.bottomView;
}

- (void)viewWillAppear:(BOOL)animated {
    self.blankView.previewPanel = [SGPreviewPanel instance];
    self.blankView.previewPanel.delegate = self;
    CGRect previewFrame = self.view.bounds;
    previewFrame.size.height -= 60.;
    self.blankView.previewPanel.frame = previewFrame;
    [self.blankView.scrollView addSubview:self.blankView.previewPanel];
    
   // [self layoutAllViews];
    
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
    [self.blankView.previewPanel refresh];
}

#pragma mark - SGPreviewPanelDelegate
- (void)openNewTab:(SGPreviewTile *)tile {
    if (tile.url) {
        SGTabsViewController *tabsC = (SGTabsViewController *)self.parentViewController;
        [tabsC addTabWithURL:tile.url withTitle:tile.label.text];
    }
}

- (void)open:(SGPreviewTile *)tile {
    if (tile.url) {
        SGTabsViewController *tabsC = (SGTabsViewController *)self.parentViewController;
        [tabsC openURL:tile.url title:tile.label.text];
    }
}

@end

@implementation SGBlankView

#define SG_BOTTOM_BAR_HEIGHT 60.

- (id)initWithFrame:(CGRect)frame {
    frame = CGRectMake(0, 80, 768., 925.);//TODO a proper calculation?
    
    if (self = [super initWithFrame:frame]) {
        frame.size.height -= SG_BOTTOM_BAR_HEIGHT;
        self.scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
        self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.scrollView.canCancelContentTouches = NO;
        self.scrollView.bounces = NO;
        self.scrollView.backgroundColor = [UIColor whiteColor];
        self.scrollView.delegate = self;
        [self addSubview:self.scrollView];
        
        CGRect bottomFrame = CGRectMake(0, frame.size.height, frame.size.width, SG_BOTTOM_BAR_HEIGHT);
        self.bottomView = [[SGBottomView alloc] initWithFrame:bottomFrame];
        self.bottomView.container = self;
        [self addSubview:self.bottomView];
    }
    
    return self;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    self.bottomView.markerPosititon = scrollView.contentOffset.x/SG_TAB_WIDTH;
}

- (void)layoutSubviews {
    CGSize scrollSize = self.scrollView.frame.size;
//    if (scrollSize.width < scrollSize.height) {
//        // The parent view is not yet properly sized
//        CGFloat width = scrollSize.width;
//        scrollSize.width = scrollSize.height;
//        scrollSize.height = width;
//    }
    
    CGSize tabSize = CGSizeMake(SG_TAB_WIDTH, scrollSize.height);
    self.tabBrowserView.frame = CGRectMake(scrollSize.width, 0, tabSize.width, scrollSize.height);
    self.scrollView.contentSize = CGSizeMake(scrollSize.width + tabSize.width, scrollSize.height);
}

@end
