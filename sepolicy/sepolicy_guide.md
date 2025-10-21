# SELinux Integration Guide for Play Integrity Fix (PIF)

## 1. Introduction

This document provides technical steps for integrating the necessary **SELinux rules** and **file contexts** for the Play Integrity Fix (PIF) integration. Following this guide ensures that the `pif-updater` service functions correctly within an SELinux Enforcing environment.

This guide assumes you are working with a compiled SELinux policy in **Common Intermediate Language (CIL)** format (e.g., `plat_sepolicy.cil`) and a corresponding `file_contexts` configuration.

---

## 2. File Contexts Integration

File contexts are required to label the PIF binary and its related data files correctly.

**Action:** Merge the contents of `pif_file_contexts` into your device's primary `file_contexts` configuration file (e.g., `plat_file_contexts`).

**`pif_file_contexts` Content:**

```plaintext
/system/bin/pif-updater       u:object_r:pif_updater_exec:s0
/data/system/pif_tmp.apk      u:object_r:pif_data_file:s0
/data/PIF.apk                 u:object_r:pif_data_file:s0
/data/system/readme_tmp.md    u:object_r:pif_data_file:s0
```

Also if you're using an unpacked (e.g., Mio Kitchen, RomTools, DNA, etc)
At the root of your ROM Working directory find `/config` folder and on `system_file_context` ensure that pif-updater context is exec instead of system_file for example :

```plaintext
/system/bin/pif-updater       u:object_r:pif_updater_exec:s0
```

---

## 3. CIL Policy Integration

The CIL policy rules are broken down into three parts:

* Type definitions
* Type attribute assignments
* Permission rules (allow statements)

### 3.1 Define New Types

These definitions introduce the `pif_updater` domain and its executable type.

**Action:** Insert the following CIL block into your primary `plat_sepolicy.cil` file where other types are defined.

**CIL Snippet:**

```lisp
(type pif_updater)
(roletype object_r pif_updater)
(type pif_updater_exec)
(roletype object_r pif_updater_exec)
(type pif_data_file)
(roletype object_r pif_data_file)
```

---

### 3.2 Assign Type Attributes

This step adds the newly defined types to existing `typeattributeset` collections. This allows `pif_updater` to inherit rules common to other processes and file types.

**Action:** Locate the corresponding `typeattributeset` blocks in your `plat_sepolicy.cil` and add the new types.

**CIL Snippets:**

```lisp
;; Add 'pif_updater' to the 'domain' typeattributeset
(typeattributeset domain (pif_updater))

;; Add PIF file types to 'file_type' and its subsets
(typeattributeset file_type (pif_data_file pif_updater_exec))
(typeattributeset data_file_type (pif_data_file))
(typeattributeset exec_type (pif_updater_exec))

;; Add 'pif_updater' to trusted and network-capable domains
(typeattributeset mlstrustedobject (pif_updater))
(typeattributeset netdomain (pif_updater))
```

**Note:** Search for `(typeattributeset domain (` in your master CIL file and add `pif_updater` to the list of types within that block.

---

### 3.3 Add Core Permissions and Transitions

This final block contains the specific `allow` rules, `typetransition`, and `dontaudit` rules that grant `pif_updater` the necessary permissions to function.

**Action:** Append the following CIL block to the end of your `plat_sepolicy.cil` file at the very bottom or anywhere you prefer along with other allow statements

**CIL Snippet:**

```lisp
(typetransition init pif_updater_exec process pif_updater)
(typetransition pif_updater system_data_file file pif_data_file)
(dontaudit pif_updater pif_data_file (file (ioctl)))
(allow pif_updater hwservicemanager (file (open read)))
(allow pif_updater pif_data_file (file (append create getattr ioctl link lock open read rename setattr unlink write)))
(allow pif_updater selinuxfs (file (map open read write)))
(allow pif_updater servicemanager (file (open read)))
(allow pif_updater storage_feature_cloudctl (file (open read)))
(allow pif_updater vndservicemanager (file (open read)))
(allow pif_updater aee_aedv (file (open read)))
(allow pif_updater crash_dump (file (open read)))
(allow pif_updater hal_bootctl_default (file (open read)))
(allow pif_updater hal_nfc_default (file (open read)))
(allow pif_updater selinuxfs (dir (open read)))
(allow pif_updater vold (file (open read)))
(allow pif_updater hal_keymaster_default (file (read)))
(allow pif_updater keystore (file (read)))
(allow pif_updater system_suspend (file (read)))
(allow pif_updater tran_hwinfo_binder (file (read)))
(allow pif_updater hwservicemanager (dir (search)))
(allow pif_updater servicemanager (dir (search)))
(allow pif_updater storage_feature_cloudctl (dir (search)))
(allow pif_updater tombstoned (file (read)))
(allow pif_updater trancamserver (file (read)))
(allow pif_updater vndservicemanager (dir (search)))
(allow pif_updater vold (dir (search)))
(allow pif_updater aee_aedv (dir (search)))
(allow pif_updater crash_dump (dir (search)))
(allow pif_updater hal_bootctl_default (dir (search)))
(allow pif_updater hal_nfc_default (dir (search)))
(allow pif_updater kernel (security (compute_av)))
(allow pif_updater pif_updater_exec (file (entrypoint execute getattr map open read)))
(allow pif_updater system_data_file (dir (add_name remove_name search write)))
(allow pif_updater pif_updater (process (execmem)))
(allow pif_updater vendor_file (file (execute execute_no_trans)))
(allow pif_updater default_prop (file (getattr map open read)))
(allow pif_updater system_prop (file (getattr map open read)))
(allow pif_updater system_data_root_file (dir (add_name write)))
(allow pif_updater system_data_root_file (file (create getattr open read setattr write)))
(allow pif_updater package_service (service_manager (find)))
(allow pif_updater system_server (binder (call transfer)))
(allow pif_updater vendor_init (dir (search)))
(allow pif_updater vendor_init (file (open read)))
(allow pif_updater pif_updater (capability (sys_ptrace)))
(allow pif_updater system_file (file (execute execute_no_trans getattr map open read)))
(allow pif_updater servicemanager (binder (call)))
(allow pif_updater kernel (dir (search)))
(allow pif_updater kernel (file (open read)))
(allow pif_updater init (dir (search)))
(allow pif_updater init (file (open read)))
(allow pif_updater ueventd (dir (search)))
(allow pif_updater ueventd (file (open read)))
(allow pif_updater prng_seeder (dir (search)))
(allow pif_updater prng_seeder (file (open read)))
(allow pif_updater logd (dir (search)))
(allow pif_updater logd (file (open read)))
(allow system_server pif_updater (fd (use)))
(allow system_server pif_updater (binder (call)))
(allow init pif_updater (process (noatsecure rlimitinh siginh transition)))
(allow init pif_updater_exec (file (execute getattr open read)))
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

