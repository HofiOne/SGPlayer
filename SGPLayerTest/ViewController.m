//
//  ViewController.m
//  SGPLayerTest
//
//  Created by hofi on 2022. 12. 19..
//  Copyright © 2022. single. All rights reserved.
//

#import "ViewController.h"
#import <SGPlayer/SGPlayer.h>

typedef NS_OPTIONS(NSUInteger, CSPPlaybackState) {
    CSPPlaybackStateStopped,
    CSPPlaybackStatePlaying,
    CSPPlaybackStatePaused,
    CSPPlaybackStateSeeking,
    CSPPlaybackStateFinished,

    CSPPlaybackStateUnknown = UINT_MAX
};


@interface ViewController ()

@property (nonatomic, strong) SGPlayer *player;
@property (nonatomic, assign) IBOutlet UIView* sgPlayerContainerView;

@property (nonatomic, assign, readwrite) BOOL loading;
@property (nonatomic, assign) CSPPlaybackState playbackState;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.player = [[SGPlayer alloc] init];
    self.player.videoRenderer.view = self.sgPlayerContainerView;
    self.player.videoRenderer.displayMode = SGDisplayModePlane;
    self.player.videoRenderer.scalingMode = SGScalingModeResizeAspect;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackInfoChanged:) name:SGPlayerDidChangeInfosNotification object:self.player];

    @try {
        self.loading = YES;
        [self.player replaceWithURL:[NSURL URLWithString:@"rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mp4"]];
    }
    @catch (NSException *exception) {
        self.loading = NO;
    }
    @catch (...) {
        self.loading = NO;
    }
}

#pragma mark - SGPlayer Notifications

- (void) playbackInfoChanged:(NSNotification *)notification
{
//    SGTimeInfo time = [SGPlayer timeInfoFromUserInfo:notification.userInfo];
    SGStateInfo state = [SGPlayer stateInfoFromUserInfo:notification.userInfo];
    SGInfoAction action = [SGPlayer infoActionFromUserInfo:notification.userInfo];

    if (action & SGInfoActionTime) {
//        if (action & SGInfoActionTimePlayback && !(state.playback & SGPlaybackStateSeeking) && !self.seeking /*&& !self.progress.isHighlighted*/) {
//            [self updateProgressWithTimeInfo:time];
//            self.currentTimeLabel.STRINGVALUE = [self timeStringFromSeconds:CMTimeGetSeconds(time.playback)];
//        }
//        if (action & SGInfoActionTimeDuration) {
//            self.durationLabel.STRINGVALUE = [self timeStringFromSeconds:CMTimeGetSeconds(time.duration)];
//        }
    }
    
    if (action & SGInfoActionState) {
        if (state.playback & SGPlaybackStateFinished) {
            self.playbackState = CSPPlaybackStateFinished;
        }
        else if (state.playback & SGPlaybackStateSeeking) {
            self.playbackState = CSPPlaybackStateSeeking;
        }
        else if (state.playback & SGPlaybackStatePlaying) {
            self.playbackState = CSPPlaybackStatePlaying;
        }
        else {
            self.playbackState = CSPPlaybackStatePaused;
        }
        
        if (self.loading && state.loading & SGLoadingStateFinished) {
            self.loading = NO;
            if (self.playbackState != CSPPlaybackStatePlaying)
                [self play];
        }

        // Loading not yet finished but has available data to play, strat it
        if (self.loading && state.loading & SGLoadingStatePlayable) {
            if (self.playbackState != CSPPlaybackStatePlaying)
                [self play];
        }
    }
}
//------------------------------------------------------------------------------

- (void) play
{
    [self.player play];
    [self.player audioRenderer].volume = 1;
}
//------------------------------------------------------------------------------


@end
