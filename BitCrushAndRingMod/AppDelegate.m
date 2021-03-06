//
//  AppDelegate.m
//  BitCrushAndRingMod
//
//  Created by Brian Wang on 10/25/14.
//  Copyright (c) 2014 BW Innovation. All rights reserved.
//

#import "AppDelegate.h"
#import "TheAmazingAudioEngine.h"
#import "AEPlaythroughChannel.h"
#import <Accelerate/Accelerate.h>
#import "Audiobus.h"

#define AB_API_KEY @"MTQxNTUwODIzNioqKkJpdENydXNoUmluZ01vZCoqKmJjcm0uYXVkaW9idXM6Ly8=:l7Ado8nYk8vsBpgXMFI/yWLjTxhaznLXXOpt/eI0wDPoWD/0gndbToW7t+4D4yvmBchymXc/SeR9Czuaab16x2vZeC47Kym7swFuqRE4aIkwqTwqetrIw7iwIhF5m1dC"

@interface AppDelegate ()

@end

@implementation AppDelegate

+ (id)sharedInstance
{
    return [[UIApplication sharedApplication] delegate];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    self.audioController = [[AEAudioController alloc] initWithAudioDescription:[AEAudioController nonInterleavedFloatStereoAudioDescription] inputEnabled:YES];
    _audioController.preferredBufferDuration = 0.005;
    [_audioController start:NULL];

    self.channel = [[AEPlaythroughChannel alloc] initWithAudioController:_audioController];
    [_audioController addInputReceiver:_channel];
    [_audioController addChannels:@[_channel]];

    _audioController.inputGain = 20.0;
    _audioController.masterOutputVolume = 0.25;
    _audioController.useMeasurementMode = YES;
    

    self.bcResolution = 1024;
    self.bcBitDepth = 100;
    self.rmFrequency = 1000;
    self.rmWaveType = 0;

    __block float wavePos = 0.0;
    
    ABAudioFilterBlock filterBlock = ^(AudioBufferList *audio, UInt32 frames, AudioTimeStamp *timestamp) {
        for (int c=0; c<audio->mNumberBuffers; c++) {
            float *p = (float *)audio->mBuffers[c].mData;
            for (int i=0; i<frames; i++, p++) {
                float value = *p;
                
                // bitcrush
                value *= _bcResolution;
                value -= fmodf(value, _bcBitDepth);
                value /= _bcResolution;
                
                // ringmod
                float waveVal = 1.0;
                switch (_rmWaveType) {
                    case 0: // sine wave
                        waveVal = sinf(wavePos * 2.0 * M_PI);
                        break;
                    case 1: // square wave
                        waveVal = (wavePos >= 0.5) ? 1.0f : -1.0f;
                        break;
                    case 2: // triangle wave
                        waveVal = (wavePos >= 0.5) ? 1.0f - 4.0f * (wavePos - 0.5) : -1.0f + 4.0f * wavePos;
                        break;
                    case 3: // sawtooth
                        waveVal = 1.0 - 2 * wavePos;
                        break;
                    default:
                        break;
                }
                value *= waveVal;
                wavePos = fmodf(wavePos + _rmFrequency / 44100.0, 1.0);
                
                *p = value;
            }
        }
    };
    self.filter = [AEBlockFilter filterWithBlock:^(AEAudioControllerFilterProducer producer,
                                                   void                     *producerToken,
                                                   const AudioTimeStamp     *time,
                                                   UInt32                    frames,
                                                   AudioBufferList          *audio) {
        // Pull audio
        OSStatus status = producer(producerToken, audio, &frames);
        if ( status != noErr ) return;
        
        // Now filter audio in 'audio'
        filterBlock(audio, frames, time);
    }];
    [_audioController addFilter:_filter];
    
    // initialize Audiobus controller
    self.audiobusController = [[ABAudiobusController alloc] initWithApiKey:AB_API_KEY];

    // set up filter port
    self.filterPort = [[ABFilterPort alloc] initWithName:@"BitCrushRingModFilter" title:@"BitCrushRingMod Filter" audioComponentDescription:(AudioComponentDescription) {
        .componentType = kAudioUnitType_RemoteEffect,
        .componentSubType = 'bcrm',
        .componentManufacturer = 'bwin'
    } processBlock:filterBlock processBlockSize:128];
    self.filterPort.clientFormat = [AEAudioController nonInterleavedFloatStereoAudioDescription];
    [self.audiobusController addFilterPort:self.filterPort];

    // set up receiver port
    self.receiverPort = [[ABReceiverPort alloc] initWithName:@"BitCrushRingModReceiver" title:@"BitCrushRingMod Receiver"];
    self.receiverPort.clientFormat = [AEAudioController nonInterleavedFloatStereoAudioDescription];
    [self.audiobusController addReceiverPort:self.receiverPort];

    // add Audiobus ports to audio controller
    self.audioController.audiobusFilterPort = self.filterPort;
    self.audioController.audiobusReceiverPort = self.receiverPort;
    
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
