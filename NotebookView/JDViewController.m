//
//  JDViewController.m
//  NotebookView
//
//  Created by Josh Deprez on 22/09/12.
//
//  JDNotebookView is licensed under the MIT license.
//
//  Copyright (c) 2012 Josh Deprez.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is furnished
//  to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "JDViewController.h"

#import <QuartzCore/QuartzCore.h>

typedef enum {
	kLeftSide = 0,
	kRightSide = 1
} PageSide;


@interface JDViewController ()
// Pages in the notebook. In addition to the ones containing content, there are two extra either side so that
// shadows work when the scroller goes outside the content area.
@property NSMutableArray *pages;

// Did the user touch the page control to change pages?
// Used to prevent mutual recursion.
@property BOOL pageControlUsed;
@end

#pragma mark -
#pragma mark NotebookPageView 

// A single page in the notebook.
@interface JDNotebookPageView : UIView 
// Consider what else your page view needs:
// - A section title label?
// - Reference to an array of content?
// - Make it pretty with background image views?
// - Reference to the view coontroller to pass back events?

// Label for demo purposes
@property UILabel *pageLabel;

// Consider using the needsReload / reloadData approach to manage content loading.
@property BOOL needsReload;

// Which side of the book is this page on?
@property NSInteger side;

// Shadow when a page is hovering over this one
@property CAGradientLayer *grad;

// Call to reload the data displayed in a page
-(void) reloadData;
@end

@implementation JDNotebookPageView

-(id) init
{
    if ((self = [super init])) {
    
        // Customise your page view
        self.backgroundColor = [UIColor whiteColor];
        
        self.pageLabel = [[UILabel alloc] init];
        self.pageLabel.alpha = 1.f;
        [self addSubview:self.pageLabel];
        
        // Set up the shadow gradient
        self.grad = [CAGradientLayer layer];
        
        // Prevent implicit animations when we change these properties.
		self.grad.actions = [NSDictionary dictionaryWithObjectsAndKeys:
							 [NSNull null], @"opacity",
							 [NSNull null], @"endPoint",
							 [NSNull null], @"startPoint",
							 nil];
        
        // Start hidden!
        self.grad.opacity = 0.f;
        
        // A black gradient from fully clear to 40% alpha black.
		self.grad.colors = [NSArray arrayWithObjects:(id)[UIColor clearColor].CGColor,
							(id)[UIColor colorWithWhite:0.f alpha:0.40f].CGColor,
							nil];
        
		[self.layer addSublayer:self.grad];
    }
    return self;
}

-(void) reloadData {
    // Consider doing your reload here
    //NSLog(@"%s", __PRETTY_FUNCTION__);
    
    // No longer need reload, but do need layout
	self.needsReload = NO;
	[self setNeedsLayout];
}

-(void) layoutSubviews
{
    // Customise with your subviews
    self.pageLabel.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    
    // Ensure the gradient is in the right spot
    CGFloat right = (self.side == kRightSide ? 1.f : 0.f);
    
    self.grad.frame = self.bounds;
	self.grad.startPoint = CGPointMake(right, 0.5f);
	self.grad.endPoint = CGPointMake(1.f - right, 0.5f);
}

@end

#pragma mark -
#pragma mark JDViewController

@implementation JDViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self recomposePageViews];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

-(void) viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	[self setupPositions:self.interfaceOrientation];
}

-(BOOL)shouldAutorotate {
    return YES;
}

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}


-(void) setupPositions:(UIInterfaceOrientation)interfaceOrientation {
    //NSLog(@"%s", __PRETTY_FUNCTION__);
    
    CGFloat portrait = (UIInterfaceOrientationIsPortrait(interfaceOrientation) ? 1.0 : 0.0);
    CGFloat landscape = (UIInterfaceOrientationIsLandscape(interfaceOrientation) ? 1.0 : 0.0);
    
    // Fix the scrollView content area
	self.scrollView.contentOffset = CGPointMake(self.notebookPageControl.currentPage * CGRectGetWidth(self.scrollView.frame), 0);
	self.scrollView.contentSize = CGSizeMake(self.notebookPageControl.numberOfPages * CGRectGetWidth(self.scrollView.frame), 100);
    
    // Reposition all the pages and so it doesn't look stupid, remove the 3D transforms while repositioning
	for (JDNotebookPageView *page in self.pages) {
		
		CATransform3D existingTransform = page.layer.transform;
		page.layer.transform = CATransform3DIdentity;
        
        // Position the pages; override the page view's layoutSubviews to reposition any content
		page.frame = CGRectMake(0,0, portrait * 368 + landscape * 456,
								portrait * 707 + landscape * 466);
		page.center = CGPointMake((int)CGRectGetMidX(self.scrollView.bounds),
								  CGRectGetMidY(self.scrollView.bounds));
		[page layoutSubviews];
		page.layer.transform = existingTransform;
	}
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:interfaceOrientation duration:duration]; // Nothing

    [self setupPositions:interfaceOrientation];
    
}

