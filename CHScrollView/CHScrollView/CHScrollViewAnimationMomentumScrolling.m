//
//  CHScrollViewAnimationMomentumScrolling.m
//  CHScrollView
//
//  Created by Hai Feng Kao on 5/31/13.
//  Copyright (c) 2013 Hai Feng Kao All rights reserved.
//

#import "CHScrollViewAnimationMomentumScrolling.h"
static const CGFloat DEFAULT_DECELERATION_RATE = 0.95;

static const CGFloat minimumBounceVelocityBeforeReturning = 100;
static const NSTimeInterval returnAnimationDuration = 0.33;

static const CGFloat springTightness = 7;
static const CGFloat springDampening = 15;

static CGFloat ClampedVelocity(CGFloat v)
{
    // do not clamp
    return v;
}

/**
 Compute the force of spring
 */
static CGFloat Spring(CGFloat velocity, CGFloat position, CGFloat restPosition, CGFloat tightness, CGFloat damping)

{
    // spring-damper system: F = - kx - bv
    const CGFloat d = position - restPosition;
    return (-tightness * d) - (damping * velocity);
}

BOOL BounceComponent(NSTimeInterval t, CHScrollViewAnimationDecelerationComponent *c, CGFloat to, CGFloat decelerationRate)
{
    if (c->bounced && c->returnTime != 0) {
        NSTimeInterval returnBounceTime = MIN(1.0f, ((t - c->returnTime) / returnAnimationDuration));
        c->position = CHQuadraticEaseOut(returnBounceTime, c->returnFrom, to);
        if (abs(c->position - to) < 0.5f) {
            // we are very close, just wrap it to the target
            c->position = to;
            returnBounceTime = 1.0f;
        }
        return (returnBounceTime == 1.0f);
    } else if (to - c->position == 0 && abs(c->velocity* physicsTimeStep) < 1.0f) {
        return YES;
    } else if (c->position != to){
        // the scrol view moves out of bounds
        const CGFloat F = Spring(c->velocity, c->position, to, springTightness, springDampening);
        
        c->velocity += F * physicsTimeStep;
        c->position += c->velocity * physicsTimeStep;
        
        if (fabsf(c->velocity) < minimumBounceVelocityBeforeReturning) {
            c->returnFrom = c->position;
            c->returnTime = t;
            c->bounced = YES;
        }
        
        return NO;
    } else {
        // normal deceleration
        c->position += c->velocity * physicsTimeStep;
        c->velocity *= decelerationRate;

        return NO;
    }
}

static NSInteger IterationToStop(CGFloat displacement,
                                 CGFloat decelerationRate,
                                 CGFloat* guessInitialSpeed)
{
    if (decelerationRate >= 1.0 || decelerationRate <= 0.0) {
        return 0; // bad parameters
    }
    if (guessInitialSpeed == NULL) {
        return 0; // bad parameters
    }
    
    NSInteger it = 0;
    
    CGFloat dist = abs(displacement);
    CGFloat speed = abs(*guessInitialSpeed);
    
    NSInteger count = 0;
    do {
        // the movement will stop when v0*r^n < 1
        // we will have n > -log v0 /log r
        
        if (speed < 1.0) {
            it = 0; // we want to avoid "log 0" case
        }else {
            it = floor(-log(speed)/log(decelerationRate)) + 1;
        }
        
        // v0 + v0*r + ... + v0*r^n = x
        speed = dist / (1.0 - pow(decelerationRate, it+1)) * (1.0 - decelerationRate);
        
        ++count;
    } while (count < 30); // the above formulus may not converge
    
    
    if (displacement < 0.0) {
        speed = -speed;
    }
    
    *guessInitialSpeed = speed;
    return it;
}

static BOOL Simulate(NSTimeInterval destinationTime,
                            NSTimeInterval* currentTime,
                            CHScrollViewAnimationDecelerationComponent *x,
                            CHScrollViewAnimationDecelerationComponent *y,
                            CGFloat decelerationRate,
                            CGFloat physicsTimeStep,
                            CHScrollView* scrollView)
{
    if (currentTime == nil || x == nil || y == nil) {
        return YES; // bad parameters
    }
    
    if (decelerationRate >= 1.0f // it will stop immediately
       || decelerationRate <= 0.0f // it will not stop all all
    )
    {
        return YES;
    }
    
    BOOL finished = NO;

    NSTimeInterval lastAnimatedTime = *currentTime;
    while (!finished && destinationTime >= lastAnimatedTime) {
        CGPoint currentOffset = CGPointMake(x->position, y->position);
        CGPoint confinedOffset = [scrollView _confinedContentOffset:currentOffset];
        const BOOL verticalIsFinished   = BounceComponent(lastAnimatedTime, y, confinedOffset.y, decelerationRate);
        const BOOL horizontalIsFinished = BounceComponent(lastAnimatedTime, x, confinedOffset.x, decelerationRate);
        
        finished = (verticalIsFinished && horizontalIsFinished);
        
        lastAnimatedTime += physicsTimeStep;
    }

    *currentTime = lastAnimatedTime; // update currentTime
    return finished;
}


@interface CHScrollViewAnimationMomentumScrolling()
@end


@implementation CHScrollViewAnimationMomentumScrolling

- (id)initWithScrollView:(CHScrollView *)sv velocity:(CGPoint)v
{
    self = [super initWithScrollView:sv velocity:v];
    
    if (self) {
        _decelerationRate = DEFAULT_DECELERATION_RATE;
    }
    
    return self;
}

- (BOOL)animate
{
    const NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];
    
    BOOL finished = Simulate(currentTime, &lastAnimatedTime, &x, &y, self.decelerationRate, physicsTimeStep, scrollView);
    
    // the real UIScrollView will scroll to the rounded position
    CGPoint roundedOffset = CGPointMake(roundf(x.position), roundf(y.position));
    [scrollView _setRestrainedContentOffset:roundedOffset];
    
    return finished;
}

- (CGPoint)targetContentOffset
{
    const NSTimeInterval currentTime = DBL_MAX;
    
    // need a copy, we don't want to change the original value
    NSTimeInterval lastTime = lastAnimatedTime;
    CHScrollViewAnimationDecelerationComponent xCopy = x;
    CHScrollViewAnimationDecelerationComponent yCopy = y;
    BOOL finished = Simulate(currentTime, &lastTime, &xCopy, &yCopy, self.decelerationRate,
                             physicsTimeStep*20.0, // we don't need the precise value. make the simulator 20x faster.
                             scrollView);
    
    NSAssert(finished, @"simulation should always be finished");
    
    // the real UIScrollView will scroll to the rounded position
    CGPoint roundedOffset = CGPointMake(roundf(xCopy.position), roundf(yCopy.position));
    
    return roundedOffset;
}

/**
	The initial velocity which can reach the target content offset before stop
	@param targetOffset the desired target content offset
	@returns the velocity which can reach the desired target offset 
 */
- (CGPoint)velocityForTargetContentOffset:(CGPoint)targetOffset
{
    CGFloat r = self.decelerationRate;
    
    NSAssert(r > 0.0 && r < 1.0, @"otherwise we will have division by zero");
    
    CGFloat distX = targetOffset.x - x.position;
    CGFloat distY = targetOffset.y - y.position;
    
    IterationToStop(distX, self.decelerationRate, &x.velocity);
    IterationToStop(distY, self.decelerationRate, &y.velocity);
    
    CGPoint v = CGPointMake(x.velocity, y.velocity);
    v.x /= physicsTimeStep;
    v.y /= physicsTimeStep;
    return v;
}

@end
