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

- (ReactNativeAudioStreaming *)init
{
   self = [super init];
   if (self) {
      [self setSharedAudioSessionCategory];
      self.audioPlayer = [[STKAudioPlayer alloc] initWithOptions:(STKAudioPlayerOptions){ .flushQueueOnSeek = YES }];
      [self.audioPlayer setDelegate:self];
      self.lastUrlString = @"";
      [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(tick:) userInfo:nil repeats:YES];

      NSLog(@"AudioPlayer initialized");
   }

   return self;
}


-(void) tick:(NSTimer*)timer
{
   if (!self.audioPlayer) {
      return;
   }

   if (self.audioPlayer.currentlyPlayingQueueItemId != nil && self.audioPlayer.state == STKAudioPlayerStatePlaying) {
      NSNumber *progress = [NSNumber numberWithFloat:self.audioPlayer.progress];
      NSNumber *duration = [NSNumber numberWithFloat:self.audioPlayer.duration];
      NSString *url = [NSString stringWithString:self.audioPlayer.currentlyPlayingQueueItemId];

      [self sendEventWithName:@"AudioBridgeEvent" body:@{
                                                     @"status": @"STREAMING",
                                                     @"progress": progress,
                                                     @"duration": duration,
                                                     @"url": url,
                                                     }];
   }
}


- (void)dealloc
{
   [self unregisterAudioInterruptionNotifications];
   [self.audioPlayer setDelegate:nil];
}


#pragma mark - Pubic API

RCT_EXPORT_METHOD(play:(NSString *) streamUrl)
{
   if (!self.audioPlayer) {
      return;
   }

   [self activate];

   if (self.audioPlayer.state == STKAudioPlayerStatePaused && [self.lastUrlString isEqualToString:streamUrl]) {
      [self.audioPlayer resume];
   } else {
      [self.audioPlayer play:streamUrl];
   }

   self.lastUrlString = streamUrl;
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

   callback(@[[NSNull null], @{@"status": status, @"progress": progress, @"duration": duration, @"url": self.lastUrlString}]);
}

#pragma mark - StreamingKit Audio Player


- (void)audioPlayer:(STKAudioPlayer *)player didStartPlayingQueueItemId:(NSObject *)queueItemId
{
   NSLog(@"AudioPlayer is playing");
}

- (void)audioPlayer:(STKAudioPlayer *)player didFinishPlayingQueueItemId:(NSObject *)queueItemId withReason:(STKAudioPlayerStopReason)stopReason andProgress:(double)progress andDuration:(double)duration
{
   NSLog(@"AudioPlayer has stopped");
}

- (void)audioPlayer:(STKAudioPlayer *)player didFinishBufferingSourceWithQueueItemId:(NSObject *)queueItemId
{
   NSLog(@"AudioPlayer finished buffering");
}

- (void)audioPlayer:(STKAudioPlayer *)player unexpectedError:(STKAudioPlayerErrorCode)errorCode {
   NSLog(@"AudioPlayer unexpected Error with code %ld", (long)errorCode);
}

- (void)audioPlayer:(STKAudioPlayer *)audioPlayer didReadStreamMetadata:(NSDictionary *)dictionary {
   NSLog(@"AudioPlayer SONG NAME  %@", dictionary[@"StreamTitle"]);

   self.currentSong = dictionary[@"StreamTitle"] ? dictionary[@"StreamTitle"] : @"";
   [self sendEventWithName:@"AudioBridgeEvent" body:@{
                                                @"status": @"METADATA_UPDATED",
                                                @"key": @"StreamTitle",
                                                @"value": self.currentSong
                                                }];
}

- (void)audioPlayer:(STKAudioPlayer *)player stateChanged:(STKAudioPlayerState)state previousState:(STKAudioPlayerState)previousState
{
   NSNumber *duration = [NSNumber numberWithFloat:self.audioPlayer.duration];
   NSNumber *progress = [NSNumber numberWithFloat:self.audioPlayer.progress];

   switch (state) {
      case STKAudioPlayerStatePlaying:
         [self sendEventWithName:@"AudioBridgeEvent" body:@{@"status": @"PLAYING", @"progress": progress, @"duration": duration, @"url": self.lastUrlString}];
         break;

      case STKAudioPlayerStatePaused:
         [self sendEventWithName:@"AudioBridgeEvent" body:@{@"status": @"PAUSED", @"progress": progress, @"duration": duration, @"url": self.lastUrlString}];
         break;

      case STKAudioPlayerStateStopped:
         [self sendEventWithName:@"AudioBridgeEvent" body:@{@"status": @"STOPPED", @"progress": progress, @"duration": duration, @"url": self.lastUrlString}];
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

- (void)setSharedAudioSessionCategory
{
   NSError *categoryError = nil;
   self.isPlayingWithOthers = [[AVAudioSession sharedInstance] isOtherAudioPlaying];

   [[AVAudioSession sharedInstance] setActive:NO error:&categoryError];
   [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:&categoryError];

   if (categoryError) {
      NSLog(@"Error setting category! %@", [categoryError description]);
   }
}

@end
