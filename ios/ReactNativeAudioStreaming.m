#import "ReactNativeAudioStreaming.h"

#define LPN_AUDIO_BUFFER_SEC 20 // Can't use this with shoutcast buffer meta data

@import AVFoundation;
@import MediaPlayer;

@implementation ReactNativeAudioStreaming

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE()

- (NSArray<NSString *> *)supportedEvents
{
  return @[@"AudioBridgeEvent"];
}

- (dispatch_queue_t)methodQueue
{
   return dispatch_get_main_queue();
}

+ (BOOL)requiresMainQueueSetup
{
   return YES;
}

- (ReactNativeAudioStreaming *)init
{
   self = [super init];
   if (self) {
      requiresSetup = YES;
      lastUrlString = @"";
      initialPosition = 0;
      
      NSLog(@"AudioPlayer initialized");
   }

   return self;
}

-(void) setup
{
   if (requiresSetup) {
      [self setupAudioPlayer];
      [self setupTimer];
      [self registerAudioInterruptionNotifications];
      requiresSetup = NO;
      
      NSLog(@"AudioPlayer setup");
   }
}

- (void)dealloc
{
   self.audioPlayer.delegate = nil;
   [self unregisterAudioInterruptionNotifications];
   [timer invalidate];
   
   NSLog(@"AudioPlayer dealloc");
}

-(void) setupAudioPlayer
{
   if (!self.audioPlayer) {
      self.audioPlayer = [[STKAudioPlayer alloc] initWithOptions:(STKAudioPlayerOptions){ .flushQueueOnSeek = YES }];
      self.audioPlayer.delegate = self;
      
      NSLog(@"AudioPlayer setup audio player");
   }
}


-(void) setupTimer
{
   timer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(tick:) userInfo:nil repeats:YES];
   
   [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
   
   NSLog(@"AudioPlayer setup timer");
}

-(void) tick:(NSTimer*)timer
{
   if (!self.audioPlayer) {
      return;
   }

   if (self.audioPlayer.currentlyPlayingQueueItemId != nil && self.audioPlayer.state == STKAudioPlayerStatePlaying) {
      NSNumber *progress = [NSNumber numberWithFloat:self.audioPlayer.progress];
      NSNumber *duration = [NSNumber numberWithFloat:self.audioPlayer.duration];
      NSString *url = lastUrlString;

      [self sendEventWithName:@"AudioBridgeEvent" body:@{
         @"status": @"STREAMING",
         @"progress": progress,
         @"duration": duration,
         @"url": url,
      }];
   }
}

#pragma mark - Pubic API

RCT_EXPORT_METHOD(play:(NSString *) streamUrl position:(double)position)
{
   [self setup];
   
   if (!self.audioPlayer) {
      return;
   }
   
   [self activate];
   
   if (self.audioPlayer.state == STKAudioPlayerStatePaused && [lastUrlString isEqualToString:streamUrl]) {
      [self.audioPlayer resume];
   } else {
      [self.audioPlayer play:streamUrl];
   }
   
   initialPosition = position;
   lastUrlString = streamUrl;
}

RCT_EXPORT_METHOD(seekToTime:(double) seconds)
{
   if (!self.audioPlayer) {
      return;
   }

   [self.audioPlayer seekToTime:seconds];
}

RCT_EXPORT_METHOD(goForward:(double) seconds)
{
   if (!self.audioPlayer) {
      return;
   }

   double newtime = self.audioPlayer.progress + seconds;

   if (self.audioPlayer.duration < newtime) {
      [self.audioPlayer stop];
   } else {
      [self.audioPlayer seekToTime:newtime];
   }
}

RCT_EXPORT_METHOD(goBack:(double) seconds)
{
   if (!self.audioPlayer) {
      return;
   }

   double newtime = self.audioPlayer.progress - seconds;

   if (newtime < 0) {
      [self.audioPlayer seekToTime:0.0];
   } else {
      [self.audioPlayer seekToTime:newtime];
   }
}

RCT_EXPORT_METHOD(pause)
{
   if (!self.audioPlayer) {
      return;
   } else {
      [self.audioPlayer pause];
      [self deactivate];
   }
}

