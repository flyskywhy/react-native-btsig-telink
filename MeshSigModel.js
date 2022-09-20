// ref to android/src/main/java/com/telink/ble/mesh/core/message/MeshSigModel.java

class MeshSigModel {
    static allList = {
        SIG_MD_CFG_SERVER: {modelId: 0x0000, modelName: "config server", group: "", deviceKeyEnc: true, isSig: true},
        SIG_MD_CFG_CLIENT: {modelId: 0x0001, modelName: "config client", group: "", deviceKeyEnc: true, isSig: true},


        SIG_MD_HEALTH_SERVER: {modelId: 0x0002, modelName: "health server", group: "health server", deviceKeyEnc: false, isSig: true},
        SIG_MD_HEALTH_CLIENT: {modelId: 0x0003, modelName: "health client", group: "health client", deviceKeyEnc: false, isSig: true},


        SIG_MD_REMOTE_PROV_SERVER: {modelId: 0x0004, modelName: "rp", group: "", deviceKeyEnc: true, isSig: true},
        SIG_MD_REMOTE_PROV_CLIENT: {modelId: 0x0005, modelName: "rp", group: "", deviceKeyEnc: true, isSig: true},
        SIG_MD_DF_CFG_S: {modelId: 0xBF30, modelName: "", group: "df cfg server", deviceKeyEnc: true, isSig: true},
        SIG_MD_DF_CFG_C: {modelId: 0xBF31, modelName: "", group: "df cfg client", deviceKeyEnc: true, isSig: true},
        SIG_MD_BRIDGE_CFG_SERVER: {modelId: 0xBF32, modelName: "", group: "", deviceKeyEnc: true, isSig: true},
        SIG_MD_BRIDGE_CFG_CLIENT: {modelId: 0xBF33, modelName: "", group: "", deviceKeyEnc: true, isSig: true},

        SIG_MD_PRIVATE_BEACON_SERVER: {modelId: 0xBF40, modelName: "", group: "", deviceKeyEnc: true, isSig: true},
        SIG_MD_PRIVATE_BEACON_CLIENT: {modelId: 0xBF41, modelName: "", group: "", deviceKeyEnc: true, isSig: true},


        SIG_MD_G_ONOFF_S: {modelId: 0x1000, modelName: "Generic OnOff Server", group: "Generic", isSig: true},
        SIG_MD_G_ONOFF_C: {modelId: 0x1001, modelName: "Generic OnOff Client", group: "Generic", isSig: true},
        SIG_MD_G_LEVEL_S: {modelId: 0x1002, modelName: "Generic Level Server", group: "Generic", isSig: true},
        SIG_MD_G_LEVEL_C: {modelId: 0x1003, modelName: "Generic Level Client", group: "Generic", isSig: true},
        SIG_MD_G_DEF_TRANSIT_TIME_S: {modelId: 0x1004, modelName: "Generic Default Transition Time Server ", group: "Generic", isSig: true},
        SIG_MD_G_DEF_TRANSIT_TIME_C: {modelId: 0x1005, modelName: "Generic Default Transition Time Client ", group: "Generic", isSig: true},
        SIG_MD_G_POWER_ONOFF_S: {modelId: 0x1006, modelName: "Generic Power OnOff Server", group: "Generic", isSig: true},
        SIG_MD_G_POWER_ONOFF_SETUP_S: {modelId: 0x1007, modelName: "Generic Power OnOff Setup Server", group: "Generic", isSig: true},
        SIG_MD_G_POWER_ONOFF_C: {modelId: 0x1008, modelName: "Generic Power OnOff Client", group: "Generic", isSig: true},
        SIG_MD_G_POWER_LEVEL_S: {modelId: 0x1009, modelName: "Generic Power Level Server", group: "Generic", isSig: true},
        SIG_MD_G_POWER_LEVEL_SETUP_S: {modelId: 0x100A, modelName: "Generic Power Level Setup Server", group: "Generic", isSig: true},
        SIG_MD_G_POWER_LEVEL_C: {modelId: 0x100B, modelName: "Generic Power Level Client", group: "Generic", isSig: true},
        SIG_MD_G_BAT_S: {modelId: 0x100C, modelName: "Generic Battery Server", group: "Generic", isSig: true},
        SIG_MD_G_BAT_C: {modelId: 0x100D, modelName: "Generic Battery Client", group: "Generic", isSig: true},
        SIG_MD_G_LOCATION_S: {modelId: 0x100E, modelName: "Generic Location Server", group: "Generic", isSig: true},
        SIG_MD_G_LOCATION_SETUP_S: {modelId: 0x100F, modelName: "Generic Location Setup Server", group: "Generic", isSig: true},
        SIG_MD_G_LOCATION_C: {modelId: 0x1010, modelName: "Generic Location Client", group: "Generic", isSig: true},
        SIG_MD_G_ADMIN_PROP_S: {modelId: 0x1011, modelName: "Generic Admin Property Server", group: "Generic", isSig: true},
        SIG_MD_G_MFR_PROP_S: {modelId: 0x1012, modelName: "Generic Manufacturer Property Server", group: "Generic", isSig: true},
        SIG_MD_G_USER_PROP_S: {modelId: 0x1013, modelName: "Generic User Property Server", group: "Generic", isSig: true},
        SIG_MD_G_CLIENT_PROP_S: {modelId: 0x1014, modelName: "Generic Client Property Server", group: "Generic", isSig: true},
        SIG_MD_G_PROP_C: {modelId: 0x1015, modelName: "Generic Property Client", group: "Generic", isSig: true}, // original: SIG_MD_G_PROP_S (may be err)

        SIG_MD_SENSOR_S: {modelId: 0x1100, modelName: "Sensor Server", group: "Sensors", isSig: true},
        SIG_MD_SENSOR_SETUP_S: {modelId: 0x1101, modelName: "Sensor Setup Server", group: "Sensors", isSig: true},
        SIG_MD_SENSOR_C: {modelId: 0x1102, modelName: "Sensor Client", group: "Sensors", isSig: true},

        SIG_MD_TIME_S: {modelId: 0x1200, modelName: "Time Server", group: "Time and Scenes", isSig: true},
        SIG_MD_TIME_SETUP_S: {modelId: 0x1201, modelName: "Time Setup Server", group: "Time and Scenes", isSig: true},
        SIG_MD_TIME_C: {modelId: 0x1202, modelName: "Time Client", group: "Time and Scenes", isSig: true},
        SIG_MD_SCENE_S: {modelId: 0x1203, modelName: "Scene Server", group: "Time and Scenes", isSig: true},
        SIG_MD_SCENE_SETUP_S: {modelId: 0x1204, modelName: "Scene Setup Server", group: "Time and Scenes", isSig: true},
        SIG_MD_SCENE_C: {modelId: 0x1205, modelName: "Scene Client", group: "Time and Scenes", isSig: true},
        SIG_MD_SCHED_S: {modelId: 0x1206, modelName: "MeshScheduler Server", group: "Time and Scenes", isSig: true},
        SIG_MD_SCHED_SETUP_S: {modelId: 0x1207, modelName: "MeshScheduler Setup Server", group: "Time and Scenes", isSig: true},
        SIG_MD_SCHED_C: {modelId: 0x1208, modelName: "MeshScheduler Client", group: "Time and Scenes", isSig: true},

        SIG_MD_LIGHTNESS_S: {modelId: 0x1300, modelName: "Light Lightness Server", group: "Lighting", isSig: true},
        SIG_MD_LIGHTNESS_SETUP_S: {modelId: 0x1301, modelName: "Light Lightness Setup Server", group: "Lighting", isSig: true},
        SIG_MD_LIGHTNESS_C: {modelId: 0x1302, modelName: "Light Lightness Client", group: "Lighting", isSig: true},
        SIG_MD_LIGHT_CTL_S: {modelId: 0x1303, modelName: "Light CTL Server", group: "Lighting", isSig: true},
        SIG_MD_LIGHT_CTL_SETUP_S: {modelId: 0x1304, modelName: "Light CTL Setup Server", group: "Lighting", isSig: true},
        SIG_MD_LIGHT_CTL_C: {modelId: 0x1305, modelName: "Light CTL Client", group: "Lighting", isSig: true},
        SIG_MD_LIGHT_CTL_TEMP_S: {modelId: 0x1306, modelName: "Light CTL Temperature Server", group: "Lighting", isSig: true},
        SIG_MD_LIGHT_HSL_S: {modelId: 0x1307, modelName: "Light HSL Server", group: "Lighting", isSig: true},
        SIG_MD_LIGHT_HSL_SETUP_S: {modelId: 0x1308, modelName: "Light HSL Setup Server", group: "Lighting", isSig: true},
        SIG_MD_LIGHT_HSL_C: {modelId: 0x1309, modelName: "Light HSL Client", group: "Lighting", isSig: true},
        SIG_MD_LIGHT_HSL_HUE_S: {modelId: 0x130A, modelName: "Light HSL Hue Server", group: "Lighting", isSig: true},
        SIG_MD_LIGHT_HSL_SAT_S: {modelId: 0x130B, modelName: "Light HSL Saturation Server", group: "Lighting", isSig: true},
        SIG_MD_LIGHT_XYL_S: {modelId: 0x130C, modelName: "Light xyL Server", group: "Lighting", isSig: true},
        SIG_MD_LIGHT_XYL_SETUP_S: {modelId: 0x130D, modelName: "Light xyL Setup Server", group: "Lighting", isSig: true},
        SIG_MD_LIGHT_XYL_C: {modelId: 0x130E, modelName: "Light xyL Client", group: "Lighting", isSig: true},
        SIG_MD_LIGHT_LC_S: {modelId: 0x130F, modelName: "Light LC Server", group: "Lighting", isSig: true},
        SIG_MD_LIGHT_LC_SETUP_S: {modelId: 0x1310, modelName: "Light LC Setup Server", group: "Lighting", isSig: true},
        SIG_MD_LIGHT_LC_C: {modelId: 0x1311, modelName: "Light LC Client", group: "Lighting", isSig: true},


        SIG_MD_CFG_DF_S: {modelId: 0xBF30, modelName: "direct forwarding server", group: "", deviceKeyEnc: true, isSig: true},
        SIG_MD_CFG_DF_C: {modelId: 0xBF31, modelName: "direct forwarding client", group: "", deviceKeyEnc: true, isSig: true},

        SIG_MD_CFG_BRIDGE_S: {modelId: 0xBF32, modelName: "subnet bridge server", group: "", deviceKeyEnc: true, isSig: true},
        SIG_MD_CFG_BRIDGE_C: {modelId: 0xBF33, modelName: "subnet bridge client", group: "", deviceKeyEnc: true, isSig: true},

        /**
         * firmware update model
         */
        SIG_MD_FW_UPDATE_S: {modelId: 0xFE00, modelName: "firmware update server", group: "OTA", isSig: true},
        SIG_MD_FW_UPDATE_C: {modelId: 0xFE01, modelName: "firmware update client", group: "OTA", isSig: true},
        SIG_MD_FW_DISTRIBUT_S: {modelId: 0xFE02, modelName: "firmware distribute server", group: "OTA", isSig: true},
        SIG_MD_FW_DISTRIBUT_C: {modelId: 0xFE03, modelName: "firmware distribute client", group: "OTA", isSig: true},
        SIG_MD_OBJ_TRANSFER_S: {modelId: 0xFF00, modelName: "object transfer server", group: "OTA", isSig: true},
        SIG_MD_OBJ_TRANSFER_C: {modelId: 0xFF01, modelName: "object transfer client", group: "OTA", isSig: true},

        // opcode aggregator
        SIG_MD_CFG_OP_AGG_S: {modelId: 0xBF54, modelName: "opcode aggregator server", group: "aggregator", deviceKeyEnc: true, isSig: true},
        SIG_MD_CFG_OP_AGG_C: {modelId: 0xBF55, modelName: "opcode aggregator client", group: "aggregator", deviceKeyEnc: true, isSig: true},


        SIG_MD_LARGE_CPS_S: {modelId: 0xBF56, modelName: "large cps server", group: "", deviceKeyEnc: true, isSig: true},
        SIG_MD_LARGE_CPS_C: {modelId: 0xBF57, modelName: "large cps client", group: "", deviceKeyEnc: true, isSig: true},

        SIG_MD_SAR_CFG_S: {modelId: 0xBF52, modelName: "SAR config server", group: "", deviceKeyEnc: true, isSig: true},
        SIG_MD_SAR_CFG_C: {modelId: 0xBF53, modelName: "SAR config client", group: "", deviceKeyEnc: true, isSig: true},

        SIG_MD_ON_DEMAND_PROXY_S: {modelId: 0xBF50, modelName: "SAR config server", group: "", deviceKeyEnc: true, isSig: true},
        SIG_MD_ON_DEMAND_PROXY_C: {modelId: 0xBF51, modelName: "SAR config client", group: "", deviceKeyEnc: true, isSig: true},

        VENDOR_MD_LIGHT_S: {modelId: 0x00000211, modelName: "Vendor light server", group: "", isSig: false},
    };

    /**
     * modelId: sig or vendor model id
     * modelName: model name
     * group: model group desc
     * deviceKeyEnc: use device key for encryption otherwise use application key
     * isSig: is sig or vendor
     */

    static useDeviceKeyForEnc(modelId) {
        const model = this.getById(modelId);
        return model != null && model.deviceKeyEnc;
    }

    // default sub list
    static getDefaultSubList() {
        return [this.allList.SIG_MD_G_ONOFF_S, this.allList.SIG_MD_LIGHTNESS_S, this.allList.SIG_MD_LIGHT_CTL_S,
                this.allList.SIG_MD_LIGHT_CTL_TEMP_S, this.allList.SIG_MD_LIGHT_HSL_S, this.allList.VENDOR_MD_LIGHT_S];
    }

    static getById(modelId) {
        for (let model of
                Object.values(this.allList)) {
            if (model.modelId == modelId) return model;
        }
        return null;
    }
}

module.exports = MeshSigModel;
