#import "RNBtSigTelink.h"
//#import "RCTLog.h"
#import <SigMeshOC/SDKLibCommand.h>
#import <SigMeshOC/Bluetooth.h>
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

@implementation deviceModel
//- (BOOL)isEqual:(id)object{
//    if ([object isKindOfClass:[deviceModel class]]) {
//        return [_peripheral.identifier.UUIDString isEqualToString:((deviceModel *)object).peripheral.identifier.UUIDString];
//    } else {
//        return NO;
//    }
//}
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
}

RCT_EXPORT_MODULE()

- (NSArray<NSString *> *)supportedEvents
{
    return @[
               @"bluetoothEnabled",
               @"bluetoothDisabled",
               @"systemLocationEnabled",
               @"systemLocationDisabled",
               @"serviceConnected",
               @"serviceDisconnected",
               @"notificationOnlineStatus",
               @"notificationGetDeviceState",
               @"deviceStatusConnecting",
               @"deviceStatusConnected",
               @"deviceStatusLogining",
               @"deviceStatusLogin",
               @"deviceStatusLogout",
               @"deviceStatusErrorAndroidN",
               @"deviceStatusUpdateMeshCompleted",
               @"deviceStatusUpdatingMesh",
               @"deviceStatusUpdateMeshFailure",
               @"deviceStatusUpdateAllMeshCompleted",
               @"deviceStatusGetLtkCompleted",
               @"deviceStatusGetLtkFailure",
               @"deviceStatusMeshOffline",
               @"deviceStatusMeshScanCompleted",
               @"deviceStatusMeshScanTimeout",
               @"deviceStatusOtaCompleted",
               @"deviceStatusOtaFailure",
               @"deviceStatusOtaProgress",
               @"deviceStatusGetFirmwareCompleted",
               @"deviceStatusGetFirmwareFailure",
               @"deviceStatusDeleteCompleted",
               @"deviceStatusDeleteFailure",
               @"leScan",
               @"leScanCompleted",
               @"leScanTimeout",
               @"meshOffline",
               @"notificationDataGetVersion",
               @"notificationDataGetMeshOtaProgress",
               @"notificationDataGetOtaState",
               @"notificationDataSetOtaModeRes",
               @"deviceStatusOtaMasterProgress",
               @"deviceStatusOtaMasterComplete",
               @"deviceStatusOtaMasterFail",
           ];
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

    //初始化SDK
    [SDKLibCommand startMeshSDK];

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
     NSLog(@"doDestroy");
 }

// RCT_EXPORT_METHOD(doResume) {
//     NSLog(@"doResume");
//     self.manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
// }

 RCT_EXPORT_METHOD(enableBluetooth) {
     NSLog(@"enableBluetooth");
 }

 RCT_EXPORT_METHOD(notModeAutoConnectMesh:(RCTPromiseResolveBlock)resolve
                   rejecter:(RCTPromiseRejectBlock)reject) {
     resolve(@YES);
     NSLog(@"notModeAutoConnectMesh");
 }

 RCT_EXPORT_METHOD(autoConnect:(NSString *)userMeshName userMeshPwd:(NSString *)userMeshPwd otaMac:(NSString *)otaMac)
 {
//     NSLog(@"meshName==========%@", userMeshName);
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
     NSLog(@"idleMode");
 }

