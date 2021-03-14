#!/usr/bin/env bash
# Lite kernel compilation script [ with Args ]
# Copyright (C) 2020 Muhammad Fadlyas (fadlyas07)
# SPDX-License-Identifier: GPL-3.0-or-later

# defconfig id chat_id bot_token

export TZ=Asia/Jakarta
AKN=${HOME}/anykernel
git clone --quiet --depth=1 https://github.com/rzlamrr/anykernel3 -b rova ${AKN}
export ARCH=arm64 && export SUBARCH=arm64
trigger_sha="$(git rev-parse HEAD)" && commit_msg="$(git log --pretty=format:'%s' -1)"
cmsg="$(git log --pretty=format:"%s" -1)"
export my_id="${CHATID}" && export channel_id="${CHATID}" && export token="${TOKED}"
git clone --quiet --depth=1 https://github.com/arter97/arm64-gcc -b master gcc
export CROSS_COMPILE=aarch64-elf-
export PATH=$(pwd)/gcc/bin:${PATH}
if [[ msm_test != 1 ]]; then # Yep, clone gcc32 for vDSO32 :(
    git clone --quiet --depth=1 https://github.com/arter97/arm32-gcc -b master gcc32
    export CROSS_COMPILE_ARM32=arm-eabi-
    export PATH=$(pwd)/gcc32/bin:${PATH}
fi
START=$(date +"%s")
make -j$(nproc) ARCH=arm64 O=out ${DEFCONFIG}
make -j$(nproc) ARCH=arm64 O=out 2>&1| tee build.log
if [[ ! -f $(pwd)/out/arch/arm64/boot/Image.gz-dtb ]] ; then
    curl -F document=@$(pwd)/build.log "https://api.telegram.org/bot${token}/sendDocument" -F chat_id=${my_id}
    curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" -d chat_id=${my_id} -d text="Build failed! at branch $(git rev-parse --abbrev-ref HEAD)"
  exit 1 ;
fi
END=$(date +"%s")
DIFF=$(( END - START ))
curl -F document=@$(pwd)/build.log "https://api.telegram.org/bot${token}/sendDocument" -F chat_id=${my_id}
LINUXV="v$(cd ../axylon && cat $(pwd)/out/.config | grep Linux/arm64 | cut -d " " -f3)"
mv $(pwd)/out/arch/arm64/boot/Image.gz-dtb ${AKN}
NAME=Axylon-rova-x49-"$(date +'%d%m%y')"
TEMPZIP=${NAME}-unsigned.zip
ZIP=${NAME}.zip
cd ${AKN} && zip -r9q "${TEMPZIP}" *
curl -sLo zipsigner-3.0.jar https://raw.githubusercontent.com/baalajimaestro/AnyKernel2/master/zipsigner-3.0.jar
java -jar zipsigner-3.0.jar "${TEMPZIP}" "${ZIP}"
curl -F "disable_web_page_preview=true" -F "parse_mode=html" -F document=@$(echo "${ZIP}") "https://api.telegram.org/bot${token}/sendDocument" -F caption="""
#riva #rolex #rova
New <b>Axylon-rova Linux "${LINUXV}"</b>
<i>Commit</i>: <code>${cmsg}</code>
<i>MD5:</i> <code>$(md5sum ${ZIP} | cut -d " " -f 1)</code>
<b>succeed</b> took $((DIFF / 60))m, $((DIFF % 60))s!" -F chat_id=${channel_id}
