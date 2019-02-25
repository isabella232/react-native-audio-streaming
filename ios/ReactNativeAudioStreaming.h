#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import "STKAudioPlayer.h"

@interface ReactNativeAudioStreaming : RCTEventEmitter <RCTBridgeModule, STKAudioPlayerDelegate>
{

@private
   NSTimer* timer;
   NSString *lastUrlString;
   double initialPosition;
   BOOL isPlayingWithOthers;
   BOOL requiresSetup;
}

@property (readwrite, retain) STKAudioPlayer *audioPlayer;

@end
