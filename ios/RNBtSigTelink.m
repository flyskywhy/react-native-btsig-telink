#import "RNBtSigTelink.h"

@implementation deviceModel
- (BOOL)isEqual:(id)object{
    if ([object isKindOfClass:[deviceModel class]]) {
        return [_peripheral.identifier.UUIDString isEqualToString:((deviceModel *)object).peripheral.identifier.UUIDString];
    } else {
        return NO;
    }
}
@end

@implementation TelinkBtSig {
    BOOL mSetNodeGroupAddrToDel;
    NSInteger mMeshAddressOfApp;
    NSInteger mSetNodeGroupMeshAddr;
    NSInteger mSetNodeGroupAddrGroupAddr;
    NSArray *mSetNodeGroupAddrEleIds;
    NSInteger mSetNodeGroupAddrEleIdsIndex;
    RCTPromiseResolveBlock mSetNodeGroupAddrResolve;
    RCTPromiseRejectBlock mSetNodeGroupAddrReject;
    RCTPromiseResolveBlock mSendCommandRspResolve;
    RCTPromiseRejectBlock mSendCommandRspReject;

    responseAllMessageBlock onVendorResponse;
    responseTelinkOnlineStatusMessageBlock onOnlineStatusNotify;
    responseGenericOnOffStatusMessageBlock onGetOnOffNotify;
    responseGenericLevelStatusMessageBlock onGetLevelNotify;
    responseLightLightnessStatusMessageBlock onGetLightnessNotify;
    responseLightCTLTemperatureStatusMessageBlock onGetTempNotify;
    responseLightCTLStatusMessageBlock onGetCtlNotify;
    responseFirmwareInformationStatusMessageBlock onGetFirmwareInfo;

    responseConfigModelSubscriptionStatusMessageBlock onGetModelSubscription;
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
    NSMutableData *data = [[NSMutableData alloc] init];
    [array enumerateObjectsUsingBlock:^(NSNumber* number, NSUInteger index, BOOL* stop) {
        uint8_t tmp = number.unsignedCharValue;
        [data appendBytes:(void *)(&tmp)length:1];
    }];

    return data;
}

- (NSMutableArray *)byteData2Array:(NSData *)data {
    NSMutableArray *array = [[NSMutableArray alloc] init];
    [data enumerateByteRangesUsingBlock:^(const void *bytes, NSRange byteRange, BOOL *stop) {
        unsigned char *dataBytes = (unsigned char*)bytes;
        for (NSInteger i = 0; i < byteRange.length; i++) {
            [array addObject:[NSNumber numberWithUnsignedChar:dataBytes[i]]];
        }
    }];

    return array;
}

// ref to configData() in SigDataSource.m
- (void)initMesh:(NSString *)netKeyJS appKey:(NSString *)appKeyJS meshAddressOfApp:(NSInteger)meshAddressOfApp devices:(NSArray *)devices provisionerSno:(NSInteger)provisionerSno provisionerIvIndex:(NSInteger)provisionerIvIndex isReplaceMeshSetting:(BOOL)isReplaceMeshSetting {
    // 初始化当前手机的唯一标识 UUID ，卸载重新安装才会重新生成
    NSString *provisionerUUID = [SigDataSource.share getCurrentProvisionerUUID];
    if (provisionerUUID == nil) {
        [SigDataSource.share saveCurrentProvisionerUUID:[LibTools convertDataToHexStr:[LibTools initMeshUUID]]];
    }

    // Even exist mesh.json, still init mesh data from JS to create a new one (saveLocationData below), because mesh.json is used by telink sdk, but actually react native APP save data in JS, so react-native-btsig-telink just mantain a smallest and enough mash.json that telink sdk can run on
    NSString *timestamp = [LibTools getNowTimeStringOfJson];
    // 1. netKeys
    SigNetkeyModel *netkey = [[SigNetkeyModel alloc] init];
    netkey.index = 0;
    netkey.phase = 0;
    netkey.timestamp = timestamp;
    netkey.oldKey = @"00000000000000000000000000000000";
    netkey.key = [LibTools convertDataToHexStr:[netKeyJS dataUsingEncoding:NSUTF8StringEncoding]];
    netkey.name = @"Default NetKey";
    netkey.minSecurity = @"secure";
    SigDataSource.share.curNetkeyModel = nil;
    [SigDataSource.share.netKeys removeAllObjects];
    [SigDataSource.share.netKeys addObject:netkey];

    // 2. appKeys
    SigAppkeyModel *appkey = [[SigAppkeyModel alloc] init];
    appkey.oldKey = @"00000000000000000000000000000000";
    appkey.key = [LibTools convertDataToHexStr:[appKeyJS dataUsingEncoding:NSUTF8StringEncoding]];
    appkey.name = @"Default AppKey";
    appkey.boundNetKey = 0;
    appkey.index = 0;
    SigDataSource.share.curAppkeyModel = nil;
    [SigDataSource.share.appKeys removeAllObjects];
    [SigDataSource.share.appKeys addObject:appkey];

    // 3. provisioners
    SigProvisionerModel *provisioner = [[SigProvisionerModel alloc] initWithExistProvisionerMaxHighAddressUnicast:0 andProvisionerUUID:[SigDataSource.share getCurrentProvisionerUUID]];
    if (isReplaceMeshSetting) {
//        provisioner = SigDataSource.share.curProvisionerModel;
    } else {
        [SigDataSource.share.provisioners removeAllObjects];
        [SigDataSource.share.provisioners addObject:provisioner];
    }

    // 4. add new provisioner (or old provisioner if isReplaceMeshSetting) to nodes, ref to addLocationNodeWithProvisioner() in SigDataSource.m
    SigDataSource.share.curNodes = nil;
    SigNodeModel *node = [[SigNodeModel alloc] init];

    [SigDataSource.share.nodes removeAllObjects];

    // init default data
    node.UUID = provisioner.UUID;
    node.secureNetworkBeacon = YES;
    node.defaultTTL = TTL_DEFAULT;
    node.features.proxyFeature = SigNodeFeaturesState_notSupported;
    node.features.friendFeature = SigNodeFeaturesState_notEnabled;
    node.features.relayFeature = SigNodeFeaturesState_notSupported;
    node.relayRetransmit.relayRetransmitCount = 5;
    node.relayRetransmit.relayRetransmitIntervalSteps = 2;
    node.unicastAddress = [NSString stringWithFormat:@"%04X",(UInt16)meshAddressOfApp];
    node.name = @"Telink iOS provisioner node";
    node.cid = @"0211";
    node.pid = @"0100";
    node.vid = @"0100";
    node.crpl = @"0100";

    // 添加本地节点的 element
    NSMutableArray *elements = [NSMutableArray array];
    SigElementModel *element = [[SigElementModel alloc] init];
    element.name = @"Primary Element";
    element.location = @"0000";
    element.index = 0;
    NSMutableArray *models = [NSMutableArray array];
//        NSArray *defaultModelIDs = @[@"0000",@"0001",@"0002",@"0003",@"0005",@"FE00",@"FE01",@"FE02",@"FE03",@"FF00",@"FF01",@"1202",@"1001",@"1003",@"1005",@"1008",@"1205",@"1208",@"1302",@"1305",@"1309",@"1311",@"1015",@"00010211"];
    NSArray *defaultModelIDs = @[@"0000",@"0001"];
    for (NSString *modelID in defaultModelIDs) {
        SigModelIDModel *modelIDModel = [[SigModelIDModel alloc] init];
        modelIDModel.modelId = modelID;
        modelIDModel.subscribe = [NSMutableArray array];
        modelIDModel.bind = [NSMutableArray arrayWithArray:@[@(0)]];
        [models addObject:modelIDModel];
    }
    element.models = models;
    element.parentNodeAddress = node.address;
    [elements addObject:element];
    node.elements = elements;

    NSData *devicekeyData = [LibTools createRandomDataWithLength:16];
    node.deviceKey = [LibTools convertDataToHexStr:devicekeyData];
    SigNodeKeyModel *nodeAppkey = [[SigNodeKeyModel alloc] init];
    nodeAppkey.index = SigDataSource.share.curAppkeyModel.index;
    if (![node.appKeys containsObject:nodeAppkey]) {
        [node.appKeys addObject:nodeAppkey];
    }
    SigNodeKeyModel *nodeNetkey = [[SigNodeKeyModel alloc] init];
    nodeNetkey.index = SigDataSource.share.curNetkeyModel.index;
    if (![node.netKeys containsObject:nodeNetkey]) {
        [node.netKeys addObject:nodeNetkey];
    }

    [SigDataSource.share.nodes addObject:node];

    // 5. add default group
    SigGroupModel *group = [[SigGroupModel alloc] init];
    [SigDataSource.share.groups removeAllObjects];
    group.address = [NSString stringWithFormat:@"%04X",0xffff];
    group.parentAddress = [NSString stringWithFormat:@"%04X",0];
    group.name = @"All";
    [SigDataSource.share.groups addObject:group];

    [SigDataSource.share.scenes removeAllObjects];
    [SigDataSource.share.encryptedArray removeAllObjects];

    SigDataSource.share.meshUUID = netkey.key;
    SigDataSource.share.schema = @"http://json-schema.org/draft-04/schema#";
    SigDataSource.share.jsonFormatID = @"http://www.bluetooth.com/specifications/assigned-numbers/mesh-profile/cdb-schema.json#";
    SigDataSource.share.meshName = @"Telink-Sig-Mesh";
//    SigDataSource.share.version = LibTools.getSDKVersion;
    SigDataSource.share.version = @"1.0.0";
    SigDataSource.share.timestamp = timestamp;

    SigDataSource.share.ivIndex = [NSString stringWithFormat:@"%08lX",(long)provisionerIvIndex];

    // set devices, ref to provisionSuccess() in SigProvisioningManager.m
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

        SigNetkeyModel *netkeyCur = [SigDataSource.share curNetkeyModel];
        SigNodeKeyModel *nodeNetkey = [[SigNodeKeyModel alloc] init];
        nodeNetkey.index = netkeyCur.index;
        if (![model.netKeys containsObject:nodeNetkey]) {
            [model.netKeys addObject:nodeNetkey];
        }

        model.deviceKey = [LibTools convertDataToHexStr:[self byteArray2Data:device[@"dhmKey"]]];
        model.peripheralUUID = nil;
        model.macAddress = [device[@"macAddress"] stringByReplacingOccurrencesOfString:@":" withString:@""];
        model.UUID = @"";

        NSData *nodeInfo = [self byteArray2Data:device[@"nodeInfo"]];
        NSData *cpsData = [nodeInfo subdataWithRange:NSMakeRange(22, nodeInfo.length - 22)];
        uint8_t page = 0;
        NSMutableData *sigPage0 = [[NSMutableData alloc] init];;
        [sigPage0 appendBytes:(void *)(&page) length:1];
        [sigPage0 appendData:cpsData];
        model.compositionData = [[SigPage0 alloc] initWithParameters:sigPage0];

//        NSLog(@"TelinkBtSig sigmodel %@", [model getDictionaryOfSigNodeModel]);

//        [SigDataSource.share addAndSaveNodeToMeshNetworkWithDeviceModel:model];
        [SigDataSource.share.nodes addObject:model];
    }

    NSLog(@"TelinkBtSig create mesh.json success");
    [SigDataSource.share saveLocationData];

