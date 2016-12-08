/*
 * @brief Main function for Quick_Jack Solution
 *
 * @note
 *
 */

#import "QuickJackApp.h"
#import "AudioUnit/AudioUnit.h"
#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import "CAXException.h"

//
#import "aurio_helper.h"


#import <MediaPlayer/MediaPlayer.h>

enum QUICK_JACK_STATE {
	QUICK_JACK_STARTBIT     = 0,
	QUICK_JACK_SAMEBIT      = 1,
	QUICK_JACK_NEXTBIT      = 2,
	QUICK_JACK_STOPBIT      = 3,
	QUICK_JACK_STARTBITFALL = 4,
	QUICK_JACK_DECODE       = 5,
};

#define fc              1200
#define df              100
#define T               (1/df)
#define N               (SInt32)(T * THIS->hwSampleRate)
#define THRESHOLD       0 // threshold used to detect start bit
#define HIGHFREQ        1378.125 // baud rate. best to take a divisible number for 44.1kS/s
#define SAMPLESPERBIT   32 // (44100 / HIGHFREQ)  // how many samples per UART bit
//#define SAMPLESPERBIT 5 // (44100 / HIGHFREQ)  // how many samples per UART bit
//#define HIGHFREQ (44100 / SAMPLESPERBIT) // baud rate. best to take a divisible number for 44.1kS/s
#define LOWFREQ         (HIGHFREQ / 2)

#define SHORT           (SAMPLESPERBIT/2 + SAMPLESPERBIT/4) // 24
#define LONG            (SAMPLESPERBIT + SAMPLESPERBIT/2)    // 48

#define NUMSTOPBITS     11 // number of stop bits to send before sending next value.
#define AMPLITUDE       (1<<24)


@implementation QuickJackApp

@synthesize rioUnit;
@synthesize inputProc;
@synthesize unitIsRunning;
@synthesize uartByteTransmit;
@synthesize uartByteReceive;
@synthesize uartRecvFlag;
@synthesize maxFPS;
@synthesize newByte;
@synthesize mute;
@synthesize micFlag;
@synthesize micSampleValue;

static dispatch_once_t vsssOnceToken;
#pragma mark -Audio Session Interruption Listener
static int rightflag = 0;

static dispatch_once_t onceToken;
void rioInterruptionListener(void *inClientData, UInt32 inInterruption)
{
	printf("Session interrupted! --- %s ---", inInterruption == kAudioSessionBeginInterruption ? "Begin Interruption" : "End Interruption");
	
	QuickJackApp *THIS = (__bridge QuickJackApp*)inClientData;
	
	if (inInterruption == kAudioSessionEndInterruption) {
		// make sure we are again the active session
		AudioSessionSetActive(true);
        
		AudioOutputUnitStart(THIS->rioUnit);
	}
	
	if (inInterruption == kAudioSessionBeginInterruption) {
		AudioOutputUnitStop(THIS->rioUnit);
    }
}

#pragma mark -Audio Session Property Listener

