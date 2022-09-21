#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

#import "SigECCEncryptHelper.h"
#import "SigFastProvisionAddManager.h"

@interface deviceModel : NSObject
@property (nonatomic,strong) CBPeripheral *peripheral;
@property (nonatomic,strong) NSString *macAddress;
@end

@interface TelinkBtSig : RCTEventEmitter <RCTBridgeModule, SigBearerDataDelegate,SigDataSourceDelegate,SigMessageDelegate,SigBluetoothDelegate>
@property (nonatomic,strong) NSMutableArray <deviceModel *> *allDevices;
@property (nonatomic, assign) BOOL allowSendLogoutWhenDisconnect;
@property (nonatomic, assign) NSInteger connectMeshAddress; // 直连节点的 mesh 地址
@end
