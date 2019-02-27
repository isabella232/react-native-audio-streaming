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
      requiresSetup = NO;

      NSLog(@"AudioPlayer setup");
   }
}

- (void)dealloc
{
   self.audioPlayer.delegate = nil;
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

RCT_EXPORT_METHOD(play:(NSString *) streamUrl position:(double)position resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
   [self setup];

   if (!self.audioPlayer) {
      reject(@"error", @"AudioPlayer not initialized", nil);
      return;
   }

   if (self.audioPlayer.state == STKAudioPlayerStatePaused && [lastUrlString isEqualToString:streamUrl]) {
      [self.audioPlayer resume];
   } else {
      [self.audioPlayer play:streamUrl];
   }

   initialPosition = position;
   lastUrlString = streamUrl;

   if (self.audioPlayer.state == STKAudioPlayerStateError) {
      reject(@"error", @"error", nil);
   }

   resolve(@"success");
}

RCT_EXPORT_METHOD(seekToTime:(double) seconds resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
   if (!self.audioPlayer) {
      reject(@"error", @"AudioPlayer not initialized", nil);
      return;
   }

   [self.audioPlayer seekToTime:seconds];

   if (self.audioPlayer.state == STKAudioPlayerStateError) {
      reject(@"error", @"error", nil);
   }

   resolve(@"success");
}

RCT_EXPORT_METHOD(goForward:(double) seconds resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
   if (!self.audioPlayer) {
      reject(@"error", @"AudioPlayer not initialized", nil);
      return;
   }

   double newtime = self.audioPlayer.progress + seconds;

   if (self.audioPlayer.duration < newtime) {
      [self.audioPlayer stop];
   } else {
      [self.audioPlayer seekToTime:newtime];
   }

   if (self.audioPlayer.state == STKAudioPlayerStateError) {
      reject(@"error", @"error", nil);
   }

   resolve(@"success");
}

RCT_EXPORT_METHOD(goBack:(double) seconds resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
   if (!self.audioPlayer) {
      reject(@"error", @"AudioPlayer not initialized", nil);
      return;
   }

   double newtime = self.audioPlayer.progress - seconds;

   if (newtime < 0) {
      [self.audioPlayer seekToTime:0.0];
   } else {
      [self.audioPlayer seekToTime:newtime];
   }

   if (self.audioPlayer.state == STKAudioPlayerStateError) {
      reject(@"error", @"error", nil);
   }

   resolve(@"success");
}

RCT_EXPORT_METHOD(pause:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
   if (!self.audioPlayer) {
      reject(@"error", @"AudioPlayer not initialized", nil);
      return;
   }
   
   [self.audioPlayer pause];

   if (self.audioPlayer.state == STKAudioPlayerStateError) {
      reject(@"error", @"error", nil);
   }

   resolve(@"success");
}

RCT_EXPORT_METHOD(resume:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
   if (!self.audioPlayer) {
      reject(@"error", @"AudioPlayer not initialized", nil);
      return;
   }
   
   [self.audioPlayer resume];

   if (self.audioPlayer.state == STKAudioPlayerStateError) {
      reject(@"error", @"error", nil);
   }

   resolve(@"success");
}

RCT_EXPORT_METHOD(stop:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
   if (!self.audioPlayer) {
      reject(@"error", @"AudioPlayer not initialized", nil);
      return;
   }
   
   [self.audioPlayer stop];
   
   if (self.audioPlayer.state == STKAudioPlayerStateError) {
      reject(@"error", @"error", nil);
   }

   resolve(@"success");
}

RCT_EXPORT_METHOD(setPlaybackRate:(double) speed resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
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

@end
