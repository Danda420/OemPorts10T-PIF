#!/bin/bash

dirnow=$PWD

if [[ ! -f $dirnow/framework.jar ]]; then
   echo "no framework.jar detected!"
   exit 1
fi

apkeditor() {
    jarfile=$dirnow/tool/APKEditor.jar
    javaOpts="-Xmx6056M -Dfile.encoding=utf-8 -Djdk.util.zip.disableZip64ExtraFieldValidation=true -Djdk.nio.zipfs.allowDotZipEntry=true"

    java $javaOpts -jar "$jarfile" "$@"
}

certificatechainPatch() {
 certificatechainPatch="
    .line $1
    invoke-static {}, Lcom/android/internal/util/danda/OemPorts10TUtils;->onEngineGetCertificateChain()V
"
}

instrumentationPatch() {
	returnline=$(expr $2 + 1)
	instrumentationPatch="    invoke-static {$1}, Lcom/android/internal/util/danda/OemPorts10TUtils;->onNewApplication(Landroid/content/Context;)V
    
    .line $returnline
    "
    
}

genCertificate() {
   local descReg=$1
   local attKeyReg=$2
   local keyParamReg=$3
   
   genCertificate="
    iget-object v0, p0, Landroid/security/KeyStoreSecurityLevel;->mSecurityLevel:Landroid/system/keystore2/IKeystoreSecurityLevel;

    invoke-static {v0, ${descReg}, ${attKeyReg}, ${keyParamReg}}, Lcom/android/internal/util/danda/OemPorts10TUtils;->genCertificate(Landroid/system/keystore2/IKeystoreSecurityLevel;Landroid/system/keystore2/KeyDescriptor;Landroid/system/keystore2/KeyDescriptor;Ljava/util/Collection;)Landroid/system/keystore2/KeyMetadata;

    move-result-object v0

    if-eqz v0, :cond_skip_spoofing

    return-object v0

    :cond_skip_spoofing"
}

onGetKeyEntry() {
   local descReg=$1
   
   onGetKeyEntry="
    invoke-static {${descReg}}, Lcom/android/internal/util/danda/OemPorts10TUtils;->onGetKeyEntry(Landroid/system/keystore2/KeyDescriptor;)Landroid/system/keystore2/KeyEntryResponse;

    move-result-object v0

    if-eqz v0, :cond_skip_spoofing

    return-object v0

    :cond_skip_spoofing"
}

expressions_fix() {
	var=$1
	escaped_var=$(printf '%s\n' "$var" | sed 's/[\/&]/\\&/g')
	escaped_var=$(printf '%s\n' "$escaped_var" | sed 's/\[/\\[/g' | sed 's/\]/\\]/g' | sed 's/\./\\./g' | sed 's/;/\\;/g')
	echo $escaped_var
}


echo "unpacking framework.jar"
apkeditor d -i framework.jar -o frmwrk > /dev/null 2>&1
mv framework.jar frmwrk.jar

echo "patching framework.jar"

keystorespiclassfile=$(find frmwrk/ -name 'AndroidKeyStoreSpi.smali' -printf '%P\n')
instrumentationsmali=$(find frmwrk/ -name "Instrumentation.smali"  -printf '%P\n')
keystore2classfile=$(find frmwrk/ -name 'KeyStore2.smali' -printf '%P\n')
keystorelvlclassfile=$(find frmwrk/ -name 'KeyStoreSecurityLevel.smali' -printf '%P\n')

engineGetCertMethod=$(expressions_fix "$(grep 'engineGetCertificateChain(' frmwrk/$keystorespiclassfile)")
newAppMethod1=$(expressions_fix "$(grep ' newApplication(Ljava/lang/ClassLoader;' frmwrk/$instrumentationsmali)")
newAppMethod2=$(expressions_fix "$(grep ' newApplication(Ljava/lang/Class;' frmwrk/$instrumentationsmali)")
getKeyEntryMethod=$(expressions_fix "$(grep ' getKeyEntry(Landroid/system/keystore2/KeyDescriptor;' frmwrk/$keystore2classfile)")
genKeyMethod=$(expressions_fix "$(grep ' generateKey(Landroid/system/keystore2/KeyDescriptor;' frmwrk/$keystorelvlclassfile)")

sed -n "/^${engineGetCertMethod}/,/^\.end method/p" frmwrk/$keystorespiclassfile > tmp_keystore
sed -i "/^${engineGetCertMethod}/,/^\.end method/d" frmwrk/$keystorespiclassfile

