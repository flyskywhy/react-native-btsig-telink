#import "RNBtSigTelink.h"
//#import "RCTLog.h"
#import <SigMeshOC/SDKLibCommand.h>
#import <SigMeshOC/Bluetooth.h>
#import <SigMeshOC/SigDataSource.h>
#import <SigMeshOC/LibTools.h>
#import <SigMeshOC/BTConst.h>
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
    RCTPromiseResolveBlock _resolvesegetAlarm;

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
        @"notificationDataGetMeshOtaProgress",
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
- (void)initMesh:(NSString *)netKey appKey:(NSString *)appKey devices:(NSArray *)devices provisionerSno:(NSInteger)provisionerSno {
    NSData *locationData = [SigDataSource.share getLocationMeshData];
    BOOL exist = locationData.length > 0;
    if (!exist) {
        //don't exist mesh.json, create and init mesh
        //1.netKeys
        SigNetkeyModel *netkey = [[SigNetkeyModel alloc] init];
        netkey.oldKey = @"";
        netkey.index = 0;
        netkey.phase = 0;
        netkey.timestamp = [LibTools getNowTimeTimestampFrome2000];
        netkey.key = [LibTools convertDataToHexStr:[netKey dataUsingEncoding:NSUTF8StringEncoding]];
        netkey.name = @"";
        netkey.minSecurity = @"high";
        [SigDataSource.share.netKeys addObject:netkey];

        //2.appKeys
        SigAppkeyModel *appkey = [[SigAppkeyModel alloc] init];
        appkey.oldKey = @"";
        appkey.key = [LibTools convertDataToHexStr:[appKey dataUsingEncoding:NSUTF8StringEncoding]];
        appkey.name = @"";
        appkey.boundNetKey = 0;
        appkey.index = 0;
        [SigDataSource.share.appKeys addObject:appkey];

        //3.provisioners
        SigProvisionerModel *provisioner = [[SigProvisionerModel alloc] initWithExistProvisionerCount:0 andProvisionerUUID:[LibTools convertDataToHexStr:[LibTools initMeshUUID]]];
        [SigDataSource.share.provisioners addObject:provisioner];

        //4.add new provisioner to nodes
        [SigDataSource.share addLocationNodeWithProvisioner:provisioner];

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

        NSLog(@"TelinkBtSig creat mesh_sample.json success");
        [SigDataSource.share saveLocationData];
    } else {
        //exist mesh.json, load json
        NSData *data = [SigDataSource.share getLocationMeshData];
        NSDictionary *meshDict = [LibTools getDictionaryWithJSONData:data];
        [SigDataSource.share setDictionaryToDataSource:meshDict];
        //Attention: it will set _ivIndex to @"11223344" when mesh.json hasn't the key @"ivIndex"
        if (!SigDataSource.share.ivIndex || SigDataSource.share.ivIndex.length == 0) {
            SigDataSource.share.ivIndex = @"11223344";
            [SigDataSource.share saveLocationData];
        }

        // set devices, ref to provision_end_callback() in SigMeshOC/LibHandle.m
        for (int i = 0; i < devices.count; i++) {
            SigNodeModel *model = [[SigNodeModel alloc] init];

            NSDictionary *device = devices[i];
            [model setAddress:[device[@"meshAddress"] unsignedShortValue]];

            // VC_node_info_t info = model.nodeInfo;
            // info.element_cnt = device[@"elementCnt"];
            // info.cps.page0_head.cid = kCompanyID;
            // info.cps.page0_head.pid = device[@"type"];
            // model.nodeInfo = info;
            model.nodeInfo = *((VC_node_info_t *)[self byteArray2Data:device[@"nodeInfo"]].bytes);

            model.deviceKey = [LibTools convertDataToHexStr:[self byteArray2Data:device[@"dhmKey"]].bytes];
            model.peripheralUUID = nil;
            model.macAddress = device[@"macAddress"];
            // model.UUID = identify;
            model.UUID = nil;
            [SigDataSource.share saveDeviceWithDeviceModel:model];
        }
    }
    //check provisioner
    [SigDataSource.share checkExistLocationProvisioner];
    //init SigScanRspModel list
    [SigDataSource.share loadScanList];
    //init SigScanRspModel list
    [SigDataSource.share loadEncryptedNodeIdentityList];
}

