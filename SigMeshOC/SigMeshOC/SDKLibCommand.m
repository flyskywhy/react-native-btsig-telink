/********************************************************************************************************
 * @file     SDKLibCommand.m 
 *
 * @brief    for TLSR chips
 *
 * @author	 telink
 * @date     Sep. 30, 2010
 *
 * @par      Copyright (c) 2010, Telink Semiconductor (Shanghai) Co., Ltd.
 *           All rights reserved.
 *           
 *			 The information contained herein is confidential and proprietary property of Telink 
 * 		     Semiconductor (Shanghai) Co., Ltd. and is available under the terms 
 *			 of Commercial License Agreement between Telink Semiconductor (Shanghai) 
 *			 Co., Ltd. and the licensee in separate contract or the terms described here-in. 
 *           This heading MUST NOT be removed from this file.
 *
 * 			 Licensees are granted free, non-transferable use of the information in this 
 *			 file under Mutual Non-Disclosure Agreement. NO WARRENTY of ANY KIND is provided. 
 *           
 *******************************************************************************************************/
//
//  SDKLibCommand.m
//  SigMeshOC
//
//  Created by Liangjiazhi on 2018/7/12.
//  Copyright © 2018年 Telink. All rights reserved.
//

#import "SDKLibCommand.h"

@implementation SDKLibCommand

+ (void)startMeshSDK {
    [SigDataSource.share configData];
    APP_reset_vendor_id(kCompanyID);
}

- (void)future {
    TeLog(@"this is doomsday");
}

- (BOOL)isBusy {
    if (self.busyTimer) {
        [[NSNotificationCenter defaultCenter] postNotificationName:NotifyCommandIsBusyOrNot object:nil userInfo:@{CommandIsBusyKey : @YES}];
        return YES;
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:NotifyCommandIsBusyOrNot object:nil userInfo:@{CommandIsBusyKey : @NO}];
        self.busyTimer = [NSTimer scheduledTimerWithTimeInterval:[NSDate distantFuture].timeIntervalSinceNow target:self selector:@selector(future) userInfo:nil repeats:NO];
        [[NSRunLoop currentRunLoop] addTimer:self.busyTimer forMode:NSRunLoopCommonModes];
        return NO;
    }
}


#pragma mark - Control（open API）
/**
 if you need do provision , you should call this method, and it'll call back what you need
 
 @param address address of new device
 @param networkKey network key, which provsion need, you can see it as password of the mesh
 @param netkeyIndex netkey index
 @param unicastAddress address of remote device
 @param uuid uuid of remote device
 @param type KeyBindTpye_Normal是普通添加模式，KeyBindTpye_Quick是快速添加模式
 @param isAuto 添加完成一个设备后，是否自动扫描添加下一个设备
 @param provisionSuccess call back when a device provision successful
 @param keyBindSuccess call back when a device keybind successful
 @param fail call back when a device add to the mesh fail
 @param finish finish add the available devices list to the mesh
 */
- (void)startAddDeviceWithNextAddress:(UInt16)address networkKey:(NSData *)networkKey netkeyIndex:(UInt16)netkeyIndex unicastAddress:(UInt16)unicastAddress uuid:(NSData *)uuid keyBindType:(KeyBindTpye)type isAutoAddNextDevice:(BOOL)isAuto provisionSuccess:(addDevice_prvisionSuccessCallBack)provisionSuccess keyBindSuccess:(addDevice_keyBindSuccessCallBack)keyBindSuccess fail:(prvisionFailCallBack)fail finish:(prvisionFinishCallBack)finish {
    [Bluetooth.share startAddDeviceWithNextAddress:address networkKey:networkKey netkeyIndex:netkeyIndex unicastAddress:unicastAddress uuid:uuid keyBindType:type isAutoAddNextDevice:isAuto provisionSuccess:provisionSuccess keyBindSuccess:keyBindSuccess fail:fail finish:finish];
}

