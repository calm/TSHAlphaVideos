# TSHAlphaVideos

Play small mp4 videos with alpha background on iOS.  TSHAlphaVideos is powerful, performant and easy to use.

![Example 1](http://i.imgur.com/B3MRxj3.gif)

### Video Processing

You'll want to start with an .mov file that has alpha-channel.  AVPlayer would play this file directly, but doing so would likely require bundling or downloading a very large file -- movs with alpha can often approach 100MB per minute or more.

Export your .mov premultiplied (matted) from AfterEffects or your video rendering software of choice.

Then, with `alpha_video.rake` in your rake scope, run

```sh
rake split_mov /path/to/matted/my_awesome_video.mov
```

You'll be prompted to install two dependencies [1](http://www.mplayerhq.hu/DOCS/man/en/mplayer.1.html) [2](http://www.modejong.com/AVAnimator/utils.html).  The second dependency, AVAnimatorUtils, will require you to download the tarball manually and include the executables in your `$PATH`

Once you get those installed, the script should run and poop out a set of resulting files.  These will look like:

```
my_awesome_video_audio.wav
my_awesome_video_alpha.mp4
my_awesome_video_rgb.mp4
my_awesome_video_no_audio.mp4
my_awesome_video.mp4
```

If you don't have the final composited version, that's because your video had no audio.  Simply use the composited `*_no_audio.mp4` instead.  Either way, this will be the file you include in your app bundle.

This file should be significantly smaller than your .mov, perhaps by a factor of 100 or more.


### Usage

Now that you have your composited side-by-side RGB and Alpha channels, we'll use `TSHAlphaVideos` to show them to your users.  This is a very simple process, as simple as adding a UIImageView to the screen.

```objc
TSHAlphaVideoController *myAwesomeVideo = [TSHAlphaVideoController videoWithRGBVideoFile:@"my_awesome_video"
                                                                            withDelegate:self];
[self.view addSubview:myAwesomeVideo.view];
[myAwesomeVideo play];
```

That's it.  TSHAlphaVideoController has a few more configuration flags, like `repeats` and `stopInsteadOfPauseWhenViewEntersBackground` that can be set before calling `play`.  The view will be properly sized according to the video file.

The `TSHAlphaVideoDelegate` responds to a number of useful messages, all optional:

```objc
- (void)alphaVideoWillPlay:(TSHAlphaVideoController *)alphaVideo;
- (void)alphaVideoDidPlay:(TSHAlphaVideoController *)alphaVideo;

- (void)        alphaVideo:(TSHAlphaVideoController *)alphaVideo
didPlayFrameAtTimeInterval:(NSTimeInterval)timeInterval
      previousTimeInterval:(NSTimeInterval)previousTimeInterval;

- (BOOL)alphaVideoShouldStop:(TSHAlphaVideoController *)alphaVideo;
- (void)alphaVideoWillStop:(TSHAlphaVideoController *)alphaVideo;
- (void)alphaVideoDidStop:(TSHAlphaVideoController *)alphaVideo;

- (void)memoryWarningStoppedVideo:(TSHAlphaVideoController *)alphaVideo;
```
