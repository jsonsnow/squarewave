//
//  ViewController.m
//  SquareWaveAudioDemo
//
//  Created by mr.cao on 15/12/26.
//  Copyright © 2015年 mr.cao. All rights reserved.
//

#import "ViewController.h"
#import "QuickJackApp.h"
@interface ViewController ()<QuickJackDelegate>
@property (nonatomic, strong) NSOperationQueue *searilQueue;
@property (nonatomic, strong) QuickJackApp *autio;
@property (nonatomic, assign) NSInteger geer;
@end

@implementation ViewController


-(NSBlockOperation *)sendByteMessage:(uint8_t )data start:(BOOL)start{
    
    __block uint32_t i = 0;
    __block uint8_t sendData;
    sendData = data;
    NSBlockOperation *opertionOne = [NSBlockOperation blockOperationWithBlock:^{
        
        while(self.autio.newByte == TRUE) {
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
        if (self.autio.newByte == FALSE) {
            self.autio.uartByteTransmit = sendData;
//            self.autio.bytes = data;
//            self.autio.sartBit = start;
            self.autio.newByte = TRUE;

            
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

-(void)sendData:(uint8_t)data {
    
    SignedByte byte[8];
    //SignedByte byte2[4];
    for (int i = 0; i < 8; i++) {
        
        int j = data >> i & (0x01);
        
        byte[i] = j;
    }

    [self.searilQueue addOperation:[self sendByteMessage:2 start:YES]];
    for (int i = 0; i < 8; i ++) {
        
        [self.searilQueue addOperation:[self sendByteMessage:byte[i] start:YES]];
    }
    [self.searilQueue addOperation:[self sendByteMessage:3 start:YES]];
    //[self.searilQueue addOperation:[self sendByteMessage:byte1 start:YES]];
    //[self.searilQueue addOperation:[self sendByteMessage:byte2 start:NO]];
    //[self.autio setUartByteTransmit:0x4];

}
- (IBAction)qiaoji:(id)sender {
    
//    bSend = YES;
//    Byte bytes[1];
//    bytes[0] = hexStringToByte(@"71");
//    _sendData = [NSData dataWithBytes:bytes length:1];
    //[self.searilQueue addOperation:[self sendByteMessage:1]];
   // uartByteTransmit = data;
    [self sendData:0x71];
   
}

- (IBAction)kuaiman:(id)sender {
//    bSend = YES;
//    Byte bytes[1];
//    bytes[0] = hexStringToByte(@"72");
//    _sendData = [NSData dataWithBytes:bytes length:1];
   // [self.searilQueue addOperation:[self sendByteMessage:2]];
   [self sendData:0x72];

    
}

- (IBAction)rounie:(id)sender {
//    bSend = YES;
//    Byte bytes[1];
//    bytes[0] = hexStringToByte(@"73");
//    _sendData = [NSData dataWithBytes:bytes length:1];
    //[self.searilQueue addOperation:[self sendByteMessage:3]];
    [self sendData:0x01];

    
}

- (IBAction)zhenjiu:(id)sender {
//    bSend = YES;
//    Byte bytes[1];
//    bytes[0] = hexStringToByte(@"74");
//    _sendData = [NSData dataWithBytes:bytes length:1];
   // [self.searilQueue addOperation:[self sendByteMessage:3]];
   [self sendData:0x02];

    
}
- (IBAction)chuijiu:(id)sender {
//    bSend = YES;
//    Byte bytes[1];
//    bytes[0] = hexStringToByte(@"75");
//    _sendData = [NSData dataWithBytes:bytes length:1];
// [self.searilQueue addOperation:[self sendByteMessage:5]];
   [self sendData:0x03];
    
}

- (IBAction)fuheshi:(id)sender {
//    bSend = YES;
//    Byte bytes[1];
//    bytes[0] = hexStringToByte(@"76");
//    _sendData = [NSData dataWithBytes:bytes length:1];
   // [self.searilQueue addOperation:[self sendByteMessage:6]];

   [self sendData:0x04];
}

- (IBAction)jia:(id)sender {
//    bSend = YES;
//    geer ++;
//    Byte bytes[1];
//    bytes[0] = hexStringToByte([NSString stringWithFormat:@"1%d",geer]);
    if (_geer >= 10) {
        
        return;
    }
    _geer ++;
    [self sendData:_geer];
    //[self.searilQueue addOperation:[self sendByteMessage:_geer]];
}
- (IBAction)jie:(id)sender {
    if (_geer <= 0) {
        
        return;
    }
    _geer --;
    [self sendData:_geer];
   // [self.searilQueue addOperation:[self sendByteMessage:_geer]];
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        self.autio = [[QuickJackApp alloc] init];
        [self.autio setDelegate:self];
    });
   
    
    // Do any additional setup after loading the view, typically from a nib.
//_hwSampleRate=AUDIO_SAMPLE_RATE;
//    [self initHighLowBuffer];
//    [self configAudio];
}

-(void)receive:(UInt8)data {
    
    NSLog(@"++++++++++++++++++the recive data:%d+++++++++++++++++++++++",data);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