/**
 if you need do provision , you should call this method, and it'll call back what you need
 
 @param address address of new device
 @param networkKey network key, which provsion need, you can see it as password of the mesh
 @param netkeyIndex netkey index
 @param peripheral device need add to mesh
 @param type KeyBindTpye_Normal是普通添加模式，KeyBindTpye_Quick是快速添加模式
 @param provisionSuccess call back when a device provision successful
 @param keyBindSuccess call back when a device keybind successful
 @param fail call back when a device add to the mesh fail
 @param finish finish add the available devices list to the mesh
 */
- (void)startAddDeviceWithNextAddress:(UInt16)address networkKey:(NSData *)networkKey netkeyIndex:(UInt16)netkeyIndex peripheral:(CBPeripheral *)peripheral keyBindType:(KeyBindTpye)type provisionSuccess:(addDevice_prvisionSuccessCallBack)provisionSuccess keyBindSuccess:(addDevice_keyBindSuccessCallBack)keyBindSuccess fail:(prvisionFailCallBack)fail finish:(prvisionFinishCallBack)finish{
    [Bluetooth.share startAddDeviceWithNextAddress:address networkKey:networkKey netkeyIndex:netkeyIndex peripheral:peripheral keyBindType:type provisionSuccess:provisionSuccess keyBindSuccess:keyBindSuccess fail:fail finish:finish];
}

/// get max scan items count
- (void)getRemoteProvisioningMaxScannedItemsWithCallback:(remoteProvisioningMaxScannedItemsCallBack)callback{
    self.maxScannedItemsCallBack = callback;
    SigNodeModel *node = [SigDataSource.share getNodeWithUUID:Bluetooth.share.currentPeripheral.identifier.UUIDString];
    if (node) {
        mesh_cmd_sig_rp_cli_send_capa(node.address);
    } else {
        TeLog(@"warning: There is no direct connect devices.");
    }
}


/// get uuid of remote
- (void)startRemoteProvisioningScanWithAddress:(UInt16)address limit:(UInt8)limit timeout:(NSTimeInterval)timeout callback:(remoteProvisioningScanCallBack)callback{
    self.remoteScanRspCallBack = callback;
    send_rp_scan_start(address,limit,timeout);
}


///before remote add，set remote add device info
- (void)setRemoteAddDeviceInfoWithUnicastAddress:(UInt16)unicastAddress uuid:(NSData *)uuid complete:(responseModelCallBack)complete{
    self.setUUIDResultCallBack = complete;
    mesh_rp_start_settings((u16)unicastAddress,(u8 *)uuid.bytes);
}


- (void)startFastProvisionAddDevicesWithPID:(UInt16)pid addSingleDeviceSuccessCallback:(addSingleDeviceSuccessCallBack)singleSuccess finish:(prvisionFinishCallBack)finish {
    self.fastProvisionAddSingleDeviceSuccessCallBack = singleSuccess;
    self.fastProvisionAddDeviceFinishCallBack = finish;
    mesh_fast_prov_start(pid);
}


/**
 function :connect bluetooth device（正常扫描连接蓝牙设备）
if you did provision process , you could call this method, and it'll call back what you need
 
 @param availableList the devices you added(注意：SDK收到非该数组的设备的数据是不会处理的)
 @param canControl you can send command to theos devices
 */
- (void)startWorkNormal:(NSArray <NSString *>*)availableList CanControl:(workWithPeripheralCallBack)canControl NS_DEPRECATED_IOS(2_0, 9_0, "Use -startWorkNormalWithComplete:") __TVOS_PROHIBITED {
    [Bluetooth.share startWorkNormal:availableList canControl:canControl];
}


- (void)startWorkNormalWithComplete:(workWithPeripheralCallBack)complete{
    [Bluetooth.share startWorkNormalWithComplete:complete];
}


/**
 function :turn on or turn off the lights part（开关）
 response data like : <f0090100 ff7f8204 000000>
 
 @param executeCommand send data immediately
 @param on 1 means on ,and 0 means off
 @param address the src adr you will send to the cmd .
 @param resMax means after sending the parameter,it will how many different packets back,0 means no ack
 @param ack if need response
 @param complete call back
 */
