#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

static NSString *const kDefaultAlphaVideoFileExtension = @"mp4";

@class TSHAlphaVideoController;

@protocol TSHAlphaVideoDelegate<NSObject>

@optional

- (void)alphaVideoWillPlay:(TSHAlphaVideoController *)alphaVideo;
- (void)alphaVideoDidPlay:(TSHAlphaVideoController *)alphaVideo;

- (void)        alphaVideo:(TSHAlphaVideoController *)alphaVideo
didPlayFrameAtTimeInterval:(NSTimeInterval)timeInterval
      previousTimeInterval:(NSTimeInterval)previousTimeInterval;

- (BOOL)alphaVideoShouldStop:(TSHAlphaVideoController *)alphaVideo;
- (void)alphaVideoWillStop:(TSHAlphaVideoController *)alphaVideo;
- (void)alphaVideoDidStop:(TSHAlphaVideoController *)alphaVideo;

- (void)memoryWarningStoppedVideo:(TSHAlphaVideoController *)alphaVideo;

@end

typedef NS_ENUM(NSInteger, TSHAlphaVideoState) {
    TSHAlphaVideoStateStopped = 0,
    TSHAlphaVideoStateLoading,
    TSHAlphaVideoStatePlaying,
    TSHAlphaVideoStatePaused
};

@interface TSHAlphaVideoController : UIViewController<AVPlayerItemOutputPullDelegate>

+ (TSHAlphaVideoController *)videoWithRGBVideoFile:(NSString *)rgbVideoFilename
                                     withDelegate:(id<TSHAlphaVideoDelegate>)delegate;

@property (nonatomic, weak) id<TSHAlphaVideoDelegate> delegate;

@property (nonatomic, assign) BOOL repeats;
@property (nonatomic, assign) BOOL stopInsteadOfPauseWhenViewEntersBackground;
@property (nonatomic, assign) BOOL disablesIdleTimerWhilePlaying;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) TSHAlphaVideoState state;

- (void)play;
- (void)restart;
- (void)stop;
- (void)pause;

- (void)seekToTime:(NSTimeInterval)seconds;

// Used to load the video resources in memory, which is useful when you want to
// just load the video and have it ready to play later on without the slight load delay.
// For example, when you are running two videos back-to-back, you can load the second video
// so it is ready to play directly after the first video is finished.
- (void)loadVideo;
- (void)loadVideoWithCompletionBlock:(void (^)(BOOL success))completionBlock;

@end
