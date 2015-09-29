#import <CoreMedia/CoreMedia.h>
#import "TSHAlphaVideoController.h"
#import "TSHAlphaVideoView.h"

@interface TSHAlphaVideoController ()

@property (nonatomic, copy) NSString *rgbVideoFilename;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerItemVideoOutput *videoOutput;
@property (atomic, strong) CADisplayLink *displayLink;

@property (nonatomic, strong) TSHAlphaVideoView *glView;

@property (nonatomic, assign) CMTime targetTime;
@property (nonatomic, assign) CGSize videoSize;
@property (nonatomic, assign) CVPixelBufferRef pixelBuffer;

@property (nonatomic, assign) BOOL shouldResumePlay;
@property (nonatomic, assign) BOOL canRemovePlayerNotification;
@property (nonatomic, assign) TSHAlphaVideoState state;

@property (nonatomic, assign) NSTimeInterval previousTimeInterval;

@end

@implementation TSHAlphaVideoController

+ (TSHAlphaVideoController *)videoWithRGBVideoFile:(NSString *)rgbVideoFilename
                                     withDelegate:(id<TSHAlphaVideoDelegate>)delegate
{
    if (![self canPlayVideoOfName:rgbVideoFilename]) {
        return nil;
    }

    TSHAlphaVideoController *videoController = [[TSHAlphaVideoController alloc] initWithRGBVideoFile:rgbVideoFilename
                                                                                      withDelegate:delegate];
    return videoController;
}

+ (BOOL)canPlayVideoOfName:(NSString *)name
{
    NSURL *url = [self urlForAlphaVideoOfName:name];
    return url != nil;
}

+ (NSURL *)urlForAlphaVideoOfName:(NSString *)name
{
    return [[NSBundle mainBundle] URLForResource:name
                                   withExtension:kDefaultAlphaVideoFileExtension];
}

- (void)dealloc
{
    CVPixelBufferRelease(_pixelBuffer);
    _pixelBuffer = nil;
    if (self.canRemovePlayerNotification) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:[self.player currentItem]];
    }
}

- (instancetype)initWithRGBVideoFile:(NSString *)rgbVideoFilename
                        withDelegate:(id<TSHAlphaVideoDelegate>)delegate
{
    self = [self initWithNibName:nil bundle:nil];
    if (self) {
        _rgbVideoFilename = [rgbVideoFilename copy];
        _delegate = delegate;
        _targetTime = CMTimeMakeWithSeconds(0.0, NSEC_PER_SEC);
        _shouldStopAggressivelyOnMemoryWarning = YES;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // set up the size of the view, and the width should be half the size of the video
    // because the video contains the rgb and alpha portions side by side.
    CGRect viewFrame = CGRectMake(0, 0, .5f * self.videoSize.width, self.videoSize.height);

    self.view.frame = viewFrame;
    self.view.clipsToBounds = YES;
    self.view.backgroundColor = [UIColor clearColor];
}

- (void)turnOnOrOffAudio
{
    float playerVolume = 1;
    AVAsset *avAsset = self.player.currentItem.asset;
    NSArray *audioTracks = [avAsset tracksWithMediaType:AVMediaTypeAudio];

    NSMutableArray *allAudioParams = [NSMutableArray array];
    for (AVAssetTrack *track in audioTracks) {
        AVMutableAudioMixInputParameters *audioInputParams = [AVMutableAudioMixInputParameters audioMixInputParameters];
        [audioInputParams setVolume:playerVolume atTime:kCMTimeZero];
        [audioInputParams setTrackID:[track trackID]];
        [allAudioParams addObject:audioInputParams];
    }
    AVMutableAudioMix *audioVolMix = [AVMutableAudioMix audioMix];
    [audioVolMix setInputParameters:allAudioParams];
    [self.player.currentItem setAudioMix:audioVolMix];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self addObservers];
    if (self.shouldResumePlay) {
        [self play];
    }
}

- (void)addObservers
{
    [self removeObservers]; // safe add

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillResignActive)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidEnterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillEnterForeground)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];

}

- (void)removeObservers
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillResignActiveNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidEnterBackgroundNotification
                                                  object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillEnterForegroundNotification
                                                  object:nil];

}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self removeObservers];

    self.shouldResumePlay = self.state == TSHAlphaVideoStatePlaying;
    [self pause];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    if (self.shouldStopAggressivelyOnMemoryWarning) {
        if ([self.delegate respondsToSelector:@selector(memoryWarningStoppedVideo:)]) {
            [self.delegate memoryWarningStoppedVideo:self];
        }
        [self stop];
    }
}

- (NSURL *)videoURL
{
    return [[self class] urlForAlphaVideoOfName:self.rgbVideoFilename];
}

