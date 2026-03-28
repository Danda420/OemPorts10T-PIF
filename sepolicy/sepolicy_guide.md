# SELinux Integration Guide for Play Integrity Fix (PIF)

## 1. Introduction

This document provides technical steps for integrating the necessary **SELinux rules** and **file contexts** for the Play Integrity Fix (PIF) integration. Following this guide ensures that the `pif-updater` service functions correctly within an SELinux Enforcing environment.

This guide assumes you are working with a compiled SELinux policy in **Common Intermediate Language (CIL)** format (e.g., `plat_sepolicy.cil`) and a corresponding `file_contexts` configuration.

---

## 2. File Contexts Integration

File contexts are required to label the PIF binary.

**Action:** Merge the contents of `pif_file_contexts` into your device's primary `file_contexts` configuration file (e.g., `plat_file_contexts`).

**`pif_file_contexts` Content:**

```plaintext
/system/bin/pif-updater		u:object_r:pif_updater_exec:s0
/system/bin/resetprop		u:object_r:pif_updater_exec:s0
/system/bin/sensitiveprops.sh		u:object_r:pif_updater_exec:s0
```

Also if you're decompiling/unpacking the partition, at the root of your ROM Working directory find `/config` folder and on `system_file_context` ensure that pif-updater context is exec instead of system_file for example :

```plaintext
/system/system/bin/pif-updater u:object_r:pif_updater_exec:s0
/system/system/bin/resetprop		u:object_r:pif_updater_exec:s0
/system/system/bin/sensitiveprops.sh		u:object_r:pif_updater_exec:s0
```

---

## 3. CIL Policy Integration

Add the CIL policies from pif_sepolicy.cil into your partition ${partition}_sepolicy.cil (e.g., `plat_sepolicy.cil`)

```plaintext
(type pif_updater)
(type pif_updater_exec)
(typeattributeset domain (pif_updater))
(typeattributeset coredomain (pif_updater)) 
(typeattributeset exec_type (pif_updater_exec))
(typeattributeset file_type (pif_updater_exec))
(typeattributeset vendor_file_type (pif_updater_exec))
(typepermissive pif_updater)
(typetransition init pif_updater_exec process pif_updater)
(allow init pif_updater (process (transition)))
(allow pif_updater pif_updater_exec (file (entrypoint open read execute getattr map)))
(allow init pif_updater_exec (file (read getattr map execute open)))
(allow init pif_updater (process (noatsecure rlimitinh siginh dyntransition)))
(allow pif_updater self (capability (sys_admin dac_override dac_read_search chown fowner fsetid kill setgid setuid setpcap linux_immutable net_bind_service net_broadcast net_admin net_raw ipc_lock ipc_owner sys_module sys_rawio sys_chroot sys_ptrace sys_pacct sys_boot sys_nice sys_resource sys_time sys_tty_config mknod lease audit_write audit_control setfcap)))
(allow pif_updater file_type (dir (create search getattr open read write add_name remove_name rmdir reparent rename lock mounton)))
(allow pif_updater file_type (file (create open read write setattr getattr lock append unlink rename map execute execute_no_trans mounton)))
(allow pif_updater dev_type (chr_file (read write open getattr ioctl map)))
(allow pif_updater dev_type (blk_file (read write open getattr ioctl map)))
(allow pif_updater fs_type (filesystem (mount unmount associate quotamod quotaget relabelfrom relabelto)))
(allow pif_updater fs_type (dir (search getattr read open mounton)))
(allow pif_updater fs_type (file (read write open getattr)))
(allow pif_updater domain (process (sigkill signal getpgid getsched setsched)))
(allow pif_updater shell_exec (file (read execute open execute_no_trans map)))
(allow pif_updater toolbox_exec (file (read execute open execute_no_trans map)))
(allow pif_updater vendor_toolbox_exec (file (read execute open execute_no_trans map)))
(allow pif_updater service_manager_type (service_manager (add find list)))
(allow pif_updater domain (binder (call transfer)))
(allow domain pif_updater (binder (call transfer)))
(allow netd pif_updater (fd (use)))
(allow netd pif_updater (tcp_socket (read write setopt getopt)))
(allow netd pif_updater (udp_socket (read write setopt getopt)))
(allow netd pif_updater (unix_stream_socket (read write setopt getopt)))
(allow system_server pif_updater (binder (call transfer)))
(allow system_server pif_updater (fd (use)))
(allow system_server pif_updater (fifo_file (write read getattr lock append)))
(allow pif_updater power_service (service_manager (find)))
(allow pif_updater mount_service (service_manager (find))) 
(allow pif_updater property_type (property_service (set)))
(allow pif_updater property_type (file (read open getattr map)))
(allow pif_updater self (tcp_socket (create connect bind listen accept write read setopt getattr getopt shutdown)))
(allow pif_updater self (udp_socket (create connect bind write read setopt getattr getopt shutdown)))
(allow pif_updater self (rawip_socket (create connect bind write read setopt getattr getopt shutdown)))
(allow kernel pif_updater (fd (use)))
```

---

## 4. Finalizing and Verification
1. **Flash and Test:** Flash the updated `partition` image containing the new `sepolicy` and `file_contexts`.

2. **If Booting issue:** If you encounter booting issue, check ramoops for details
Run this command when you can't boot, in recovery
```bash
adb pull /sys/fs/pstore
```
then check the ramoops file, look for `sepolicy` it show on exactly which line you messed up.

3. **Verify:** After booting, check for SELinux denials:

```bash
adb shell dmesg | grep "avc: denied"
```
No denials related to `pif-updater` should appear if the policy is correctly integrated and the PIF.apk should be updated automatically when you cleanflashed if you have done this correctly.
but if the user-added json and/or keyboxes doesn't work, you might need to address denials related to that on your own.. you can just use that command to get those denials then you can address it by using this template:
```plaintext
(allow scontext tcontext (tclass (whats denied)))
;; for ex:
(allow gmscore_app system_file (file (read open getattr)))
```


