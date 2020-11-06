#import "RNBtSigTelink.h"
//#import "RCTLog.h"
#import <SigMeshOC/SDKLibCommand.h>
#import <SigMeshOC/Bluetooth.h>
#import <SigMeshOC/SigDataSource.h>
#import <SigMeshOC/LibTools.h>
#import <SigMeshOC/BTConst.h>
#import <SigMeshOC/OTAManager.h>
#import <SigMeshOC/MeshOTAManager.h>
//#import "BTCentralManager.h"
//#import "MeshOTAManager.h"
//#import "MeshOTAItemModel.h"
//#import "SysSetting.h"


#define kCentralManager ([BTCentralManager shareBTCentralManager])

#define kEndTimer(timer) \
if (timer) { \
[timer invalidate]; \
timer = nil; \
}

#define kOTAPartSize (16*8)
#define kOTAWriteInterval (0.005)

#define SIG_1_OPCODE_SIZE  1
#define SIG_2_OPCODE_SIZE  2
#define VENDOR_OPCODE_SIZE 3

@implementation deviceModel
- (BOOL)isEqual:(id)object{
    if ([object isKindOfClass:[deviceModel class]]) {
        return [_peripheral.identifier.UUIDString isEqualToString:((deviceModel *)object).peripheral.identifier.UUIDString];
    } else {
        return NO;
    }
}
@end


//@interface TelinkBtSig() <BTCentralManagerDelegate>
@interface TelinkBtSig()

@end

@implementation TelinkBtSig {
    RCTPromiseResolveBlock _resolveBlock;
    RCTPromiseResolveBlock _resolvedateBlock;
    RCTPromiseResolveBlock _resolveMesheBlock;
    RCTPromiseResolveBlock _resolvesetNodeGroupAddr;

    RCTPromiseRejectBlock _rejectsetNodeGroupAddr;
    RCTPromiseRejectBlock _rejectBlock;

    responseVendorModelCallBack onVendorResponse;

    responseModelCallBack onOnlineStatusNotify;
    responseModelCallBack onGetOnOffNotify;
    responseModelCallBack onGetLevelNotify;
    responseModelCallBack onGetLightnessNotify;
    responseModelCallBack onGetCtlNotify;
    responseModelCallBack onGetFirmwareInfo;
}

RCT_EXPORT_MODULE()

- (NSArray<NSString *> *)supportedEvents
{
    return @[
        @"bluetoothDisabled",
        @"bluetoothEnabled",
        @"deviceStatusConnected",
        @"deviceStatusConnecting",
        @"deviceStatusDeleteCompleted",
        @"deviceStatusDeleteFailure",
        @"deviceStatusErrorAndroidN",
        @"deviceStatusGetFirmwareCompleted",
        @"deviceStatusGetFirmwareFailure",
        @"deviceStatusGetLtkCompleted",
        @"deviceStatusGetLtkFailure",
        @"deviceStatusLogining",
        @"deviceStatusLogin",
        @"deviceStatusLogout",
        @"deviceStatusMeshOffline",
        @"deviceStatusMeshScanCompleted",
        @"deviceStatusMeshScanTimeout",
        @"deviceStatusOtaCompleted",
        @"deviceStatusOtaFailure",
        @"deviceStatusOtaMasterComplete",
        @"deviceStatusOtaMasterFail",
        @"deviceStatusOtaMasterProgress",
        @"deviceStatusOtaProgress",
        @"deviceStatusUpdateAllMeshCompleted",
        @"deviceStatusUpdateMeshCompleted",
        @"deviceStatusUpdateMeshFailure",
        @"deviceStatusUpdatingMesh",
        @"leScan",
        @"leScanCompleted",
        @"leScanTimeout",
        @"meshOffline",
        @"notificationDataGetCtl",
        @"notificationDataGetMeshOtaApplyStatus",
        @"notificationDataGetMeshOtaProgress",
        @"notificationDataGetMeshOtaFirmwareDistributionStatus",
        @"notificationDataGetLevel",
        @"notificationDataGetLightness",
        @"notificationDataGetOnOff",
        @"notificationDataGetOtaState",
        @"notificationDataGetTemp",
        @"notificationDataGetVersion",
        @"notificationDataSetOtaModeRes",
        @"notificationGetDeviceState",
        @"notificationOnlineStatus",
        @"notificationVendorResponse",
        @"saveOrUpdateJS",
        @"serviceConnected",
        @"serviceDisconnected",
        @"systemLocationDisabled",
        @"systemLocationEnabled",
    ];
}

- (NSData *)byteArray2Data:(NSArray *)array {
    NSMutableData *data = [NSMutableData data];
    [array enumerateObjectsUsingBlock:^(NSNumber* number, NSUInteger index, BOOL* stop) {
        uint8_t tmp = number.unsignedCharValue;
        [data appendBytes:(void *)(&tmp)length:1];
    }];

    return data;
}

- (NSArray *)byteData2Array:(NSData *)data {
    NSMutableArray *array = [[NSMutableArray alloc] init];
    [data enumerateByteRangesUsingBlock:^(const void *bytes, NSRange byteRange, BOOL *stop) {
        unsigned char *dataBytes = (unsigned char*)bytes;
        for (NSInteger i = 0; i < byteRange.length; i++) {
            [array addObject:[NSNumber numberWithInt:(dataBytes[i]) & 0xff]];
        }
    }];

    return array;
}

