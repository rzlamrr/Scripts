#!/usr/bin/env bash
# Simple kernel compilation script
# Copyright (C) 2020 Muhammad Fadlyas (fadlyas07)
# SPDX-License-Identifier: GPL-3.0-or-later

if [[ -n $CI ]] ; then
    echo "Yeay, build running on CI!" ;
        if [[ -z $CHATID ]] && [[ -z $TOKED ]] ; then
            echo 'chat id and bot token is not set or empty.' ;
            exit 1 ;
        fi
    ls -Aq &>/dev/null
else
    echo "Okay, build running on VM!" ;
        if [[ -z $CHATID ]] && [[ -z $TOKED ]] ; then
            read -p "Enter your chat id: " chat_id
            read -p "Enter your bot token: " token
            export chat_id token
        fi
    ls -Aq &>/dev/null
fi

config_path="$(pwd)/arch/arm64/configs"
device=riva
config_device=riva_defconfig

[[ ! -d "$(pwd)/anykernel-3" ]] && git clone https://github.com/fadlyas07/anykernel-3 --depth=1 &>/dev/null
[[ ! -d "$(pwd)/origin_gcc" ]] && git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 --depth=1 -b android-9.0.0_r59 origin_gcc &>/dev/null
[[ ! -d "$(pwd)/origin_gcc32" ]] && git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 --depth=1 -b android-9.0.0_r59 origin_gcc32 &>/dev/null

# Needed to export
export ARCH=arm64
export SUBARCH=arm64
export TELEGRAM_ID=$CHATID
export TELEGRAM_TOKEN=$TOKED
export KBUILD_BUILD_USER=rzlamrr
export KBUILD_BUILD_HOST=dvstLab

mkdir "$(pwd)/temporary"

tg_send_message() {
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
         -d "disable_web_page_preview=true" \
         -d "parse_mode=html" \
         -d chat_id="$TELEGRAM_ID" \
         -d text="$(
                    for POST in "${@}" ; do
                        echo "${POST}"
                    done
            )" &>/dev/null
}

build_kernel() {
    PATH="$(pwd)/origin_gcc/bin:$(pwd)/origin_gcc32/bin:$PATH" \
    make -j"$(nproc --all)" O=out \
                            ARCH=arm64 \
                            CROSS_COMPILE=aarch64-linux-android- \
                            CROSS_COMPILE_ARM32=arm-linux-androideabi-
}

# Main Environment
product_name='Axylon'
temp="$(pwd)/temporary"
pack="$(pwd)/anykernel-3"
kernel_img="$(pwd)/out/arch/arm64/boot/Image.gz-dtb"

build_start=$(date +"%s")

# build kernel - 1
build_date="$(TZ=Asia/Jakarta date +'%H%M-%d%m%y')"
make ARCH=arm64 O=out $config_device &>/dev/null
build_kernel 2>&1| tee "Log-$(TZ=Asia/Jakarta date +'%d%m%y').log"
mv Log-*.log $temp

if [[ ! -f "$kernel_img" ]] ; then
    build_end=$(date +"%s")
    build_diff=$(($build_end - $build_start))
    curl -F document=@$(echo $temp/Log-*.log) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="$TELEGRAM_ID"
    tg_send_message "<b>build throw an errors!</b> ($(git rev-parse --abbrev-ref HEAD), Build took $(($build_diff / 60)) minutes, $(($build_diff % 60)) seconds."
    exit 1 ;
fi

TEMPZIPNAME=$product_name-RIVA-"$build_date"-unsigned.zip
ZIPNAME=$product_name-RIVA-"$build_date".zip
kernel_version="$(cat $(pwd)/out/.config | grep Linux/arm64 | cut -d " " -f3)"
curl -F document=@$(echo $temp/Log-*.log) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="$TELEGRAM_ID"
mv "$kernel_img" "$pack/zImage"
cd $pack
zip -r9 $TEMPZIPNAME * -x .git README.md LICENCE $(echo *.zip) &>/dev/null
curl -sLo zipsigner-3.0.jar https://raw.githubusercontent.com/baalajimaestro/AnyKernel2/master/zipsigner-3.0.jar
java -jar zipsigner-3.0.jar "${TEMPZIPNAME}" "${ZIPNAME}"
rm $TEMPZIPNAME
cd ..
curl -F chat_id="$TELEGRAM_ID" -F "disable_web_page_preview=true" -F "parse_mode=html" -F document=@"$(echo "$pack"/*RIVA*.zip)" "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F caption="New #riva build is available!
($kernel_version, $(git rev-parse --abbrev-ref HEAD | cut -b 9-15)) at commit $(git log --pretty=format:"%h (\"%s\")" -1) | <b>SHA1:</b> $(sha1sum "$(echo "$pack"/*.zip)" | awk '{ print $1 }')."