// Recompose the page views
// Decides how many pages to create and sets them up.
-(void) recomposePageViews
{    
    // First, remove all the existing pages and recreate the array.
	[self.pages makeObjectsPerformSelector:@selector(removeFromSuperview)];
	
	self.pages = [NSMutableArray array];
    
    // Figure out how many pages you need
	//const uint itemsPerFace = kItemsPerSpread / 2;
	uint i=0;
	JDNotebookPageView *page;
	
    // Fake two pages either side to get shadow
    page = [[JDNotebookPageView alloc] init];
    [self.pages addObject:page];
    page.frame = CGRectMake(0,0,CGRectGetWidth(self.scrollView.frame) / 2, CGRectGetHeight(self.scrollView.frame));
    page.side = kLeftSide;
    page.alpha = 0.f;
    page.layer.anchorPoint = CGPointMake(1.f, 0.5f);
    [self.scrollView addSubview:page];
   
    page = [[JDNotebookPageView alloc] init];
    [self.pages addObject:page];
    page.frame = CGRectMake(0,0,CGRectGetWidth(self.scrollView.frame) / 2, CGRectGetHeight(self.scrollView.frame));
    page.side = kRightSide;
    page.alpha = 0.f;
    page.layer.anchorPoint = CGPointMake(0.f, 0.5f);
    [self.scrollView addSubview:page];
 
	// Actual content pages, 6 for demo purposes.
	page = nil;
	for (i=0; i<6; ++i) {
        page = [[JDNotebookPageView alloc] init];
        [self.pages addObject:page];
        page.frame = CGRectMake(0,0,CGRectGetWidth(self.scrollView.frame) / 2, CGRectGetHeight(self.scrollView.frame));
        page.side = (i % 2 == 0 ? kLeftSide : kRightSide);
        
        // Set up additional things in your page
        page.pageLabel.text = [NSString stringWithFormat:@"Page %d", i];
        [page.pageLabel sizeToFit];
        
        page.alpha = 0.f;
        page.layer.anchorPoint = CGPointMake(1 - (i % 2), 0.5f);
        page.needsReload = YES;
        [self.scrollView addSubview:page];
		
	}
	
    // Pad with one extra right page if using a non-even number of pages
    if (self.pages.count % 2) { 
        page = [[JDNotebookPageView alloc] init];
        [self.pages addObject:page];
        page.frame = CGRectMake(0,0,CGRectGetWidth(self.scrollView.frame) / 2, CGRectGetHeight(self.scrollView.frame));
        page.side = kRightSide;
        page.alpha = 0.f;
        page.layer.anchorPoint = CGPointMake(0.f, 0.5f);
        [self.scrollView addSubview:page];
    }
    
    // Two non-content pages either side to get shadow
    page = [[JDNotebookPageView alloc] init];
    [self.pages addObject:page];
    page.frame = CGRectMake(0,0,CGRectGetWidth(self.scrollView.frame) / 2, CGRectGetHeight(self.scrollView.frame));
    page.side = kLeftSide;
    page.alpha = 0.f;
    page.layer.anchorPoint = CGPointMake(1.f, 0.5f);
    [self.scrollView addSubview:page];
    page = [[JDNotebookPageView alloc] init];
    [self.pages addObject:page];
    page.frame = CGRectMake(0,0,CGRectGetWidth(self.scrollView.frame) / 2, CGRectGetHeight(self.scrollView.frame));
    page.side = kRightSide;
    page.alpha = 0.f;
    page.layer.anchorPoint = CGPointMake(0.f, 0.5f);
    [self.scrollView addSubview:page];
	
    // Adjust the content size to reflect the number of pages.
	self.scrollView.contentSize = CGSizeMake((i+1)/2 * CGRectGetWidth(self.view.frame), 100);
	self.notebookPageControl.numberOfPages = (i+1) / 2;
	self.notebookPageControl.currentPage = /*self.currentPage =*/ 0;
	
    // Get the left and right pages showing to load their data, and then show them.
	JDNotebookPageView *leftPage = nil, *rightPage = nil;
	if (self.pages.count > 2) {
		leftPage = [self.pages objectAtIndex:2];
		if (self.pages.count > 3) {
			rightPage = [self.pages objectAtIndex:3];
		}
	}
	[leftPage reloadData];
	[rightPage reloadData];
	
	leftPage.alpha = rightPage.alpha = 1.f;
}