//    NSLog(@"TelinkBtSig DataSource %@", [SigDataSource.share getFormatDictionaryFromDataSource]);
//    NSLog(@"TelinkBtSig currentProvisionerUUID %@", [SigDataSource.share getCurrentProvisionerUUID]);

    if (isReplaceMeshSetting) {
        [SigDataSource.share setLocationSno:(UInt32)provisionerSno];
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:@((UInt32)provisionerSno) forKey:kCurrenProvisionerSno_key];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];

    // check provisioner
    [SigDataSource.share checkExistLocationProvisioner];

    // 在 SigMeshOCDemo/SigMeshOCDemo/ViewController/Setting/Share/ShareInVC.m 示范
    // 扫描别人分享来的数据后需要 scanList removeAllObjects ，实际发现不清空也没问题，然后又发现
    // 这里每次启动 APP 都不加载缓存实际上也算是清空 scanList 也能正常使用，那保险起见就把下面语句注释了
    // init SigScanRspModel list
//    [SigDataSource.share loadScanList];
}

// ref to startMeshSDK() in SDKLibCommand.m
- (void)startMeshSDK:(NSString *)netKey appKey:(NSString *)appKey meshAddressOfApp:(NSInteger)meshAddressOfApp devices:(NSArray *)devices provisionerSno:(NSInteger)provisionerSno provisionerIvIndex:(NSInteger)provisionerIvIndex {
    // 初始化本地存储的 mesh 网络数据
    [self initMesh:netKey appKey:appKey meshAddressOfApp:meshAddressOfApp devices:devices provisionerSno:provisionerSno provisionerIvIndex:provisionerIvIndex isReplaceMeshSetting:false];

    // 初始化 ECC 算法的公钥( iphone 6s 耗时 0.6~1.3 秒，放到背景线程调用)
    [SigECCEncryptHelper.share performSelectorInBackground:@selector(eccInit) withObject:nil];

    // 初始化添加设备的参数
    [SigAddDeviceManager.share setNeedDisconnectBetweenProvisionToKeyBind:NO];

    // 初始化蓝牙
    [[SigBluetooth share] bleInit:^(CBCentralManager * _Nonnull central) {
        TeLogInfo(@"finish init SigBluetooth.");
        [SigMeshLib share];

//        SigBluetooth.share.delegate = self;
    }];

    // 默认为 NO ，连接速度更加快。设置为 YES ，表示扫描到的设备必须包含 MacAddress ，有些客户在添加流程需要通过 MacAddress 获取三元组信息，需要使用 YES
//    [SigBluetooth.share setWaitScanRseponseEnabel:YES];
}

RCT_EXPORT_METHOD(doInit:(NSString *)netKey appKey:(NSString *)appKey meshAddressOfApp:(NSInteger)meshAddressOfApp devices:(NSArray *)devices provisionerSno:(NSInteger)provisionerSno provisionerIvIndex:(NSInteger)provisionerIvIndex extendBearerMode:(NSInteger)extendBearerMode) {
    self->mMeshAddressOfApp = meshAddressOfApp;
    self.allowSendLogoutWhenDisconnect = YES;
    self.connectMeshAddress = -1;

    SigDataSource.share.telinkExtendBearerMode = extendBearerMode;
    if (extendBearerMode == SigTelinkExtendBearerMode_noExtend) {
        SigDataSource.share.defaultUnsegmentedMessageLowerTransportPDUMaxLength = kUnsegmentedMessageLowerTransportPDUMaxLength;
    } else {
        // 这里 kDLEUnsegmentLength = 229 与 Android 版本中的
        // UNSEGMENTED_ACCESS_PAYLOAD_MAX_LENGTH_LONG = 225
        // 是能对应起来的，因为 Android 版本中可以看到 Transport 和 PAYLOAD 都是差 4 个字节
        SigDataSource.share.defaultUnsegmentedMessageLowerTransportPDUMaxLength = kDLEUnsegmentLength;
    }

    SigDataSource.share.fipsP256EllipticCurve = SigFipsP256EllipticCurve_auto;

    // 使用 index.native.js 中的 setLogLevel 会更方便
    // 客户开发到后期， APP 稳定后可以不集成该功能，且上架最好关闭 log 保存功能。(客户发送 iTunes 中的日志文件“TelinkSDKDebugLogData”给泰凌微即可)
//    [SigLogger.share setSDKLogLevel:SigLogLevelDebug];
//    [SigLogger.share setSDKLogLevel:SigLogLevelAll];

    /* 初始化 SDK */
    // 1. 一个 provisioner 分配的地址范围，默认为 0x400
    SigDataSource.share.defaultAllocatedUnicastRangeHighAddress = kAllocatedUnicastRangeHighAddress;
    // 2. mesh 网络的 sequenceNumber 步长，默认为128
    SigDataSource.share.defaultSequenceNumberIncrement = kSequenceNumberIncrement;
//    SigDataSource.share.defaultSequenceNumberIncrement = 16;
    // 3. 启动SDK
//    [SDKLibCommand startMeshSDK];
     [self startMeshSDK:netKey appKey:appKey meshAddressOfApp:meshAddressOfApp devices:devices provisionerSno:provisionerSno provisionerIvIndex:provisionerIvIndex];

    // telink demo 示范了下面添加自定义设备信息以支持 fast bind （也就是 Android 代码中说的
    // defaultbound），但实际上对我们 react native APP 来说当然是应该将自定义代码实现在 JS
    // 中，以避免开发者 hack 修改 node_modules/react-native-btsig-telink 中的内容。
    // 因此，相应的 JS 添加自定义设备信息以支持 fast bind 的方法是在 index.native.js 中的
    // configNode() 里传入需要 fast bind 的自定义设备的 cpsData 数据
    //
    // 另，为支持 fast provision ，本文件最终还是提供了 add2defaultNodeInfos() 供 JS 调用
    //
    // (可选) SDK 默认实现了 PID 为 1 和 7 的设备的 fast bind 功能，其它类型的设备可通过以下接口添加该类型设备默认的 nodeInfo 以实现 fast bind 功能
    // 示范代码：添加 PID=8 ， composition data=TemByte 的数据到 SigDataSource.share.defaultNodeInfos
//    DeviceTypeModel *model = [[DeviceTypeModel alloc] initWithCID:kCompanyID PID:8];
//    static Byte TemByte[] = {(Byte) 0x11, (Byte) 0x02, (Byte) 0x01, (Byte) 0x00, (Byte) 0x32, (Byte) 0x37, (Byte) 0x69, (Byte) 0x00, (Byte) 0x07, (Byte) 0x00, (Byte) 0x00, (Byte) 0x00, (Byte) 0x19, (Byte) 0x01, (Byte) 0x00, (Byte) 0x00, (Byte) 0x02, (Byte) 0x00, (Byte) 0x03, (Byte) 0x00, (Byte) 0x04, (Byte) 0x00, (Byte) 0x05, (Byte) 0x00, (Byte) 0x00, (Byte) 0xfe, (Byte) 0x01, (Byte) 0xfe, (Byte) 0x02, (Byte) 0xfe, (Byte) 0x00, (Byte) 0xff, (Byte) 0x01, (Byte) 0xff, (Byte) 0x00, (Byte) 0x12, (Byte) 0x01, (Byte) 0x12, (Byte) 0x00, (Byte) 0x10, (Byte) 0x02, (Byte) 0x10, (Byte) 0x04, (Byte) 0x10, (Byte) 0x06, (Byte) 0x10, (Byte) 0x07, (Byte) 0x10, (Byte) 0x03, (Byte) 0x12, (Byte) 0x04, (Byte) 0x12, (Byte) 0x06, (Byte) 0x12, (Byte) 0x07, (Byte) 0x12, (Byte) 0x00, (Byte) 0x13, (Byte) 0x01, (Byte) 0x13, (Byte) 0x03, (Byte) 0x13, (Byte) 0x04, (Byte) 0x13, (Byte) 0x11, (Byte) 0x02, (Byte) 0x00, (Byte) 0x00, (Byte) 0x00, (Byte) 0x00, (Byte) 0x02, (Byte) 0x00, (Byte) 0x02, (Byte) 0x10, (Byte) 0x06, (Byte) 0x13};
//    NSData *nodeInfoData = [NSData dataWithBytes:TemByte length:76];
//    [model setCompositionData:nodeInfoData];
//    [SigDataSource.share.defaultNodeInfos addObject:model];

    // (可选) SDK 默认 publish 周期为 20 秒，通过修改可以修改 SDK 的默认 publish 参数，或者客户自行实现 publish 检测机制。
//    SigPeriodModel *periodModel = [[SigPeriodModel alloc] init];
//    periodModel.numberOfSteps = kPublishIntervalOfDemo;
//    periodModel.numberOfSteps = 5; // 整形，范围 0x01~0x3F
//    periodModel.resolution = [LibTools getSigStepResolutionInMillisecondsOfJson:SigStepResolution_seconds];
//    SigDataSource.share.defaultPublishPeriodModel = periodModel;

    SigMeshLib.share.transmissionTimerInterval = 0.600;
//    SigDataSource.share.needPublishTimeModel = NO;

    // (可选) v3.3.3 新增配置项
//    SigDataSource.share.defaultReliableIntervalOfLPN = kSDKLibCommandTimeout;
//    SigDataSource.share.defaultReliableIntervalOfNotLPN = kSDKLibCommandTimeout * 2;

     __weak typeof(self) weakSelf = self;

    onVendorResponse = ^(UInt16 source, UInt16 destination, SigMeshMessage * _Nonnull responseMessage) {

        UInt32 opcode = responseMessage.opCode;
//        NSLog(@"TelinkBtSig onVendorResponse opcode=0x%x, parameters=%@", opcode, responseMessage.parameters);

        // convert opcode -> opcodeJs e.g. 0xE31102 -> 0x0211E3
        UInt32 opcodeJs = ((opcode >> 16) & 0x0000ff) | (opcode & 0x00ff00) | ((opcode << 16) & 0xff0000);
//        NSLog(@"TelinkBtSig onVendorResponse opcode to JS is 0x%x", opcodeJs);

        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInt:source] forKey:@"meshAddress"];
        [dict setObject:[NSNumber numberWithInt:opcodeJs] forKey:@"opcode"];
        [dict setObject:(NSArray *)[weakSelf byteData2Array:responseMessage.parameters] forKey:@"params"];
        [weakSelf sendEventWithName:@"notificationVendorResponse" body:dict];
    };

    self.onlineStatusMessages = [NSMutableArray array];

    onOnlineStatusNotify = ^(UInt16 source, UInt16 destination, SigTelinkOnlineStatusMessage * _Nonnull responseMessage) {
        TeLogDebug(@"onOnlineStatusNotify");
        SigTelinkOnlineStatusMessage *message = [weakSelf getOnlineStatusMessage:responseMessage.address];

        if (message != nil) {
            if (message.state == responseMessage.state && message.brightness == responseMessage.brightness && message.temperature == responseMessage.temperature) {
                return;
            } else {
                message.state = responseMessage.state;
                message.brightness = responseMessage.brightness;
                message.temperature = responseMessage.temperature;
            }
        } else {
            [weakSelf.onlineStatusMessages addObject:responseMessage];
        }

        NSMutableArray *array = [[NSMutableArray alloc] init];
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInt:responseMessage.address] forKey:@"meshAddress"];
        [dict setObject:[NSNumber numberWithInt:responseMessage.brightness] forKey:@"brightness"];
        [dict setObject:[NSNumber numberWithInt:responseMessage.temperature] forKey:@"colorTemp"];
        int connectionStatus;
        if (responseMessage.state == DeviceStateOutOfLine) {
            connectionStatus = -1;
        } else {
            if (responseMessage.brightness == 0) {
                connectionStatus = 0;
            } else {
                connectionStatus = 1;
            }
        }
        [dict setObject:[NSNumber numberWithInt:connectionStatus] forKey:@"status"];
        [array addObject:dict];
        [weakSelf sendEventWithName:@"notificationOnlineStatus" body:array];
    };

    onGetOnOffNotify = ^(UInt16 source, UInt16 destination, SigGenericOnOffStatus * _Nonnull responseMessage) {
        NSLog(@"TelinkBtSig onGetOnOffNotify");
        BOOL isOn = responseMessage.isAcknowledged ? responseMessage.targetState : responseMessage.isOn;
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInt:source] forKey:@"meshAddress"];
        [dict setObject:[NSNumber numberWithInt:isOn ? 1 : 0] forKey:@"onOff"];
        [weakSelf sendEventWithName:@"notificationDataGetOnOff" body:dict];
    };

    onGetLevelNotify = ^(UInt16 source, UInt16 destination, SigGenericLevelStatus * _Nonnull responseMessage) {
        NSLog(@"TelinkBtSig onGetLevelNotify");
        UInt16 level = responseMessage.isAcknowledged ? responseMessage.targetLevel : responseMessage.level;
        UInt8 brightness = [SigHelper.share getUInt8LumFromSInt16Level:level];
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInt:source] forKey:@"meshAddress"];
        [dict setObject:[NSNumber numberWithInt:brightness] forKey:@"brightness"];
        [weakSelf sendEventWithName:@"notificationDataGetLevel" body:dict];
    };

    onGetLightnessNotify = ^(UInt16 source, UInt16 destination, SigLightLightnessStatus * _Nonnull responseMessage) {
        NSLog(@"TelinkBtSig onGetLightnessNotify");
        UInt16 lightness = responseMessage.isAcknowledged ? responseMessage.targetLightness : responseMessage.presentLightness;
        UInt8 lum = [SigHelper.share getUInt8LumFromUint16Lightness:lightness];

        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInt:source] forKey:@"meshAddress"];
        [dict setObject:[NSNumber numberWithInt:lum] forKey:@"brightness"];
        [weakSelf sendEventWithName:@"notificationDataGetLightness" body:dict];
    };

    onGetCtlNotify = ^(UInt16 source, UInt16 destination, SigLightCTLStatus * _Nonnull responseMessage) {
        NSLog(@"TelinkBtSig onGetCtlNotify");
        UInt16 lightness = responseMessage.isAcknowledged ? responseMessage.targetCTLLightness : responseMessage.presentCTLLightness;
        UInt8 lum = [SigHelper.share getUInt8LumFromUint16Lightness:lightness];
        UInt16 temp = responseMessage.isAcknowledged ? responseMessage.targetCTLTemperature : responseMessage.presentCTLTemperature;
        UInt8 colorTemp = [SigHelper.share getUInt8Temperature100FromUint16Temperature:temp];
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInt:source] forKey:@"meshAddress"];
        [dict setObject:[NSNumber numberWithInt:lum] forKey:@"brightness"];
        [dict setObject:[NSNumber numberWithInt:colorTemp] forKey:@"colorTemp"];
        [weakSelf sendEventWithName:@"notificationDataGetCtl" body:dict];
    };

    onGetTempNotify = ^(UInt16 source, UInt16 destination, SigLightCTLTemperatureStatus * _Nonnull responseMessage) {
        NSLog(@"TelinkBtSig onGetTemp");
        UInt16 temp = responseMessage.isAcknowledged ? responseMessage.targetCTLTemperature : responseMessage.presentCTLTemperature;
        UInt8 colorTemp = [SigHelper.share getUInt8Temperature100FromUint16Temperature:temp];
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInt:source] forKey:@"meshAddress"];
        [dict setObject:[NSNumber numberWithInt:colorTemp] forKey:@"colorTemp"];
        [weakSelf sendEventWithName:@"notificationDataGetTemp" body:dict];
    };

    onGetFirmwareInfo = ^(UInt16 source,UInt16 destination,SigFirmwareUpdateInformationStatus *responseMessage) {
        NSLog(@"TelinkBtSig onGetFirmwareInfo");
        SigFirmwareInformationEntryModel *firstEntry = [responseMessage.firmwareInformationList firstObject];
        if (firstEntry == nil) {
            return;
        }
        // responseMessage.firmwareInformationList.firstObject.currentFirmwareID.length = 4: 2 bytes pid(设备类型) + 2 bytes vid(版本id)
        if (firstEntry.currentFirmwareID.length < 4) {
            return;
        }
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInt:source] forKey:@"meshAddress"];
        NSData *data = [firstEntry.currentFirmwareID subdataWithRange:NSMakeRange(2, 2)];
        [dict setObject:[[NSString alloc] initWithBytes:data.bytes length:data.length encoding:NSUTF8StringEncoding] forKey:@"version"];
        [weakSelf sendEventWithName:@"notificationDataGetVersion" body:dict];
    };

    onGetModelSubscription = ^(UInt16 source, UInt16 destination, SigConfigModelSubscriptionStatus * _Nonnull responseMessage) {
        // TODO: weakSelf will cause `Thread 1: EXC_BAD_ACCESS (code=1, addreess=)`
        // crash, maybe should consider move these logic into index.native.js
        if (self->mSetNodeGroupAddrResolve != nil) {
            if (responseMessage.status == SigConfigMessageStatus_success) {
                NSLog(@"%x sub group address: %x", source, responseMessage.address);
                self->mSetNodeGroupAddrEleIdsIndex++;
                [self setNextModelGroupAddr];
            } else {
                if (self->mSetNodeGroupAddrReject != nil) {
                    self->mSetNodeGroupAddrReject(@"setSubscription", @"setSubscription grouping status fail!", nil);
                }
                self->mSetNodeGroupAddrReject = nil;
                NSLog(@"set group sub error");
            }
        }
    };

    SigDataSource.share.delegate = self;
    SigBearer.share.dataDelegate = self;
    SigMeshLib.share.delegateForDeveloper = self;

    // only telinkApiGetOnlineStatueFromUUIDWithResponseMaxCount() is called at least once
    // after bearerDidOpen below, then discoverOutlineNodeCallback() can work normally
    [SigPublishManager.share setDiscoverOutlineNodeCallback:^(NSNumber * _Nonnull unicastAddress) {
        TeLogVerbose(@"setDiscoverOutlineNodeCallback %@", unicastAddress);
        NSMutableArray *array = [[NSMutableArray alloc] init];
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:unicastAddress forKey:@"meshAddress"];
        [dict setObject:[NSNumber numberWithInt:-1] forKey:@"status"];
        [array addObject:dict];
        [weakSelf sendEventWithName:@"notificationOnlineStatus" body:array];
    }];

    // discoverOnlineNodeCallback() is not guarantee of being called by
    // didReceiveMessage() in SigMeshLib.m, so use onOnlineStatusNotify()
    // above instead of setDiscoverOnlineNodeCallback() below