// ref to configData() in SigMeshOC/SigDataSource.m
- (void)initMesh:(NSString *)netKeyJS appKey:(NSString *)appKeyJS meshAddressOfApp:(NSInteger)meshAddressOfApp devices:(NSArray *)devices provisionerSno:(NSInteger)provisionerSno provisionerIvIndex:(NSInteger)provisionerIvIndex {
    // Even exist mesh.json, still create a new one with data from JS and init mesh
    //1.netKeys
    SigNetkeyModel *netkey = [[SigNetkeyModel alloc] init];
    netkey.oldKey = @"";
    netkey.index = 0;
    netkey.phase = 0;
    netkey.timestamp = [LibTools getNowTimeTimestampFrome2000];
    netkey.key = [LibTools convertDataToHexStr:[netKeyJS dataUsingEncoding:NSUTF8StringEncoding]];
    netkey.name = @"";
    netkey.minSecurity = @"high";
    [SigDataSource.share.netKeys addObject:netkey];

    // The first use of SigDataSource.share above will call init() in SigMeshOC/SigDataSource.m
    // and cause _ivIndex = @"11223344" , for share with android telink sdk which set
    // ivIndex to 0 as default, we need this
    SigDataSource.share.ivIndex = [NSString stringWithFormat:@"%08lX",(long)provisionerIvIndex];

    //2.appKeys
    SigAppkeyModel *appkey = [[SigAppkeyModel alloc] init];
    appkey.oldKey = @"";
    appkey.key = [LibTools convertDataToHexStr:[appKeyJS dataUsingEncoding:NSUTF8StringEncoding]];
    appkey.name = @"";
    appkey.boundNetKey = 0;
    appkey.index = 0;
    [SigDataSource.share.appKeys addObject:appkey];

    //3.provisioners
    SigProvisionerModel *provisioner = [[SigProvisionerModel alloc] initWithExistProvisionerCount:0 andProvisionerUUID:[LibTools convertDataToHexStr:[LibTools initMeshUUID]]];
    [SigDataSource.share.provisioners addObject:provisioner];

    //4.add new provisioner to nodes, ref to addLocationNodeWithProvisioner() in SigMeshOC/SigDataSource.m
    SigNodeModel *node = [[SigNodeModel alloc] init];

    //init defoult data
    node.UUID = provisioner.UUID;
    node.secureNetworkBeacon = YES;
    node.defaultTTL = TTL_DEFAULT;
    node.features.proxy = 2;
    node.features.friend = 0;
    node.features.relay = 2;
    node.relayRetransmit.count = 3;
    node.relayRetransmit.interval = 0;
    node.networkTransmit.count = 5;
    node.networkTransmit.interval = 2;
    [SigDataSource.share saveCurrentProvisionerUUID:provisioner.UUID];
    node.unicastAddress = [NSString stringWithFormat:@"%04X",(UInt16)meshAddressOfApp];
    NSData *devicekeyData = [LibTools createRandomDataWithLength:16];
    node.deviceKey = [LibTools convertDataToHexStr:devicekeyData];
    SigNodeKeyModel *nodeAppkey = [[SigNodeKeyModel alloc] init];
    nodeAppkey.index = appkey.index;
    if (![node.appKeys containsObject:nodeAppkey]) {
        [node.appKeys addObject:nodeAppkey];
    }

    VC_node_info_t node_info = {};
    //_nodeInfo默认赋值ff
    memset(&node_info, 0xff, sizeof(VC_node_info_t));
    node_info.node_adr = [LibTools uint16From16String:node.unicastAddress];
    node_info.element_cnt = 1;
    node_info.cps.len_cps = SIZE_OF_PAGE0_LOCAL;
    memcpy(&node_info.cps.page0_head, gp_page0, SIZE_OF_PAGE0_LOCAL);
    node.nodeInfo = node_info;

    [SigDataSource.share.nodes addObject:node];

    //5.add default group
    SigGroupModel *group = [[SigGroupModel alloc] init];
    group.address = [NSString stringWithFormat:@"%04X",0xffff];
    group.parentAddress = [NSString stringWithFormat:@"%04X",0];
    group.name = @"All";
    [SigDataSource.share.groups addObject:group];

    SigDataSource.share.meshUUID = netkey.key;
    SigDataSource.share.$schema = @"telink-semi.com";
    SigDataSource.share.meshName = @"Telink-Sig-Mesh";
    SigDataSource.share.version = LibTools.getSDKVersion;
    SigDataSource.share.timestamp = [LibTools getNowTimeTimestampFrome2000];

    // set devices, ref to provision_end_callback() and App_key_bind_end_callback() in SigMeshOC/LibHandle.m
    for (int i = 0; i < devices.count; i++) {
        SigNodeModel *model = [[SigNodeModel alloc] init];

        NSDictionary *device = devices[i];
        [model setAddress:[device[@"meshAddress"] unsignedShortValue]];

        SigAppkeyModel *appkeyCur = [SigDataSource.share curAppkeyModel];
        SigNodeKeyModel *nodeAppkey = [[SigNodeKeyModel alloc] init];
        nodeAppkey.index = appkeyCur.index;
        if (![model.appKeys containsObject:nodeAppkey]) {
            [model.appKeys addObject:nodeAppkey];
        }

        [model setNodeInfo:*((VC_node_info_t *)[self byteArray2Data:device[@"nodeInfo"]].bytes)];

        model.deviceKey = [LibTools convertDataToHexStr:[self byteArray2Data:device[@"dhmKey"]]];
        model.peripheralUUID = nil;
        model.macAddress = [device[@"macAddress"] stringByReplacingOccurrencesOfString:@":" withString:@""];
        model.UUID = nil;

//        NSLog(@"TelinkBtSig sigmodel %@", [model getDictionaryOfSigNodeModel]);

//        [SigDataSource.share saveDeviceWithDeviceModel:model];
        [SigDataSource.share.nodes addObject:model];
    }

    NSLog(@"TelinkBtSig create mesh.json success");
    [SigDataSource.share saveLocationData];

    //check provisioner
    [SigDataSource.share checkExistLocationProvisioner];

    // 由于在 SigMeshOCDemo/SigMeshOCDemo/ViewController/Setting/ShareInVC.m
    // 看到说扫描别人分享来的数据后需要清空下面的 list ，虽然暂时发现不清空也没问题，但既然
    // 这里每次启动 APP 都不加载缓存也就是清空 list 也能正常使用，那保险起见就把下面两句都注释了
    //init SigScanRspModel list
//    [SigDataSource.share loadScanList];
    //init SigScanRspModel list
//    [SigDataSource.share loadEncryptedNodeIdentityList];

//    [SigDataSource.share setLocationSno:(UInt32)provisionerSno];
    [[NSUserDefaults standardUserDefaults] setObject:@((UInt32)provisionerSno) forKey:kCurrenProvisionerSno_key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// ref to startMeshSDK() in SigMeshOC/SDKLibCommand.m
- (void)initMeshLib {
    // 在 Bluetooth.share() -> [[Bluetooth alloc] init] ->  BLEProperties.init()
    // 中调用的 C 函数 mesh_init_all() 会触发回调 LibHandle.mesh_par_retrieve_store_win32() ->
    // 而进入 mesh_key_retrieve_win32() 以获取上面 initMesh() 中由 JS 层传过来保存在 SigDataSource 中的 netKey 和 appKey
    // 以及进入 update_VC_info_from_json() 以获取上面 initMesh() 中由 JS 层传过来保存在 SigDataSource 中的 devices
    // 至于 JS 层传来 provisionerSno ，由上面 initMesh() 中自定义的 setLocationSno 进行初始化，后续设备触发的 mesh_misc_store_win32 中调用 setLocationSno 时则会回调保存回 JS 层

    //init Bluetooth
    [Bluetooth share];

    APP_reset_vendor_id(kCompanyID);
}

- (void)startMeshSDK:(NSString *)netKey appKey:(NSString *)appKey meshAddressOfApp:(NSInteger)meshAddressOfApp devices:(NSArray *)devices provisionerSno:(NSInteger)provisionerSno provisionerIvIndex:(NSInteger)provisionerIvIndex {
    [self initMesh:netKey appKey:appKey meshAddressOfApp:meshAddressOfApp devices:devices provisionerSno:provisionerSno provisionerIvIndex:provisionerIvIndex];
    [self initMeshLib];
    [Bluetooth.share.commandHandle provisionLocation:[netKey dataUsingEncoding:NSUTF8StringEncoding] withLocationAddress:(int)meshAddressOfApp netketIndex:0];
}

RCT_EXPORT_METHOD(doInit:(NSString *)netKey appKey:(NSString *)appKey meshAddressOfApp:(NSInteger)meshAddressOfApp devices:(NSArray *)devices provisionerSno:(NSInteger)provisionerSno provisionerIvIndex:(NSInteger)provisionerIvIndex) {
    //    [[BTCentralManager shareBTCentralManager] stopScan];
    //扫描我的在线灯
    // [BTCentralManager shareBTCentralManager].delegate = self;
    // self.devArray = [[NSMutableArray alloc] init];
    // self.BTDevArray = [[NSMutableArray alloc] init];
    // self.dict = [[NSMutableDictionary alloc] init];
    // self.DisConnectDevArray = [[NSMutableArray alloc] init];
    // self.isNeedRescan = YES;
    // self.configNode = NO;
    // self.HomePage = YES;
    // self.isStartOTA = NO;
    self.connectMeshAddress = -1;

    //init SDK
//    [SDKLibCommand startMeshSDK];
     [self startMeshSDK:netKey appKey:appKey meshAddressOfApp:meshAddressOfApp devices:devices provisionerSno:provisionerSno provisionerIvIndex:provisionerIvIndex];

     __weak typeof(self) weakSelf = self;


    // ref to anasislyResponseData() in SigMeshOC/LibHandle.m
    onVendorResponse = ^(VendorResponseModel *model) {
        NSLog(@"TelinkBtSig onVendorResponse %@", model.rspData); //0xf0080002000100e3110201
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInt:model.address] forKey:@"meshAddress"];
        [dict setObject:[NSNumber numberWithInt:model.vendorOPCode] forKey:@"opcode"];
        [dict setObject:(NSArray *)[weakSelf byteData2Array:model.customData] forKey:@"params"];
        [weakSelf sendEventWithName:@"notificationVendorResponse" body:dict];
    };
    Bluetooth.share.commandHandle.responseVendorIDCallBack = onVendorResponse;

    // ref to responseBack() in SigMeshOC/Bluetooth.m
    onOnlineStatusNotify = ^(ResponseModel *model) {
        NSLog(@"TelinkBtSig onOnlineStatusNotify");
        NSMutableArray *array = [[NSMutableArray alloc] init];
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInt:model.address] forKey:@"meshAddress"];
        [dict setObject:[NSNumber numberWithInt:model.currentValue] forKey:@"brightness"];
        [dict setObject:[NSNumber numberWithInt:model.pointValue] forKey:@"colorTemp"];
        [dict setObject:[NSNumber numberWithInt:model.currentState ? 1 : -1] forKey:@"status"];
        [array addObject:dict];
        [weakSelf sendEventWithName:@"notificationOnlineStatus" body:array];
    };

    onGetOnOffNotify = ^(ResponseModel *model) {
        NSLog(@"TelinkBtSig onGetOnOffNotify");
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInt:model.address] forKey:@"meshAddress"];
        [dict setObject:[NSNumber numberWithInt:model.currentState] forKey:@"onOff"];
        [weakSelf sendEventWithName:@"notificationDataGetOnOff" body:dict];
    };

    onGetLevelNotify = ^(ResponseModel *model) {
        NSLog(@"TelinkBtSig onGetLevelNotify");
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInt:model.address] forKey:@"meshAddress"];
        [dict setObject:[NSNumber numberWithInt:model.currentValue] forKey:@"brightness"];
        [weakSelf sendEventWithName:@"notificationDataGetLevel" body:dict];
    };

    onGetLightnessNotify = ^(ResponseModel *model) {
        NSLog(@"TelinkBtSig onGetLightnessNotify");
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInt:model.address] forKey:@"meshAddress"];
        [dict setObject:[NSNumber numberWithInt:model.currentValue] forKey:@"brightness"];
        [weakSelf sendEventWithName:@"notificationDataGetLightness" body:dict];
    };

    onGetCtlNotify = ^(ResponseModel *model) {
        NSLog(@"TelinkBtSig onGetCtlNotify");
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInt:model.address] forKey:@"meshAddress"];
        if (model.opcode == OpcodeCurrentCTLResponse) {
            [dict setObject:[NSNumber numberWithInt:model.currentValue] forKey:@"brightness"];
            [dict setObject:[NSNumber numberWithInt:model.pointValue] forKey:@"colorTemp"];
            [weakSelf sendEventWithName:@"notificationDataGetCtl" body:dict];
        } else {
            [dict setObject:[NSNumber numberWithInt:model.currentValue] forKey:@"colorTemp"];
            [weakSelf sendEventWithName:@"notificationDataGetTemp" body:dict];
        }
    };

    onGetFirmwareInfo = ^(ResponseModel *model) {
        NSLog(@"TelinkBtSig onGetFirmwareInfo %@", model.rspData); // 0xf00c0002000100b602110200fb3137
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInt:model.address] forKey:@"meshAddress"];
        /*
        u16 cid，  (vendor id)
        u16 pid,   (设备类型)
        u16 vid    (版本id)
         */
        if (model.rspData.length < 15) {
            return;
        }
        NSData *data = [model.rspData subdataWithRange:NSMakeRange(model.rspData.length - 2, 2)];
        [dict setObject:[[NSString alloc] initWithBytes:data.bytes length:data.length encoding:NSUTF8StringEncoding] forKey:@"version"];
        [weakSelf sendEventWithName:@"notificationDataGetVersion" body:dict];
    };

    Bluetooth.share.commandHandle.notifyOnlineStatusCallBack = onOnlineStatusNotify;
    Bluetooth.share.commandHandle.switchOnOffCallBack = onGetOnOffNotify;
    Bluetooth.share.commandHandle.changeLevelCallBack = onGetLevelNotify;
    Bluetooth.share.commandHandle.changeBrightnessCallBack = onGetLightnessNotify;
    Bluetooth.share.commandHandle.changeTemperatureCallBack = onGetCtlNotify;
    Bluetooth.share.commandHandle.getFwInfoCallBack = onGetFirmwareInfo;

    Bluetooth.share.bleCentralUpdateStateCallBack = ^(CBCentralManagerState state) {
        if (Bluetooth.share.state == StateNormal) {
            switch (state) {
                case CBCentralManagerStatePoweredOn:
                    [weakSelf sendEventWithName:@"bluetoothEnabled" body:nil];
                    NSLog(@"TelinkBtSig bluetoothEnabled");
                    break;
                case CBCentralManagerStatePoweredOff:
                     [weakSelf sendEventWithName:@"bluetoothDisabled" body:nil];
                     NSLog(@"TelinkBtSig bluetoothDisabled");
                   break;
                default:
                    break;
            }
        }
    };

    [self sendEventWithName:@"serviceConnected" body:nil];
    [self sendEventWithName:@"bluetoothEnabled" body:nil];
    [self sendEventWithName:@"deviceStatusLogout" body:nil];

    // //注册通知，当app由后台切换到前台，在appdelegate中通知获取灯的状态，避免在后台时，灯的状态发生改变，而app上数据没有更新
    // [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive) name:@"applicationDidBecomeActive" object:nil];

    Bluetooth.share.commandHandle.setLocationSnoCallBack = ^(UInt32 sno)  {
        NSLog(@"TelinkBtSig sno set %d", sno);
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInt:sno] forKey:@"provisionerSno"];
        [dict setObject:[NSNumber numberWithBool:YES] forKey:@"hasOnlineStatusNotifyRaw"];
        [weakSelf sendEventWithName:@"saveOrUpdateJS" body:dict];
    };
}


