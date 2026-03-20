# Framework Play Integrity Fix (PIF)

framework-level implementation to pass Play Integrity checks on Android ROMs.

## Features
- **Bootloader Spoof (Broken TEE devices are supported too!)**  
  Well.. we needed this now just to pass device integrity.
- **GMS & Vending Properties Spoof**  
  Patches system properties to match certified devices for GMS & Vending.
- **Security Patch Spoof**  
  Spoofs Security Patch so that it passes strong integrity.
- **Vending SDK 32 Spoof**  
  Just incase. (this wont get enabled usually)
- **PIF.apk Updater**  
  Automatically fetches the latest PIF.apk from this repository.
- **Direct keybox.xml and pif.json support**  
  Auto switches to .xml and .json if `persist.sys.oemports10t.utils.pif.autoupdate` is false.

---

## Setup

### 1. Clone or Download
Clone this repository or download the ZIP archive and extract it.


### 2. Install Dependencies

#### Arch Linux
```sh
sudo pacman -Syu --needed jre-openjdk zip unzip android-sdk-build-tools
```

#### RHEL / Fedora / CentOS / Alma / Rocky
```sh
sudo dnf install -y java-latest-openjdk android-tools zip unzip
# or
sudo yum install -y java-17-openjdk android-tools zip unzip
```

#### Debian / Ubuntu / Linux Mint
```sh
sudo apt-get update && sudo apt-get install -y openjdk-17-jre android-sdk-libsparse-utils android-sdk-platform-tools zip unzip
```

#### openSUSE / SLES
```sh
sudo zypper install -y java-latest-openjdk android-tools zip unzip
```

---

## Usage

1. Import all files from:
   - `ROM/system` → into your system partition  
   - `ROM/vendor` → into your vendor partition  

2. Add the required properties from `ROM/build.prop` to your device’s `build.prop`.  

3. Place `framework.jar` inside the `framework_patcher` folder.  

4. Run the patcher:
   ```sh
   ./patchframework.sh
   ```

5. Wait for the patching process to complete.  

6. Replace your system’s `framework.jar` with the patched version.  

7. Remove any files in system/framework named:
   ```
   boot-framework.*
   ```

---

## How to use pif-updater?
Check [this README](pif-updater.md). The commands and pif.json format is explained there.

---

## Notes
- framework.jar patch script is only for Linux x86_64. Android is not supported.
- This implementation will be updated whenever Google changes Play Integrity.  
- `PIF.apk` is updated if keys/properties get banned, just run `pif-updater`.
- Some of those Implementation Features is adjusted via PIF.apk bools/strings, so no need to worry about that.. i'll only enable and disable whats important for passing play integrity.
* On devices running **SELinux Enforcing**, you may need to integrate additional SELinux rules for `pif-updater` or the implementation (for those user-added json and keyboxes). See the full guide below:

---

### 🔗 [SELinux Integration Guide for Play Integrity Fix (PIF)](./sepolicy/sepolicy_guide.md)


Refer to the above guide for complete steps to integrate the SELinux policy and file contexts required for `pif-updater` auto updater service in enforcing environments.