- (CGSize)videoSize
{
    if (_videoSize.width == 0 && _videoSize.height == 0) {
        AVPlayer *tempPlayer = [self playerForVideoURL];
        NSArray *tracks = [tempPlayer.currentItem.asset tracksWithMediaType:AVMediaTypeVideo];
        AVAssetTrack *track = tracks.firstObject;
        CGFloat screenFactor = 1.0 / [UIScreen mainScreen].scale;
        CGSize naturalSize = track.naturalSize;
        _videoSize = CGSizeMake(screenFactor * naturalSize.width, screenFactor * naturalSize.height);
    }

    return _videoSize;
}

- (AVPlayer *)playerForVideoURL
{
    NSURL *url = [self videoURL];
    if (!url) {
        return nil;
    }
    return [AVPlayer playerWithURL:url];
}

- (TSHAlphaVideoView *)glView
{
    if (!_glView) {
        UIApplicationState state = [[UIApplication sharedApplication] applicationState];
        if (state == UIApplicationStateBackground || state == UIApplicationStateInactive) {
            return nil;
        }
        CGRect viewFrame = CGRectMake(0, 0, .5f * self.videoSize.width, self.videoSize.height);
        _glView = [[TSHAlphaVideoView alloc] initWithFrame:viewFrame];
        _glView.backgroundColor = [UIColor clearColor];
        [self.view addSubview:_glView];
    }
    return _glView;
}

- (NSTimeInterval)duration
{
    return CMTimeGetSeconds(self.player.currentItem.asset.duration);
}

- (void)appWillEnterForeground
{
    [self playIfShould];
}

- (void)appDidBecomeActive
{
    [self playIfShould];
}

- (void)playIfShould
{
    if (self.shouldResumePlay) {
        [self play];
    }
}

- (void)appWillResignActive
{
    self.shouldResumePlay = self.state == TSHAlphaVideoStatePlaying;
    [self pause];
    [self.glView prepareForBackground];
}

- (void)appDidEnterBackground
{
    if (self.stopInsteadOfPauseWhenViewEntersBackground) {
        [self stop];
    } else {
        [self pause];
    }
    [self.glView prepareForBackground];
}

- (void)loadVideo
{
    [self loadVideoWithCompletionBlock:NULL];
}

- (void)loadVideoWithCompletionBlock:(void (^)(BOOL success))completionBlock
{
    self.player = [self playerForVideoURL];
    if (!self.player) {
        if (completionBlock) {
            completionBlock(NO);
        }
        return;
    }
    
    // this notification will be used to help loop the video after it's ended.
    self.player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(videoDidPlayToEndTime:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:self.player.currentItem];
    self.canRemovePlayerNotification = YES;
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf.player.currentItem.asset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf setupVideoOutput];
                weakSelf.state = TSHAlphaVideoStatePaused;
                if (completionBlock) {
                    completionBlock(YES);
                }
            });
        }];
    });
}

- (void)setupVideoOutput
{
    NSDictionary *options = @{
                              (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
                              (__bridge NSString *)kCVPixelBufferOpenGLESCompatibilityKey : @YES
                              };
    self.videoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:options];
    self.videoOutput.suppressesPlayerRendering = YES;
    [self.videoOutput requestNotificationOfMediaDataChangeWithAdvanceInterval:.1];
    [self.player.currentItem addOutput:self.videoOutput];
    
    [self createDisplayLink];
}

- (void)createDisplayLink
{
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkCallback:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    self.displayLink.frameInterval = 2;
    self.displayLink.paused = YES;
}

- (void)setTargetTime:(CMTime)targetTime
{
    _targetTime = targetTime;
    [self.player seekToTime:self.targetTime
            toleranceBefore:kCMTimeZero
             toleranceAfter:kCMTimeZero];
}

- (void)startPlayer
{
    [self willPlay];

    [self turnOnOrOffAudio];

    [self.player play];
    self.state = TSHAlphaVideoStatePlaying;
    self.shouldResumePlay = NO;  // reset the state
    // don't let the device go to sleep while the movie is playing.
    if (self.disablesIdleTimerWhilePlaying) {
        [UIApplication sharedApplication].idleTimerDisabled = YES;
    }
    if (!self.displayLink) {
        [self createDisplayLink];
    }
    self.displayLink.paused = NO;
    [self didPlay];
}

- (void)pause
{
    if (self.state != TSHAlphaVideoStatePlaying) {
        return;
    }
    self.state = TSHAlphaVideoStatePaused;

    [UIApplication sharedApplication].idleTimerDisabled = NO;

    if (self.displayLink) {
        self.displayLink.paused = YES;
    }
    self.targetTime = self.player.currentTime;
    self.player.rate = 0.0f;
}