//    [SigPublishManager.share setDiscoverOnlineNodeCallback:^(NSNumber * _Nonnull unicastAddress) {
//        TeLogVerbose(@"setDiscoverOnlineNodeCallback %@", unicastAddress);
//        NSMutableArray *array = [[NSMutableArray alloc] init];
//        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
//        [dict setObject:unicastAddress forKey:@"meshAddress"];
//        [dict setObject:[NSNumber numberWithInt:1] forKey:@"status"];
//        [array addObject:dict];
//        [weakSelf sendEventWithName:@"notificationOnlineStatus" body:array];
//    }];

    [SDKLibCommand setBluetoothCentralUpdateStateCallback: ^(CBCentralManagerState state) {
        TeLogVerbose(@"setBluetoothCentralUpdateStateCallback state=%ld",(long)state);
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
    }];

    [self sendEventWithName:@"serviceConnected" body:nil];
    [self sendEventWithName:@"bluetoothEnabled" body:nil];
    [self sendEventWithName:@"deviceStatusLogout" body:nil];

    // 注册通知，当 APP 由后台切换到前台，在 AppDelegate.m 中通知获取灯的状态，避免在后台时，
    // 灯的状态发生改变，而 APP 上数据没有更新
    // 当然这里只是 iOS 原生写法的示例，实际上应该在 react native APP 的 JS 代码中做这些前后台切换的业务逻辑
    // [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive) name:@"applicationDidBecomeActive" object:nil];
}

RCT_EXPORT_METHOD(setLogLevel:(NSUInteger)level)
{
    [SigLogger.share setSDKLogLevel:level];
}

#pragma  mark - SigDataSourceDelegate
- (void)onSequenceNumberUpdate:(UInt32)sequenceNumber ivIndexUpdate:(UInt32)ivIndex {
    __weak typeof(self) weakSelf = self;
    NSLog(@"TelinkBtSig onSequenceNumberUpdate %d", sequenceNumber);
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [dict setObject:[NSNumber numberWithInt:sequenceNumber] forKey:@"provisionerSno"];
    [dict setObject:[NSNumber numberWithInt:ivIndex] forKey:@"provisionerIvIndex"];
    [dict setObject:[NSNumber numberWithBool:YES] forKey:@"hasOnlineStatusNotifyRaw"];
    [weakSelf sendEventWithName:@"saveOrUpdateJS" body:dict];
}

#pragma  mark - SigMessageDelegate
- (void)didReceiveMessage:(SigMeshMessage *)message sentFromSource:(UInt16)source toDestination:(UInt16)destination {
    TeLogDebug(@"source:%d Response: opcode=0x%x, parameters=%@", source, (unsigned int)message.opCode, message.parameters);

    // getOpCodeTypeWithOpcode 0x0211E3 or 0x01B6 is used with Android (Opcode.java) and JS (index.native.js)
    // getOpCodeTypeWithUInt32Opcode 0xE31102 or 0xB601 is used with iOS (SigEnumeration.h and SigGenericMessage.h)

    if ([SigHelper.share getOpCodeTypeWithUInt32Opcode:message.opCode] == SigOpCodeType_vendor3) {
        onVendorResponse(source, destination, message);
    } else {
        switch (message.opCode) {
            case 0x804A: // SigConfigNodeResetStatus
                TeLogDebug("kickout in sendCommand");
                break;
            case 0x801F:
// setNextModelGroupAddr() use successCallback:onGetModelSubscription is enough, if use 0x801F here,
// in some case 0x801F is triggered here, will cause self->mSetNodeGroupAddrResolve(params) crash for
// self->mSetNodeGroupAddrResolve is nil
//                onGetModelSubscription(source, destination, (SigConfigModelSubscriptionStatus *)message);
                break;
            case 0x5D:
//                onGetTimeNotify(source, destination, (SigTimeStatus *)message);
                break;
            case 0x5F:
//                onGetAlarmNotify(source, destination, (SigSchedulerActionStatus *)message);
                break;
            case 0x8204:
                onGetOnOffNotify(source, destination, (SigGenericOnOffStatus *)message);
                break;
            case 0x8208:
                onGetLevelNotify(source, destination, (SigGenericLevelStatus *)message);
                break;
            case 0x824E:
                onGetLightnessNotify(source, destination, (SigLightLightnessStatus *)message);
                break;
            case 0x8260:
                onGetCtlNotify(source, destination, (SigLightCTLStatus *)message);
                break;
            case 0x8266:
                onGetTempNotify(source, destination, (SigLightCTLTemperatureStatus *)message);
                break;
            case 0xB602:
                onGetFirmwareInfo(source, destination, (SigFirmwareUpdateInformationStatus *)message);
            default:
                if ([message isKindOfClass:[SigTelinkOnlineStatusMessage class]]) {
                    // message.opCode is 0
                    onOnlineStatusNotify(source, destination, (SigTelinkOnlineStatusMessage *)message);
                } else {
                    NSLog(@"TelinkBtSig didReceiveMessage unsupported opcode=0x%x you can add by your self", (unsigned int)message.opCode);
                }
                break;
        }
    }
}

- (SigTelinkOnlineStatusMessage *)getOnlineStatusMessage:(UInt16)address{
    @synchronized(self) {
        for (SigTelinkOnlineStatusMessage *message in self.onlineStatusMessages) {
            if (message.address == address) {
                return message;
            }
        }
        return nil;
    }
}

