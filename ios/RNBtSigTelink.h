#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

#import <CoreBluetooth/CoreBluetooth.h>
#import <TelinkSigMeshLib/LibTools.h>
#import <TelinkSigMeshLib/MeshOTAManager.h>
#import <TelinkSigMeshLib/OTAManager.h>
#import <TelinkSigMeshLib/SDKLibCommand.h>
#import <TelinkSigMeshLib/SigAddDeviceManager.h>
#import <TelinkSigMeshLib/SigBluetooth.h>
#import <TelinkSigMeshLib/SigBearer.h>
#import <TelinkSigMeshLib/SigConfigMessage.h>
#import <TelinkSigMeshLib/SigConst.h>
#import <TelinkSigMeshLib/SigDataSource.h>
#import <TelinkSigMeshLib/SigECCEncryptHelper.h>
#import <TelinkSigMeshLib/SigEnumeration.h>
#import <TelinkSigMeshLib/SigFastProvisionAddManager.h>
#import <TelinkSigMeshLib/SigGenericMessage.h>
#import <TelinkSigMeshLib/SigHelper.h>
#import <TelinkSigMeshLib/SigLogger.h>
#import <TelinkSigMeshLib/SigMeshLib.h>
#import <TelinkSigMeshLib/SigModel.h>
#import <TelinkSigMeshLib/SigPublishManager.h>

@interface deviceModel : NSObject
@property (nonatomic,strong) CBPeripheral *peripheral;
@property (nonatomic,strong) NSString *macAddress;
@end

@interface TelinkBtSig : RCTEventEmitter <RCTBridgeModule, SigBearerDataDelegate,SigDataSourceDelegate,SigMessageDelegate,SigBluetoothDelegate>
@property (nonatomic,strong) NSMutableArray <deviceModel *> *allDevices;
@property (nonatomic, assign) BOOL allowSendLogoutWhenDisconnect;
@property (nonatomic, assign) NSInteger connectMeshAddress; // 直连节点的 mesh 地址
@end
