# How to use pif-updater

## Normal update
```shell
su
pif-updater
```

## Insert own pif.json and/or keybox.xml
```shell
su
pif-updater -k $PATH_TO_KEYBOX
pif-updater -p $PATH_TO_PIF
# or both simultaneously
pif-updater -p $PATH_TO_PIF -k $PATH_TO_KEYBOX
```
example:
```shell
su
pif-updater -k /sdcard/Downloads/keybox.xml
pif-updater -p /sdcard/Downloads/pif.json
# or both simultaneously
pif-updater -p /sdcard/Downloads/pif.json -k /sdcard/Downloads/keybox.xml
```
or you can just implement an UI interface for importing these and execute the commands!

## pif.json format
```json
{
  "MANUFACTURER": "Google",
  "BRAND": "google",
  "DEVICE": "cheetah",
  "PRODUCT": "cheetah_beta",
  "MODEL": "Pixel 7",
  "FINGERPRINT": "google/cheetah_beta/cheetah:16/CP11.251209.009/14837756:user/release-keys",
  "SECURITY_PATCH": "2025-12-05",
  "FIRST_API_LEVEL": "34"
}
```