- (void)applicationWillResignActive {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    TeLogInfo(@"applicationWillResignActive");
}

- (void)applicationDidEnterBackground {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    TeLogInfo(@"applicationDidEnterBackground");
}

- (void)applicationWillEnterForeground {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    TeLogInfo(@"applicationWillEnterForeground");
}

- (void)applicationDidBecomeActive {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    TeLogInfo(@"applicationWillEnterForeground");
}

- (void)applicationWillTerminate {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    TeLogInfo(@"applicationWillTerminate");
}

RCT_EXPORT_METHOD(doDestroy) {
    NSLog(@"TelinkBtSig doDestroy");
}

 RCT_EXPORT_METHOD(doResume) {
     NSLog(@"TelinkBtSig doResume");
 }

RCT_EXPORT_METHOD(enableBluetooth) {
    NSLog(@"TelinkBtSig enableBluetooth");
}

RCT_EXPORT_METHOD(resetExtendBearerMode:(NSInteger)extendBearerMode) {
    SigDataSource.share.telinkExtendBearerMode = extendBearerMode;
    if (extendBearerMode == SigTelinkExtendBearerMode_noExtend) {
        SigDataSource.share.defaultUnsegmentedMessageLowerTransportPDUMaxLength = kUnsegmentedMessageLowerTransportPDUMaxLength;
    } else {
         SigDataSource.share.defaultUnsegmentedMessageLowerTransportPDUMaxLength = kDLEUnsegmentLength;
    }
}

RCT_EXPORT_METHOD(notModeAutoConnectMesh:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    if ([SigBearer.share isAutoReconnect] == NO) {
        resolve(@YES);
        NSLog(@"TelinkBtSig notModeAutoConnectMesh resolve");
    } else {
        reject(@"notModeAutoConnectMesh", @"SigBearer.isAutoReconnect is YES", nil);
        NSLog(@"TelinkBtSig notModeAutoConnectMesh reject");
    }
}

RCT_EXPORT_METHOD(autoConnect) {
    NSLog(@"TelinkBtSig autoConnect");
    if ([SDKLibCommand isBLEInitFinish]) {
        NSLog(@"TelinkBtSig SDKLibCommand isBLEInitFinish");
        [SigBearer.share startMeshConnectWithComplete:^(BOOL successful) {
            NSLog(@"TelinkBtSig startMeshConnectWithComplete");
            if (successful) {
                NSLog(@"TelinkBtSig startMeshConnectWithComplete successful");
                [self meshDidConnected];
            }
        }];
    }
}

- (void)meshDidConnected {
    __weak typeof(self) weakSelf = self;
    CBPeripheral *tem = [SigBearer.share getCurrentPeripheral];
//    SigScanRspModel *scanRspModel = [SigDataSource.share getScanRspModelWithUUID:tem.identifier.UUIDString];

    // with telink APP sdk 3.3.3.5 and FW sdk 3.2.1, scanRspModel.address will always be 0,
    // so not use scanRspModel here
//    SigNodeModel *node = [SigDataSource.share getNodeWithAddress:scanRspModel.address];

    SigNodeModel *node = [SigMeshLib.share.dataSource getNodeWithUUID:tem.identifier.UUIDString];

    int address = [node address];
    NSLog(@"TelinkBtSig getNodeWithUUID %d %@", address, node.macAddress);

    // if use getCurrentConnectedNode, sometimes address is 0 in 1st call of bearerDidOpen,
    // then after 620ms will 2nd call to be not 0 but e.g. 1
    if (address == 0) {
        // getCurrentConnectedNode address mostly be 0, but to help getNodeWithUUID
        node = SigMeshLib.share.dataSource.getCurrentConnectedNode;

        address = [node address];
        NSLog(@"TelinkBtSig getCurrentConnectedNode %d %@", address, node.macAddress);

        if (address == 0) {
            return;
        }
    }

    NSLog(@"TelinkBtSig deviceStatusLogin address:%d", address);
    self.connectMeshAddress = address;
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [dict setObject:[NSNumber numberWithInt:address] forKey:@"connectMeshAddress"];
    [weakSelf sendEventWithName:@"deviceStatusLogin" body:dict];
}

#pragma  mark - SigBearerDataDelegate
- (void)bearerDidConnectedAndDiscoverServices:(SigBearer *)bearer {
}

- (void)bearerDidOpen:(SigBearer *)bearer {
    NSLog(@"TelinkBtSig bearerDidOpen");
    // only telinkApiGetOnlineStatueFromUUIDWithResponseMaxCount() is called at least once
    // after bearerDidOpen, then discoverOutlineNodeCallback() above can work normally
    [SDKLibCommand telinkApiGetOnlineStatueFromUUIDWithResponseMaxCount:0 successCallback:^(UInt16 source, UInt16 destination, SigGenericOnOffStatus * _Nonnull responseMessage) {
        NSLog(@"TelinkBtSig telinkApiGetOnlineStatueFromUUIDWithResponseMaxCount successCallback");
        [self meshDidConnected];
    } resultCallback:^(BOOL isResponseAll, NSError * _Nullable error) {
        NSLog(@"TelinkBtSig telinkApiGetOnlineStatueFromUUIDWithResponseMaxCount error %@", error);
    }];
}

- (void)bearer:(SigBearer *)bearer didCloseWithError:(NSError *)error {
    if (self.allowSendLogoutWhenDisconnect) {
        __weak typeof(self) weakSelf = self;
        TeLogVerbose(@"TelinkBtSig deviceStatusLogout");
        [weakSelf sendEventWithName:@"deviceStatusLogout" body:nil];
    }
}

RCT_EXPORT_METHOD(idleMode:(BOOL)disconnect) {
    NSLog(@"TelinkBtSig idleMode");
    // If your JS APP call it frequently, then must comment bellow, otherwise can't claim in configNode()
    if (disconnect) {
        // can comment cleanAllCommandsAndRetry to avoid this JS error when Debug(Release is OK):
        // Invariant Violation: No callback found with cbID 7319 and callID 3659 for  TelinkBtSig.getTime - most likely the callback was already invoked. Args: '[{"code":"getTime","message":"getTime fail","domain":"Mesh is disconnected!"
        // need clean commands has resultCallback to JS e.g. getTime()
       [SigMeshLib.share cleanAllCommandsAndRetry];

       [SigBearer.share stopMeshConnectWithComplete:nil];
    }
}

RCT_EXPORT_METHOD(startScan:(NSInteger)timeoutSeconds isSingleNode:(BOOL)isSingleNode) {
    // need below to clean scanList, otherwise kickout sometime don't work
    [SigDataSource.share.scanList removeAllObjects];
    NSMutableArray *tem = [NSMutableArray array];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:tem];
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:kScanList_key];
    [[NSUserDefaults standardUserDefaults] synchronize];

    self.allDevices = [NSMutableArray array];
    __weak typeof(self) weakSelf = self;

    // to avoid this JS error when Debug(Release is OK):
    // Invariant Violation: No callback found with cbID 7319 and callID 3659 for  TelinkBtSig.getTime - most likely the callback was already invoked. Args: '[{"code":"getTime","message":"getTime fail","domain":"Mesh is disconnected!"
    // need clean commands has resultCallback to JS e.g. getTime()
    [SigMeshLib.share cleanAllCommandsAndRetry];

    [SDKLibCommand stopMeshConnectWithComplete:^(BOOL successful) {
        if (!successful) {
            return;
        }
        TeLogInfo(@"stopMeshConnect success.");
        [weakSelf sendEventWithName:@"deviceStatusLogout" body:nil];
        [SDKLibCommand scanUnprovisionedDevicesWithResult:^(CBPeripheral * _Nonnull peripheral, NSDictionary<NSString *,id> * _Nonnull advertisementData, NSNumber * _Nonnull RSSI, BOOL unprovisioned) {
            TeLogInfo(@"==========peripheral=%@,advertisementData=%@,RSSI=%@,unprovisioned=%d",peripheral,advertisementData,RSSI,unprovisioned);
            if (unprovisioned) {
                SigScanRspModel *scanRspModel = [SigDataSource.share getScanRspModelWithUUID:peripheral.identifier.UUIDString];
                NSData *advDataServiceData = [(NSDictionary *)advertisementData[CBAdvertisementDataServiceDataKey] allValues].firstObject;
                BOOL isEsp32 = false;
                if (scanRspModel.macAddress == nil && scanRspModel.CID == 0xDDDD) { // advDataServiceData also start with DDDD
                    // aboud DDDD ref to comments in onLeScan(ScanEvent event) of
                    // react-native-btsig-telink/android/src/main/java/com/telink/ble/mesh/TelinkBtSigNativeModule.java
                    isEsp32 = true;
                }
                if (isEsp32) {
                    if (advDataServiceData.length >= 8) {
                        scanRspModel.macAddress = [LibTools convertDataToHexStr:[advDataServiceData subdataWithRange:NSMakeRange(2, 6)]];
                        scanRspModel.PID=0; // TODO: like Android code using rsvUser[0] and [1], even they are 0 in ESP32 by default
                    }
                }

                if (scanRspModel == nil || scanRspModel.macAddress == nil) {
                    return;
                }

                // 如 SigModel.m 中所示“固件v3.2.1及之前版本的广播包”与
                // “固件v3.2.2及之后版本的广播包”之间的差异，其实就是固件代码
                // mesh_commmon.c 的 mesh_scan_rsp_init() 里在新版中多广播了 2 个字节
                // tbl_scanRsp.vendor_id = g_vendor_id 所以最终导致
                // SigScanRspModel.initWithPeripheral 处理 3.2.1 及之前的设备时得到的
                // _macAddress 是错误的，为了不修改官方的 SigModel.m ，就补丁在这吧。
                if (!isEsp32 && advDataServiceData.length >= 16) {
                    scanRspModel.macAddress = [LibTools convertDataToHexStr:[LibTools turnOverData:[advDataServiceData subdataWithRange:NSMakeRange(10, 6)]]];
                }

                NSString *macAddress = [LibTools getMacStringWithMac:scanRspModel.macAddress];
                deviceModel *device = [[deviceModel alloc] init];
                device.peripheral = peripheral;
                device.macAddress = macAddress;
                if (![weakSelf.allDevices containsObject:device]) {
                    [weakSelf.allDevices addObject:device];
                    NSLog(@"TelinkBtSig ScanNewDevice macAddress = %@", macAddress);

                    NSMutableDictionary *event = [[NSMutableDictionary alloc] init];
                    if (scanRspModel.advName) {
                        [event setObject:scanRspModel.advName forKey:@"deviceName"];
                    }
//                     [event setObject:[NSString stringWithFormat:@"%@", scanRspModel.advertisementDataServiceData] forKey:@"meshName"];
//                     [event setObject:[NSNumber numberWithInt:scanRspModel.address] forKey:@"meshAddress"];
                    [event setObject:macAddress forKey:@"macAddress"];
//                     [event setObject:[NSNumber numberWithInt:scanRspModel.uuid] forKey:@"meshUUID"];
                    [event setObject:[NSNumber numberWithInt:scanRspModel.PID] forKey:@"productUUID"];
//                     [event setObject:[NSNumber numberWithBool:scanRspModel.provisioned] forKey:@"status"];

                    NSData * rsvUserData = [self getRsvUserFromAdvData:advertisementData];
                    if (rsvUserData != nil) {
                        char *buffer = (char *)rsvUserData.bytes;
                        NSMutableArray *rsvUser = [[NSMutableArray alloc] init];
                        for (int i = 0; i < rsvUserData.length; i++) {
                            [rsvUser addObject:[NSNumber numberWithUnsignedChar:buffer[i]]];
                        }
                        [event setObject:rsvUser forKey:@"rsvUser"];
                    } else {
                        NSMutableArray *rsvUser = [[NSMutableArray alloc] init];
                        for (int i = 0; i < 11; i++) { // 11 comes from Android
                            [rsvUser addObject:[NSNumber numberWithUnsignedChar:0]];
                        }
                        [event setObject:rsvUser forKey:@"rsvUser"];
                    }
                    NSLog(@"TelinkBtSig ScanNewDevice rsvUser = %@", rsvUserData);

                    [event setObject:RSSI forKey:@"rssi"];

                    NSData * versionData = [advDataServiceData subdataWithRange:NSMakeRange(4, 2)];
                    char *buffer = (char *)versionData.bytes;
                    NSMutableArray *version = [[NSMutableArray alloc] init];
                    for (int i = 0; i < versionData.length; i++) {
                        if (isEsp32) {
                            //  TODO: set to 'V0.0' here, so you may use e.g. rsvUser[2] and [3] in JS code
                            [version addObject:[NSNumber numberWithUnsignedChar:0x30]];
                        } else {
                            [version addObject:[NSNumber numberWithUnsignedChar:buffer[i]]];
                        }
                    }
                    [event setObject:version forKey:@"version"];

                    [weakSelf sendEventWithName:@"leScan" body:event];
                }
            }
        }];

        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf performSelector:@selector(scanFinish) withObject:nil afterDelay:timeoutSeconds];
        });
    }];
}

