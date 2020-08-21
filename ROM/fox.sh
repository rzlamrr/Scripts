#!/usr/bin/env bash

export TZ=":Asia/Jakarta"

function wkt() {
    DATELOG=$(date "+%H%M-%d%m%Y")
}

before () {
    apt install git aria2 -y
    git clone https://gitlab.com/OrangeFox/misc/scripts
    bash setup/android_build_env.sh
    bash setup/install_android_sdk.sh
}

sink () {
    repo init -u https://gitlab.com/OrangeFox/Manifest.git -b fox_9.0
    repo sync -j32 --force-sync
}

batang () {
    git clone https://github.com/SunnyRaj84348/twrp_device_xiaomi_riva -b android-9.0_4.9 device/xiaomi/riva
    git clone https://github.com/omnirom/android_vendor_qcom_opensource_commonsys -b android-9.0 vendor/qcom/opensource/commonsys
}

makan () {
    . build/envsetup.sh
    export ALLOW_MISSING_DEPENDENCIES=true
    export FOX_USE_TWRP_RECOVERY_IMAGE_BUILDER=1
    export OF_FLASHLIGHT_ENABLE=1
    export OF_USE_MAGISKBOOT=1
    export OF_NO_TREBLE_COMPATIBILITY_CHECK=1
    export W_EXTRA_LANGUAGES=true
    export LC_ALL="C"
    lunch omni_riva-eng
}

masak() {
    mka recoveryimage -j$(nproc --all)
}

tg_doc() {
    curl -F name=document -F document=@$1 -H "Content-Type:multipart/form-data" "https://api.telegram.org/bot$BOT_TOKEN/sendDocument?chat_id=1095222353"
}

cd scripts
before
cd ..
mkdir OrangeFox
cd OrangeFox
wkt
if sink | tee sink-${DATELOG}.txt;then
    batang
    makan
    if masak | tee masak-${DATELOG}.txt;then
#        FILEPATH=${OUT}/${FILE}
        tg_doc out/target/product/riva/OrangeFox*riva.zip
        tg_doc masak-${DATELOG}.txt
        echo done
    else
        grep -iE 'crash|error|failed|fatal|fail' masak-${DATELOG}.txt > masaktrim-${DATELOG}.txt
        tg_doc masak-${DATELOG}.txt
        tg_doc masaktrim-${DATELOG}.txt
    fi
else
    tg_doc sink-${DATELOG}.txt
fi