void propListener(	void *                  inClientData,
				  AudioSessionPropertyID	inID,
				  UInt32                  inDataSize,
				  const void *            inData)
{
	QuickJackApp* THIS = (__bridge QuickJackApp*)inClientData;
    
    
	if (inID == kAudioSessionProperty_AudioRouteChange)
	{
		try {
			// if there was a route change, we need to dispose the current rio unit and create a new one
			XThrowIfError(AudioComponentInstanceDispose(THIS->rioUnit), "couldn't dispose remote i/o unit");		
			
			SetupRemoteIO(THIS->rioUnit, THIS->inputProc, THIS->thruFormat);
			
			UInt32 size = sizeof(THIS->hwSampleRate);
			XThrowIfError(AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, &size, &THIS->hwSampleRate), "couldn't get new sample rate");
			
			XThrowIfError(AudioOutputUnitStart(THIS->rioUnit), "couldn't start unit");
			
			// we need to rescale the sonogram view's color thresholds for different input
			CFStringRef newRoute;
			size = sizeof(CFStringRef);
			XThrowIfError(AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &size, &newRoute), "couldn't get new audio route");
			if (newRoute)
			{	
				CFShow(newRoute);

                if (CFStringCompare(newRoute, CFSTR("HeadphonesAndMicrophone"), NULL) == kCFCompareEqualTo) // headset plugged in
                {
                    printf("This HeadphonesAndMicrophone1111111\n");
                    // MIC initial 拔出
                    //THIS.mute = YES;
                    THIS.mute = NO;
                    THIS.micFlag = YES;
                    CFStringRef routeA;
                    UInt32 propertySizeA = sizeof(CFStringRef);
                    //XThrowIfError(AudioSessionSetActive(true), "couldn't set audio session active\n");
                    XThrowIfError(AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &propertySizeA, &routeA), "couldn't get new audio route");
                    
				}
                if (CFStringCompare(newRoute, CFSTR("HeadsetInOut"), NULL) == kCFCompareEqualTo) // headset plugged in
				{
                    // MIC insert 插入
                    THIS.mute = NO;
                    THIS.micFlag = YES;
                    printf("This headsetInOut.......\n");
                    //AudioOutputUnitStart(THIS->rioUnit);
                   // 插入设备
                    if([THIS->theDelegate respondsToSelector:@selector(hasDeviceInsert:)]) {
                        [THIS->theDelegate hasDeviceInsert:@"HeadsetInOut"];
                        
                    } 

				}
                if (CFStringCompare(newRoute, CFSTR("ReceiverAndMicrophone"), NULL) == kCFCompareEqualTo) // headset plugged in
                {
                    printf("This ReceiverAndMicrophone.......\n");
                    // MIC removed 耳机拔出
                    THIS.mute = NO;
                    
                    // 插入设备
                    if([THIS->theDelegate respondsToSelector:@selector(hasDeviceInsert:)]) {
                        [THIS->theDelegate hasDeviceInsert:@"ReceiverAndMicrophone"];
                    }
                }
			}
		} catch (CAXException e) {
			char buf[256];
			fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
		}
		
	}
}


#pragma mark -RIO Render Callback

#define DECDEBUGBYTE

- (UInt8 *)uartRecvBuf
{
    return uartRecvBuf;
}