RCT_EXPORT_METHOD(resume)
{
   if (!self.audioPlayer) {
      return;
   } else {
      [self activate];
      [self.audioPlayer resume];
   }
}

RCT_EXPORT_METHOD(stop)
{
   if (!self.audioPlayer) {
      return;
   } else {
      [self.audioPlayer stop];
      [self deactivate];
   }
}

RCT_EXPORT_METHOD(setPlaybackRate:(double) speed)
{
   return;
}


RCT_EXPORT_METHOD(getStatus: (RCTResponseSenderBlock) callback)
{
   NSString *status = @"STOPPED";
   NSNumber *duration = [NSNumber numberWithFloat:self.audioPlayer.duration];
   NSNumber *progress = [NSNumber numberWithFloat:self.audioPlayer.progress];

   if (!self.audioPlayer) {
      status = @"ERROR";
   } else if ([self.audioPlayer state] == STKAudioPlayerStatePlaying) {
      status = @"PLAYING";
   } else if ([self.audioPlayer state] == STKAudioPlayerStatePaused) {
      status = @"PAUSED";
   } else if ([self.audioPlayer state] == STKAudioPlayerStateBuffering) {
      status = @"BUFFERING";
   }

   callback(@[[NSNull null], @{@"status": status, @"progress": progress, @"duration": duration, @"url": lastUrlString}]);
}

#pragma mark - StreamingKit Audio Player

- (void)audioPlayer:(STKAudioPlayer *)player didStartPlayingQueueItemId:(NSObject *)queueItemId
{
   // if progress is less then initalPosition call seekToTime and then reset initalPosition
   if(self.audioPlayer.progress < initialPosition) {
      [self.audioPlayer seekToTime:initialPosition];
      initialPosition = 0;
   }
   NSLog(@"AudioPlayer is playing");
}

- (void)audioPlayer:(STKAudioPlayer *)player didFinishPlayingQueueItemId:(NSObject *)queueItemId withReason:(STKAudioPlayerStopReason)stopReason andProgress:(double)progress andDuration:(double)duration
{
   if (stopReason == STKAudioPlayerStopReasonEof || stopReason == STKAudioPlayerStopReasonNone) {
      [self sendEventWithName:@"AudioBridgeEvent" body:@{@"status": @"COMPLETED"}];
   }
}

-(void) audioPlayer:(STKAudioPlayer*)audioPlayer didFinishBufferingSourceWithQueueItemId:(nonnull NSObject *)queueItemId {
   NSLog(@"AudioPlayer finished buffering");
}

- (void)audioPlayer:(STKAudioPlayer *)player stateChanged:(STKAudioPlayerState)state previousState:(STKAudioPlayerState)previousState
{
   NSNumber *duration = [NSNumber numberWithFloat:self.audioPlayer.duration];
   NSNumber *progress = [NSNumber numberWithFloat:self.audioPlayer.progress];
   
   switch (state) {
      case STKAudioPlayerStatePlaying:
         [self sendEventWithName:@"AudioBridgeEvent" body:@{@"status": @"PLAYING", @"progress": progress, @"duration": duration, @"url": lastUrlString}];
         break;
         
      case STKAudioPlayerStatePaused:
         [self sendEventWithName:@"AudioBridgeEvent" body:@{@"status": @"PAUSED", @"progress": progress, @"duration": duration, @"url": lastUrlString}];
         break;
         
      case STKAudioPlayerStateStopped:
         [self sendEventWithName:@"AudioBridgeEvent" body:@{@"status": @"STOPPED", @"progress": progress, @"duration": duration, @"url": lastUrlString}];
         break;
         
      case STKAudioPlayerStateBuffering:
         [self sendEventWithName:@"AudioBridgeEvent" body:@{@"status": @"BUFFERING"}];
         break;
         
      case STKAudioPlayerStateError:
         [self sendEventWithName:@"AudioBridgeEvent" body:@{@"status": @"ERROR"}];
         break;
         
      default:
         break;
   }
}

-(void) audioPlayer:(STKAudioPlayer*)audioPlayer unexpectedError:(STKAudioPlayerErrorCode)errorCode
{
   NSLog(@"AudioPlayer unexpected Error with code %ld", (long)errorCode);
}