// ref to startMeshSDK() in SigMeshOC/SDKLibCommand.m
- (void)initMeshLib {
    // 在 Bluetooth.share() -> [[Bluetooth alloc] init] ->  BLEProperties.init()
    // 中调用的 C 函数 mesh_init_all() 会触发回调 LibHandle.mesh_par_retrieve_store_win32() ->
    // 而进入 mesh_key_retrieve_win32() 以获取上面 initMesh() 中由 JS 层传过来保存在 SigDataSource 中的 netKey 和 appKey
    // 以及进入 update_VC_info_from_json() 以获取上面 initMesh() 中由 JS 层传过来保存在 SigDataSource 中的 devices
    // 至于 provisionerSno ，既然完全在 ios SDK 内部自产自销，那相关使用方式就与 android SDK 不同，不需要通过
    // [SigDataSource.share setLocationSno] 的方式由 JS 层传过来进行保存，也不需要通过
    // [SigDataSource.share.getLocationSno] 以及在 mesh_misc_store_win32 中增加回调的
    // 方式（就像 android SDK 中 TelinkApplication.saveMisc() 那样的回调做法）来保存回 JS 层
    // 所以上面 initMesh() 中并没有处理 provisionerSno
    //init Bluetooth
    [Bluetooth share];

    APP_reset_vendor_id(kCompanyID);
}

- (void)startMeshSDK:(NSString *)netKey appKey:(NSString *)appKey meshAddressOfApp:(NSInteger)meshAddressOfApp devices:(NSArray *)devices provisionerSno:(NSInteger)provisionerSno {
    [self initMesh:netKey appKey:appKey devices:devices provisionerSno:provisionerSno];
    [self initMeshLib];
    [Bluetooth.share.commandHandle provisionLocation:[netKey dataUsingEncoding:NSUTF8StringEncoding] withLocationAddress:(int)meshAddressOfApp netketIndex:0];
}

