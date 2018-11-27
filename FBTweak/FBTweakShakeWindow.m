/**
 Copyright (c) 2014-present, Facebook, Inc.
 All rights reserved.
 
 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree. An additional grant
 of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBTweakEnabled.h"
#import "FBTweakStore.h"
#import "FBTweakShakeWindow.h"
#import "FBTweakViewController.h"
#import "_FBKeyboardManager.h"

NS_ASSUME_NONNULL_BEGIN

// Minimum shake time required to present tweaks on device.
static CFTimeInterval _FBTweakShakeWindowMinTimeInterval = 0.4;

@implementation FBTweakShakeWindow {
  BOOL _shaking;
  BOOL _active;
}

- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    // Maintain this state manually using notifications so Tweaks can be used in app extensions, where UIApplication is unavailable.
    self->_active = YES;
    self->_shakeEnabled = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationWillResignActiveWithNotification:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationDidBecomeActiveWithNotification:) name:UIApplicationDidBecomeActiveNotification object:nil];

#if FB_TWEAK_ENABLED
    UITapGestureRecognizer *threeFingersDoubleTapRecognizer =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_presentTweaks)];
    threeFingersDoubleTapRecognizer.numberOfTapsRequired = 2;
    threeFingersDoubleTapRecognizer.numberOfTouchesRequired = 3;
    [self addGestureRecognizer:threeFingersDoubleTapRecognizer];
#endif
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)_applicationWillResignActiveWithNotification:(NSNotification *)notification {
  _active = NO;
}

- (void)_applicationDidBecomeActiveWithNotification:(NSNotification *)notification {
  _active = YES;
}

- (void)_presentTweaks {
  UIViewController * _Nullable visibleViewController = [self findVisibleViewController];
  if (!visibleViewController || [visibleViewController isKindOfClass:[FBTweakViewController class]]) {
    return;
  }

  FBTweakStore *store = [FBTweakStore sharedInstance];
  FBTweakViewController *viewController = [[FBTweakViewController alloc] initWithStore:store];
  viewController.tweaksDelegate = self;
  [visibleViewController presentViewController:viewController animated:YES completion:NULL];
}

- (UIViewController * _Nullable)findVisibleViewController {
  UIViewController * _Nullable visibleViewController = self.rootViewController;
  if (!visibleViewController) {
    return nil;
  }

  while (visibleViewController.presentedViewController != nil) {
    visibleViewController = visibleViewController.presentedViewController;
  }

  return visibleViewController;
}

- (nullable FBTweakViewController *)findTweakViewController {
  UIViewController * _Nullable visibleViewController = [self findVisibleViewController];

  if (![visibleViewController isKindOfClass:[FBTweakViewController class]]) {
    return nil;
  }

  return (FBTweakViewController *)visibleViewController;
}

- (void)dismissTweaksViewController {
  FBTweakViewController * _Nullable viewController = [self findTweakViewController];
  if (viewController) {
    [self dismissTweaksViewController:viewController];
  }
}

- (void)dismissTweaksViewController:(FBTweakViewController *)tweakViewController {
  [tweakViewController.view endEditing:YES];
  [tweakViewController dismissViewControllerAnimated:YES completion:NULL];
}

- (void)tweakViewControllerPressedDone:(FBTweakViewController *)tweakViewController {
  [self dismissTweaksViewController:tweakViewController];
}

- (BOOL)_shouldPresentTweaks {
#if TARGET_IPHONE_SIMULATOR && FB_TWEAK_ENABLED
  return YES;
#elif FB_TWEAK_ENABLED
  return _shakeEnabled && _shaking && _active;
#else
  return NO;
#endif
}

- (void)motionBegan:(UIEventSubtype)motion withEvent:(nullable UIEvent *)event {
  if (motion == UIEventSubtypeMotionShake) {
    _shaking = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, _FBTweakShakeWindowMinTimeInterval * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
      if ([self _shouldPresentTweaks]) {
        [self _presentTweaks];
      }
    });
  }
  [super motionBegan:motion withEvent:event];
}

- (void)motionEnded:(UIEventSubtype)motion withEvent:(nullable UIEvent *)event {
  if (motion == UIEventSubtypeMotionShake) {
    _shaking = NO;
  }
  [super motionEnded:motion withEvent:event];
}

@end

NS_ASSUME_NONNULL_END
