#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
// #import "BTDevItem.h"
// #import "DeviceModel.h"
#import <CoreBluetooth/CoreBluetooth.h>

@interface TelinkBtSig : RCTEventEmitter <RCTBridgeModule, CBCentralManagerDelegate>

@property (nonatomic, assign) BOOL isNeedRescan;
@property(nonatomic, strong) CBCentralManager *manager;
//@property(nonatomic, strong) NSMutableArray <DeviceModel *> *devArray;
//@property(nonatomic, strong) NSMutableArray <BTDevItem *> *BTDevArray;
@property(nonatomic, strong) NSMutableDictionary *cfg;
@property(nonatomic, strong) NSMutableDictionary *dict;
//@property(nonatomic, strong) NSMutableArray <BTDevItem *> *DisConnectDevArray;
@property(nonatomic, strong) NSMutableDictionary *node;
@property(nonatomic, assign) BOOL configNode;
@property(nonatomic, strong) NSString *pwd;
@property(nonatomic, assign) BOOL HomePage;
@property(nonatomic, strong) NSString *userMeshName;
@property(nonatomic, strong) NSString *userMeshPwd;

@property (nonatomic, strong) NSData *otaData;
@property (nonatomic, assign) NSInteger number; //数据包的包个数；
@property (nonatomic, assign) NSInteger location;  //当前所发送的包的Index；
@property (nonatomic, strong) NSTimer *otaTimer;
@property (nonatomic, assign) BOOL isSingleSendFinsh;
@property (nonatomic, assign) BOOL Sending;
@property (nonatomic, assign) BOOL isStartOTA;
@property (nonatomic, strong) NSMutableArray *array;
@end