- (void)applicationWillResignActive {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    // [kCentralManager setNotifyOpenPro];
}


- (void)applicationWillTerminate {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


// - (void)OnDevChange:(id)sender Item:(BTDevItem *)item Flag:(DevChangeFlag)flag {
//     //if (!self.isStartOTA) return;
//     //    kCentralManager.isAutoLogin = NO;

//     NSLog(@"flag==========%u", flag);
//     switch (flag) {
//         case DevChangeFlag_Add:                 [self dosomethingWhenDiscoverDevice:item]; break;
//         case DevChangeFlag_Connected:           [self dosomethingWhenConnectedDevice:item]; break;
//         case DevChangeFlag_Login:               [self dosomethingWhenLoginDevice:item]; break;
//         case DevChangeFlag_DisConnected:        [self dosomethingWhenDisConnectedDevice:item]; break;
//         default:    break;
//     }
// }

// - (void)resetStatusOfAllLight {
//     NSLog(@"resetStatusOfAllLight");
// }

// #pragma mark- Delegate

// - (void)dosomethingWhenDiscoverDevice:(BTDevItem *)item {
//     NSLog(@"dosomethingWhenDiscoverDevice item = %d", item.u_DevAdress);

//     NSMutableDictionary *event = [[NSMutableDictionary alloc] init];

//     [event setObject:item.name forKey:@"deviceName"];
//     [event setObject:[NSString stringWithFormat:@"%@", item.u_Name] forKey:@"meshName"];
//     [event setObject:[NSNumber numberWithInt:item.u_DevAdress] forKey:@"meshAddress"];
//     [event setObject:[NSString stringWithFormat:@"%x", item.u_Mac] forKey:@"macAddress"];
//     [event setObject:[NSNumber numberWithInt:item.u_meshUuid] forKey:@"meshUUID"];
//     [event setObject:[NSNumber numberWithInt:item.productID] forKey:@"productUUID"];
//     [event setObject:[NSNumber numberWithInt:item.u_Status] forKey:@"status"];

//     [self sendEventWithName:@"leScan" body:event];

//     NSMutableArray *macs = [[NSMutableArray alloc] init];
//     for (int i = 0; i < self.BTDevArray.count; i++) {
//         [macs addObject:@(self.BTDevArray[i].u_DevAdress)];
//     }
//     if (![macs containsObject:@(item.u_DevAdress)]) {
//         [self.BTDevArray addObject:item];
//     }

//     //    //sdk中连接设备会停止扫描，加延时确保所有灯都能扫描到
//     //    if (self.BTDevArray.count==1) {
//     //        [kCentralManager connectWithItem:item];
//     //    }
// }


// - (void)dosomethingWhenConnectedDevice:(BTDevItem *)item {
//     NSLog(@"dosomethingWhenConnectedDevice item = %d ", item.u_DevAdress);
// }

// - (void)dosomethingWhenLoginDevice:(BTDevItem *)item {
//     if (self.configNode) {
//         if ([[NSString stringWithFormat:@"%x", item.u_Mac] isEqualToString:[self.node objectForKey:@"macAddress"]]) {
//             [self.dict setObject:item forKey:[NSString stringWithFormat:@"%d", [[self.node objectForKey:@"meshAddress"] intValue]]];
//             if (item.u_DevAdress == [[self.node objectForKey:@"meshAddress"] intValue]) {
//                 [self resultOfReplaceAddress:item.u_DevAdress];
//             } else {
//                 [kCentralManager replaceDeviceAddress:item.u_DevAdress WithNewDevAddress:[[self.node objectForKey:@"meshAddress"] intValue]];
//             }

//             self.configNode = !self.configNode;
//         }
//     } else {
//         NSMutableDictionary *event = [[NSMutableDictionary alloc] init];
//         [event setObject:[NSNumber numberWithInt:item.u_DevAdress] forKey:@"meshAddress"];
//         [event setObject:[NSNumber numberWithInt:item.u_DevAdress] forKey:@"connectMeshAddress"];
//         [self sendEventWithName:@"deviceStatusLogin" body:event];
//     }
// }

// - (void)dosomethingWhenDisConnectedDevice:(BTDevItem *)item {
//     NSLog(@"dosomethingWhenDisConnectedDevice");
//     if (_HomePage) {
//         NSMutableArray *array = [[NSMutableArray alloc] init];
//         for (DeviceModel *omodel in self.devArray) {
//             if (item.u_DevAdress == omodel.u_DevAdress) {
//                 NSMutableDictionary *event = [[NSMutableDictionary alloc] init];
//                 [event setObject:[NSNumber numberWithInt:omodel.reserve] forKey:@"reserve"];
//                 [event setObject:[NSNumber numberWithInt:2] forKey:@"status"];
//                 [event setObject:[NSNumber numberWithInt:omodel.brightness] forKey:@"brightness"];
//                 [event setObject:[NSNumber numberWithInt:omodel.u_DevAdress] forKey:@"meshAddress"];
//                 [array addObject:event];
//             }
//         }
//         [self sendEventWithName:@"notificationOnlineStatus" body:array];
//     }
// }

// - (void)scanedLoginCharacteristic {
//     [kCentralManager loginWithPwd:self.pwd];
// }

// - (void)notifyBackWithDevice:(DeviceModel *)model {
//     if (!model) return;
//     NSMutableArray *macs = [[NSMutableArray alloc] init];
//     for (int i = 0; i < self.devArray.count; i++) {
//         [macs addObject:@(self.devArray[i].u_DevAdress)];
//     }
//     //AppDelegate *delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
//     //更新既有设备状态
//     if ([macs containsObject:@(model.u_DevAdress)]) {
//         NSUInteger index = [macs indexOfObject:@(model.u_DevAdress)];
//         DeviceModel *tempModel = [self.devArray objectAtIndex:index];
//         [tempModel updataLightStata:model];
//     }
//     //添加新设备
//     else {
//         DeviceModel *omodel = [[DeviceModel alloc] initWithModel:model];
//         [self.devArray addObject:omodel];
//     }
//     NSLog(@"model = %@", model.versionString);
//     NSMutableDictionary *event = [[NSMutableDictionary alloc] init];

//     [event setObject:[NSNumber numberWithInt:model.reserve] forKey:@"reserve"];
//     [event setObject:[NSNumber numberWithInt:model.stata] forKey:@"status"];
//     [event setObject:[NSNumber numberWithInt:model.brightness] forKey:@"brightness"];
//     [event setObject:[NSNumber numberWithInt:model.u_DevAdress] forKey:@"meshAddress"];

//     NSMutableArray *array = [NSMutableArray arrayWithObject:event];
//     [self sendEventWithName:@"notificationOnlineStatus" body:array];
//     [[MeshOTAManager share] setCurrentDevices:self.devArray];
// }

RCT_EXPORT_METHOD(doDestroy) {
    NSLog(@"TelinkBtSig doDestroy");
}

// RCT_EXPORT_METHOD(doResume) {
//     NSLog(@"doResume");
//     self.manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
// }

RCT_EXPORT_METHOD(enableBluetooth) {
    NSLog(@"TelinkBtSig enableBluetooth");
}

RCT_EXPORT_METHOD(notModeAutoConnectMesh:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    resolve(@YES);
    NSLog(@"TelinkBtSig notModeAutoConnectMesh");
}

RCT_EXPORT_METHOD(autoConnect:(NSString *)networkKey) {
    NSLog(@"TelinkBtSig autoConnect");

    [Bluetooth.share setBleScanNewDeviceCallBack:nil];
    if (Bluetooth.share.state == StateNormal) {
        CBPeripheral *tem = [Bluetooth.share currentPeripheral];
        if ([Bluetooth.share isConnected]) {
//            SigNodeModel *node = [SigDataSource.share getNodeWithUUID:tem.identifier.UUIDString];
            SigScanRspModel *scanRspModel = [SigDataSource.share getScanRspModelWithUUID:tem.identifier.UUIDString];
            SigNodeModel *node = [SigDataSource.share getNodeWithAddress:scanRspModel.address];
            NSLog(@"TelinkBtSig connected %d %@ %@", scanRspModel.address, node.macAddress, tem.identifier.UUIDString);

            [Bluetooth.share.commandHandle getOnlineStatusWithExecuteCommand:YES reqCount:3 Completation:^(ResponseModel *model){
                Bluetooth.share.commandHandle.getOnlineStatusCallBack = nil;

                __weak typeof(self) weakSelf = self;
                NSLog(@"TelinkBtSig deviceStatusLogin");
                self.connectMeshAddress = [node address];
                NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                [dict setObject:[NSNumber numberWithInt:[node address]] forKey:@"connectMeshAddress"];
                [weakSelf sendEventWithName:@"deviceStatusLogin" body:dict];

                [Bluetooth.share setBleDisconnectOrConnectFailCallBack:^(CBPeripheral *peripheral) {
                    NSLog(@"TelinkBtSig deviceStatusLogout");
                    [weakSelf sendEventWithName:@"deviceStatusLogout" body:nil];
                }];
            }];
        } else if (tem && tem.state == CBPeripheralStateConnecting) {
            return;
        } else {
            NSLog(@"TelinkBtSig auto reconnect");
            if (Bluetooth.share.manager.isScanning) {
                [Bluetooth.share.manager stopScan];
            }
            [Bluetooth.share startWorkNormalWithComplete:nil];
        }
    } else {
        [Bluetooth.share startWorkNormalWithComplete:nil];
    }

//     [[BTCentralManager shareBTCentralManager] stopScan];
//     [self.devArray removeAllObjects];
//     [self.BTDevArray removeAllObjects];
//     [self.DisConnectDevArray removeAllObjects];
//     kCentralManager.scanWithOut_Of_Mesh = NO;
//     self.pwd = userMeshPwd;
//     self.HomePage = YES;
//     self.userMeshName = userMeshName;
//     self.userMeshPwd = userMeshPwd;
//
//     [kCentralManager startScanWithName:userMeshName Pwd:userMeshPwd AutoLogin:YES];
}

RCT_EXPORT_METHOD(autoRefreshNotify:(NSInteger) repeatCount Interval:(NSInteger) NSInteger) {
//     [kCentralManager setNotifyOpenPro];
}

RCT_EXPORT_METHOD(idleMode:(BOOL)disconnect) {
    NSLog(@"TelinkBtSig idleMode");
    // If your JS APP call it frequently, then must comment bellow, otherwise can't claim in configNode()
    // if (disconnect) {
    //    [Bluetooth.share stopAutoConnect];
    //    [Bluetooth.share cancelAllConnecttionWithComplete:nil];
    // }
}

RCT_EXPORT_METHOD(startScan:(NSInteger)timeoutSeconds isSingleNode:(BOOL)isSingleNode) {
    // need below to clean scanList, otherwise kickout sometime don't work
    [SigDataSource.share.scanList removeAllObjects];
    NSMutableArray *tem = [NSMutableArray array];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:tem];
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:kScanList_key];
    [[NSUserDefaults standardUserDefaults] synchronize];

    NSMutableArray *matchsListTem = [NSMutableArray array];
    NSData *matchsListData = [NSKeyedArchiver archivedDataWithRootObject:matchsListTem];
    [[NSUserDefaults standardUserDefaults] setObject:matchsListData forKey:kMatchsList_key];
    NSMutableArray *noMatchsListTem = [NSMutableArray array];
    NSData *noMatchsListData = [NSKeyedArchiver archivedDataWithRootObject:noMatchsListTem];
    [[NSUserDefaults standardUserDefaults] setObject:noMatchsListData forKey:kNoMatchsList_key];
    [[NSUserDefaults standardUserDefaults] synchronize];


    self.allDevices = [NSMutableArray array];
    __weak typeof(self) weakSelf = self;
    [Bluetooth.share cancelAllConnecttionWithComplete:^{
        [weakSelf sendEventWithName:@"deviceStatusLogout" body:nil];
        [Bluetooth.share setBleScanNewDeviceCallBack:^(CBPeripheral *peripheral, BOOL provisioned) {
            if (provisioned) {
                SigScanRspModel *scanRspModel = [SigDataSource.share getScanRspModelWithUUID:peripheral.identifier.UUIDString];
                if (scanRspModel == nil || scanRspModel.macAddress == nil || scanRspModel.PID == 0) {
                    // Because scanRspModel is saved by NSOperationQueue in didDiscoverPeripheral() of SigMeshOC/Bluetooth.m ,we need here especially `scanRspModel.PID == 0`
                    return;
                }

                NSString *macAddress = [LibTools getMacStringWithMac:scanRspModel.macAddress];
                deviceModel *device = [[deviceModel alloc] init];
                device.peripheral = peripheral;
                device.macAddress = macAddress;
                if (![weakSelf.allDevices containsObject:device]) {
                    [weakSelf.allDevices addObject:device];
                    NSLog(@"TelinkBtSig ScanNewDevice macAddress = %@", macAddress);

                    NSMutableDictionary *event = [[NSMutableDictionary alloc] init];
                    // [event setObject:scanRspModel.nodeIdentityData forKey:@"deviceName"];
                    // [event setObject:[NSString stringWithFormat:@"%@", scanRspModel.networkIDData] forKey:@"meshName"];
                    // [event setObject:[NSNumber numberWithInt:scanRspModel.address] forKey:@"meshAddress"];
                    [event setObject:macAddress forKey:@"macAddress"];
                    // [event setObject:[NSNumber numberWithInt:scanRspModel.uuid] forKey:@"meshUUID"];
                    [event setObject:[NSNumber numberWithInt:scanRspModel.PID] forKey:@"productUUID"];
                    // [event setObject:[NSNumber numberWithInt:scanRspModel.CID] forKey:@"status"];
                    [weakSelf sendEventWithName:@"leScan" body:event];
                }
            }
        }];
        [Bluetooth.share stopAutoConnect];
        [Bluetooth.share setProvisionState];
        [Bluetooth.share startScan];

        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf performSelector:@selector(scanFinish) withObject:nil afterDelay:timeoutSeconds];
        });
    }];