-(void) notebookPageControlChanged:(id)sender {
    // From the page selected by the page control, scroll to that page.
    
	int page = self.notebookPageControl.currentPage, width = self.scrollView.contentSize.width / self.notebookPageControl.numberOfPages;
    [self.scrollView scrollRectToVisible:CGRectMake(page * width - (CGRectGetWidth(self.scrollView.frame) - width) / 2,
                                                       0,
                                                       CGRectGetWidth(self.scrollView.frame),
                                                       CGRectGetHeight(self.scrollView.frame))
                                   animated:YES];
    self.pageControlUsed = YES;
}



#pragma mark -
#pragma mark UIScrollViewDelegate methods


-(void) scrollViewDidScroll:(UIScrollView *)scrollView {
    
    // If this is a user scroll, detect which page we are on right now and update the page control.
	if (!self.pageControlUsed) {
		CGFloat pageWidth = scrollView.contentSize.width / self.notebookPageControl.numberOfPages;
		int page = floor((scrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1;
		
		if (page != self.notebookPageControl.currentPage)
		{
			self.notebookPageControl.currentPage = page;
		}
	}
    
	CGFloat w = CGRectGetWidth(scrollView.frame);
	CGFloat nx = scrollView.contentOffset.x / w;
	
    // Figure out the index into the pages array
    // and decide which pages to bring to the front.
	uint j = 2*(uint)nx + 3; // Two per spread plus the dummy pages plus 1 for the page on the right
	if (j < self.pages.count) {
		[scrollView bringSubviewToFront:[self.pages objectAtIndex:j]];
        // Plus another 1 to show the page on the opposite of the page on the right (the next left page)
		if (j+1 < self.pages.count) {
			[scrollView bringSubviewToFront:[self.pages objectAtIndex:j+1]];
		}
	}
	
    // Adjust all the pages based on the scroll position.
	for (int i=0; i<self.pages.count; ++i) {
		JDNotebookPageView *page = [self.pages objectAtIndex:i];
		
        // Maths!
		page.center = CGPointMake((int)CGRectGetMidX(scrollView.bounds),
								  CGRectGetMidY(scrollView.bounds));
		float pivot = ((i-2)/2) + 0.25f - (i&1)*0.5f;
		page.alpha = (fabs(pivot - nx) < 0.75) ? 1.f : 0.f;
        
        // If the page has become visible and needs a reload, reload ASAP!
		if (page.alpha && page.needsReload) [page reloadData];
		
        // Change the positioning and opacity of the shadow layers.
		if (((i&1) == 0) == (nx > pivot)) {
            // This page is under the page being lifted
			page.grad.endPoint = CGPointMake((1 - (i&1)) + ((i&1) ? 1 : -1)*sin(M_PI * fabs(pivot - nx) - M_PI_4), 0.5f);
			page.grad.startPoint = CGPointMake(((i&1) ? 0.1f : -0.1f) + page.grad.endPoint.x, 0.5f);
			page.grad.opacity = 1.f;
		} else {
            // This page is being lifted and should grey out as it approaches right angles with the book
			page.grad.endPoint = CGPointMake((i&1) ? 0.f : 1.f, 0.5f);
			page.grad.startPoint = CGPointMake((i&1) ? 1.f : 0.f, 0.5f);
			page.grad.opacity = MIN(1.f, MAX(0.f, 2.f*fabs(pivot - nx) - 0.5f));
        }

		CGFloat turn = MIN(1.f, MAX(0.f, (((i-2)/2) - nx) * (i%2 ? -1 : 1)));
        
        // Apply the 3D transform to the page.
		CATransform3D transform = CATransform3DMakeRotation((i%2 ? M_PI : -M_PI) * turn, 0.0f, -1.0f, 0.0f);
        // Adjust the transform slightly to add perspective
		transform.m14 = (i%2 ? -0.001f : 0.001f) * turn;
		transform.m34 = (i%2 ? 0.002f : -0.002f) * turn;
		page.layer.transform = transform;
	}
    
}


- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    self.pageControlUsed = NO;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    self.pageControlUsed = NO;
}

@end