RCT_EXPORT_METHOD(doInit:(NSString *)netKey appKey:(NSString *)appKey meshAddressOfApp:(NSInteger)meshAddressOfApp devices:(NSArray *)devices provisionerSno:(NSInteger)provisionerSno) {
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

    //init SDK
    [SDKLibCommand startMeshSDK];
    // [self startMeshSDK:netKey appKey:appKey meshAddressOfApp:meshAddressOfApp devices:devices provisionerSno:provisionerSno];

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
// TODO:    Bluetooth.share.bleCentralUpdateStateCallBack = what centralManagerDidUpdateState() did bellow

    [self sendEventWithName:@"serviceConnected" body:nil];
    [self sendEventWithName:@"bluetoothEnabled" body:nil];
    [self sendEventWithName:@"deviceStatusLogout" body:nil];

    // //注册通知，当app由后台切换到前台，在appdelegate中通知获取灯的状态，避免在后台时，灯的状态发生改变，而app上数据没有更新
    // [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive) name:@"applicationDidBecomeActive" object:nil];
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


- (void)centralManagerDidUpdateState:(nonnull CBCentralManager *)central {
     //第一次打开或者每次蓝牙状态改变都会调用这个函数
     if (central.state == CBCentralManagerStatePoweredOn) {
         NSLog(@"蓝牙设备开着");
     } else {
         NSLog(@"蓝牙设备关着");

         UIAlertView *alterView = [[UIAlertView alloc]initWithTitle:@"提示" message:@"请打开蓝牙！" delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil];
         [alterView show];
     }
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
    __weak typeof(self) weakSelf = self;
    NSLog(@"TelinkBtSig autoConnect");
    [Bluetooth.share startWorkNormalWithComplete:^(NSString *uuidString) {
        NSLog(@"TelinkBtSig deviceStatusLogin");
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInt:[[SigDataSource.share getCurrentConnectedNode] address]] forKey:@"connectMeshAddress"];
        [weakSelf sendEventWithName:@"deviceStatusLogin" body:dict];

        [Bluetooth.share setBleDisconnectOrConnectFailCallBack:^(CBPeripheral *peripheral) {
            NSLog(@"TelinkBtSig deviceStatusLogout");
            [weakSelf sendEventWithName:@"deviceStatusLogout" body:nil];
        }];
    }];


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
    [Bluetooth.share setNormalState];
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


 RCT_EXPORT_METHOD(startOta:(NSArray *) value) {
//     //数组转化成bytes
//     unsigned c = (int)value.count;
//     uint8_t *bytes = (uint8_t*)malloc(sizeof(*bytes) * c);
//     unsigned i;
//     for (i = 0; i < c; i++) {
//         NSString *str = [value objectAtIndex:i];
//         int byte = [str intValue];
//         bytes[i] = (uint8_t)byte;
//     }
//     self.otaData = [NSData dataWithBytesNoCopy:bytes length:c freeWhenDone:YES];

//     self.location = 0;
//     self.isStartOTA = YES;
//     if (![[MeshOTAManager share] isMeshOTAing]) {
//         [self configMeshOTAList];
//     } else {
//         [[MeshOTAManager share] continueMeshOTAWithDeviceType:1 progressHandle:^(MeshOTAState meshState, NSInteger progress) {
//             if (meshState == MeshOTAState_normal) {
//                 //点对点OTA阶段
//                 NSString *t = [NSString stringWithFormat:@"ota firmware push... progress:%ld%%", (long)progress];
//                 NSLog(@"ota = %@", t);
//                 NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
//                 [dict setObject:[NSNumber numberWithInteger:progress] forKey:@"otaMasterProgress"];
//                 [self sendEventWithName:@"deviceStatusOtaMasterProgress" body:dict];
//             } else if (meshState == MeshOTAState_continue) {
//                 //meshOTA阶段
//                 NSString *t = [NSString stringWithFormat:@"package meshing... progress:%ld%%", (long)progress];
//                 NSLog(@"ota = %@", t);
//             }
//         } finishHandle:^(NSInteger successNumber, NSInteger failNumber) {
//             NSString *tip = [NSString stringWithFormat:@"success:%ld,fail:%ld", (long)successNumber, (long)failNumber];
//             NSLog(@"ota = %@", tip);
//             NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
//             [self sendEventWithName:@"deviceStatusOtaMasterComplete" body:dict];
//         } errorHandle:^(NSError *error) {
//             NSLog(@"ota = %@", error.domain);
//             NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
//             [self sendEventWithName:@"deviceStatusOtaMasterFail" body:dict];
//         }];
//     }
 }

