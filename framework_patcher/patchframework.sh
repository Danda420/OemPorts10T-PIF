#!/bin/bash

G='\033[0;32m'
R='\033[0;31m'
NC='\033[0m'

PATCH_REPORT=""

add_report() {
    if [ "$2" == "success" ]; then
        PATCH_REPORT+="${G}$1 applied${NC}\n"
    else
        PATCH_REPORT+="${R}$1 failed${NC}\n"
    fi
}

dirnow=$PWD

if [[ ! -f $dirnow/framework.jar ]]; then
   echo "no framework.jar detected!"
   exit 1
fi

apkeditor() {
    jarfile=$dirnow/tool/APKEditor.jar
    javaOpts="-Xmx4096M -Dfile.encoding=utf-8 -Djdk.util.zip.disableZip64ExtraFieldValidation=true -Djdk.nio.zipfs.allowDotZipEntry=true"

    java $javaOpts -jar "$jarfile" "$@"
}

certificatechainPatch() {
 certificatechainPatch="
    .line $1
    invoke-static {}, Lcom/android/internal/util/danda/OemPorts10TUtils;->onEngineGetCertificateChain()V
"
}

instrumentationPatch() {
	returnline=$(expr $2 + 1 2>/dev/null)
	instrumentationPatch="    invoke-static {$1}, Lcom/android/internal/util/danda/OemPorts10TUtils;->onNewApplication(Landroid/content/Context;)V
    
    .line $returnline
    "
}

genCertificate() {
   local esLamReg=$1
   local descReg=$2
   local argsReg=$3
   local retReg=$4
   
   genCertificate="
    invoke-static {p0, ${esLamReg}, ${descReg}, ${argsReg}}, Lcom/android/internal/util/danda/OemPorts10TUtils;->genCertificate(Ljava/lang/Object;Ljava/lang/Object;Landroid/system/keystore2/KeyDescriptor;Ljava/util/Collection;)Landroid/system/keystore2/KeyMetadata;

    move-result-object ${retReg}

    if-eqz ${retReg}, :cond_skip_spoofing

    return-object ${retReg}

    :cond_skip_spoofing"
}

onGetKeyEntry() {
   local esLamReg=$1
   local descReg=$2
   
   onGetKeyEntry="
    invoke-static {p0, ${esLamReg}, ${descReg}}, Lcom/android/internal/util/danda/OemPorts10TUtils;->onGetKeyEntry(Ljava/lang/Object;Ljava/lang/Object;Landroid/system/keystore2/KeyDescriptor;)Landroid/system/keystore2/KeyEntryResponse;

    move-result-object ${descReg}

    if-eqz ${descReg}, :cond_skip_spoofing

    return-object ${descReg}

    :cond_skip_spoofing"
}

