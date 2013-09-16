//
//  CHViewController.m
//  CHScrollView
//
//  Created by Lono Kao on 5/29/13.
//  Copyright (c) 2013 com.haifeng. All rights reserved.
//

#import "ViewController.h"
#import "CHScrollView.h"

#import <QuartzCore/QuartzCore.h>

#define ScrollView CHScrollView
#define ScrollViewDelegate CHScrollViewDelegate
@interface ViewController ()<CHScrollViewDelegate>
@property (nonatomic, weak) UIView* appleView;
@property (nonatomic, weak) ScrollView* scrollView;
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    UIImageView* appleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"apple.png"]];
    self.appleView = appleView;
    
    appleView.contentMode = UIViewContentModeScaleToFill;
    
    appleView.frame = CGRectMake(0.0, 0.0, 768, 1024);
    ScrollView* scrollView = [[ScrollView alloc] initWithFrame:self.view.bounds];
    
    scrollView.contentSize = appleView.bounds.size;
    scrollView.delegate = self;
    scrollView.maximumZoomScale = 3.0;
    scrollView.zoomScale = 1.0;
    scrollView.decelerationRate = UIScrollViewDecelerationRateNormal;
    scrollView.backgroundColor = [UIColor blackColor];
    self.scrollView = scrollView;
    
    [scrollView addSubview:appleView];
    
    [self.view addSubview:scrollView];
    
    UITapGestureRecognizer *doubleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(scrollViewDoubleTapped:)];
    doubleTapRecognizer.numberOfTapsRequired = 2;
    doubleTapRecognizer.numberOfTouchesRequired = 1;
    [self.view addGestureRecognizer:doubleTapRecognizer];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UIView*)viewForZoomingInScrollView:(ScrollView *)scrollView
{
    return self.appleView;
}

- (void)scrollViewDoubleTapped:(UITapGestureRecognizer*)recognizer {
    ScrollView* scrollView = self.scrollView;
    CGPoint pointInView = [recognizer locationInView:[self viewForZoomingInScrollView:scrollView]];
    
    // Zoom
    if (scrollView.zoomScale >= scrollView.maximumZoomScale) {
        // Zoom out
        [scrollView setZoomScale:scrollView.minimumZoomScale animated:YES];
        
    } else {
        //[scrollView setZoomScale:scrollView.maximumZoomScale animated:YES];
        [scrollView zoomToRect:CGRectMake(pointInView.x, pointInView.y, 1, 1) animated:YES];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    static int i = 1;
    static CGFloat fps = 60.0f;
    static CGFloat prevOffset = 0.0f;
    static NSTimeInterval prevTime = 0.0f;
    
    CGFloat speed = 0.0f;
    NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];
    if (prevTime != 0.0f) {
        
        CGFloat frameCount = (currentTime - prevTime) / (1.0f/fps);
        speed = (scrollView.contentOffset.y - prevOffset)/ frameCount;
    }
    
    prevOffset = scrollView.contentOffset.y;
    
    
    NSLog(@"[TEST] %d scroll = %f %f speed %f %f", i, scrollView.contentOffset.x, scrollView.contentOffset.y, speed, (currentTime - prevTime));
    ++i;
    prevTime = currentTime;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    NSLog(@"[TEST] velocity.y = %f", velocity.y);
    NSLog(@"[TEST] deceleration = %f", scrollView.decelerationRate);
    NSLog(@"[TEST] calculated constant = %f", (targetContentOffset->y-scrollView.contentOffset.y+velocity.y*velocity.y*(scrollView.decelerationRate+1)/(2*scrollView.decelerationRate))/velocity.y);
    NSLog(@"[TEST] target offset = %f %f", targetContentOffset->x, targetContentOffset->y);
}
@end