//     [[BTCentralManager shareBTCentralManager] stopScan];
//     [self.devArray removeAllObjects];
//     [self.BTDevArray removeAllObjects];
//     [self.DisConnectDevArray removeAllObjects];
//     self.configNode = NO;
//     self.HomePage = NO;
//     kCentralManager.scanWithOut_Of_Mesh = NO;
//     kCentralManager.timeOut = 60;
//     self.pwd = @"123";
//     self.userMeshName = meshName;
//     self.userMeshPwd = @"123";
//     self.location = 0;
//     //    [kCentralManager startScanWithName:meshName Pwd:@"123" AutoLogin:YES];
//     dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1000 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
//         [kCentralManager startScanWithName:meshName Pwd:@"123" AutoLogin:NO];
//     });
}

- (void)scanFinish {
    [Bluetooth.share setBleScanNewDeviceCallBack:nil];  // need this otherwise keyBindSuccess if configNode to quickly just after startScan

    // even cancelPreviousPerformRequestsWithTarget in configNode(),
    // still sometime cause delayMeshProxyInit in readGattFinishWithPeripheral() of
    // SigMeshOC/Bluetooth.m, so comment it, and worked well.
    //    [Bluetooth.share setNormalState];

    [Bluetooth.share stopScan];
}

- (NSInteger)getOpcodeSize:(NSInteger)opVal {
        return (opVal & 0x80) != 0
                ?
                ((opVal & 0x40) != 0 ? VENDOR_OPCODE_SIZE : SIG_2_OPCODE_SIZE)
                :
                SIG_1_OPCODE_SIZE;
}