- (void)switchOnOffWithExecuteCommand:(BOOL)executeCommand on:(BOOL)on address:(UInt16)address resMax:(int)resMax ack:(BOOL)ack Completation:(responseModelCallBack)complete {
    if (ack && executeCommand && resMax > 0) {
        if ([self isBusy]) {
            return;
        }
    }
    self.switchOnOffCallBack = complete;
    if (executeCommand) {
        access_cmd_onoff(address, (u8)resMax, (u8)(on ? 1 : 0), ack?1:0, nil);
        //test，call api without response.
//        access_cmd_onoff(address, (u8)0, (u8)(on ? 1 : 0), ack?0:0, nil);
    }
}


/**
 change brightness call back（亮度）

 @param executeCommand send data immediately
 @param address the src adr you will send to the cmd .
 @param para parameters
 @param isGet get/edit
 @param ack if need response
 @param complete call back
 */
- (void)changeBrightnessWithExecuteCommand:(BOOL)executeCommand address:(UInt16)address para:(float)para isGet:(BOOL)isGet respondMax:(int)respondMax ack:(BOOL)ack Completation:(responseModelCallBack)complete {
    if (ack && executeCommand && respondMax > 0) {
        if ([self isBusy]) {
            return;
        }
    }
    self.changeBrightnessCallBack = complete;
    if (executeCommand) {
        if (isGet) {
            access_get_lum(address, (u32)respondMax);
        } else {
            access_set_lum(address, (u8)respondMax, (u8)para, ack?1:0);
        }
    }
}



/**
 change temprature call back（色温）

 @param executeCommand send data immediately
 @param address the src adr you will send to the cmd .
 @param para parameters
 @param isGet get/edit
 @param ack if need response
 @param complete call back
 */
- (void)changeTempratureWithExecuteCommand:(BOOL)executeCommand address:(UInt16)address para:(float)para isGet:(BOOL)isGet respondMax:(int)respondMax ack:(BOOL)ack Completation:(responseModelCallBack)complete {
    if (ack && executeCommand && respondMax > 0) {
        if ([self isBusy]) {
            return;
        }
    }
    self.changeTemperatureCallBack = complete;
    if (executeCommand) {
        if (isGet) {
            access_cmd_get_light_ctl_temp(address, (u32)respondMax);
        }else{
            access_cmd_set_light_ctl_temp_100(address, (u8)respondMax, (u8)para, ack?1:0);
        }
    }
}


/**
 change HSL call back（HSL）
 
 @param executeCommand send data immediately
 @param address the src adr you will send to the cmd .
 @param hue hue
 @param saturation saturation
 @param brightness brightness
 @param isGet get/edit
 @param ack if need response
 @param complete call back
 */
- (void)changeHSLWithExecuteCommand:(BOOL)executeCommand address:(UInt16)address hue:(UInt8)hue saturation:(UInt8)saturation brightness:(UInt8)brightness isGet:(BOOL)isGet respondMax:(int)respondMax ack:(BOOL)ack Completation:(responseModelCallBack)complete {
    if (ack && executeCommand && respondMax > 0) {
        if ([self isBusy]) {
            return;
        }
    }
    self.changeHSLCallBack = complete;
    if (executeCommand) {
        if (isGet) {
            access_cmd_get_light_hsl(address, (u32)respondMax);
        }else{
            transition_par_t trans;
            trans.delay = 0;
            trans.transit_t = 0;
            //注意，第六个参数为0则没有response，为1则有response。
            access_cmd_set_light_hsl_100(address, (u8)respondMax, (u8)brightness, (u8)hue, (u8)saturation, ack?1:0, &trans);
        }
    }
}


/**
 change level call back（Level）
 
 @param executeCommand send data immediately
 @param address the src adr you will send to the cmd .
 @param level parameters
 @param isGet get/edit
 @param ack if need response
 @param complete call back
 */
