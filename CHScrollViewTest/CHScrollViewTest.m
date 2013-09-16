//
//  CHScrollViewTest.m
//  CHScrollViewTest
//
//  Created by Lono Kao on 9/14/13.
//  Copyright (c) 2013 com.haifeng. All rights reserved.
//

#import "CHScrollViewAnimationMomentumScrolling.h"
#import "CHScrollViewTest.h"
#import "CHScrollView.h"
@implementation CHScrollViewTest

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)testMomentumScrollingVelocityZero
{
    CHScrollView* scrollView = [[CHScrollView alloc] init];
    CGPoint velocity = CGPointZero;
    CHScrollViewAnimationMomentumScrolling* scrolling = [[CHScrollViewAnimationMomentumScrolling alloc] initWithScrollView:scrollView
                                                                     velocity:velocity];
    CGPoint newVelocity = [scrolling velocityForTargetContentOffset:CGPointZero];
    STAssertTrue(CGPointEqualToPoint(newVelocity, CGPointZero), @"should not move all all");
}

- (void)testMomentumScrollingVelocity
{
    CHScrollView* scrollView = [[CHScrollView alloc] init];
    CGPoint velocity = CGPointZero;
    CHScrollViewAnimationMomentumScrolling* scrolling = [[CHScrollViewAnimationMomentumScrolling alloc] initWithScrollView:scrollView
                                                                                                                  velocity:velocity];
    scrolling.decelerationRate = 0.1;
    CGPoint newVelocity = [scrolling velocityForTargetContentOffset:CGPointMake(11.1, 11.1)];
    STAssertTrue(newVelocity.x > 594 && newVelocity.x <= 600.0, @"other values are acceptalbe. the answer is not unique");
    STAssertTrue(newVelocity.y > 594 && newVelocity.y <= 600.0, @"other values are acceptalbe. the answer is not unique");
}

@end