// ref to react-native-btsig-telink/android/src/main/java/com/telink/sig/mesh/model/MeshCommand.java
- (NSData *)meshCommandToBytes:(NSInteger)opcode meshAddress:(NSInteger)meshAddress value:(NSArray *)value {
    NSInteger OpcodeSize = [self getOpcodeSize:opcode];
    NSInteger reLen = 10 + OpcodeSize + (value == nil ? 0 : value.count);
    uint8_t result[reLen];
    int index = 0;

    result[index++] = (uint8_t) (HCI_CMD_BULK_CMD2DEBUG & 0xFF);
    result[index++] = (uint8_t) ((HCI_CMD_BULK_CMD2DEBUG >> 8) & 0xFF);

    result[index++] = (uint8_t) (0 & 0xFF);
    result[index++] = (uint8_t) ((0 >> 8) & 0xFF);

    result[index++] = (uint8_t) (0 & 0xFF);
    result[index++] = (uint8_t) ((0 >> 8) & 0xFF);

    result[index++] = 2;//retryCnt;
    result[index++] = 0;//rspMax;

    result[index++] = (uint8_t) (meshAddress & 0xFF);
    result[index++] = (uint8_t) ((meshAddress >> 8) & 0xFF);

    result[index++] = (uint8_t) (opcode & 0xFF);
    if (OpcodeSize >= 2) {
        result[index++] = (uint8_t) ((opcode >> 8) & 0xFF);
        if (OpcodeSize == 3) {
            result[index++] = (uint8_t) ((opcode >> 16) & 0xFF);
        }
    }
    if (value != nil) {
        for (int i = 0; i < value.count; i++) {
            result[index++] = ((NSNumber *)[value objectAtIndex:i]).unsignedCharValue;
        }
    }

    return [NSData dataWithBytes:result length:reLen];
}

RCT_EXPORT_METHOD(sendCommand:(NSInteger)opcode meshAddress:(NSInteger)meshAddress value:(NSArray *)value immediate:(BOOL)immediate) {
    NSData *cmdData = [self meshCommandToBytes:opcode meshAddress:meshAddress value:value];
    SendOpByINI((u8 *)cmdData.bytes, (u32)cmdData.length);
}


RCT_EXPORT_METHOD(startOta:(NSString *)mac firmware:(NSArray *)firmware resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    __weak typeof(self) weakSelf = self;
    [OTAManager.share startOTAWithOtaData:[self byteArray2Data:firmware] models:@[[SigDataSource.share getDeviceWithMacAddress:[mac stringByReplacingOccurrencesOfString:@":" withString:@""]]] singleSuccessAction:^(SigNodeModel *device) {
        resolve(@true);
    } singleFailAction:^(SigNodeModel *device) {
        reject(@"", @"OTA_FAIL", nil);
    } singleProgressAction:^(float progress) {
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInt:(int)progress] forKey:@"otaMasterProgress"];
        [weakSelf sendEventWithName:@"deviceStatusOtaMasterProgress" body:dict];
    } finishAction:^(NSArray<SigNodeModel *> *successModels, NSArray<SigNodeModel *> *fileModels) {
        NSLog(@"TelinkBtSig OTA finished");
    }];
 }

