/*
 * @brief QuickJackApp.h
 *
 * @note
 *
 */

#import <Foundation/Foundation.h>
#import "AudioUnit/AudioUnit.h"
#import "aurio_helper.h"
#import "CAStreamBasicDescription.h"
#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>

@protocol QuickJackDelegate;

void propListener(	void *                  inClientData,
                  AudioSessionPropertyID	inID,
                  UInt32                  inDataSize,
                  const void *            inData);
@interface QuickJackApp : NSObject<UIAlertViewDelegate>
{
	id <QuickJackDelegate>			theDelegate;
	
	AudioUnit					rioUnit;
	AURenderCallbackStruct		inputProc;
	DCRejectionFilter*			dcFilter;
	CAStreamBasicDescription	thruFormat;
	Float64						hwSampleRate;

	UInt8						uartByteTransmit;
    UInt8                       uartByteReceive;
    UInt8                       uartRecvFlag;
    UInt32                      uartRecvNum;
    UInt8                       uartRecvBuf[1024];
	BOOL						mute;
	BOOL						newByte;
	UInt32						maxFPS;
    BOOL                        micFlag;
    float                       micSampleValue;
}
	
- (void) setDelegate:(id <QuickJackDelegate>) delegate;
- (id) init;


@property (nonatomic, assign)	AudioUnit				rioUnit;
@property (nonatomic, assign)	AURenderCallbackStruct	inputProc;
@property (nonatomic, assign)	int						unitIsRunning;
@property (nonatomic, assign)   UInt8					uartByteTransmit;
@property (nonatomic, assign)   UInt8                   uartByteReceive;
@property (nonatomic, assign)   UInt32					maxFPS;
@property (nonatomic, assign)	BOOL					newByte;
@property (nonatomic, assign)	BOOL					mute;
@property (nonatomic, assign)	BOOL					micFlag;
@property (nonatomic, assign)   UInt8                   uartRecvFlag;
@property (nonatomic, assign)   UInt32                  uartRecvNum;
@property (nonatomic, assign)   UInt8                   *uartRecvBuf;



@property (nonatomic, assign)   float                   micSampleValue;

@end
	
	
@protocol QuickJackDelegate <NSObject>
	
- (void) receive:(UInt8)data;
@optional;
//-(void) sendData:(NSNotification *)notification;
- (void)hasDeviceInsert:(NSString *)headState;

@end
