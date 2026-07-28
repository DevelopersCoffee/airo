// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "../video_player_avfoundation_objc/include/video_player_avfoundation_objc/FVPNativeVideoView.h"

#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>

static NSNotificationName const AiroPlayerLayerAvailableNotification =
    @"AiroPlayerLayerAvailable";
static NSNotificationName const AiroPlayerLayerUnavailableNotification =
    @"AiroPlayerLayerUnavailable";

@implementation FVPNativeVideoView

- (instancetype)initWithPlayer:(AVPlayer *)player {
  self = [super init];
  if (self) {
    self.wantsLayer = YES;
    ((AVPlayerLayer *)self.layer).player = player;
    [[NSNotificationCenter defaultCenter]
        postNotificationName:AiroPlayerLayerAvailableNotification
                      object:(AVPlayerLayer *)self.layer];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter]
      postNotificationName:AiroPlayerLayerUnavailableNotification
                    object:(AVPlayerLayer *)self.layer];
}

- (CALayer *)makeBackingLayer {
  return [[AVPlayerLayer alloc] init];
}

@end