RCT_EXPORT_METHOD(startMeshOTA:(NSArray *)meshAddresses firmware:(NSArray *)firmware) {
    __weak typeof(self) weakSelf = self;
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [dict setObject:[NSNumber numberWithInt:SigDataSource.share.curLocationNodeModel.address] forKey:@"meshAddress"];
    [dict setObject:@"start" forKey:@"status"];
    [weakSelf sendEventWithName:@"notificationDataGetMeshOtaFirmwareDistributionStatus" body:dict];

    [MeshOTAManager.share startMeshOTAWithLocationAddress:SigDataSource.share.curLocationNodeModel.address cid:0x0211 deviceAddresses:meshAddresses otaData:[self byteArray2Data:firmware] progressHandle:^(NSInteger progress) {
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInt:(int)progress] forKey:@"OtaSlaveProgress"];
        [weakSelf sendEventWithName:@"notificationDataGetMeshOtaProgress" body:dict];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (progress == 100) {
                NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                [dict setObject:[NSNumber numberWithInt:SigDataSource.share.curLocationNodeModel.address] forKey:@"meshAddress"];
                [dict setObject:@"stop" forKey:@"status"];
                [weakSelf sendEventWithName:@"notificationDataGetMeshOtaFirmwareDistributionStatus" body:dict];

                [Bluetooth.share setNormalState];
            }
        });
    } finishHandle:^(NSArray<NSNumber *> *successAddresses, NSArray<NSNumber *> *failAddresses) {
        for (unsigned i = 0; i < successAddresses.count; i++) {
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
            [dict setObject:[successAddresses objectAtIndex:i] forKey:@"meshAddress"];
            [dict setObject:@"success" forKey:@"status"];
            [weakSelf sendEventWithName:@"notificationDataGetMeshOtaApplyStatus" body:dict];
        }
        for (unsigned i = 0; i < failAddresses.count; i++) {
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
            [dict setObject:[failAddresses objectAtIndex:i] forKey:@"meshAddress"];
            [dict setObject:@"failure" forKey:@"status"];
            [weakSelf sendEventWithName:@"notificationDataGetMeshOtaApplyStatus" body:dict];
        }
    } errorHandle:^(NSError *error) {
        NSLog(@"TelinkBtSig MeshOTA error = %@",error);
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInt:SigDataSource.share.curLocationNodeModel.address] forKey:@"meshAddress"];
        [dict setObject:@"error" forKey:@"status"];
        [weakSelf sendEventWithName:@"notificationDataGetMeshOtaFirmwareDistributionStatus" body:dict];
    }];
}

RCT_EXPORT_METHOD(pauseMeshOta) {
    APP_set_mesh_ota_pause_flag(1);
}

RCT_EXPORT_METHOD(continueMeshOta) {
    APP_set_mesh_ota_pause_flag(0);
}

RCT_EXPORT_METHOD(stopMeshOTA:(NSString *)tag) {
    [MeshOTAManager.share stopMeshOTA];
}

RCT_EXPORT_METHOD(changePower:(NSInteger)meshAddress value:(NSInteger)value) {
    [Bluetooth.share.commandHandle switchOnOffWithExecuteCommand:YES on:(value == 1) address:meshAddress resMax:0 ack:YES Completation:onGetOnOffNotify];
}

RCT_EXPORT_METHOD(changeBrightness:(NSInteger)meshAddress value:(NSInteger)value) {
    [Bluetooth.share.commandHandle changeBrightnessWithExecuteCommand:YES address:meshAddress para:value isGet:NO respondMax:0 ack:YES Completation:onGetLightnessNotify];
}

RCT_EXPORT_METHOD(changeTemperatur:(NSInteger)meshAddress value:(float)value) {
    [Bluetooth.share.commandHandle changeTempratureWithExecuteCommand:YES address:meshAddress para:value isGet:NO respondMax:0 ack:YES Completation:onGetCtlNotify];
}

RCT_EXPORT_METHOD(changeColor:(NSInteger)meshAddress hue:(NSInteger)hue saturation:(NSInteger)saturation brightness:(NSInteger)brightness) {
    [Bluetooth.share.commandHandle changeHSLWithExecuteCommand:YES address:meshAddress hue:hue saturation:saturation brightness:brightness isGet:NO respondMax:0 ack:YES Completation:nil];
}

- (deviceModel *)getDeviceModelWithMac:(NSString *)mac{
    @synchronized(self) {
        for (deviceModel *model in self.allDevices) {
            if ([model.macAddress isEqualToString:mac]) {
                return model;
            }
        }
        return nil;
    }
}

RCT_EXPORT_METHOD(configNode:(NSDictionary *)node isToClaim:(BOOL)isToClaim resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    if (isToClaim) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(scanFinish) object:nil];
        [Bluetooth.share stopScan]; // need this otherwise sometime will connectPeripheral() other node macAddress in blockState() of SigMeshOC/Bluetooth.m
        [Bluetooth.share setBleScanNewDeviceCallBack:nil];  // need this otherwise keyBindSuccess difficult
        Bluetooth.share.commandHandle.responseVendorIDCallBack = nil;
        [Bluetooth.share stopAutoConnect];
        [Bluetooth.share cancelAllConnecttionWithComplete:nil];
        [Bluetooth.share clearCachelist];
        NSData *key = [SigDataSource.share curNetKey];
        NSLog(@"TelinkBtSig AddNewDevice %@", [node objectForKey:@"macAddress"]);

        SigScanRspModel *scanRspModel = [SigDataSource.share getScanRspModelWithMac:[[node objectForKey:@"macAddress"] stringByReplacingOccurrencesOfString:@":" withString:@""]];
        CBPeripheral *peripheral = [Bluetooth.share getPeripheralWithUUID:scanRspModel.uuid];

        // TODO: use getPeripheralWithUUID() instead of getDeviceModelWithMac(), and modify SigScanRspModel.isEqual()
        // in SigMeshOC/Model.m to the form of SigNodeModel.isEqual() in SigMeshOC/SigDataSource.m
        // then can remove getDeviceModelWithMac() and self.allDevices