sed -n "/^${newAppMethod1}/,/^\.end method/p" frmwrk/$instrumentationsmali > inst1
sed -i "/^${newAppMethod1}/,/^\.end method/d" frmwrk/$instrumentationsmali

sed -n "/^${newAppMethod2}/,/^\.end method/p" frmwrk/$instrumentationsmali > inst2
sed -i "/^${newAppMethod2}/,/^\.end method/d" frmwrk/$instrumentationsmali

sed -n "/^${getKeyEntryMethod}/,/^\.end method/p" frmwrk/$keystore2classfile > getKeyEntry_tmp
sed -i "/^${getKeyEntryMethod}/,/^\.end method/d" frmwrk/$keystore2classfile

sed -n "/^${genKeyMethod}/,/^\.end method/p" frmwrk/$keystorelvlclassfile > genKey_tmp
sed -i "/^${genKeyMethod}/,/^\.end method/d" frmwrk/$keystorelvlclassfile

inst1_insert=$(expr $(wc -l < inst1) - 2)
instreg=$(grep "Landroid/app/Application;->attach(Landroid/content/Context;)V" inst1 | awk '{print $3}' | sed 's/},//')
instline=$(expr $(grep -r ".line" inst1 | tail -n 1 | awk '{print $2}') + 1)
instrumentationPatch $instreg $instline
echo "$instrumentationPatch" | sed -i "${inst1_insert}r /dev/stdin" inst1

inst2_insert=$(expr $(wc -l < inst2) - 2)
instreg=$(grep "Landroid/app/Application;->attach(Landroid/content/Context;)V" inst2 | awk '{print $3}' | sed 's/},//')
instline=$(expr $(grep -r ".line" inst2 | tail -n 1 | awk '{print $2}') + 1)
instrumentationPatch $instreg $instline
echo "$instrumentationPatch" | sed -i "${inst2_insert}r /dev/stdin" inst2

kstoreline=$(expr $(grep -r ".line" tmp_keystore | head -n 1 | awk '{print $2}') - 2)
certificatechainPatch $kstoreline
echo "$certificatechainPatch" | sed -i '4r /dev/stdin' tmp_keystore

cat inst1 >> frmwrk/$instrumentationsmali
cat inst2 >> frmwrk/$instrumentationsmali
cat tmp_keystore >> frmwrk/$keystorespiclassfile

descReg=$(cat getKeyEntry_tmp | grep -E ', "descriptor" ' | awk '{print $2}' | awk -F ',' '{print $1}')
onGetKeyEntry $descReg
awk -v payload="$onGetKeyEntry" '
    /new-instance .*, Landroid\/security\/KeyStore2\$\$ExternalSyntheticLambda/ {
        print payload
        print ""
    }
    { print $0 }
' getKeyEntry_tmp >> frmwrk/$keystore2classfile

descReg=$(cat genKey_tmp | grep -E ', "descriptor" ' | awk '{print $2}' | awk -F ',' '{print $1}')
attKeyReg=$(cat genKey_tmp | grep -E ', "attestationKey" ' | awk '{print $2}' | awk -F ',' '{print $1}')
keyParamReg=$(cat genKey_tmp | grep -E 'Landroid/hardware/security/keymint/KeyParameter' | head -n 2 | grep '"args"' | awk '{print $2}' | awk -F ',' '{print $1}')
genCertificate $descReg $attKeyReg $keyParamReg
awk -v payload="$genCertificate" '
    /new-instance .*, Landroid\/security\/KeyStoreSecurityLevel\$\$ExternalSyntheticLambda/ {
        print payload
        print ""
    }
    { print $0 }
' genKey_tmp >> frmwrk/$keystorelvlclassfile

rm -rf inst1 inst2 tmp_keystore getKeyEntry_tmp genKey_tmp

echo "repacking framework.jar classes"

apkeditor b -i frmwrk > /dev/null 2>&1
unzip frmwrk_out.apk 'classes*.dex' -d frmwrk > /dev/null 2>&1

rm -rf frmwrk/.cache
patchclass=$(expr $(find frmwrk/ -type f -name '*.dex' | wc -l) + 1)
cp PIF/classes.dex frmwrk/classes${patchclass}.dex

cd frmwrk
echo "zipping class"
zip -qr0 -t 07302003 $dirnow/frmwrk.jar classes*
cd $dirnow
echo "zipaligning framework.jar"
zipalign -v 4 frmwrk.jar framework.jar > /dev/null
rm -rf frmwrk.jar frmwrk frmwrk_out.apk
