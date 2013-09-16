//
//  CHScrollViewAnimationMomentumScrolling.h
//  CHScrollView
//
//  Created by Hai Feng Kao on 5/31/13.
//  Copyright (c) 2013 Hai Feng Kao All rights reserved.
//

#import "CHScrollViewAnimationDeceleration.h"

@interface CHScrollViewAnimationMomentumScrolling : CHScrollViewAnimationDeceleration
@property (nonatomic, assign) CGFloat decelerationRate; // unit test only

- (CGPoint)targetContentOffset;
- (CGPoint)velocityForTargetContentOffset:(CGPoint)targetOffset;
@end

// unit test only
BOOL BounceComponent(NSTimeInterval t, CHScrollViewAnimationDecelerationComponent *c, CGFloat to, CGFloat decelerationRate);