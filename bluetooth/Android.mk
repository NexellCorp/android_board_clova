LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := bt_vendor.conf
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_OUT)/etc/bluetooth
# LOCAL_MODULE_TAGS := optional
LOCAL_SRC_FILES :=  $(LOCAL_MODULE)
include $(BUILD_PREBUILT)

# BCM434545.hcd file
# ========================================================
include $(CLEAR_VARS)
LOCAL_MODULE := BCM434545.hcd
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)/firmware
LOCAL_MODULE_TAGS := optional
LOCAL_SRC_FILES := $(LOCAL_MODULE)
include $(BUILD_PREBUILT)

# BCM20710A1_001.002.014.0103.0117.hcd file
# ========================================================
include $(CLEAR_VARS)
LOCAL_MODULE := BCM20710A1_001.002.014.0103.0117.hcd
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)/firmware
LOCAL_MODULE_TAGS := optional
LOCAL_SRC_FILES := $(LOCAL_MODULE)
include $(BUILD_PREBUILT)
