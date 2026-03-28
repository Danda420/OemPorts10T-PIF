#!/system/bin/sh

resetprop ro.secureboot.lockstate locked
resetprop ro.boot.flash.locked 1
resetprop ro.boot.realme.lockstate 1
resetprop ro.boot.vbmeta.device_state locked
resetprop ro.boot.verifiedbootstate green
resetprop ro.boot.veritymode enforcing
resetprop ro.boot.selinux enforcing
resetprop ro.boot.warranty_bit 0
resetprop ro.build.tags release-keys
resetprop ro.build.type user
resetprop ro.debuggable 0
resetprop ro.is_ever_orange 0
resetprop ro.secure 1
resetprop ro.vendor.boot.warranty_bit 0
resetprop ro.vendor.warranty_bit 0
resetprop ro.warranty_bit 0
resetprop vendor.boot.vbmeta.device_state locked
resetprop vendor.boot.verifiedbootstate green