static OSStatus	PerformThru(
							void						*inRefCon, 
							AudioUnitRenderActionFlags 	*ioActionFlags, 
							const AudioTimeStamp 		*inTimeStamp, 
							UInt32 						inBusNumber, 
							UInt32 						inNumberFrames, 
							AudioBufferList 			*ioData)
{
	QuickJackApp *THIS = (__bridge QuickJackApp *)inRefCon;
	OSStatus err = AudioUnitRender(THIS->rioUnit, ioActionFlags, inTimeStamp, 1, inNumberFrames, ioData);
	 // 需要发送正弦波的个数
    int sinCount = 0;
    
	// TX vars
	static UInt32 phase = 0;
	static UInt32 phase2 = 0;
	static UInt32 lastPhase2 = 0;
	static SInt32 sample = 0;
	static SInt32 lastSample = 0;
	static int decState = QUICK_JACK_STARTBIT;
	static int byteCounter = 1;
	static UInt8 parityTx = 0;
	
	// UART decoding
	static int bitNum = 0;
	static uint8_t uartByte = 0;
	
	// UART encode
	static uint32_t phaseEnc = 0;
	static uint32_t nextPhaseEnc = SAMPLESPERBIT;
	static uint8_t uartByteTx = 0x0;
	static int32_t uartBitTx = 0;
	static uint8_t state = QUICK_JACK_STARTBIT;
	static float uartBitEnc[SAMPLESPERBIT];
	static uint8_t currentBit = 1;
	static UInt8 parityRx = 0;
//    static float val = 0;
	static SInt32* lchannel;
	if (err) { printf("PerformThru: error %d\n", (int)err); return err; }
	
	// Remove DC component
//	for(UInt32 i = 0; i < ioData->mNumberBuffers; ++i)
//		THIS->dcFilter[i].InplaceFilter((SInt32*)(ioData->mBuffers[i].mData), inNumberFrames, 1);
	lchannel = (SInt32*)(ioData->mBuffers[0].mData);
//	printf("sample %f\n", THIS->hwSampleRate);
	
	/************************************
	 * UART Decoding
	 ************************************/
#if 1
    
    if(THIS->mute == YES) { // 耳机拔出
        sample = lastSample = 0;
        phase = phase2 = lastPhase2 = 0;
        
        decState = QUICK_JACK_STARTBIT;
        byteCounter = 1;
        parityTx = 0;
        bitNum = 0;
        uartByte = 0;
    } else if (THIS->mute == NO) { // 耳机插入
        for(int j = 0; j < inNumberFrames; j++) {
            THIS->micSampleValue = lchannel[j];
            //NSLog(@"samleValue:%d", (int)lchannel[j]);
            phase2 += 1;
            
            if (THIS->micSampleValue < THRESHOLD) { // 判断起始位
                sample = 0;
            } else {
                sample = 1;
            }
            
            if (sample != lastSample) {
                // transition
                SInt32 diff = phase2 - lastPhase2;
                switch (decState) {
                    case QUICK_JACK_STARTBIT: // 开始，第一个数据位
                        if (lastSample == 0 && sample == 1)
                        {
                            // low->high transition. Now wait for a long period
                            decState = QUICK_JACK_STARTBITFALL;
                        }
                        break;
                    case QUICK_JACK_STARTBITFALL:
                        if (( SHORT < diff ) && (diff < LONG))
                        {
                            // looks like we got a 1->0 transition.
                            bitNum = 0;
                            parityRx = 0;
                            uartByte = 0;
                            decState = QUICK_JACK_DECODE;
    //                        printf("diff %d, %d, %d\r\n", diff, SHORT, LONG );
                        } else {
    //                        sample = lastSample = 0;
    //                        phase = phase2 = 0;
                            decState = QUICK_JACK_STARTBIT;
                        }
                        break;
                    case QUICK_JACK_DECODE:
                        if (( SHORT < diff) && (diff < LONG)) {
                            // we got a valid sample.
                            if (bitNum < 8) {
                                uartByte = ((uartByte >> 1) + (sample << 7));
                                bitNum += 1;
                                parityRx += sample;
                                 //printf("the short and long is %d and %d diff:%d-----------%d,%d++++++++++++++%d phase2:%d\n",SHORT,LONG,(int)diff,uartByte,(int)sample,bitNum,(unsigned int)phase2);

    //                            printf("Bit %d value %ld diff %ld parity %d\n", bitNum, sample, diff, parityRx & 0x01);

                            } else if (bitNum == 8) {
                                // parity bit
                                if(sample != (parityRx & 0x01))
                                {
    #ifdef DECDEBUGBYTE
                                   // printf(" -- parity %d,  UartByte 0x%x\n", (int)sample, uartByte);
    #endif
                                    decState = QUICK_JACK_STARTBIT;
                                    uartByte = 0;
                                } else {
    #ifdef DECDEBUGBYTE
                                    //printf(" ++ good parity %d, UartByte 0x%x\n", (int)sample, uartByte);
    #endif
                                    
    //                                if([THIS->theDelegate respondsToSelector:@selector(receive:)]) {
    //                                    [THIS->theDelegate receive:uartByte];
    //                                }
                                    bitNum += 1;
                                }
                                
                            } else {
                                // we should now have the stopbit
                                if (sample == 1) {
                                    // we have a new and valid byte!
    #ifdef DECDEBUGBYTE
                                    //printf(" ++ StopBit: %ld UartByte 0x%x\n", sample, uartByte);
    #endif
    //								NSAutoreleasePool	 *autoreleasepool = [[NSAutoreleasePool alloc] init];
                                    //////////////////////////////////////////////
                                    // This is where we receive the byte!!!
                                    if([THIS->theDelegate respondsToSelector:@selector(receive:)]) {
                                        [THIS->theDelegate receive:uartByte];
                                    }
                                    
                                    sample = sample;
                                    THIS.uartByteReceive = uartByte;
                                    THIS.uartRecvFlag = 1;
                                    THIS.uartRecvBuf[THIS.uartRecvNum] = THIS.uartByteReceive;
                                    THIS.uartRecvNum++;
                                    if(THIS.uartRecvNum>=256) THIS.uartRecvNum = 0;
                                } else {
                                    // not a valid byte.
    #ifdef DECDEBUGBYTE
                                    //printf(" -- StopBit: %ld UartByte %d\n", sample, uartByte);
    #endif
                                }
                                decState = QUICK_JACK_STARTBIT;
                            }
                        } else if (diff > LONG) {
    #ifdef DECDEBUGBYTE
    //						printf("diff too long %ld\n", diff);
    #endif
    /*                        sample = lastSample = 0;
                            phase = phase2 = lastPhase2 = 0;
                        
                            byteCounter = 1;
                            parityTx = 0;
                            bitNum = 0;
                            uartByte = 0;
    */
                            decState = QUICK_JACK_STARTBIT;
                        } else {
                            // don't update the phase as we have to look for the next transition
                           // printf("don't update the phase as we have to look for the next transition int wave:%d\n",THIS.currentFrame);
                            lastSample = sample;
                            continue;
                        }
                        break;
                    default:
                        break;
                }
                lastPhase2 = phase2;
            }
            lastSample = sample;
        }
        
    }

#endif
	
	if (THIS->mute == NO)
    {
		// prepare sine wave
		
        SInt32 values[inNumberFrames];
		/*******************************
		 * Generate 22kHz Tone
		 *******************************/
		//周期
        
		double waves ;
        for(int j = 0; j < inNumberFrames; j++) {
            
            waves = 0;
            
            waves += sin(M_PI * 2.0f / THIS->hwSampleRate * 15025.0 * phase);
            //waves += sin(M_PI * phase+0.5); // This should be 22.050kHz
            
            waves *= (AMPLITUDE); // <--------- make sure to divide by how many waves you're stacking
            
            values[j] = (SInt32)waves;
            //values[j] += values[j]<<16;
            //printf("%d: %ld\n", phase, values[j]);
            phase++;
        }
      
      
        dispatch_once(&onceToken, ^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    rightflag = 1;
                    NSLog(@"444444444444444444444");
            });
        });
        if (rightflag == 1) {
            for (int i = 0; i < inNumberFrames; i++) {
                values[i] = 0;
            }
        }
        memcpy(ioData->mBuffers[1].mData, values, ioData->mBuffers[1].mDataByteSize);

        
        SInt32 sinValues[inNumberFrames];
        for (int i = 0; i < inNumberFrames; i++) {
            sinValues[i] = 0;
        }
        memcpy(ioData->mBuffers[0].mData, sinValues, ioData->mBuffers[0].mDataByteSize);
		/*******************************
		 * UART Encoding
		 *******************************/
        if (THIS->newByte == TRUE) {
            
            double waves;
            phase=0;
            
            int sampleCount = 59;
            //            int sampleCount = 23;
            
            //绘制正线波
           // SignedByte dataByte[1];
            
            if (THIS.sartBit) {
                
                for (int i = 0; i < 4; i ++) {
                    
                    if (i == 0) {
                        
                        for(int j = 0; j < sampleCount; j++) {
                            // int bit =  THIS->uartByteTransmit >> i & (0x01);
                            waves = 0;
                            waves = sin(M_PI *2.0f*(j/(float)(sampleCount - 1)));
                            waves *= (AMPLITUDE); // <--------- make sure to divide by how many waves you're stacking
                            
                            if (j >= 30 && j <= 48) {
                                
                                sinValues[i*sampleCount + j] = -(SInt32)waves;
                                
                            } else {
                                sinValues[i*sampleCount + j] = (SInt32)waves;
                            }
                            //                    values[j] += values[j]<<16;
                            //                   printf("hwSampleRate:%lf, phase:%d, values: %d\n", THIS->hwSampleRate, (unsigned int)phase, (int)values[j]);
                            phase++;
                        }
                    } else {
                        
                        
                        if (THIS.bytes[i] != 0) {
                            
                            for(int j = 0; j < sampleCount; j++) {
                                // int bit =  THIS->uartByteTransmit >> i & (0x01);
                                waves = 0;
                                waves = sin(M_PI *2.0f*(j/(float)(sampleCount - 1)));
                                waves *= (AMPLITUDE); // <--------- make sure to divide by how many waves you're stacking
                                
                                if (j >= 20 && j <= 29) {
                                    
                                    sinValues[i*sampleCount + j] = -(SInt32)waves;
                                    
                                } else {
                                    sinValues[i*sampleCount + j] = (SInt32)waves;
                                }
                                //                    values[j] += values[j]<<16;
                                //                   printf("hwSampleRate:%lf, phase:%d, values: %d\n", THIS->hwSampleRate, (unsigned int)phase, (int)values[j]);
                                phase++;
                            }

                        } else {
                            
                            for(int j = 0; j < sampleCount; j++) {
                                // int bit =  THIS->uartByteTransmit >> i & (0x01);
                                waves = 0;
                                waves = sin(M_PI *2.0f*(j/(float)(sampleCount - 1)));
                                waves *= (AMPLITUDE); // <--------- make sure to divide by how many waves you're stacking
                                
                                if (j >= 30 && j <= 48) {
                                    
                                    sinValues[i*sampleCount + j] = -(SInt32)waves;
                                    
                                } else {
                                    sinValues[i*sampleCount + j] = (SInt32)waves;
                                }
                                //                    values[j] += values[j]<<16;
                                //                   printf("hwSampleRate:%lf, phase:%d, values: %d\n", THIS->hwSampleRate, (unsigned int)phase, (int)values[j]);
                                phase++;
                            }

                            
                        }
                    }
                    
                    for (int k = 4 * sampleCount; k< 256; k++) {
                        sinValues[k] = 0;
                    }
                }
                THIS.sartBit = FALSE;
                THIS.newByte = FALSE;
            } else {
                
                for (int i = 0; i < 4; i ++) {
                    
                    if (THIS.bytes[i] != 0) {
                        
                        for(int j = 0; j < sampleCount; j++) {
                            // int bit =  THIS->uartByteTransmit >> i & (0x01);
                            waves = 0;
                            waves = sin(M_PI *2.0f*(j/(float)(sampleCount - 1)));
                            waves *= (AMPLITUDE); // <--------- make sure to divide by how many waves you're stacking
                            
                            if (j >= 20 && j <= 29) {
                                
                                sinValues[i*sampleCount + j] = -(SInt32)waves;
                                
                            } else {
                                sinValues[i*sampleCount + j] = (SInt32)waves;
                            }
                            //                    values[j] += values[j]<<16;
                            //                   printf("hwSampleRate:%lf, phase:%d, values: %d\n", THIS->hwSampleRate, (unsigned int)phase, (int)values[j]);
                            phase++;
                        }
                        
                    } else {
                        
                        for(int j = 0; j < sampleCount; j++) {
                            // int bit =  THIS->uartByteTransmit >> i & (0x01);
                            waves = 0;
                            waves = sin(M_PI *2.0f*(j/(float)(sampleCount - 1)));
                            waves *= (AMPLITUDE); // <--------- make sure to divide by how many waves you're stacking
                            
                            if (j >= 30 && j <= 48) {
                                
                                sinValues[i*sampleCount + j] = -(SInt32)waves;
                                
                            } else {
                                sinValues[i*sampleCount + j] = (SInt32)waves;
                            }
                            //                    values[j] += values[j]<<16;
                            //                   printf("hwSampleRate:%lf, phase:%d, values: %d\n", THIS->hwSampleRate, (unsigned int)phase, (int)values[j]);
                            phase++;
                        }
                        
                        
                    }
                }
                for (int k = 4 * sampleCount; k< 256; k++) {
                    sinValues[k] = 1;
                }
                memcpy(ioData->mBuffers[0].mData, sinValues, ioData->mBuffers[0].mDataByteSize);
                THIS.newByte = FALSE;

            }

//            for (int i = 0; i < 10; i++) {
//                
//                for(int j = 0; j < sampleCount; j++) {
//                   // int bit =  THIS->uartByteTransmit >> i & (0x01);
//                    waves = 0;
//                    waves = sin(M_PI *2.0f*(j/(float)(sampleCount - 1)));
//                    waves *= (AMPLITUDE); // <--------- make sure to divide by how many waves you're stacking
//                    
//                    sinValues[i*sampleCount + j] = (SInt32)waves;
//                    //                    values[j] += values[j]<<16;
//                    //                   printf("hwSampleRate:%lf, phase:%d, values: %d\n", THIS->hwSampleRate, (unsigned int)phase, (int)values[j]);
//                    phase++;
//                }
//            }
//            for (int k = sinCount * sampleCount; k< 256; k++) {
//                sinValues[k] = 1;
//            }
//            memcpy(ioData->mBuffers[0].mData, sinValues, ioData->mBuffers[0].mDataByteSize);
//            THIS.newByte = NO;
        }
        
        
    }
	return err;
}