- (void)changeLevelWithExecuteCommand:(BOOL)executeCommand address:(UInt16)address level:(s16)level isGet:(BOOL)isGet respondMax:(int)respondMax ack:(BOOL)ack Completation:(responseModelCallBack)complete {
    if (ack && executeCommand && respondMax > 0) {
        if ([self isBusy]) {
            return;
        }
    }
    self.changeLevelCallBack = complete;
    if (executeCommand) {
        if (isGet) {
            access_cmd_get_level(address, (u32)respondMax);
        } else {
            transition_par_t trans;
            trans.delay = 0;
            trans.transit_t = 0;
            access_cmd_set_delta(address, (u8)respondMax, level, ack?1:0, &trans);
        }
    }
}


/**
 get subscribe list（获取当单灯的组地址，注意：开关、亮度等配置不同，组地址列表可能存在不同，默认获取开关配置的组地址列表。）
client, subscribe list : <f00d0100 ff7f802a 00010001 1001c0>
server, subscribe list : <f00d0100 ff7f802a 00010000 1001c0>
one more : <f00f0100 ff7f802a 00010000 1001c000 c0>
 
 @param executeCommand send data immediately
 @param address device's address which should response
 @param isClient client / server
 @param complete call back
 */
- (void)getSubscribeList:(BOOL)executeCommand address:(UInt16)address isClient:(BOOL)isClient complete:(responseModelCallBack)complete {
    if (executeCommand) {
        if ([self isBusy]) {
            return;
        }
    }
    self.getSubscribeListCallBack = complete;
    if (executeCommand) {
        u16 tem = isClient ? (u16)SIG_MD_G_ONOFF_C : (u16)SIG_MD_G_ONOFF_S;
        cfg_cmd_sub_get(address, address, tem);
    }
}


/**
 change subscribe list（编辑单灯的组地址，包括添加、删除。注意：SDK提供了大量的option，详细值可参考lib里面mesh_node.h的line129开始的宏定义。）
response data like :
 client, cancel subscribe: <f00d0100 ff7f801f 00010001 c00110>
 client,        subscribe: <f00d0100 ff7f801f 00010001 c00110>
 server, cancel subscribe: <f00d0100 ff7f801f 00010001 c00010>
 server,        subscribe: <f00d0100 ff7f801f 00010001 c00010> // use for group control
 
 @param executeCommand send data immediately
 @param groAdd subscribe address
 @param nodeAddress device's address which should response
 @param eleAddress device's element address which should response
 @param add subscribe/cancel subscribe
 @param option eg: SIG_MD_G_ONOFF_C、SIG_MD_G_ONOFF_S
 @param complete call back
 */
- (void)editSubscribeListWithExecuteCommand:(BOOL)executeCommand groAdd:(UInt16)groAdd nodeAddress:(UInt16)nodeAddress eleAddress:(UInt16)eleAddress add:(BOOL)add option:(UInt32)option Completation:(responseModelCallBack)complete {
    if (executeCommand) {
        if ([self isBusy]) {
            return;
        }
    }
    self.editSubscribeListCallBack = complete;
    if (executeCommand) {
        u16 op = (u16)(add ? OpcodeSubscriptorAddRequest : OpcodeSubscriptorDelRequest);
        cfg_cmd_sub_set(op, nodeAddress, eleAddress, groAdd, (u32)option, kSigmodel_SIGParameters);
    }
}


/**
 change publish list（编辑单灯的publish地址，色温灯配置CTL model，RGB灯配置HSL model。配置pub_adr传0xff，取消传0x0。）
 
 @param executeCommand send data immediately
 @param pub_adr publish address
 @param nodeAddress device's address which should response
 @param eleAddress device's element address which should response
 @param option eg: SIG_MD_G_ONOFF_C、SIG_MD_G_ONOFF_S
 @param period period.steps:The number of steps,period.res:The resolution of the Number of Steps field. Document in "Mesh_v1.0.pdf",page 137.
 @param complete call back
 */