// - (void)configMeshOTAList {
//     [[MeshOTAManager share] startMeshOTAWithDeviceType:1 otaData:self.otaData progressHandle:^(MeshOTAState meshState, NSInteger progress) {
//         if (meshState == MeshOTAState_normal) {
//             //点对点OTA阶段
//             NSString *t = [NSString stringWithFormat:@"ota firmware push... progress:%ld%%", (long)progress];
//             NSLog(@"ota = %@", t);
//             NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
//             [dict setObject:[NSNumber numberWithInteger:progress] forKey:@"otaMasterProgress"];
//             [self sendEventWithName:@"deviceStatusOtaMasterProgress" body:dict];
//         } else if (meshState == MeshOTAState_continue) {
//             //meshOTA阶段
//             NSString *t = [NSString stringWithFormat:@"package meshing... progress:%ld%%", (long)progress];
//             NSLog(@"ota = %@", t);
//         }
//     } finishHandle:^(NSInteger successNumber, NSInteger failNumber) {
//         NSString *tip = [NSString stringWithFormat:@"success:%ld,fail:%ld", (long)successNumber, (long)failNumber];
//         NSLog(@"ota = %@", tip);
//         NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
//         [self sendEventWithName:@"deviceStatusOtaMasterComplete" body:dict];
//     } errorHandle:^(NSError *error) {
//         NSLog(@"ota = %@", error.domain);
//         NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
//         [self sendEventWithName:@"deviceStatusOtaMasterFail" body:dict];
//     }];
// }


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
        Bluetooth.share.commandHandle.responseVendorIDCallBack = nil;
    //    [Bluetooth.share stopAutoConnect];
    //    [Bluetooth.share cancelAllConnecttionWithComplete:nil];
        [Bluetooth.share clearCachelist];
        NSData *key = [SigDataSource.share curNetKey]; // TODO: use from js

        // TODO: use getPeripheralWithUUID() instead of getDeviceModelWithMac(), and modify SigScanRspModel.isEqual()
        // in SigMeshOC/Model.m to the form of SigNodeModel.isEqual() in SigMeshOC/SigDataSource.m
        // then can remove getDeviceModelWithMac() and self.allDevices
        // SigScanRspModel *scanRspModel = [SigDataSource.share getScanRspModelWithMac:[[node objectForKey:@"macAddress"] stringByReplacingOccurrencesOfString:@":" withString:@""]];
        // CBPeripheral *peripheral = Bluetooth.share getPeripheralWithUUID:scanRspModel.uuid];
        deviceModel *device = [self getDeviceModelWithMac:[node objectForKey:@"macAddress"]];
        if (device == nil) {
            reject(@"need rescan", @"AddNewDevice fail", nil);
            Bluetooth.share.commandHandle.responseVendorIDCallBack = onVendorResponse;
            return;
        }

        UInt16 provisionAddress = [[node objectForKey:@"meshAddress"] intValue];

        // TODO: check if device support fast bind
        BOOL fastBind = false;
        NSUInteger type = 0;
        if (fastBind) {
            type = 1;
        }
        [Bluetooth.share.commandHandle startAddDeviceWithNextAddress:provisionAddress networkKey:key netkeyIndex:SigDataSource.share.curNetkeyModel.index peripheral:device.peripheral keyBindType:type provisionSuccess:^(NSString *identify, UInt16 address) {
            NSLog(@"TelinkBtSig AddNewDevice %d provisionSuccess", provisionAddress);
            SigNodeModel *model = [SigDataSource.share getNodeWithAddress:provisionAddress];
            if (model) {
                NSLog(@"TelinkBtSig AddNewDevice node_adr %d", model.nodeInfo.node_adr);
            }
        } keyBindSuccess:^(NSString *identify, UInt16 address) {
            NSLog(@"TelinkBtSig AddNewDevice %d keyBindSuccess", provisionAddress);

            NSMutableDictionary *event = [[NSMutableDictionary alloc] init];
            SigNodeModel *model = [SigDataSource.share getNodeWithAddress:address];
            VC_node_info_t node_info = model.nodeInfo;
            int VC_node_info_t_length = sizeof(VC_node_info_t);
            char nodeInfoArray[VC_node_info_t_length];

            // TODO: 是否需要：把大端模式的数字Number转为本机数据存放模式比如 UInt16 address = CFSwapInt16BigToHost(node.address);

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
        NSString *macAddress = [[node objectForKey:@"macAddress"] stringByReplacingOccurrencesOfString:@":" withString:@""];
        BOOL isDirect = [macAddress isEqualToString:[SigDataSource.share getCurrentConnectedNode].macAddress];
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

RCT_EXPORT_METHOD(getTime:(NSInteger)meshAddress relayTimes:(NSInteger)relayTimes resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
//     NSLog(@"getTime");
//     NSArray *value = [NSArray arrayWithObject:[NSNumber numberWithInteger:relayTimes]];
//     [[BTCentralManager shareBTCentralManager] sendCommand:0xE8 meshAddress:meshAddress value:value];
//     _resolvedateBlock = resolve;
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

RCT_EXPORT_METHOD(getAlarm:(NSInteger)meshAddress relayTimes:(NSInteger)relayTimes alarmId:(NSInteger)alarmId resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
//     NSLog(@"getAlarm");
//     //    NSArray *value = [NSArray arrayWithObjects:[NSNumber numberWithInteger:relayTimes],[NSNumber numberWithInteger:alarmId],nil];
//     //    [[BTCentralManager shareBTCentralManager] sendCommand:0xE6 meshAddress:meshAddress value:value];
//     //    _resolvesegetAlarm = resolve;
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