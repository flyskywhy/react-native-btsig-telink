// ref to android/src/main/java/com/telink/ble/mesh/entity/CompositionData.java

const MeshSigModel = require("./MeshSigModel");

class CompositionData {
    /**
     * bit 0 Relay feature support: 0 = False, 1 = True
     */
    static FEATURE_RELAY = 0b0001;

    /**
     * bit 1 Proxy feature support: 0 = False, 1 = True
     */
    static FEATURE_PROXY = 0b0010;

    /**
     * bit 2 Friend feature support: 0 = False, 1 = True
     */
    static FEATURE_FRIEND = 0b0100;

    /**
     * bit 3 Low Power feature support: 0 = False, 1 = True
     */
    static FEATURE_LOW_POWER = 0b1000;


    /**
     * Contains a 16-bit company identifier assigned by the Bluetooth SIG
     */
    cid;

    /**
     * Contains a 16-bit vendor-assigned product identifier
     */
    pid;

    /**
     * Contains a 16-bit vendor-assigned product version identifier
     */
    vid;

    /**
     * Contains a 16-bit value representing the minimum number of replay protection list entries in a device
     */
    crpl;

    /**
     * supported features
     * 16 bits
     */
    features;

    elements = null;

    static toBytes(cpsData) {
        let result = [];

        result.push(cpsData.cid & 0xFF);
        result.push((cpsData.cid >> 8) & 0xFF);
        result.push(cpsData.pid & 0xFF);
        result.push((cpsData.pid >> 8) & 0xFF);
        result.push(cpsData.vid & 0xFF);
        result.push((cpsData.vid >> 8) & 0xFF);
        result.push(cpsData.crpl & 0xFF);
        result.push((cpsData.crpl >> 8) & 0xFF);
        result.push(cpsData.features & 0xFF);
        result.push((cpsData.features >> 8) & 0xFF);

        for (let element of cpsData.elements) {
            result.push(element.location & 0xFF);
            result.push((element.location >> 8) & 0xFF);

            result.push(element.sigNum & 0xFF);
            result.push(element.vendorNum & 0xFF);

            for (let model of element.sigModels) {
                result.push(model & 0xFF);
                result.push((model >> 8) & 0xFF);
            }


            for (let model of element.vendorModels) {
                result.push(model & 0xFF);
                result.push((model >> 8) & 0xFF);
                result.push((model >> 16) & 0xFF);
                result.push((model >> 24) & 0xFF);
            }
        }

        return result;
    }

    static from(data) {
        let index = 0;
        let cpsData = new CompositionData();
        cpsData.cid = (data[index++] & 0xFF) | ((data[index++] & 0xFF) << 8);
        cpsData.pid = (data[index++] & 0xFF) | ((data[index++] & 0xFF) << 8);
        cpsData.vid = (data[index++] & 0xFF) | ((data[index++] & 0xFF) << 8);
        cpsData.crpl = (data[index++] & 0xFF) | ((data[index++] & 0xFF) << 8);
        cpsData.features = (data[index++] & 0xFF) | ((data[index++] & 0xFF) << 8);

        cpsData.elements = [];
        while (index < data.length) {
            let element = new Element();
            element.location = (data[index++] & 0xFF) | ((data[index++] & 0xFF) << 8);
            element.sigNum = (data[index++] & 0xFF);
            element.vendorNum = (data[index++] & 0xFF);

            element.sigModels = [];
            for (let i = 0; i < element.sigNum; i++) {
                element.sigModels.push((data[index++] & 0xFF) | ((data[index++] & 0xFF) << 8));
            }

            element.vendorModels = [];
            for (let j = 0; j < element.vendorNum; j++) {
                //sample 11 02 01 00 cid: 11 02 modelId: 01 00 -> 0x00010211
                element.vendorModels.push(((data[index++] & 0xFF)) | ((data[index++] & 0xFF) << 8) |
                        ((data[index++] & 0xFF) << 16) | ((data[index++] & 0xFF) << 24));
            }

            cpsData.elements.push(element);
        }

        return cpsData;
    }

    /**
     * @param configExcept config model not include
     * @deprecated
     */
    getAllModels(configExcept) {
        if (this.elements == null) return null;
        let models = [];
        for (let ele of this.elements) {
            if (ele.sigModels != null) {
                if (!configExcept) {
                    models.concat(ele.sigModels);
                } else {
                    for (let modelId of ele.sigModels) {
                        if (!MeshSigModel.useDeviceKeyForEnc(modelId)) {
                            models.push(modelId);
                        }
                    }
                }

            }
            if (ele.vendorModels != null) {
                models.concat(ele.vendorModels);
            }
        }

        return models;
    }

    getElementOffset(modelId) {
        let offset = 0;
        for (let ele of this.elements) {
            if (ele.sigModels != null && ele.sigModels.includes(modelId)) {
                return offset;
            }
            if (ele.vendorModels != null && ele.vendorModels.includes(modelId)) {
                return offset;
            }
            offset++;
        }
        return -1;
    }

    relaySupport() {
        return (this.features & this.FEATURE_RELAY) != 0;
    }

    proxySupport() {
        return (this.features & this.FEATURE_PROXY) != 0;
    }

    friendSupport() {
        return (this.features & this.FEATURE_FRIEND) != 0;
    }

    lowPowerSupport() {
        return (this.features & this.FEATURE_LOW_POWER) != 0;
    }

    toString() {
        let elementInfo = '';
        let element;
        for (let i = 0; i < this.elements.length; i++) {
            element = this.elements[i];
            elementInfo += 'element ' + i + ' : \n';
            elementInfo += 'location: ' + element.location + '\n';
            elementInfo += 'SIG models-' + element.sigModels.length + ':';
            let sig;
            for (let j = 0; j < element.sigModels.length; j++) {
                sig = '0x' + element.sigModels[j].toString(16);
                elementInfo += sig + ' ';
            }
            elementInfo += '\n';
//            elementInfo += 'VENDOR\n';
            elementInfo += 'Vendor models-' + element.vendorModels.length + ':';
            for (let j = 0; j < element.vendorModels.length; j++) {
                elementInfo += '0x' + element.vendorModels[j].toString(16) + '\t';
            }
            elementInfo += '\n';
        }

        return 'CompositionData{' +
                'cid=' + '0x' + this.cid.toString(16) +
                ', pid=' + '0x' + this.pid.toString(16) +
                ', vid=' + '0x' + this.vid.toString(16) +
                ', crpl=' + '0x' + this.crpl.toString(16) +
                ', features=' + '0x' + this.features.toString(16) +
                ', elements=\n' + elementInfo +
                '}';
    }
}

class Element {

    /**
     * 2 bytes
     * Contains a location descriptor
     */
    location;

    /**
     * 1 byte
     * Contains a count of SIG Model IDs in this element
     */
    sigNum;

    /**
     * 1 byte
     * Contains a count of Vendor Model IDs in this element
     */
    vendorNum;

    /**
     * Contains a sequence of NumS SIG Model IDs
     */
    sigModels = null;

    /**
     * Contains a sequence of NumV Vendor Model IDs
     */
    vendorModels = null;

    containModel(sigModelId) {
        if (this.sigModels == null || this.sigModels.length == 0) return false;
        for (let modelId of this.sigModels) {
            if (sigModelId == modelId) return true;
        }
        return false;
    }
}

module.exports = {
    CompositionData,
    Element,
};