- (void)editPublishListWithExecuteCommand:(BOOL)executeCommand publishAddress:(UInt16)pub_adr nodeAddress:(UInt16)nodeAddress eleAddress:(UInt16)eleAddress option:(UInt32)option period:(mesh_pub_period_t)period Completation:(responseModelCallBack)complete {
    if (executeCommand) {
        if ([self isBusy]) {
            return;
        }
    }
    self.publishListResponseCallBack = complete;
    if (executeCommand) {
        mesh_model_pub_par_t par_t;
        par_t.appkey_idx = 0;
        par_t.credential_flag = 0;
        par_t.rfu = 0;
        par_t.ttl = 0xff;//0xFF(表示采用节点默认参数)
        par_t.period = period;
        mesh_transmit_t transmit;
        transmit.val = 0x15;//0x15, count = 2, invl_steps = 5
        par_t.transmit = transmit;
        cfg_cmd_pub_set(nodeAddress, eleAddress, pub_adr, &par_t, (u32)option, kSigmodel_SIGParameters);
    }
}


/**
 get Publish Address
 
 @param executeCommand send data immediately
 @param nodeAddress device's address which should response
 @param eleAddress device's eleAddress address which should response
 @param option eg: SIG_MD_G_ONOFF_C、SIG_MD_G_ONOFF_S
 @param complete call back
 */
- (void)getPublishAddressWithExecuteCommand:(BOOL)executeCommand nodeAddress:(UInt16)nodeAddress eleAddress:(UInt16)eleAddress option:(UInt32)option Completation:(responseModelCallBack)complete {
    if (executeCommand) {
        if ([self isBusy]) {
            return;
        }
    }
    self.publishListResponseCallBack = complete;
    if (executeCommand) {
        cfg_cmd_pub_get(nodeAddress, eleAddress, (u32)option, kSigmodel_SIGParameters);
    }
}


/**
 Get Online device, publish use access_cmd_onoff_get()

 @param executeCommand send data immediately
 @param reqCount wether is need response
 @param complete call back
 @return wether is send Bluetooth packet
 */
- (BOOL)getOnlineStatusWithExecuteCommand:(BOOL)executeCommand reqCount:(int)reqCount Completation:(responseModelCallBack)complete {
    if (executeCommand) {
        if ([self isBusy]) {
            return NO;
        }
    }
    self.getOnlineStatusCallBack = complete;
    if (executeCommand) {
//        access_cmd_get_light_ctl(0xffff, (u32)reqCount);//v2.5及之前使用的API，当前依然可以，看客户取舍(纯lum的设备，该接口获取不到状态数据)
//        access_get_lum(0xffff, (u32)reqCount);//v2.6版本统一使用获取lum做设备在线状态判断。
        access_cmd_onoff_get(0xffff, (u32)reqCount);//v2.7版本统一使用获取开关做设备在线状态判断。
    }
    return YES;
}


/// Get Online device, private use OnlineStatusCharacteristic
- (BOOL)getOnlineStatusFromUUIDWithCompletation:(responseModelCallBack)complete{
    if ([self isBusy]) {
        return NO;
    }
    if (Bluetooth.share.store.OnlineStatusCharacteristic != nil) {
        self.getOnlineStatusCallBack = complete;
        [Bluetooth.share getOnlineStatueFromUUID];
        return YES;
    }
    return NO;
}


/**
 get device lum（获取设备亮度）

 @param executeCommand send data immediately
 @param nodeAddress device's address which should response
 @param reqCount wether is need response
 @param complete call back
 @return wether is send Bluetooth packet
 */
- (BOOL)getLumWithExecuteCommand:(BOOL)executeCommand nodeAddress:(UInt16)nodeAddress reqCount:(int)reqCount Completation:(responseModelCallBack)complete {
    if (executeCommand) {
        if ([self isBusy]) {
            return NO;
        }
    }
    self.changeBrightnessCallBack = complete;
    if (executeCommand) {
        access_get_lum((u16)nodeAddress, (u32)reqCount);
    }
    return YES;
}

/**
 Get CTL, (Lum and Temprature)

 @param executeCommand send data immediately
 @param nodeAddress device's address which should response
 @param reqCount wether is need response
 @param complete call back
 @return wether is send Bluetooth packet
 */
- (BOOL)getCTLWithExecuteCommand:(BOOL)executeCommand nodeAddress:(UInt16)nodeAddress reqCount:(int)reqCount Completation:(responseModelCallBack)complete {
    if (executeCommand) {
        if ([self isBusy]) {
            return NO;
        }
    }
    self.changeTemperatureCallBack = complete;
    if (executeCommand) {
        access_cmd_get_light_ctl((u16)nodeAddress, (u32)reqCount);
    }
    return YES;
}