- (NSData *)getRsvUserFromAdvData:(NSDictionary<NSString *,id> *)advertisementData {
    if ([advertisementData.allKeys containsObject:CBAdvertisementDataManufacturerDataKey]) {
        NSData *allData = advertisementData[CBAdvertisementDataManufacturerDataKey];
        if (allData.length >= 29) {
            return [allData subdataWithRange:NSMakeRange(18, 11)];
        }
    }

    return nil;
}

- (void)scanFinish {
    [SDKLibCommand stopScan];
}

RCT_EXPORT_METHOD(setCommandsQueueIntervalMs:(NSInteger)interval) {
    // Seems there is no working CommandsQueue in this telink iOS SDK,
    // so just return
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(getCommandsQueueIntervalMs) {
    // Seems there is no working CommandsQueue in this telink iOS SDK,
    // so just return 240 like telink Android SDK did
    return [NSNumber numberWithInt:240];
}

RCT_EXPORT_METHOD(clearCommandQueue) {
    [SigMeshLib.share cleanAllCommandsAndRetry];
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(getCommandQueueLength) {
    return [NSNumber numberWithInt:(int)SigMeshLib.share.commands.count];
}

RCT_EXPORT_METHOD(sendCommand:(NSInteger)opcode meshAddress:(NSInteger)meshAddress value:(NSArray *)value rspOpcode:(NSInteger)rspOpcode tidPosition:(NSInteger)tidPosition immediate:(BOOL)immediate) {
    if (immediate) {
        [SigMeshLib.share cleanAllCommandsAndRetry];
    }
    // if immediate is false and rspOpcode is not OPCODE_INVALID in index.native.js
    // and use SigMeshLib.share.isBusyNow below, will cause
    // 10s busy, so not use SigMeshLib.share.isBusyNow just like android code
    // (if retryCount is 0 will not busy, but still SigDataSource.share.defaultRetryCount
    // as 2 here to match android code DEFAULT_RETRY_CNT = 2 in MeshMessage.java )
//    if (SigMeshLib.share.isBusyNow) {
//        TeLogInfo(@"sendCommand busy");
//        return;
//    }

    // if retryCount is SigDataSource.share.defaultRetryCount as known is 2
    // and rspOpcode is not OPCODE_INVALID in index.native.js, the same
    // command will be sent 3 times, while android code DEFAULT_RETRY_CNT = 2 in
    // MeshMessage.java, but the command will only be sent 1 times on Android,
    // so `retryCount = 0` here to match iOS and Android
//    int retryCount = SigDataSource.share.defaultRetryCount;
    int retryCount = 0;

    // getOpCodeTypeWithOpcode 0x0211E3 or 0x01B6 is used with Android (Opcode.java) and JS (index.native.js)
    // getOpCodeTypeWithUInt32Opcode 0xE31102 or 0xB601 is used with iOS (SigEnumeration.h and SigGenericMessage.h)

    IniCommandModel *model = [IniCommandModel alloc];
    if ([SigHelper.share getOpCodeTypeWithOpcode:(UInt8)(opcode & 0xff)] == SigOpCodeType_vendor3) {
        model = [model initVendorModelIniCommandWithNetkeyIndex:SigDataSource.share.curNetkeyModel.index appkeyIndex:SigDataSource.share.curAppkeyModel.index retryCount:retryCount responseMax:0 address:meshAddress opcode:opcode & 0xff vendorId:(opcode >> 8) & 0xffff responseOpcode:rspOpcode & 0xff tidPosition:tidPosition > 0 ? tidPosition : 0 tid:(tidPosition > 0 && tidPosition <= value.count) ? ((NSNumber *)value[tidPosition - 1]).unsignedCharValue : 0  commandData:[self byteArray2Data:value]];
    } else {
        model = [model initSigModelIniCommandWithNetkeyIndex:SigDataSource.share.curNetkeyModel.index appkeyIndex:SigDataSource.share.curAppkeyModel.index retryCount:retryCount responseMax:0 address:meshAddress opcode:opcode commandData:[self byteArray2Data:value]];
    }

    [SDKLibCommand sendIniCommandModel:model successCallback:^(UInt16 source, UInt16 destination, SigMeshMessage * _Nonnull responseMessage) {} resultCallback:^(BOOL isResponseAll, NSError * _Nullable error) {}];
}

RCT_EXPORT_METHOD(sendCommandRsp:(NSInteger)opcode meshAddress:(NSInteger)meshAddress value:(NSArray *)value rspOpcode:(NSInteger)rspOpcode relayTimes:(NSInteger)relayTimes retryCnt:(NSInteger)retryCnt tidPosition:(NSInteger)tidPosition immediate:(BOOL)immediate resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    if (immediate) {
        [SigMeshLib.share cleanAllCommandsAndRetry];
    }
    // getOpCodeTypeWithOpcode 0x0211E3 or 0x01B6 is used with Android (Opcode.java) and JS (index.native.js)
    // getOpCodeTypeWithUInt32Opcode 0xE31102 or 0xB601 is used with iOS (SigEnumeration.h and SigGenericMessage.h)

    IniCommandModel *model = [IniCommandModel alloc];
    if ([SigHelper.share getOpCodeTypeWithOpcode:(UInt8)(opcode & 0xff)] == SigOpCodeType_vendor3) {
        model = [model initVendorModelIniCommandWithNetkeyIndex:SigDataSource.share.curNetkeyModel.index appkeyIndex:SigDataSource.share.curAppkeyModel.index retryCount:retryCnt responseMax:relayTimes address:meshAddress opcode:opcode & 0xff vendorId:(opcode >> 8) & 0xffff responseOpcode:rspOpcode & 0xff tidPosition:tidPosition > 0 ? tidPosition : 0 tid:(tidPosition > 0 && tidPosition <= value.count) ? ((NSNumber *)value[tidPosition - 1]).unsignedCharValue : 0  commandData:[self byteArray2Data:value]];
    } else {
        model = [model initSigModelIniCommandWithNetkeyIndex:SigDataSource.share.curNetkeyModel.index appkeyIndex:SigDataSource.share.curAppkeyModel.index retryCount:retryCnt responseMax:relayTimes address:meshAddress opcode:opcode commandData:[self byteArray2Data:value]];
    }

    self->mSendCommandRspResolve = resolve;
    self->mSendCommandRspReject = reject;

    [SDKLibCommand sendIniCommandModel:model successCallback:^(UInt16 source, UInt16 destination, SigMeshMessage * _Nonnull responseMessage) {
//        NSLog(@"TelinkBtSig sendCommandRsp successCallback source = %x", source);
        // resultCallback will not be invoked if relayTimes AKA responseMax be 0 , so be here
        if (relayTimes == 0) {
            if (self->mSendCommandRspResolve != nil) {
                NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                [dict setObject:[NSNumber numberWithInt:(int)rspOpcode] forKey:@"opcode"];
                self->mSendCommandRspResolve(dict);
                self->mSendCommandRspResolve = nil;
                self->mSendCommandRspReject = nil;
            }
        }
    } resultCallback:^(BOOL isResponseAll, NSError * _Nullable error) {
        if (relayTimes != 0) {
            if (isResponseAll) {
                if (self->mSendCommandRspResolve != nil) {
                    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                    [dict setObject:[NSNumber numberWithInt:(int)rspOpcode] forKey:@"opcode"];
                    self->mSendCommandRspResolve(dict);
                    self->mSendCommandRspResolve = nil;
                    self->mSendCommandRspReject = nil;
                }
            } else {
                if (self->mSendCommandRspReject != nil) {
                    self->mSendCommandRspReject(@"onSendCommandRspFailure", @"onSendCommandRspFailure isResponseAll: false", error);
                    self->mSendCommandRspReject = nil;
                    self->mSendCommandRspResolve = nil;
                }
            }
        }
    }];
}

RCT_EXPORT_METHOD(getFirmwareInfo:(NSInteger)meshAddress) {
#ifdef kExist
    // if use SigMeshLib.share.isBusyNow below, will cause
    // 10s busy, so not use SigMeshLib.share.isBusyNow just like android code
    // (if retryCount is 0 will not busy, but still SigDataSource.share.defaultRetryCount
    // as 2 here to match android code DEFAULT_RETRY_CNT = 2 in MeshMessage.java )
//    if (SigMeshLib.share.isBusyNow) {
//        TeLogInfo(@"getFirmwareInfo busy");
//        return;
//    }

    // 2.firmwareUpdateInformationGet ，该消息在 modelID：kSigModel_FirmwareUpdateServer_ID 里面
    UInt16 modelIdentifier = kSigModel_FirmwareUpdateServer_ID;
    NSArray *curNodes = [NSArray arrayWithArray:SigDataSource.share.curNodes];
    NSInteger responseMax = 0;
    NSMutableArray *LPNArray = [NSMutableArray array];
    for (SigNodeModel *model in curNodes) {
        NSArray *addressArray = [model getAddressesWithModelID:@(modelIdentifier)];
        if (model.state != DeviceStateOutOfLine && addressArray && addressArray.count > 0 && model.features.lowPowerFeature == SigNodeFeaturesState_notSupported) {
            responseMax ++;
        }
        if (model.features.lowPowerFeature != SigNodeFeaturesState_notSupported) {
            [LPNArray addObject:model];
        }
    }

    NSOperationQueue *operationQueue = [[NSOperationQueue alloc] init];
    [operationQueue addOperationWithBlock:^{
        // 这个 block 语句块在子线程中执行
        // 如果 responseMax = 0 ，则无需发送到 0xFFFF 获取版本号
        if (responseMax > 0 || (responseMax == 0 && LPNArray.count == 0)) {
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            [SDKLibCommand firmwareUpdateInformationGetWithDestination:kMeshAddress_allNodes firstIndex:0 entriesLimit:1 retryCount:SigDataSource.share.defaultRetryCount responseMaxCount:responseMax successCallback:self->onGetFirmwareInfo resultCallback:^(BOOL isResponseAll, NSError * _Nullable error) {
                TeLogInfo(@"isResponseAll=%d,error=%@",isResponseAll,error);
                dispatch_semaphore_signal(semaphore);
            }];
            // Most provide 4 seconds
            dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 10.0));
        }

        if (LPNArray && LPNArray.count) {
            for (SigNodeModel *model in LPNArray) {
                dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                [SDKLibCommand firmwareUpdateInformationGetWithDestination:model.address firstIndex:0 entriesLimit:1 retryCount:SigDataSource.share.defaultRetryCount responseMaxCount:1 successCallback:self->onGetFirmwareInfo resultCallback:^(BOOL isResponseAll, NSError * _Nullable error) {
                    TeLogInfo(@"isResponseAll=%d,error=%@",isResponseAll,error);
                    dispatch_semaphore_signal(semaphore);
                }];
                // Most provide 4 seconds
                dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 10.0));
            }
        }
    }];
