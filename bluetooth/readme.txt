<<<< file :: device/nexell/clova/device.mk >>>>

# bluetooth
PRODUCT_COPY_FILES += \
        frameworks/native/data/etc/android.hardware.bluetooth_le.xml:system/etc/permissions/android.hardware.bluetooth_le.xml \
        frameworks/native/data/etc/android.hardware.bluetooth.xml:system/etc/permissions/android.hardware.bluetooth.xml

<<<< file :: device/nexell/clova/BoardConfig.mk >>>>

# bluetooth

BOARD_HAVE_BLUETOOTH := true
BOARD_HAVE_BLUETOOTH_BCM := true
BOARD_BLUETOOTH_BDROID_BUILDCFG_INCLUDE_DIR := device/nexell/clova/bluetooth
BOARD_CUSTOM_BT_CONFIG := device/nexell/clova/bluetooth/vnd_generic.txt

<<<< file :: device/nexell/clova/aosp_clova.mk >>>>
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += config.disable_bluetooth=false

<<<< file :: sepolicy/file_contexts >>>>
/dev/ttyAMA1            u:object_r:hci_attach_dev:s0

<<<< file :: sepolicy/bluetooth.te >>>>

allow bluetooth sysfs:file read;
allow bluetooth sysfs:file write;

<<<< file :: device/nexell/clova/init.clova.rc >>>>

section >> on boot
    # bluetooth
    chown bluetooth net_bt_stack /sys/class/rfkill/rfkill0/type
    chown bluetooth net_bt_stack /sys/class/rfkill/rfkill0/state
    chmod 0660 /sys/class/rfkill/rfkill0/state

    chmod 0660 /dev/ttyAMA1
    chown bluetooth net_bt_stack /dev/ttyAMA1

section >> on post-fs-data
    # bluetooth
    mkdir /data/misc/bluetooth 0770 bluetooth net_bt_stack

<<<< directory :: device/nexell/clova/bluetooth >>>>
    Android.mk
    BCM20710A1_001.002.014.0103.0117.hcd
    BCM434545.hcd
    bdroid_buildcfg.h
    bt_vendor.conf
    readme.txt
    vnd_generic.txt

<<<< file/directory :: device/nexell/clova/overlay/packages/apps/Bluetooth/res/values/config.xml >>>>


<<<< file :: hardware/broadcom/libbt/Android.mk >>>>

# bluetooth for BCM HCD files
LOCAL_REQUIRED_MODULES := \
        bt_vendor.conf \
        BCM20710A1_001.002.014.0103.0117.hcd \
        BCM434545.hcd 