/**
 Get provision Status

 @param success success
 @param fail fail
 */
//- (void)provisionStatus:(resultCallBack)success fail:(resultCallBack)fail {
//    int state = get_provision_state();
//    if (state != 0) {
//        if (success) {
//            success();
//        }
//    } else {
//        if (fail) {
//            fail();
//        }
//    }
//}


/**
 Kick out

 @param address address
 */
- (void)kickoutDevice:(UInt16)address complete:(resultCallBack)complete {
    if ([self isBusy]) {
        return;
    }
    self.delectDeviceCallBack = complete;
    [[Bluetooth share] kickOut:address];
}


///provisionLocation
///- before you do provision, you should do local provision first, if you did it, and you need't do it again
- (void)provisionLocation:(NSData *)netkeydata withLocationAddress:(int)locationAddress netketIndex:(u16)netketIndex{
    provisionLocal(netkeydata,locationAddress,netketIndex);
}


///provision
- (void)provisionMesh:(NSData *)netkeydata address:(UInt16)address netkeyIndex:(u16)netkeyIndex{
    provision(netkeydata, address,netkeyIndex);
}


///sendOTAData
- (void)sendOTAData:(NSData *)data index:(int)index {
    sendData(data, index);
}


- (void)keyBind:(u16)address appkey:(NSData *)appkey appkeyIndex:(u16)appkeyIndex netkeyIndex:(u16)netkeyIndex keyBindType:(KeyBindTpye)type keyBindSuccess:(addDevice_keyBindSuccessCallBack)keyBindSuccess fail:(prvisionFailCallBack)fail {
    [[Bluetooth share] keyBind:address appkey:appkey appkeyIndex:appkeyIndex netkeyIndex:netkeyIndex keyBindType:type keyBindSuccess:keyBindSuccess fail:fail];
}


/**
 refresh modelID
 */
- (void)refreshModelIDList{
    refreshKeyBindModelID();
}


/**
 sendCommandData

 @param address node address
 @param rsp_max response max count
 @param opcode opcode
 @param data custom data
 @return 0 means send success，-1 means send fail(eg:the length of data is longger than MESH_CMD_ACCESS_LEN_MAX.)
 */
- (int)sendCommandData:(UInt16)address rsp_max:(UInt8)rsp_max opcode:(UInt16)opcode data:(NSData *)data {
    u8 *par = (u8 *)data.bytes;
    return SendOpParaDebug(address, rsp_max, opcode, par, (int)data.length);
}


/// setNowTime
- (void)setNowTimeWithComplete:(resultCallBack)complete{
    if (complete) {
        self.setTimeCallBack = complete;
    }
    time_status_t time = (time_status_t){0,0,0,0,0,0,0};
    time.TAI_sec = (u32)[LibTools secondsFrome2000];
    
    [NSTimeZone resetSystemTimeZone]; // 重置手机系统的时区
    NSInteger offset = [NSTimeZone localTimeZone].secondsFromGMT;

    time.zone_offset = offset/60/15+64;//时区=分/15+64
    TeLog(@"设置秒数：%d，时区：%d",time.TAI_sec,time.zone_offset);
    access_cmd_time_set(0xffff,0,&time);
}

- (void)statusNowTime {
    time_status_t time = (time_status_t){0,0,0,0,0,0,0};
    time.TAI_sec = (u32)[LibTools secondsFrome2000];
    
    [NSTimeZone resetSystemTimeZone]; // 重置手机系统的时区
    NSInteger offset = [NSTimeZone localTimeZone].secondsFromGMT;

    time.zone_offset = offset/60/15+64;//时区=分/15+64
    time.time_auth = 1;//每次无条件接受这个时间指令。
    TeLog(@"设置秒数：%d，时区：%d",time.TAI_sec,time.zone_offset);
    SendOpParaDebug(0xffff, 0, TIME_STATUS, (u8 *)&time, sizeof(time_status_t));
}