#endif
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
#ifdef kExist
    if (kExistMeshOTA) {
        __weak typeof(self) weakSelf = self;
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInt:SigDataSource.share.curLocationNodeModel.address] forKey:@"meshAddress"];
        [dict setObject:@"start" forKey:@"status"];
        [weakSelf sendEventWithName:@"notificationDataGetMeshOtaFirmwareDistributionStatus" body:dict];

        NSData *firmwareData = [self byteArray2Data:firmware];

        // incomingFirmwareMetadata 默认为 8 个字节的 0 。需要 bin 文件里面从 index 为 2 开始取 4 个字节的数据，再补充 4 个字节的 0
        UInt32 tem32 = 0;
        NSData *temData = [NSData dataWithBytes:&tem32 length:4];
        NSMutableData *metaData = [NSMutableData dataWithData:[firmwareData subdataWithRange:NSMakeRange(2, 4)]];
        [metaData appendData:temData];

        // if use SigMeshLib.share.isBusyNow below, will cause
        // 10s busy, so not use SigMeshLib.share.isBusyNow just like android code
        // (if retryCount is 0 will not busy, but still SigDataSource.share.defaultRetryCount
        // as 2 here to match android code DEFAULT_RETRY_CNT = 2 in MeshMessage.java )
//        if (SigMeshLib.share.isBusyNow) {
//            TeLogInfo(@"startMeshOTA busy");
//            return;
//        }

        MeshOTAManager.share.updatePolicy = SigUpdatePolicyType_verifyAndApply;
        MeshOTAManager.share.phoneIsDistributor = YES;
        MeshOTAManager.share.needCheckVersionAfterApply = NO;

        [MeshOTAManager.share startFirmwareUpdateWithDeviceAddresses:meshAddresses otaData:firmwareData incomingFirmwareMetadata:metaData gattDistributionProgressHandle:^(NSInteger progress) {
            NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
            [params setObject:[NSNumber numberWithInteger:progress] forKey:@"otaMasterProgress"];
            [weakSelf sendEventWithName:@"deviceStatusOtaMasterProgress" body:params];
        } advDistributionProgressHandle:^(SigFirmwareDistributionReceiversList *responseMessage) {
            SigUpdatingNodeEntryModel *firstEntry = [responseMessage.receiversList firstObject];
            if (firstEntry == nil) {
                return;
            }

            NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
            [params setObject:[NSNumber numberWithInt:firstEntry.transferProgress] forKey:@"otaSlaveProgress"];
            [weakSelf sendEventWithName:@"notificationDataGetMeshOtaProgress" body:params];
        } finishHandle:^(NSArray<NSNumber *> *successAddresses, NSArray<NSNumber *> *failAddresses) {
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
            [dict setObject:[NSNumber numberWithInt:SigDataSource.share.curLocationNodeModel.address] forKey:@"meshAddress"];
            [dict setObject:@"stop" forKey:@"status"];
            [weakSelf sendEventWithName:@"notificationDataGetMeshOtaFirmwareDistributionStatus" body:dict];

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
        } errorHandle:^(NSError * _Nullable error) {
            NSLog(@"TelinkBtSig MeshOTA error = %@",error);
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
            [dict setObject:[NSNumber numberWithInt:SigDataSource.share.curLocationNodeModel.address] forKey:@"meshAddress"];
            [dict setObject:@"error" forKey:@"status"];
            [weakSelf sendEventWithName:@"notificationDataGetMeshOtaFirmwareDistributionStatus" body:dict];
        }];
    }
#endif
}

RCT_EXPORT_METHOD(stopMeshOTA:(NSString *)tag) {
#ifdef kExist
    [MeshOTAManager.share stopMeshOTA];
#endif
}

RCT_EXPORT_METHOD(changePower:(NSInteger)meshAddress value:(NSInteger)value) {
    // if use SigMeshLib.share.isBusyNow below, will cause
    // 10s busy, so not use SigMeshLib.share.isBusyNow just like android code
    // (if retryCount is 0 will not busy, but still SigDataSource.share.defaultRetryCount
    // as 2 here to match android code DEFAULT_RETRY_CNT = 2 in MeshMessage.java )
//    if (SigMeshLib.share.isBusyNow) {
//        TeLogInfo(@"changePower busy");
//        return;
//    }

    [SDKLibCommand genericOnOffSetWithDestination:meshAddress isOn:(value == 1) retryCount:SigDataSource.share.defaultRetryCount responseMaxCount:0 ack:YES successCallback:onGetOnOffNotify resultCallback:^(BOOL isResponseAll, NSError * _Nullable error){}];
}

RCT_EXPORT_METHOD(changeBrightness:(NSInteger)meshAddress value:(NSInteger)value) {
    // if use SigMeshLib.share.isBusyNow below, will cause
    // 10s busy, so not use SigMeshLib.share.isBusyNow just like android code
    // (if retryCount is 0 will not busy, but still SigDataSource.share.defaultRetryCount
    // as 2 here to match android code DEFAULT_RETRY_CNT = 2 in MeshMessage.java )
//    if (SigMeshLib.share.isBusyNow) {
//        TeLogInfo(@"changeBrightness busy");
//        return;
//    }

    UInt16 lightness = [SigHelper.share getUint16LightnessFromUInt8Lum:value];
    [SDKLibCommand lightLightnessSetWithDestination:meshAddress lightness:lightness retryCount:SigDataSource.share.defaultRetryCount responseMaxCount:0 ack:NO successCallback:onGetLightnessNotify resultCallback:^(BOOL isResponseAll, NSError * _Nullable error){}];
}

RCT_EXPORT_METHOD(changeTemperatur:(NSInteger)meshAddress value:(float)value) {
    // if use SigMeshLib.share.isBusyNow below, will cause
    // 10s busy, so not use SigMeshLib.share.isBusyNow just like android code
    // (if retryCount is 0 will not busy, but still SigDataSource.share.defaultRetryCount
    // as 2 here to match android code DEFAULT_RETRY_CNT = 2 in MeshMessage.java )
//    if (SigMeshLib.share.isBusyNow) {
//        TeLogInfo(@"changeTemperatur busy");
//        return;
//    }

    UInt16 temperature = [SigHelper.share getUint16TemperatureFromUInt8Temperature100:value];
    [SDKLibCommand lightCTLTemperatureSetWithDestination:meshAddress temperature:temperature deltaUV:0 retryCount:SigDataSource.share.defaultRetryCount responseMaxCount:0 ack:NO successCallback:onGetTempNotify resultCallback:^(BOOL isResponseAll, NSError * _Nullable error){}];
}