RCT_EXPORT_METHOD(startScan:(NSInteger)timeoutSeconds isSingleNode:(BOOL)isSingleNode) {
    self.allDevices = [NSMutableArray array];
    __weak typeof(self) weakSelf = self;
    [Bluetooth.share cancelAllConnecttionWithComplete:^{
        [self sendEventWithName:@"deviceStatusLogout" body:nil];
        [Bluetooth.share setBleScanNewDeviceCallBack:^(CBPeripheral *peripheral, BOOL provisioned, SigScanRspModel *scanRspModel) {
            if (provisioned) {
                deviceModel *device = [[deviceModel alloc] init];
                device.peripheral = peripheral;
                device.macAddress = scanRspModel.macAddress;
                if (![weakSelf.allDevices containsObject:device]) {
                    [weakSelf.allDevices addObject:device];
                    NSLog(@"ScanNewDevice macAddress = %@", scanRspModel.macAddress);

                    NSMutableDictionary *event = [[NSMutableDictionary alloc] init];
//                    [event setObject:scanRspModel.nodeIdentityData forKey:@"deviceName"];
//                    [event setObject:[NSString stringWithFormat:@"%@", scanRspModel.networkIDData] forKey:@"meshName"];
//                    [event setObject:[NSNumber numberWithInt:scanRspModel.address] forKey:@"meshAddress"];
                    [event setObject:[NSString stringWithFormat:@"%@", scanRspModel.macAddress] forKey:@"macAddress"];
//                    [event setObject:[NSNumber numberWithInt:scanRspModel.uuid] forKey:@"meshUUID"];
                    [event setObject:[NSNumber numberWithInt:scanRspModel.PID] forKey:@"productUUID"];
//                    [event setObject:[NSNumber numberWithInt:scanRspModel.CID] forKey:@"status"];
                    [self sendEventWithName:@"leScan" body:event];
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

- (void)scanFinish{
    [Bluetooth.share setNormalState];
    [Bluetooth.share stopScan];
}

 RCT_EXPORT_METHOD(sendCommand:(NSInteger)opcode meshAddress:(NSInteger)meshAddress value:(NSArray *) value immediate :(BOOL)immediate) {
//     NSArray *arr = [kCentralManager devArrs];
//     for (BTDevItem *item in arr) {
//         NSLog(@"sendCommand meshAddress = %d", item.u_DevAdress);
//     }
//     [[BTCentralManager shareBTCentralManager] sendCommand:opcode meshAddress:meshAddress value:value];
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
//     NSArray *arr = [kCentralManager devArrs];
//     for (BTDevItem *dev in arr) {
//         if (dev.u_DevAdress == meshAddress) {
//             if (value == 1) {
//                 [[BTCentralManager shareBTCentralManager] turnOffCertainLightWithAddress:dev.u_DevAdress];
//             }
//             else {
//                 [[BTCentralManager shareBTCentralManager] turnOnCertainLightWithAddress:dev.u_DevAdress];
//             }
//         }
//     }
 }

 RCT_EXPORT_METHOD(changeBrightness:(NSString *)meshAddress value:(NSInteger)value) {
//     for (DeviceModel *dev in self.devArray) {
//         if ([[NSString stringWithFormat:@"%x", dev.u_DevAdress] isEqual:meshAddress]) {
//             NSLog(@"brightness====%ld", dev.brightness);
//             if (dev.stata == LightStataTypeOff && value > 0) {
//                 [kCentralManager turnOnCertainLightWithAddress:dev.u_DevAdress];
//             } else if (dev.stata == LightStataTypeOn && value == 0) {
//                 [kCentralManager turnOffCertainLightWithAddress:dev.u_DevAdress];
//                 return;
//             }
//             [kCentralManager setLightOrGroupLumWithDestinateAddress:dev.u_DevAdress WithLum:value];
//         }
//     }
 }

 RCT_EXPORT_METHOD(changeTemperatur:(NSString *)meshAddress value:(float)value) {
//     for (DeviceModel *dev in self.devArray) {
//         if ([[NSString stringWithFormat:@"%x", dev.u_DevAdress] isEqual:meshAddress]) {
//             [kCentralManager setCTOfLightWithDestinationAddress:dev.u_DevAdress AndCT:value];
//         }
//     }
 }

 RCT_EXPORT_METHOD(changeColor:(NSString *)meshAddress value:(NSInteger)value) {
//     //NSLog(@"value4=====%ld", value);
//     //[[BTCentralManager shareBTCentralManager] setLightOrGroupRGBWithDestinateAddress:self.selData.u_DevAdress WithColorR:red WithColorG:green WithB:blue];
 }

 RCT_EXPORT_METHOD(configNode:(NSDictionary *)node cfg:(NSDictionary *)cfg resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
//     self.cfg = [[NSMutableDictionary alloc] initWithDictionary:cfg];
//     self.node = [[NSMutableDictionary alloc] initWithDictionary:node];
//     self.configNode = YES;
//     NSLog(@"configNode node = %@", [node objectForKey:@"macAddress"]);
//     for (BTDevItem *bt in self.BTDevArray) {
//         if ([[NSString stringWithFormat:@"%x", bt.u_Mac] isEqualToString:[node objectForKey:@"macAddress"]]) {
//             [kCentralManager connectWithItem:bt];
//         }
//     }
//     NSLog(@"configNode node = %d", [[node objectForKey:@"meshAddress"] intValue]);

//     _resolveBlock = resolve;
//     _rejectBlock = reject;
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