/// save scene
- (void)saveSceneWithAddress:(u16)address resMax:(u32)resMax sceneId:(u16)sceneId Completation:(responseModelCallBack)complete{
    int ack = 0;
    if (complete && resMax > 0) {
        if ([self isBusy]) {
            return;
        }
        ack = 1;
        self.saveSceneCallBack = complete;
    }
    access_cmd_scene_store(address,resMax,sceneId,ack);
}


/// recall scene
- (void)recallSceneWithAddress:(u16)address resMax:(u32)resMax sceneId:(u16)sceneId Completation:(responseModelCallBack)complete{
    int ack = 0;
    if (complete && resMax > 0) {
        if ([self isBusy]) {
            return;
        }
        ack = 1;
        self.recallSceneCallBack = complete;
    }
    transition_par_t trans = (transition_par_t){};
    trans.delay = 0;
    trans.transit_t = 0;
    access_cmd_scene_recall(address,resMax,sceneId,ack,&trans);
}


/// delete scene
- (void)delSceneWithAddress:(u16)address resMax:(u32)resMax sceneId:(u16)sceneId Completation:(responseModelCallBack)complete{
    int ack = 0;
    if (complete && resMax > 0) {
        if ([self isBusy]) {
            return;
        }
        ack = 1;
        self.delSceneCallBack = complete;
    }
    access_cmd_scene_del(address,resMax,sceneId,ack);
}

/// get scene register status
- (void)getSceneRegisterStatusWithAddress:(u16)address resMax:(u32)resMax Completation:(responseModelCallBack)complete{
    if ([self isBusy]) {
        return;
    }

    self.delSceneCallBack = complete;
    access_cmd_scene_reg_get(address, resMax);
}

/// set scheduler action
- (void)setSchedulerActionWithAddress:(u16)address resMax:(u32)resMax schedulerModel:(SchedulerModel *)schedulerModel Completation:(responseModelCallBack)complete{
    int ack = 0;
    if (complete && resMax > 0) {
        if ([self isBusy]) {
            return;
        }
        ack = 1;
        self.setSchedulerActionCallBack = complete;
    }
    scheduler_t scheduler = (scheduler_t){0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
    scheduler.valid_flag_or_idx = schedulerModel.schedulerID;
    scheduler.year = schedulerModel.year;
    scheduler.month = schedulerModel.month;
    scheduler.day = schedulerModel.day;
    scheduler.hour = schedulerModel.hour;
    scheduler.minute = schedulerModel.minute;
    scheduler.second = schedulerModel.second;
    scheduler.week = schedulerModel.week;
    scheduler.action = schedulerModel.action;
    scheduler.trans_t = 0;
    scheduler.scene_id = schedulerModel.sceneId;
    scheduler.rand_hour = 0;
    scheduler.rand_min = 0;
    scheduler.rand_sec = 0;
    scheduler.rsv = 0;
//    NSData *data = [[NSData alloc] initWithBytes:&scheduler length:8];
//    TeLog(@"scheduler=%016llX,schedulerData=%016llX",[LibTools NSDataToUInt:data],schedulerModel.schedulerData);
    access_cmd_schd_action_set(address,resMax,&scheduler,ack);
}

/// get scheduler status
- (void)getSchedulerStatusWithAddress:(u16)address resMax:(u32)resMax Completation:(responseModelCallBack)complete {
    if ([self isBusy]) {
        return;
    }
    self.getSchedulerStatusCallBack = complete;
    access_cmd_schd_get(address, resMax);
}

/// get scheduler action
- (void)getSchedulerActionWithAddress:(u16)address resMax:(u32)resMax schedulerModelID:(u8)schedulerModelID Completation:(responseModelCallBack)complete {
    if ([self isBusy]) {
        return;
    }
    self.getSchedulerActionCallBack = complete;
    access_cmd_schd_action_get(address,resMax,schedulerModelID);
}

/// get fw info
- (void)getFwInfoWithAddress:(u16)address Completation:(responseModelCallBack)complete{
    if ([self isBusy]) {
        return;
    }

    self.getFwInfoCallBack = complete;
    access_cmd_fw_info_get(address);
}

@end