onDeleteKey() {
   local descReg=$1
   
   onDeleteKey="
    invoke-static {${descReg}}, Lcom/android/internal/util/danda/OemPorts10TUtils;->onDeleteKey(Landroid/system/keystore2/KeyDescriptor;)V"
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

instrumentationsmali=$(find frmwrk/ -name "Instrumentation.smali"  -printf '%P\n')
keystore2classfile=$(find frmwrk/ -name 'KeyStore2.smali' -printf '%P\n')
keystorelvlclassfile=$(find frmwrk/ -name 'KeyStoreSecurityLevel.smali' -printf '%P\n')

newAppMethod1=$(expressions_fix "$(grep ' newApplication(Ljava/lang/ClassLoader;' frmwrk/$instrumentationsmali)")
newAppMethod2=$(expressions_fix "$(grep ' newApplication(Ljava/lang/Class;' frmwrk/$instrumentationsmali)")
getKeyEntryMethod=$(expressions_fix "$(grep ' getKeyEntry(Landroid/system/keystore2/KeyDescriptor;' frmwrk/$keystore2classfile)")
deleteKeyMethod=$(expressions_fix "$(grep ' deleteKey(Landroid/system/keystore2/KeyDescriptor;' frmwrk/$keystore2classfile)")
genKeyMethod=$(expressions_fix "$(grep ' generateKey(Landroid/system/keystore2/KeyDescriptor;' frmwrk/$keystorelvlclassfile)")

sed -n "/^${newAppMethod1}/,/^\.end method/p" frmwrk/$instrumentationsmali > inst1
sed -i "/^${newAppMethod1}/,/^\.end method/d" frmwrk/$instrumentationsmali

sed -n "/^${newAppMethod2}/,/^\.end method/p" frmwrk/$instrumentationsmali > inst2
sed -i "/^${newAppMethod2}/,/^\.end method/d" frmwrk/$instrumentationsmali

sed -n "/^${getKeyEntryMethod}/,/^\.end method/p" frmwrk/$keystore2classfile > getKeyEntry_tmp
sed -i "/^${getKeyEntryMethod}/,/^\.end method/d" frmwrk/$keystore2classfile

sed -n "/^${deleteKeyMethod}/,/^\.end method/p" frmwrk/$keystore2classfile > delKey_tmp
sed -i "/^${deleteKeyMethod}/,/^\.end method/d" frmwrk/$keystore2classfile

sed -n "/^${genKeyMethod}/,/^\.end method/p" frmwrk/$keystorelvlclassfile > genKey_tmp
sed -i "/^${genKeyMethod}/,/^\.end method/d" frmwrk/$keystorelvlclassfile


inst1_insert=$(expr $(wc -l < inst1 2>/dev/null) - 2 2>/dev/null)
instreg=$(grep "Landroid/app/Application;->attach(Landroid/content/Context;)V" inst1 | awk '{print $3}' | sed 's/},//')
instline=$(expr $(grep -r ".line" inst1 | tail -n 1 | awk '{print $2}') + 1 2>/dev/null)
instrumentationPatch $instreg $instline
echo "$instrumentationPatch" | sed -i "${inst1_insert}r /dev/stdin" inst1 2>/dev/null
if grep -q "OemPorts10TUtils;->onNewApplication" inst1; then add_report "Patch 1 (Instrumentation: newApplication ClassLoader)" "success"; else add_report "Patch 1 (Instrumentation 1)" "failed"; fi

inst2_insert=$(expr $(wc -l < inst2 2>/dev/null) - 2 2>/dev/null)
instreg=$(grep "Landroid/app/Application;->attach(Landroid/content/Context;)V" inst2 | awk '{print $3}' | sed 's/},//')
instline=$(expr $(grep -r ".line" inst2 | tail -n 1 | awk '{print $2}') + 1 2>/dev/null)
instrumentationPatch $instreg $instline
echo "$instrumentationPatch" | sed -i "${inst2_insert}r /dev/stdin" inst2 2>/dev/null
if grep -q "OemPorts10TUtils;->onNewApplication" inst2; then add_report "Patch 2 (Instrumentation: newApplication Class)" "success"; else add_report "Patch 2 (Instrumentation 2)" "failed"; fi

cat inst1 >> frmwrk/$instrumentationsmali
cat inst2 >> frmwrk/$instrumentationsmali

descReg=$(grep -r -E ', "descriptor" ' delKey_tmp | awk '{print $2}' | awk -F ',' '{print $1}')
onDeleteKey $descReg
awk -v payload="$onDeleteKey" '
    /new-instance .*, Landroid\/security\/KeyStore2\$\$ExternalSyntheticLambda/ {
        print payload
        print ""
    }
    { print $0 }
' delKey_tmp >> frmwrk/$keystore2classfile
if grep -q "OemPorts10TUtils;->onDeleteKey" frmwrk/$keystore2classfile; then add_report "Patch 3 (KeyStore2: deleteKey)" "success"; else add_report "Patch 4 (KeyStore2: deleteKey)" "failed"; fi

esLamReg=$(grep ', Landroid/security/KeyStore2$$ExternalSyntheticLambda[0-9]*;$' getKeyEntry_tmp | awk '{print $2}' | awk -F ',' '{print $1}')
descReg=$(grep -r -E ', "descriptor" ' getKeyEntry_tmp | awk '{print $2}' | awk -F ',' '{print $1}')
onGetKeyEntry $esLamReg $descReg
awk -v payload="$onGetKeyEntry" '
    /invoke-(virtual|direct) .*, Landroid\/security\/KeyStore2;->handleRemoteExceptionWithRetry/ {
        print payload
        print ""
    }
    { print }
' getKeyEntry_tmp >> frmwrk/$keystore2classfile
if grep -q "OemPorts10TUtils;->onGetKeyEntry" frmwrk/$keystore2classfile; then add_report "Patch 4 (KeyStore2: getKeyEntry)" "success"; else add_report "Patch 5 (KeyStore2: getKeyEntry)" "failed"; fi

esLamReg=$(grep ', Landroid/security/KeyStoreSecurityLevel$$ExternalSyntheticLambda[0-9]*;$' genKey_tmp | awk '{print $2}' | awk -F ',' '{print $1}')
descReg=$(grep -r -E '.local' genKey_tmp | grep -E ', "descriptor"' | awk '{print $2}' | awk -F ',' '{print $1}')
if [[ $descReg == "" ]]; then
   descReg=$(grep -r -E '.param' genKey_tmp | grep -E ', "descriptor"' | awk '{print $2}' | awk -F ',' '{print $1}')
fi
argsReg=$(grep -r -E '.local' genKey_tmp | grep -E ', "args"' | tail -n1 | awk '{print $2}' | awk -F ',' '{print $1}')
retReg=$(grep -r -E 'return-object ' genKey_tmp | awk '{print $2}')
genCertificate $esLamReg $descReg $argsReg $retReg
awk -v payload="$genCertificate" '
    /invoke-direct .*, Landroid\/security\/KeyStoreSecurityLevel;->(handleExceptions|retryBusyException)/ {
        print payload
        print ""
    }
    { print $0 }
' genKey_tmp >> frmwrk/$keystorelvlclassfile
if grep -q "OemPorts10TUtils;->genCertificate" frmwrk/$keystorelvlclassfile; then add_report "Patch 5 (KeyStoreSecurityLevel: genKey)" "success"; else add_report "Patch 6 (KeyStoreSecurityLevel: genKey)" "failed"; fi


rm -rf inst1 inst2 tmp_keystore getKeyEntry_tmp genKey_tmp delKey_tmp

printf "\n------------------------\n%b------------------------\n\n" "$PATCH_REPORT"

echo "repacking framework.jar classes"

if apkeditor b -i frmwrk &> build.log; then
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
    echo -e "${G}done!${NC}"
    echo "
    Dont forget to add liboemports_pif.so to /system/etc/public.libraries.txt
    "
else
    echo -e "${R}repack failed! check build.log${NC}"
fi