//        deviceModel *device = [self getDeviceModelWithMac:[node objectForKey:@"macAddress"]];
//        CBPeripheral *peripheral;
//        if (device) {
//            peripheral = device.peripheral;
//        }

        if (peripheral == nil) {
            reject(@"need rescan", @"AddNewDevice fail", nil);
            Bluetooth.share.commandHandle.responseVendorIDCallBack = onVendorResponse;
            return;
        }

        UInt16 provisionAddress = [[node objectForKey:@"meshAddress"] intValue];

        BOOL fastBind = true; // fastBind will be checked again in keybindAction() of SigMeshOC/Bluetooth.m , so true here

        [Bluetooth.share.commandHandle startAddDeviceWithNextAddress:provisionAddress networkKey:key netkeyIndex:SigDataSource.share.curNetkeyModel.index peripheral:peripheral keyBindType:fastBind ? KeyBindTpye_Quick : KeyBindTpye_Normal provisionSuccess:^(NSString *identify, UInt16 address) {
            if (identify && address != 0) {
                NSLog(@"TelinkBtSig AddNewDevice %d provisionSuccess", provisionAddress);
            } else {
                reject(@"provision", @"AddNewDevice fail", nil);
            }
        } keyBindSuccess:^(NSString *identify, UInt16 address) {
            NSLog(@"TelinkBtSig AddNewDevice %d keyBindSuccess", provisionAddress);

            NSMutableDictionary *event = [[NSMutableDictionary alloc] init];
            SigNodeModel *model = [SigDataSource.share getNodeWithAddress:address];
            VC_node_info_t node_info = model.nodeInfo;

//            NSLog(@"TelinkBtSig AddNewDevice node_info %@", [LibTools convertDataToHexStr:[NSData dataWithBytes:(u8 *)&node_info length:sizeof(VC_node_info_t)]]);

            if (fastBind) {
                SigScanRspModel *scanRspModel = [SigDataSource.share getScanRspModelWithUUID:identify];
                if (scanRspModel != nil && scanRspModel.macAddress != nil && scanRspModel.CID != 0 && scanRspModel.PID != 0) {
                    DeviceTypeModel *deviceType = [SigDataSource.share getNodeInfoWithCID:scanRspModel.CID PID:scanRspModel.PID];
                    node_info.cps.len_cps = deviceType.cpsDataLen; // otherwise the SDK will give you 0x0C
                    VC_node_info_t private_node_info = deviceType.defultNodeInfo;
                    memcpy(&node_info.cps.page0_head.cid, (Byte *)&private_node_info.cps.page0_head.cid, deviceType.cpsDataLen);
                    node_info.cps.page0_head.pid = scanRspModel.PID;
                    NSLog(@"TelinkBtSig AddNewDevice replace pid %x", node_info.cps.page0_head.pid);
                    if ([scanRspModel.advertisementData.allKeys containsObject:CBAdvertisementDataServiceDataKey]) {
                        NSData *advDataServiceData = [(NSDictionary *)scanRspModel.advertisementData[CBAdvertisementDataServiceDataKey] allValues].firstObject;
                        if (advDataServiceData) {
                            if (advDataServiceData.length >= 6) {
                                node_info.cps.page0_head.vid = [LibTools uint16FromBytes:[advDataServiceData subdataWithRange:NSMakeRange(4, 2)]];
                                NSLog(@"TelinkBtSig AddNewDevice replace vid %x", node_info.cps.page0_head.vid);
                            }
                        }
                    }
//                    NSLog(@"TelinkBtSig AddNewDevice node_repl %@", [LibTools convertDataToHexStr:[NSData dataWithBytes:(u8 *)&node_info length:sizeof(VC_node_info_t)]]);
                    model.nodeInfo = node_info;
                    [SigDataSource.share saveDeviceWithDeviceModel:model];
                }
            }

            int VC_node_info_t_length = sizeof(VC_node_info_t);
            u8 nodeInfoArray[VC_node_info_t_length];

            memcpy(nodeInfoArray, &node_info, VC_node_info_t_length);
            int nodeInfoWithoutCpsDataLength = 22;
            int nodeInfoValidLength = nodeInfoWithoutCpsDataLength + node_info.cps.len_cps;
            NSMutableArray *nodeInfo = [[NSMutableArray alloc] init];
            for (int i = 0; i < nodeInfoValidLength; i++) {
                [nodeInfo addObject:[NSNumber numberWithInt:nodeInfoArray[i]]];
            }
            NSLog(@"TelinkBtSig AddNewDevice nodeInfo = %@", nodeInfo);
            NSLog(@"TelinkBtSig AddNewDevice pid = %@", model.pid);

            [event setObject:nodeInfo forKey:@"nodeInfo"];
            [event setObject:[NSNumber numberWithInt:node_info.element_cnt] forKey:@"elementCnt"];
            [event setObject:[NSNumber numberWithInt:node_info.cps.page0_head.pid] forKey:@"type"];
            NSMutableArray *dhmKey = [[NSMutableArray alloc] init];
            int dev_key_length = sizeof(node_info.dev_key);
            for (int i = 0; i < dev_key_length; i++) {
                [dhmKey addObject:[NSNumber numberWithInt:node_info.dev_key[i]]];
            }
            NSLog(@"TelinkBtSig AddNewDevice dhmKey = %@", dhmKey);
            [event setObject:dhmKey forKey:@"dhmKey"];
            resolve(event);
        } fail:^(NSString *errorString) {
            NSLog(@"TelinkBtSig AddNewDevice %d fail: %@", provisionAddress, errorString);
            reject(errorString, @"AddNewDevice fail", nil);
        } finish:^{
            NSLog(@"TelinkBtSig AddNewDevice finish");

            Bluetooth.share.commandHandle.responseVendorIDCallBack = self->onVendorResponse;
        }];
    } else {
        __weak typeof(self) weakSelf = self;

//        NSString *macAddress = [[node objectForKey:@"macAddress"] stringByReplacingOccurrencesOfString:@":" withString:@""];
//        BOOL isDirect = [macAddress isEqualToString:[SigDataSource.share getCurrentConnectedNode].macAddress];
        // isDirect above sometime is not correct, so use isDirect below
        BOOL isDirect = self.connectMeshAddress == [[node objectForKey:@"meshAddress"] unsignedShortValue];

        if (isDirect) {
            [Bluetooth.share setBleDisconnectOrConnectFailCallBack:^(CBPeripheral *peripheral) {
                NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                if (resolve != nil) {
                    resolve(dict);
                }
                [weakSelf sendEventWithName:@"deviceStatusLogout" body:nil];
                [Bluetooth.share setBleDisconnectOrConnectFailCallBack:^(CBPeripheral *peripheral) {
                    [weakSelf sendEventWithName:@"deviceStatusLogout" body:nil];
                }];
            }];
        }
        [Bluetooth.share.commandHandle kickoutDevice:[[node objectForKey:@"meshAddress"] unsignedShortValue] complete:^{
            NSLog(@"TelinkBtSig kickout success");
            if (isDirect) {
                NSLog(@"TelinkBtSig kickout direct");
                //if node is Bluetooth.share.currentPeripheral, wait node didDisconnectPeripheral, delay 1.5s and pop.
            } else {
                NSLog(@"TelinkBtSig kickout remote");
                //if node isn't Bluetooth.share.currentPeripheral, delay 5s and pop.
                [weakSelf performSelector:@selector(kickoutFinish:) withObject:resolve afterDelay:5];
            }
        }];
    }
}

- (void)kickoutFinish:(RCTPromiseResolveBlock)resolve {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    if (resolve != nil) {
        resolve(dict);
    }
}

// - (void)resultOfReplaceAddress:(uint32_t )resultAddress
// {
//     for (BTDevItem *bt in self.BTDevArray) {
//         if ([[NSString stringWithFormat:@"%x", bt.u_Mac] isEqualToString:[self.node objectForKey:@"macAddress"]]) {
//             bt.u_DevAdress = resultAddress;
//             NSLog(@"configNode b1 = %@", bt.description);
//             GetLTKBuffer;
//             [kCentralManager setOut_Of_MeshWithName:[self.cfg objectForKey:@"oldName"] PassWord:[self.cfg objectForKey:@"oldPwd"] NewNetWorkName:[self.cfg objectForKey:@"newName"] Pwd:[self.cfg objectForKey:@"newPwd"] ltkBuffer:ltkBuffer ForCertainItem:bt];
//         }
//     }
// }

RCT_EXPORT_METHOD(setTime:(NSInteger)meshAddress) {
    [Bluetooth.share.commandHandle setNowTimeWithComplete:nil];
}

RCT_EXPORT_METHOD(getTime:(NSInteger)meshAddress relayTimes:(NSInteger)relayTimes resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    [Bluetooth.share.commandHandle getTimeWithComplete:meshAddress complete:^(ResponseModel *model) {
        unsigned int taiSec = model.currentValue;
        unsigned long sec = (unsigned long)taiSec + 946684800;

        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSString stringWithFormat:@"%ld",sec] forKey:@"time"];
        resolve(dict);

        NSLog(@"TelinkBtSig onGetTime taiSec: 0x%x, sec %ld", taiSec, sec);
    }];
}

// - (void)getDevDate:(NSDate *)date
// {
//     NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
//     [dateFormatter setDateFormat:@"yyyy/MM/dd HH:mm:ss"];
//     NSString *dateString = [dateFormatter stringFromDate:date];
//     NSLog(@"time strDate = %@", dateString);
//     NSMutableDictionary *event = [[NSMutableDictionary alloc] init];
//     [event setObject:dateString forKey:@"time"];