-(void) audioPlayer:(STKAudioPlayer *)audioPlayer logInfo:(NSString *)line
{
   NSLog(@"%@", line);
}

#pragma mark - Audio Session

- (void)activate
{
   NSError *categoryError = nil;

   [[AVAudioSession sharedInstance] setActive:YES error:&categoryError];
   [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&categoryError];

   if (categoryError) {
      NSLog(@"Error setting category! %@", [categoryError description]);
   }
}

- (void)deactivate
{
   NSError *categoryError = nil;

   [[AVAudioSession sharedInstance] setActive:NO error:&categoryError];

   if (categoryError) {
      NSLog(@"Error setting category! %@", [categoryError description]);
   }
}


- (void)registerAudioInterruptionNotifications
{
   // Register for audio interrupt notifications
   [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(onAudioInterruption:)
                                                name:AVAudioSessionInterruptionNotification
                                              object:nil];
   // Register for route change notifications
   [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(onRouteChangeInterruption:)
                                                name:AVAudioSessionRouteChangeNotification
                                              object:nil];
}

- (void)unregisterAudioInterruptionNotifications
{
   [[NSNotificationCenter defaultCenter] removeObserver:self
                                                   name:AVAudioSessionRouteChangeNotification
                                                 object:nil];
   [[NSNotificationCenter defaultCenter] removeObserver:self
                                                   name:AVAudioSessionInterruptionNotification
                                                 object:nil];
}

- (void)onAudioInterruption:(NSNotification *)notification
{
   // Get the user info dictionary
   NSDictionary *interruptionDict = notification.userInfo;

   // Get the AVAudioSessionInterruptionTypeKey enum from the dictionary
   NSInteger interuptionType = [[interruptionDict valueForKey:AVAudioSessionInterruptionTypeKey] integerValue];

   // Decide what to do based on interruption type
   switch (interuptionType)
   {
      case AVAudioSessionInterruptionTypeBegan:
         NSLog(@"Audio Session Interruption case started.");
         [self.audioPlayer pause];
         break;

      case AVAudioSessionInterruptionTypeEnded:
         NSLog(@"Audio Session Interruption case ended.");
         isPlayingWithOthers = [[AVAudioSession sharedInstance] isOtherAudioPlaying];
         (isPlayingWithOthers) ? [self.audioPlayer stop] : [self.audioPlayer resume];
         break;

      default:
         NSLog(@"Audio Session Interruption Notification case default.");
         break;
   }
}

- (void)onRouteChangeInterruption:(NSNotification *)notification
{

   NSDictionary *interruptionDict = notification.userInfo;
   NSInteger routeChangeReason = [[interruptionDict valueForKey:AVAudioSessionRouteChangeReasonKey] integerValue];

   switch (routeChangeReason)
   {
      case AVAudioSessionRouteChangeReasonUnknown:
         NSLog(@"routeChangeReason : AVAudioSessionRouteChangeReasonUnknown");
         break;

      case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
         // A user action (such as plugging in a headset) has made a preferred audio route available.
         NSLog(@"routeChangeReason : AVAudioSessionRouteChangeReasonNewDeviceAvailable");
         break;

      case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
         // The previous audio output path is no longer available.
         [self.audioPlayer stop];
         break;

      case AVAudioSessionRouteChangeReasonCategoryChange:
         // The category of the session object changed. Also used when the session is first activated.
         NSLog(@"routeChangeReason : AVAudioSessionRouteChangeReasonCategoryChange"); //AVAudioSessionRouteChangeReasonCategoryChange
         break;

      case AVAudioSessionRouteChangeReasonOverride:
         // The output route was overridden by the app.
         NSLog(@"routeChangeReason : AVAudioSessionRouteChangeReasonOverride");
         break;

      case AVAudioSessionRouteChangeReasonWakeFromSleep:
         // The route changed when the device woke up from sleep.
         NSLog(@"routeChangeReason : AVAudioSessionRouteChangeReasonWakeFromSleep");
         break;

      case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory:
         // The route changed because no suitable route is now available for the specified category.
         NSLog(@"routeChangeReason : AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory");
         break;
   }
}
@end