- (void)stop
{
    if (self.state == TSHAlphaVideoStateStopped) {
        return;
    }

    if ([self shouldStop]) {
        [self willStop];
        [self pause];
        [self seekToTime:0];
        self.previousTimeInterval = 0;
        
        self.state = TSHAlphaVideoStateStopped;
        // clean up on stop
        if (self.canRemovePlayerNotification) {
            [[NSNotificationCenter defaultCenter] removeObserver:self
                                                            name:AVPlayerItemDidPlayToEndTimeNotification
                                                          object:[self.player currentItem]];
            self.canRemovePlayerNotification = NO;
        }
        
        [self.player.currentItem removeOutput:self.videoOutput];
        if (self.displayLink) {
            [self.displayLink invalidate];
            self.displayLink = nil;
        }
        [self didStop];
    }
}

- (void)restart
{
    [self seekToTime:0];
    [self play];
}

- (void)willPlay
{
    if ([self.delegate respondsToSelector:@selector(alphaVideoWillPlay:)]) {
        [self.delegate alphaVideoWillPlay:self];
    }
}

- (void)play
{
    switch (self.state) {
        case TSHAlphaVideoStatePaused:
            [self startPlayer];
            break;
        case TSHAlphaVideoStateStopped:{
            __weak typeof(self) weakSelf = self;
            [self loadVideoWithCompletionBlock:^(BOOL success){
                if (success) {
                    [weakSelf startPlayer];
                } else {
                    // TODO: video has not been loaded from server yet...
                }
            }];
        }
        case TSHAlphaVideoStateLoading:
        case TSHAlphaVideoStatePlaying:
            return;
    }
}

- (void)didPlay
{
    if ([self.delegate respondsToSelector:@selector(alphaVideoDidPlay:)]) {
        [self.delegate alphaVideoDidPlay:self];
    }
}

- (BOOL)shouldStop
{
    if([self.delegate respondsToSelector:@selector(alphaVideoShouldStop:)]) {
        return [self.delegate alphaVideoShouldStop:self];
    }
    return YES;
}

- (void)willStop
{
    if([self.delegate respondsToSelector:@selector(alphaVideoWillStop:)]) {
        [self.delegate alphaVideoWillStop:self];
    }
}

- (void)didStop
{
    if ([self.delegate respondsToSelector:@selector(alphaVideoDidStop:)]) {
        [self.delegate alphaVideoDidStop:self];
    }
}

- (void)videoDidPlayToEndTime:(NSNotification *)notification
{
    if (self.repeats) {
        [self seekToTime:0];
    } else {
        [self seekToTime:self.duration];
        [self stop];
    }
}

- (void)alphaVideoDidPlayFrameAtTimeInterval:(NSTimeInterval)timeInterval
{
    if ([self.delegate respondsToSelector:@selector(alphaVideo:didPlayFrameAtTimeInterval:previousTimeInterval:)]) {;
        [self.delegate alphaVideo:self
       didPlayFrameAtTimeInterval:timeInterval
             previousTimeInterval:self.previousTimeInterval];
    }
    self.previousTimeInterval = timeInterval;
}

- (void)seekToTime:(NSTimeInterval)seconds
{
    self.targetTime = CMTimeMakeWithSeconds(seconds, NSEC_PER_SEC);
    [self alphaVideoDidPlayFrameAtTimeInterval:seconds];
    self.previousTimeInterval = seconds;
}

#pragma mark - CADisplayLink Callback

- (void)displayLinkCallback:(CADisplayLink *)sender
{
    if (!self.videoOutput) {
        return;
    }
    
    NSTimeInterval nextDisplayTime = sender.timestamp + sender.duration;
    CMTime itemTime = [self.videoOutput itemTimeForHostTime:nextDisplayTime];

    if ([self.videoOutput hasNewPixelBufferForItemTime:itemTime] && [UIApplication sharedApplication].applicationState != UIApplicationStateBackground) {
        CVPixelBufferRelease(_pixelBuffer);
        _pixelBuffer = [self.videoOutput copyPixelBufferForItemTime:itemTime
                                                 itemTimeForDisplay:nil];
        if (_pixelBuffer) {
            [self.glView displayPixelBuffer:_pixelBuffer];

            NSTimeInterval timeInterval = CMTimeGetSeconds(itemTime);
            [self alphaVideoDidPlayFrameAtTimeInterval:timeInterval];
        }
    } else {
        if (self.state == TSHAlphaVideoStatePlaying) {
            self.player.rate = 1.0f;
        }
    }
}

@end