//     _resolvedateBlock(event);
// }

RCT_EXPORT_METHOD(setAlarm:(NSInteger)meshAddress index:(NSInteger)index year:(NSInteger)year month:(NSInteger)month day:(NSInteger)day hour:(NSInteger)hour minute:(NSInteger)minute second:(NSInteger)second week:(NSInteger)week action:(NSInteger)action sceneId:(NSInteger)sceneId) {
    SchedulerModel *model = [[SchedulerModel alloc] init];
    model.schedulerID = index;
    model.valid_flag_or_idx = model.schedulerID;
    model.year = year;
    model.month = month;
    model.day = day;
    model.hour = hour;
    model.minute = minute;
    model.second = second;
    model.week = week;
    model.action = action;
    model.sceneId = sceneId;

    [Bluetooth.share.commandHandle setSchedulerActionWithAddress:meshAddress resMax:0 schedulerModel:model Completation:nil];
}

RCT_EXPORT_METHOD(getAlarm:(NSInteger)meshAddress relayTimes:(NSInteger)relayTimes alarmId:(NSInteger)alarmId resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    [Bluetooth.share.commandHandle getSchedulerActionWithAddress:meshAddress resMax:0 schedulerModelID:alarmId Completation:^(ResponseModel *m) {
        SchedulerModel *model = [[SchedulerModel alloc] init];
        // model.schedulerID = (UInt8)alarmId;
        // model.valid_flag_or_idx = model.schedulerID;

//        NSLog(@"TelinkBtSig getAlarm %@", m.rspData);
//        TelinkBtSig getAlarm {length = 18, bytes = 0xf00f000100d80a5f02000000000000000000}
//        TelinkBtSig getAlarm {length = 18, bytes = 0xf00f00010089195f41fe7f803ce01f000000}
//        TelinkBtSig getAlarm {length = 18, bytes = 0xf00f00010089195f42fe7f103de00f000000}

        //data字节翻转
        NSMutableData *data = [NSMutableData data];
        for (int i=15; i>=8; i--) {
            [data appendData:[m.rspData subdataWithRange:NSMakeRange(i, 1)]];
        }
        model.schedulerData = [LibTools NSDataToUInt:data];
        model.sceneId = [LibTools uint16FromBytes:[m.rspData subdataWithRange:NSMakeRange(16, 2)]];

        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInt:(int)[model valid_flag_or_idx]] forKey:@"alarmId"];
        [dict setObject:[NSNumber numberWithInt:(int)[model year]] forKey:@"year"];
        [dict setObject:[NSNumber numberWithInt:(int)[model month]] forKey:@"month"];
        [dict setObject:[NSNumber numberWithInt:(int)[model day]] forKey:@"day"];
        [dict setObject:[NSNumber numberWithInt:(int)[model hour]] forKey:@"hour"];
        [dict setObject:[NSNumber numberWithInt:(int)[model minute]] forKey:@"minute"];
        [dict setObject:[NSNumber numberWithInt:(int)[model second]] forKey:@"second"];
        [dict setObject:[NSNumber numberWithInt:(int)[model week]] forKey:@"week"];
        [dict setObject:[NSNumber numberWithInt:(int)[model action]] forKey:@"action"];
        [dict setObject:[NSNumber numberWithInt:(int)[model transitionTime]] forKey:@"transTime"];
        [dict setObject:[NSNumber numberWithInt:(int)model.sceneId] forKey:@"sceneId"];
        resolve(dict);
    }];
}

RCT_EXPORT_METHOD(setNodeGroupAddr:(BOOL)toDel meshAddress:(NSInteger)meshAddress groupAddress:(NSInteger)groupAddress resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
//     NSMutableArray *array = [[NSMutableArray alloc] init];
//     if (toDel) {
//         [array addObject:[NSNumber numberWithInt:0]];
//     } else {
//         [array addObject:[NSNumber numberWithInt:1]];
//     }
//     [[BTCentralManager shareBTCentralManager] setNodeGroupAddr:meshAddress groupAddress:groupAddress toDel:toDel];

//     _resolvesetNodeGroupAddr = resolve;
//     _rejectsetNodeGroupAddr = reject;
}

// - (void)onGetGroupNotify:(NSArray *)array
// {
//     for (NSNumber *num in array) {
//         NSLog(@"array = %@", [NSNumber numberWithInt:num]);
//     }
//     if (array.count) {
//         _resolvesetNodeGroupAddr(array);
//     } else {
//         _rejectsetNodeGroupAddr(0, @"GetGroup return null", nil);
//     }

// }

// /**
//  *OTA回调
//  */
// - (void)OnDevNotify:(id)sender Byte:(uint8_t *)bytes
// {
//     NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
//     int meshAddress = bytes[3];
//     [dict setObject:[NSNumber numberWithInt:meshAddress] forKey:@"meshAddress"];
//     switch (bytes[10]) {
//         case 0x00://version
//             [dict setObject:[[NSString alloc]initWithData:[[NSData dataWithBytes:bytes length:20] subdataWithRange:NSMakeRange(11, 4)] encoding:NSUTF8StringEncoding] forKey:@"version"];
//             [self sendEventWithName:@"notificationDataGetVersion" body:dict];
//             break;
//         case 0x04://OtaSlaveProgress
//             [dict setObject:[NSNumber numberWithInt:(int) bytes[11]] forKey:@"OtaSlaveProgress"];
//             [self sendEventWithName:@"notificationDataGetMeshOtaProgress" body:dict];
//             break;
//         case 0x05://GET_DEVICE_STATE
//             switch (bytes[11]) {
//                 case 0:
//                     [dict setObject:@"idle" forKey:@"otaState"];
//                     break;
//                 case 1:
//                     [dict setObject:@"slave" forKey:@"otaState"];
//                     break;
//                 case 2:
//                     [dict setObject:@"master" forKey:@"otaState"];
//                     break;
//                 case 3:
//                     [dict setObject:@"onlyRelay" forKey:@"otaState"];
//                     break;
//                 case 4:
//                     [dict setObject:@"complete" forKey:@"otaState"];
//                     break;

//                 default:
//                     break;
//             }
//             [self sendEventWithName:@"notificationDataGetOtaState" body:dict];
//             break;
//         case 0x06://OtaSlaveProgress
//             if (bytes[11] == 0) {
//                 [dict setObject:@"ok" forKey:@"setOtaModeRes"];
//             } else {
//                 [dict setObject:@"err" forKey:@"setOtaModeRes"];
//             }
//             [self sendEventWithName:@"notificationDataSetOtaModeRes" body:dict];
//             break;
//         default:
//             break;
//     }
// }

// - (void)OnDevOperaStatusChange:(id)sender Status:(OperaStatus)status {
//     if (status == DevOperaStatus_SetNetwork_Finish) {
//         [self sendEventWithName:@"deviceStatusLogout" body:nil];
//         //查询版本号
//         [[BTCentralManager shareBTCentralManager] readFeatureOfselConnectedItem];
//     }
// }

// /*data:<56312e48 00000000 00000000>*/
// - (void)OnConnectionDevFirmWare:(NSData *)data {
//     NSString *firm = [[NSString alloc]initWithData:[data subdataWithRange:NSMakeRange(0, 4)] encoding:NSUTF8StringEncoding];
//     NSLog(@"OnConnectionDevFirmWare:%@", firm);

//     NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
//     [dict setObject:firm forKey:@"firmwareRevision"];
//     if (_resolveBlock) {
//         _resolveBlock(dict);
//     }
// }

// - (void)exceptionReport:(int)stateCode errorCode:(int)errorCode deviceID:(int)deviceID
// {
//     NSLog(@"exceptionReport = %d", errorCode);
// }

// - (void)loginTimeout:(TimeoutType)type
// {
//     NSLog(@"loginTimeout = %d", type);
// }

@end
