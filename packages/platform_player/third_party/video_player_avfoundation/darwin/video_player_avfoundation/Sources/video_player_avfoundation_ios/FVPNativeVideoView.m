// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "../video_player_avfoundation_objc/include/video_player_avfoundation_objc/FVPNativeVideoView.h"

#import <AVFoundation/AVFoundation.h>

static NSNotificationName const AiroPlayerLayerAvailableNotification =
    @"AiroPlayerLayerAvailable";
static NSNotificationName const AiroPlayerLayerUnavailableNotification =
    @"AiroPlayerLayerUnavailable";

@interface FVPPlayerView : UIView
@end

@implementation FVPPlayerView
+ (Class)layerClass {
  return [AVPlayerLayer class];
}

- (void)setPlayer:(AVPlayer *)player {
  [(AVPlayerLayer *)[self layer] setPlayer:player];
}
@end

@interface FVPNativeVideoView ()
@property(nonatomic) FVPPlayerView *playerView;
@end

@implementation FVPNativeVideoView
- (instancetype)initWithPlayer:(AVPlayer *)player {
  if (self = [super init]) {
    _playerView = [[FVPPlayerView alloc] init];
    [_playerView setPlayer:player];
    [[NSNotificationCenter defaultCenter]
        postNotificationName:AiroPlayerLayerAvailableNotification
                      object:(AVPlayerLayer *)_playerView.layer];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter]
      postNotificationName:AiroPlayerLayerUnavailableNotification
                    object:(AVPlayerLayer *)_playerView.layer];
}

- (FVPPlayerView *)view {
  return self.playerView;
}
@end