RCT_EXPORT_METHOD(changeColor:(NSInteger)meshAddress hue:(NSInteger)hue saturation:(NSInteger)saturation brightness:(NSInteger)brightness) {
    // if use SigMeshLib.share.isBusyNow below, will cause
    // 10s busy, so not use SigMeshLib.share.isBusyNow just like android code
    // (if retryCount is 0 will not busy, but still SigDataSource.share.defaultRetryCount
    // as 2 here to match android code DEFAULT_RETRY_CNT = 2 in MeshMessage.java )
//    if (SigMeshLib.share.isBusyNow) {
//        TeLogInfo(@"changeColor busy");
//        return;
//    }

    [SDKLibCommand lightHSLSetWithDestination:meshAddress HSLLight:brightness HSLHue:hue HSLSaturation:saturation retryCount:SigDataSource.share.defaultRetryCount responseMaxCount:0 ack:NO successCallback:^(UInt16 source, UInt16 destination, SigLightHSLStatus * _Nonnull responseMessage){} resultCallback:^(BOOL isResponseAll, NSError * _Nullable error){}];
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

- (NSMutableArray *) cpsDataToBytes:(SigPage0 *)sigPage0 {
    NSData *sigPageData = sigPage0.parameters;
    NSData *cpsData = [sigPageData subdataWithRange:NSMakeRange(1, sigPageData.length - 1)];
    return [self byteData2Array:cpsData];
}

- (NSArray *) toVCNodeInfo:(NSInteger)nodeAdr elementCnt:(NSInteger)elementCnt deviceKey:(NSArray *)deviceKey cpsData:(NSArray *)cpsData {
    NSMutableArray *result = [[NSMutableArray alloc] init];
    [result addObject:[NSNumber numberWithInt:(nodeAdr & 0xFF)]];
    [result addObject:[NSNumber numberWithInt:((nodeAdr >> 8) & 0xFF)]];
    [result addObject:[NSNumber numberWithInt:(elementCnt & 0xFF)]];
    UInt8 rsv = 0;
    [result addObject:[NSNumber numberWithInt:rsv]];
    [result addObjectsFromArray:deviceKey];
    UInt16 cpsDataLen = cpsData.count;
    [result addObject:[NSNumber numberWithInt:(cpsDataLen & 0xFF)]];
    [result addObject:[NSNumber numberWithInt:((cpsDataLen >> 8) & 0xFF)]];
    [result addObjectsFromArray:cpsData];
    return result;
}

RCT_EXPORT_METHOD(configNode:(NSDictionary *)node cpsDataArray:(NSArray *)cpsDataArray elementCnt:(NSInteger)elementCnt isToClaim:(BOOL)isToClaim resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    if (isToClaim) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(scanFinish) object:nil];

        // found in telink sdk 3.1.0 need this stopScan otherwise sometime will
        // connectPeripheral() other node macAddress in blockState() in
        // SigMeshOC/Bluetooth.m
        // so in telink sdk 3.3.3.5 I just keep it without many tests (who like test?)
        [SDKLibCommand stopScan];

        self.allowSendLogoutWhenDisconnect = NO;

        NSData *key = [SigDataSource.share curNetKey];
        if (SigDataSource.share.curNetkeyModel.phase == distributingKeys) {
            if (SigDataSource.share.curNetkeyModel.oldKey) {
                key = [LibTools nsstringToHex:SigDataSource.share.curNetkeyModel.oldKey];
            }
        }

        // to avoid this JS error when Debug(Release is OK):
        // Invariant Violation: No callback found with cbID 7319 and callID 3659 for  TelinkBtSig.getTime - most likely the callback was already invoked. Args: '[{"code":"getTime","message":"getTime fail","domain":"Mesh is disconnected!"
        // need clean commands has resultCallback to JS e.g. getTime()
        [SigMeshLib.share cleanAllCommandsAndRetry];

        [SDKLibCommand stopMeshConnectWithComplete:^(BOOL successful) {
            if (successful) {
                NSLog(@"TelinkBtSig AddNewDevice %@", [node objectForKey:@"macAddress"]);

//                SigScanRspModel *scanRspModel = [SigDataSource.share getScanRspModelWithMac:[[node objectForKey:@"macAddress"] stringByReplacingOccurrencesOfString:@":" withString:@""]];
//                CBPeripheral *peripheral = [SigBluetooth.share getPeripheralWithUUID:scanRspModel.uuid];
                deviceModel *device = [self getDeviceModelWithMac:[node objectForKey:@"macAddress"]];
                CBPeripheral *peripheral;
                if (device) {
                    peripheral = device.peripheral;
                }

                if (peripheral == nil) {
                    self.allowSendLogoutWhenDisconnect = YES;
                    NSLog(@"TelinkBtSig AddNewDevice need rescan");
                    reject(@"need rescan", @"AddNewDevice need rescan", nil);
                    return;
                }

                UInt16 provisionAddress = [[node objectForKey:@"meshAddress"] intValue];

                KeyBindType keyBindType = KeyBindType_Normal;
                UInt16 pid = 0;
                NSData *cpsData = nil;

                if (cpsDataArray.count > 0) {
                    keyBindType = KeyBindType_Fast;
                    pid = (((NSNumber *)[cpsDataArray objectAtIndex:3]).unsignedCharValue << 8) | ((NSNumber *)[cpsDataArray objectAtIndex:2]).unsignedCharValue;
                    cpsData = [self byteArray2Data:cpsDataArray];
                }

                ProvisionType provisionType = ProvisionType_NoOOB;
                NSData *staticOOBData = nil;

                // TODO: support oob comes from sig draft features?
                // SigOOBModel *oobModel = [SigDataSource.share getSigOOBModelWithUUID:scanRspModel.advUuid];
                // if (oobModel && oobModel.OOBString && (oobModel.OOBString.length == 32 || oobModel.OOBString.length == 64)) {
                //     provisionType = ProvisionType_StaticOOB;
                //     staticOOBData = [LibTools nsstringToHex:oobModel.OOBString];
                // }

                NSLog(@"TelinkBtSig AddNewDevice cpsData %@", cpsData);
                [SDKLibCommand startAddDeviceWithNextAddress:provisionAddress networkKey:key netkeyIndex:SigDataSource.share.curNetkeyModel.index appkeyModel:SigDataSource.share.curAppkeyModel peripheral:peripheral provisionType:provisionType staticOOBData:staticOOBData keyBindType:keyBindType productID:pid cpsData:cpsData provisionSuccess:^(NSString * _Nonnull identify, UInt16 address) {
                    if (identify && address != 0) {
                        NSLog(@"TelinkBtSig AddNewDevice %d provisionSuccess", provisionAddress);
                    } else {
                        reject(@"provision", @"AddNewDevice fail identify", nil);
                    }
                } provisionFail:^(NSError * _Nonnull error) {
                    self.allowSendLogoutWhenDisconnect = YES;
                    NSLog(@"TelinkBtSig AddNewDevice %d fail: %@", provisionAddress, error);
                    reject(@"provision", @"AddNewDevice provision fail", error);
                } keyBindSuccess:^(NSString * _Nonnull identify, UInt16 address) {
                    NSLog(@"TelinkBtSig AddNewDevice %d keyBindSuccess", provisionAddress);

                    NSMutableDictionary *event = [[NSMutableDictionary alloc] init];
                    SigNodeModel *model = [SigDataSource.share getNodeWithAddress:address];

                    UInt16 productId = model.compositionData.productIdentifier;

                    //  VC_node_info_t node_info
                    UInt8 node_info_elementCnt = model.compositionData.elements.count;
                    NSMutableArray *node_info_cpsData = [self cpsDataToBytes:model.compositionData];

                    if (keyBindType == KeyBindType_Fast) {
                        SigScanRspModel *scanRspModel = [SigDataSource.share getScanRspModelWithUUID:identify];
                        if (scanRspModel != nil && scanRspModel.macAddress != nil && scanRspModel.CID != 0 && scanRspModel.PID != 0) {
                            productId = scanRspModel.PID;

                            node_info_elementCnt = elementCnt;
                            node_info_cpsData = [NSMutableArray arrayWithArray:cpsDataArray];

                            // maybe your project does not need these 2 lines
                            [node_info_cpsData replaceObjectAtIndex:2 withObject:[NSNumber numberWithInt:(scanRspModel.PID) & 0xff]];
                            [node_info_cpsData replaceObjectAtIndex:3 withObject:[NSNumber numberWithInt:(scanRspModel.PID >> 8) & 0xff]];

                            NSLog(@"TelinkBtSig AddNewDevice replace pid %x", scanRspModel.PID);
                            if ([scanRspModel.advertisementData.allKeys containsObject:CBAdvertisementDataServiceDataKey]) {
                                NSData *advDataServiceData = [(NSDictionary *)scanRspModel.advertisementData[CBAdvertisementDataServiceDataKey] allValues].firstObject;
                                if (advDataServiceData) {
                                    if (advDataServiceData.length >= 6) {
                                        UInt16 vid = [LibTools uint16FromBytes:[advDataServiceData subdataWithRange:NSMakeRange(4, 2)]];
                                        [node_info_cpsData replaceObjectAtIndex:4 withObject:[NSNumber numberWithInt:(vid) & 0xff]];
                                        [node_info_cpsData replaceObjectAtIndex:5 withObject:[NSNumber numberWithInt:(vid >> 8) & 0xff]];
                                        NSLog(@"TelinkBtSig AddNewDevice replace vid %x", vid);
                                    }
                                }
                            }

//                            model.compositionData.productIdentifier = scanRspModel.PID;
//                            [SigDataSource.share addAndSaveNodeToMeshNetworkWithDeviceModel:model];
                        }
                    }

                    NSMutableArray *deviceKey = [self byteData2Array:[LibTools nsstringToHex:model.deviceKey]];

                    NSArray *nodeInfo = [self toVCNodeInfo:address elementCnt:node_info_elementCnt deviceKey:deviceKey cpsData:node_info_cpsData];

//                    NSLog(@"TelinkBtSig AddNewDevice nodeInfo = %@", nodeInfo);
//                    NSLog(@"TelinkBtSig AddNewDevice pid = %@", model.pid);

                    [event setObject:nodeInfo forKey:@"nodeInfo"];
                    [event setObject:[NSNumber numberWithInt:node_info_elementCnt] forKey:@"elementCnt"];
                    [event setObject:[NSNumber numberWithInt:productId] forKey:@"type"];
                    NSLog(@"TelinkBtSig AddNewDevice dhmKey = %@", deviceKey);
                    [event setObject:deviceKey forKey:@"dhmKey"];
                    self.allowSendLogoutWhenDisconnect = YES;
                    resolve(event);
                } keyBindFail:^(NSError * _Nonnull error) {
                    self.allowSendLogoutWhenDisconnect = YES;
                    NSLog(@"TelinkBtSig AddNewDevice %d keyBind fail: %@", provisionAddress, error);
                    reject(@"keyBind", @"AddNewDevice keyBind fail", error);
                }];
            } else {
                self.allowSendLogoutWhenDisconnect = YES;
                NSLog(@"TelinkBtSig AddNewDevice stop mesh fail");
                reject(@"keyBind", @"AddNewDevice stop mesh fail", nil);
            }
        }];
    } else {
        // if use SigMeshLib.share.isBusyNow below, will cause
        // 10s busy, so not use SigMeshLib.share.isBusyNow just like android code
        // (if retryCount is 0 will not busy, but still SigDataSource.share.defaultRetryCount
        // as 2 here to match android code DEFAULT_RETRY_CNT = 2 in MeshMessage.java )
//        if (SigMeshLib.share.isBusyNow) {
//            TeLogInfo(@"kickout busy")
//            reject(@"kickout", @"kickout busy", nil);
//            return;
//        }

        __weak typeof(self) weakSelf = self;

//        NSString *macAddress = [[node objectForKey:@"macAddress"] stringByReplacingOccurrencesOfString:@":" withString:@""];
//        BOOL isDirect = [macAddress isEqualToString:[SigDataSource.share getCurrentConnectedNode].macAddress];
        // isDirect above sometime is not correct, so use isDirect below
        BOOL isDirect = self.connectMeshAddress == [[node objectForKey:@"meshAddress"] unsignedShortValue];

        [SDKLibCommand resetNodeWithDestination:[[node objectForKey:@"meshAddress"] unsignedShortValue] retryCount:SigDataSource.share.defaultRetryCount responseMaxCount:0 successCallback:^(UInt16 source, UInt16 destination, SigConfigNodeResetStatus * _Nonnull responseMessage) {
            NSLog(@"TelinkBtSig kickout success");
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
            resolve(dict);
            if (isDirect) {
                NSLog(@"TelinkBtSig kickout direct");
                [weakSelf sendEventWithName:@"deviceStatusLogout" body:nil];
            } else {
                NSLog(@"TelinkBtSig kickout remote");
            }
        } resultCallback:^(BOOL isResponseAll, NSError * _Nullable error) {}];
    }
}

RCT_EXPORT_METHOD(add2defaultNodeInfos:(NSInteger)cid pid:(NSInteger)pid cpsData:(NSArray *)cpsData) {
    DeviceTypeModel *model = [[DeviceTypeModel alloc] initWithCID:(UInt16)cid PID:(UInt16)pid];
    [model setCompositionData:[self byteArray2Data:cpsData]];
    [SigDataSource.share.defaultNodeInfos addObject:model];
}

RCT_EXPORT_METHOD(claimAllAtOnce:(NSInteger)meshAddress pids:(NSArray *)pids resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    __weak typeof(self) weakSelf = self;

    deviceModel * device = [self.allDevices firstObject];
    CBPeripheral *peripheral;
    if (device) {
        peripheral = device.peripheral;
    }

    if (peripheral == nil) {
        NSLog(@"TelinkBtSig claimAllAtOnce need rescan");
        reject(@"keyBind", @"claimAllAtOnce need rescan", nil);
        return;
    }

    [SDKLibCommand stopScan];
    [SigBearer.share changePeripheral:peripheral result:^(BOOL successful) {
        if (successful) {
            [SigBearer.share openWithResult:^(BOOL successful) {
                if (successful) {
                    [SigFastProvisionAddManager.share startFastProvisionWithProvisionAddress:meshAddress productIds:pids currentConnectedNodeIsUnprovisioned:YES scanResponseCallback:^(NSData * _Nonnull deviceKey, NSString * _Nonnull macAddress, UInt16 address, UInt16 pid) {
                    } startProvisionCallback:^{
                    } addSingleDeviceSuccessCallback:^(NSData * _Nonnull deviceKey, NSString * _Nonnull macAddress, UInt16 address, UInt16 pid) {
                        TeLogInfo(@"fast provision single success, deviceKey=%@, macAddress=%@, address=0x%x, pid=%d", [LibTools convertDataToHexStr:deviceKey], macAddress, address, pid);

                        NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
                        [params setObject:[LibTools getMacStringWithMac:macAddress] forKey:@"macAddress"];
                        [params setObject:[NSNumber numberWithUnsignedShort:address] forKey:@"meshAddress"];
                        [params setObject:[NSNumber numberWithUnsignedShort:pid] forKey:@"productUUID"];
                        [params setObject:[self byteData2Array:deviceKey] forKey:@"dhmKey"];
                        [weakSelf sendEventWithName:@"deviceStatusUpdatingMesh" body:params];
                    } finish:^(NSError * _Nullable error) {
                        if (error) {
                            NSLog(@"TelinkBtSig claimAllAtOnce fail: %@", error);
                            reject(@"keyBind", @"claimAllAtOnce fail", error);
                        } else {
                            NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
                            resolve(params);
                        }
                    }];
                } else {
                    NSLog(@"TelinkBtSig claimAllAtOnce connect fail");
                    reject(@"keyBind", @"claimAllAtOnce connect fail", nil);
                }
            }];
        } else {
            NSLog(@"TelinkBtSig claimAllAtOnce change node fail");
            reject(@"keyBind", @"claimAllAtOnce change node fail", nil);
        }
    }];
}