- (void) setDelegate:(id <QuickJackDelegate>) delegate {
	theDelegate = delegate;
}

- (id) init {
	// Initialize our remote i/o unit
//    NSError *errStr = nil;
	inputProc.inputProc = PerformThru;
	inputProc.inputProcRefCon = (__bridge void *)self;
    
    self.mute = NO;
	newByte = FALSE;
	//++++
	try {
//        //调节音量
//        MPVolumeView *mmP = [[MPVolumeView alloc] init];
//        
//        UISlider *mmV = nil;
//        for (UIView *view in mmP.subviews) {
//            if ([view.class.description isEqualToString:@"MPVolumeSlider"]) {
//                mmV = (UISlider *)view;
//                break;
//            }
//        }
//        
////        float systemVolume = mmV.value;
//        [mmV setValue:1.0f animated:YES];
//        [mmV sendActionsForControlEvents:UIControlEventTouchUpInside];
//        
//        
//        [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
//            if (granted) {
//                NSLog(@"同意");
//            } else {
//                UIAlertView *alert = [UIAlertView alloc];
//                if (vsssOnceToken == 0) {
//                    alert = [alert  initWithTitle:@"提示" message:@"请允许获取麦克风！" delegate:self cancelButtonTitle:@"确定" otherButtonTitles: nil];
//                    alert.tag = 101;
//                    [alert show];
//                }else {
//                    alert = [alert initWithTitle:@"提示" message:@"请到“设置->隐私->源健康”允许麦克风权限" delegate:self cancelButtonTitle:@"确定" otherButtonTitles: nil];
//                    alert.tag = 102;
//                    [alert show];
//                }
//                
//            }
//        }];
        
        //7.0第一次运行会提示，是否允许使用麦克风
//        AVAudioSession *session = [AVAudioSession sharedInstance];
//        if (![session setActive:YES error:&errStr]) {
//            NSLog(@"AVAudioSession setActive failr:%@", errStr);
//        };
        // Initialize and configure the audio session
        //++++
      
        
        dispatch_once(&vsssOnceToken, ^{
    
            XThrowIfError(AudioSessionInitialize(NULL, NULL, rioInterruptionListener, (__bridge void *)self), "couldn't initialize audio session");
        });
        
        
        XThrowIfError(AudioSessionSetActive(true), "couldn't set audio session active\n");
//        XThrowIfError(AudioSessionInitialize(NULL, NULL, rioInterruptionListener, (__bridge void *)self), "couldn't initialize audio session");
		
        
        UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_None;
		XThrowIfError(AudioSessionSetProperty(kAudioSessionProperty_OverrideAudioRoute, sizeof(audioRouteOverride), &audioRouteOverride), "couldn't set audio RouteOverride");
        
        UInt32 audioCategory = kAudioSessionCategory_PlayAndRecord;
		XThrowIfError(AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(audioCategory), &audioCategory), "couldn't set audio category");
    
		XThrowIfError(AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, propListener, (__bridge void *)self), "couldn't set property listener");
		
		Float32 preferredBufferSize = .005;
		XThrowIfError(AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration, sizeof(preferredBufferSize), &preferredBufferSize), "couldn't set i/o buffer duration");
		
		UInt32 size = sizeof(hwSampleRate);
		XThrowIfError(AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, &size, &hwSampleRate), "couldn't get hw sample rate");
		
		XThrowIfError(SetupRemoteIO(rioUnit, inputProc, thruFormat), "couldn't setup remote i/o unit");
		
		dcFilter = new DCRejectionFilter[thruFormat.NumberChannels()];
		
		UInt32 maxFPSt;
		size = sizeof(maxFPSt);
		XThrowIfError(AudioUnitGetProperty(rioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFPSt, &size), "couldn't get the remote I/O unit's max frames per slice");
		self.maxFPS = maxFPSt;
		
		XThrowIfError(AudioOutputUnitStart(rioUnit), "couldn't start remote i/o unit");
		
		size = sizeof(thruFormat);
		XThrowIfError(AudioUnitGetProperty(rioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &thruFormat, &size), "couldn't get the remote I/O unit's output client format");
		
		unitIsRunning = 1;
	}
	catch (CAXException &e) {
		char buf[256];
		fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
		unitIsRunning = 0;
		if (dcFilter)
        {
            delete[] dcFilter;
            dcFilter = nil;
        }
	}
	catch (...) {
		fprintf(stderr, "An unknown error occurred\n");
        unitIsRunning = 0;
        if (dcFilter)
        {
            delete[] dcFilter;
            dcFilter = nil;
        }
	}
	return self;
}

