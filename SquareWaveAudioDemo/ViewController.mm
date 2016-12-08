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


- (IBAction)qiaoji:(id)sender {
    
//    bSend = YES;
//    Byte bytes[1];
//    bytes[0] = hexStringToByte(@"71");
//    _sendData = [NSData dataWithBytes:bytes length:1];
    //[self.searilQueue addOperation:[self sendByteMessage:1]];
}

- (IBAction)kuaiman:(id)sender {
//    bSend = YES;
//    Byte bytes[1];
//    bytes[0] = hexStringToByte(@"72");
//    _sendData = [NSData dataWithBytes:bytes length:1];
   // [self.searilQueue addOperation:[self sendByteMessage:2]];

    
}

- (IBAction)rounie:(id)sender {
//    bSend = YES;
//    Byte bytes[1];
//    bytes[0] = hexStringToByte(@"73");
//    _sendData = [NSData dataWithBytes:bytes length:1];
    //[self.searilQueue addOperation:[self sendByteMessage:3]];

    
}

- (IBAction)zhenjiu:(id)sender {
//    bSend = YES;
//    Byte bytes[1];
//    bytes[0] = hexStringToByte(@"74");
//    _sendData = [NSData dataWithBytes:bytes length:1];
   // [self.searilQueue addOperation:[self sendByteMessage:3]];

    
}
- (IBAction)chuijiu:(id)sender {
//    bSend = YES;
//    Byte bytes[1];
//    bytes[0] = hexStringToByte(@"75");
//    _sendData = [NSData dataWithBytes:bytes length:1];
// [self.searilQueue addOperation:[self sendByteMessage:5]];
    
}

- (IBAction)fuheshi:(id)sender {
//    bSend = YES;
//    Byte bytes[1];
//    bytes[0] = hexStringToByte(@"76");
//    _sendData = [NSData dataWithBytes:bytes length:1];
   // [self.searilQueue addOperation:[self sendByteMessage:6]];

    
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
    //[self.searilQueue addOperation:[self sendByteMessage:_geer]];
}
- (IBAction)jie:(id)sender {
    if (_geer <= 0) {
        
        return;
    }
    _geer --;
   // [self.searilQueue addOperation:[self sendByteMessage:_geer]];
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.autio = [[QuickJackApp alloc] init];
    [self.autio setDelegate:self];
    
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