RCT_EXPORT_METHOD(replaceMeshSetting:(NSString *)netKey appKey:(NSString *)appKey devices:(NSArray *)devices) {
    // to avoid this JS error when Debug(Release is OK):
    // Invariant Violation: No callback found with cbID 7319 and callID 3659 for  TelinkBtSig.getTime - most likely the callback was already invoked. Args: '[{"code":"getTime","message":"getTime fail","domain":"Mesh is disconnected!"
    // need clean commands has resultCallback to JS e.g. getTime()
    [SigMeshLib.share cleanAllCommandsAndRetry];

    // TODO: maybe let not provisionerSno:129 provisionerIvIndex:0 but use current like Android
    [SDKLibCommand stopMeshConnectWithComplete:^(BOOL successflu) {
        [self initMesh:netKey appKey:appKey meshAddressOfApp:self->mMeshAddressOfApp devices:devices provisionerSno:129 provisionerIvIndex:0 isReplaceMeshSetting:true];
        [SigDataSource.share.scanList removeAllObjects];
    }];

}

RCT_EXPORT_METHOD(replaceMeshSetting6:(NSString *)netKey appKey:(NSString *)appKey meshAddressOfApp:(NSInteger)meshAddressOfApp devices:(NSArray *)devices provisionerSno:(NSInteger)provisionerSno provisionerIvIndex:(NSInteger)provisionerIvIndex) {
    // to avoid this JS error when Debug(Release is OK):
    // Invariant Violation: No callback found with cbID 7319 and callID 3659 for  TelinkBtSig.getTime - most likely the callback was already invoked. Args: '[{"code":"getTime","message":"getTime fail","domain":"Mesh is disconnected!"
    // need clean commands has resultCallback to JS e.g. getTime()
    [SigMeshLib.share cleanAllCommandsAndRetry];

    [SDKLibCommand stopMeshConnectWithComplete:^(BOOL successflu) {
        [self initMesh:netKey appKey:appKey meshAddressOfApp:meshAddressOfApp devices:devices provisionerSno:provisionerSno provisionerIvIndex:provisionerIvIndex isReplaceMeshSetting:true];
        [SigDataSource.share.scanList removeAllObjects];
    }];

}

RCT_EXPORT_METHOD(setTime:(NSInteger)meshAddress) {
    // if use SigMeshLib.share.isBusyNow below, will cause
    // 10s busy, so not use SigMeshLib.share.isBusyNow just like android code
    // (if retryCount is 0 will not busy, but still SigDataSource.share.defaultRetryCount
    // as 2 here to match android code DEFAULT_RETRY_CNT = 2 in MeshMessage.java )
//    if (SigMeshLib.share.isBusyNow) {
//        TeLogInfo(@"setTime busy");
//        return;
//    }

    UInt64 second = [LibTools secondsFrome2000];
    [NSTimeZone resetSystemTimeZone];//重置手机系统的时区
    NSInteger offset = [NSTimeZone localTimeZone].secondsFromGMT;
    UInt8 zone_offset = offset/60/15+64;//时区=分/15+64
    TeLogInfo(@"send request for set time, address=0x%04x,second=%llu,zone_offset=%d.", meshAddress, second, zone_offset);
    SigTimeModel *timeModel = [[SigTimeModel alloc] initWithTAISeconds:second subSeconds:0 uncertainty:0 timeAuthority:0 TAI_UTC_Delta:0 timeZoneOffset:zone_offset];
    [SDKLibCommand timeSetWithDestination:meshAddress timeModel:timeModel retryCount:SigDataSource.share.defaultRetryCount responseMaxCount:0 successCallback:^(UInt16 source,UInt16 destination,SigTimeStatus *responseMessage){} resultCallback:^(BOOL isResponseAll, NSError * _Nullable error){}];
}

RCT_EXPORT_METHOD(getTime:(NSInteger)meshAddress relayTimes:(NSInteger)relayTimes resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    // if use SigMeshLib.share.isBusyNow below, will cause
    // 10s busy, so not use SigMeshLib.share.isBusyNow just like android code
    // (if retryCount is 0 will not busy, but still SigDataSource.share.defaultRetryCount
    // as 2 here to match android code DEFAULT_RETRY_CNT = 2 in MeshMessage.java )
//    if (SigMeshLib.share.isBusyNow) {
//        TeLogInfo(@"getTime busy");
//        reject(@"getTime", @"getTime busy", nil);
//        return;
//    }

    [SDKLibCommand timeGetWithDestination:meshAddress retryCount:SigDataSource.share.defaultRetryCount responseMaxCount:0 successCallback:^(UInt16 source, UInt16 destination, SigTimeStatus * _Nonnull responseMessage) {
        UInt64 taiSec = responseMessage.timeModel.TAISeconds;
        UInt64 sec = taiSec + 946684800;

        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSString stringWithFormat:@"%llu",sec] forKey:@"time"];
        resolve(dict);

        NSLog(@"TelinkBtSig onGetTime taiSec: 0x%llx, sec %llu", taiSec, sec);
    } resultCallback:^(BOOL isResponseAll, NSError * _Nullable error) {
        if (!isResponseAll) {
            TeLogInfo(@"getTime fail");
            reject(@"getTime", @"getTime fail", error);
        }
    }];
}

RCT_EXPORT_METHOD(setAlarm:(NSInteger)meshAddress index:(NSInteger)index year:(NSInteger)year month:(NSInteger)month day:(NSInteger)day hour:(NSInteger)hour minute:(NSInteger)minute second:(NSInteger)second week:(NSInteger)week action:(NSInteger)action sceneId:(NSInteger)sceneId) {
    // if use SigMeshLib.share.isBusyNow below, will cause
    // 10s busy, so not use SigMeshLib.share.isBusyNow just like android code
    // (if retryCount is 0 will not busy, but still SigDataSource.share.defaultRetryCount
    // as 2 here to match android code DEFAULT_RETRY_CNT = 2 in MeshMessage.java )
//    if (SigMeshLib.share.isBusyNow) {
//        TeLogInfo(@"setAlarm busy");
//        return;
//    }

    SchedulerModel *model = [[SchedulerModel alloc] init];
    model.schedulerID = index;
    model.year = year;
    model.month = month;
    model.day = day;
    model.hour = hour;
    model.minute = minute;
    model.second = second;
    model.week = week;
    model.action = action;
    model.sceneId = sceneId;

    [SDKLibCommand schedulerActionSetWithDestination:meshAddress schedulerModel:model retryCount:SigDataSource.share.defaultRetryCount responseMaxCount:0 ack:NO successCallback:^(UInt16 source, UInt16 destination, SigSchedulerActionStatus * _Nonnull responseMessage){} resultCallback:^(BOOL isResponseAll, NSError * _Nullable error){}];
}

RCT_EXPORT_METHOD(getAlarm:(NSInteger)meshAddress relayTimes:(NSInteger)relayTimes alarmId:(NSInteger)alarmId resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    // if use SigMeshLib.share.isBusyNow below, will cause
    // 10s busy, so not use SigMeshLib.share.isBusyNow just like android code
    // (if retryCount is 0 will not busy, but still SigDataSource.share.defaultRetryCount
    // as 2 here to match android code DEFAULT_RETRY_CNT = 2 in MeshMessage.java )
//    if (SigMeshLib.share.isBusyNow) {
//        TeLogInfo(@"getAlarm busy");
//        reject(@"getAlarm", @"getAlarm busy", nil);
//        return;
//    }

    [SDKLibCommand schedulerActionGetWithDestination:meshAddress schedulerIndex:alarmId retryCount:SigDataSource.share.defaultRetryCount responseMaxCount:0 successCallback:^(UInt16 source, UInt16 destination, SigSchedulerActionStatus * _Nonnull responseMessage) {
        SchedulerModel *model = responseMessage.schedulerModel;
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInt:(int)[model schedulerID]] forKey:@"alarmId"];
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
    } resultCallback:^(BOOL isResponseAll, NSError * _Nullable error) {
        if (!isResponseAll) {
            TeLogInfo(@"getAlarm fail");
            reject(@"getAlarm", @"getAlarm fail", error);
        }
    }];
}

RCT_EXPORT_METHOD(setNodeGroupAddr:(BOOL)toDel meshAddress:(NSInteger)meshAddress groupAddress:(NSInteger)groupAddress eleIds:(NSArray *)eleIds resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    // if use SigMeshLib.share.isBusyNow below, will cause
    // 10s busy, so not use SigMeshLib.share.isBusyNow just like android code
    // (if retryCount is 0 will not busy, but still SigDataSource.share.defaultRetryCount
    // as 2 here to match android code DEFAULT_RETRY_CNT = 2 in MeshMessage.java )
//    if (SigMeshLib.share.isBusyNow) {
//        TeLogInfo(@"setNodeGroupAddr busy");
//        reject(@"setNodeGroupAddr", @"setNodeGroupAddr busy", nil);
//        return;
//    }

    self->mSetNodeGroupAddrToDel = toDel;
    self->mSetNodeGroupMeshAddr = meshAddress;
    self->mSetNodeGroupAddrGroupAddr = groupAddress;
    self->mSetNodeGroupAddrEleIds = eleIds;
    self->mSetNodeGroupAddrEleIdsIndex = 0;
    self->mSetNodeGroupAddrResolve = resolve;
    self->mSetNodeGroupAddrReject = reject;
    [self setNextModelGroupAddr];
}

- (void) setNextModelGroupAddr {
    if (self->mSetNodeGroupAddrEleIdsIndex > self->mSetNodeGroupAddrEleIds.count - 1) {
        if (self->mSetNodeGroupAddrResolve != nil) {
            NSMutableArray *params = [[NSMutableArray alloc] init];
            self->mSetNodeGroupAddrResolve(params);
        }
        self->mSetNodeGroupAddrResolve = nil;
    } else {
        NSDictionary *eleId = [self->mSetNodeGroupAddrEleIds objectAtIndex:self->mSetNodeGroupAddrEleIdsIndex];
        UInt16 elementAddr = [[eleId objectForKey:@"elementAddr"] intValue];
        UInt32 option = [[eleId objectForKey:@"modelId"] intValue];
        NSLog(@"elementAddr:%x option: %x", elementAddr, option);
        BOOL isSig = [[eleId objectForKey:@"isSig"] boolValue];
        UInt16 modelIdentifier = 0;
        UInt16 companyIdentifier = 0;
        if (isSig) {
            //sig model
            modelIdentifier = option;
        } else {
            //vendor model
            modelIdentifier = (option >> 16) & 0xFFFF;
            companyIdentifier = option & 0xFFFF;
        }

        TeLogInfo(@"send request for edit subscribe list");
        if (self->mSetNodeGroupAddrToDel) {
            [SDKLibCommand configModelSubscriptionDeleteWithDestination:self->mSetNodeGroupMeshAddr groupAddress:self->mSetNodeGroupAddrGroupAddr elementAddress:elementAddr modelIdentifier:modelIdentifier companyIdentifier:companyIdentifier retryCount:SigDataSource.share.defaultRetryCount responseMaxCount:0 successCallback:onGetModelSubscription resultCallback:^(BOOL isResponseAll, NSError * _Nullable error) {
                if (!isResponseAll) {
                    if (self->mSetNodeGroupAddrReject != nil) {
                        self->mSetNodeGroupAddrReject(@"setSubscription", @"setSubscription return false", nil);
                    }
                    self->mSetNodeGroupAddrReject = nil;
                }
            }];
        } else {
            [SDKLibCommand configModelSubscriptionAddWithDestination:self->mSetNodeGroupMeshAddr toGroupAddress:self->mSetNodeGroupAddrGroupAddr elementAddress:elementAddr modelIdentifier:modelIdentifier companyIdentifier:companyIdentifier retryCount:SigDataSource.share.defaultRetryCount responseMaxCount:0 successCallback:onGetModelSubscription resultCallback:^(BOOL isResponseAll, NSError * _Nullable error) {
                if (!isResponseAll) {
                    if (self->mSetNodeGroupAddrReject != nil) {
                        self->mSetNodeGroupAddrReject(@"setSubscription", @"setSubscription return false", nil);
                    }
                    self->mSetNodeGroupAddrReject = nil;
                }
            }];
        }
    }
}

@end