//-(void)setUartByteTransmit:(UInt8)data{
//    
//    uartByteTransmit = data;
//    SignedByte bytes[8];
//    for (int i = 0; i < 8; i++) {
//        
//        int j = data >> i & (0x01);
//        bytes[i] = j;
//    }
//    self.bytes = bytes;
//    self.sartBit = YES;
//    [self sendByteMessage:5];
//    
//}

-(NSBlockOperation *)sendByteMessage:(uint8_t )data {
    
    __block uint32_t i = 0;
    __block uint8_t sendData = 0;
    sendData = data;
    NSBlockOperation *opertionOne = [NSBlockOperation blockOperationWithBlock:^{
        
        while(self.newByte == TRUE) {
            if( i<1000000 ) {
                i++;
                NSLog(@"----------");
                //NSLog(@"can't write：%s___%d",__FILE__,__LINE__);
                //[NSThread sleepForTimeInterval:1];
            }
            else {
                return;
            }
        }
        // waveformPeriod - 0.007
        [NSThread sleepForTimeInterval:0.02 - 0.007];
        if (self.newByte == FALSE) {
            //self.uartByteTransmit = sendData;
            self.newByte = TRUE;
            
            
        }
        NSLog(@"write 0");
        
    }];
    
    return opertionOne;
    
}

-(NSOperationQueue *)searilQueue {
    
    if (!_searilQueue) {
        
        _searilQueue = [[NSOperationQueue alloc] init];
        _searilQueue.maxConcurrentOperationCount = 1;
    }
    
    return _searilQueue;
}


- (int) send:(UInt8) data {
    
	if (newByte == FALSE) {
		// transmitter ready
		self.uartByteTransmit = data;
		newByte = TRUE;
		return 0;
	} else {
		return 1;
	}
}
/**
 * 这个一定要，崩溃的bug
 */
- (void)dealloc
{
    rightflag = 0;
    onceToken = 0;
    if (dcFilter) {
        
        delete[] dcFilter;
        dcFilter = nil;
    }
    AudioOutputUnitStop(rioUnit);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    onceToken = 0;
    NSLog(@"QuickJackAPP 888");
}
#pragma mark- UIAlertDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == 102) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"prefs:root"]];
        
    }
}


@end
