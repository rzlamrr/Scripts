#!/bin/bash
#
# Copyright (C) 2020 azrim.
# Copyright (C) 2020 rzlamrr.
# All rights reserved.

clear
# Parse the provided parameters
function param() {
    while [[ $# -ge 1 ]]; do
        case ${1} in
            "-u"|"--user")
                shift
                export KBUILD_BUILD_USER=${1} ;;

            "-h"|"--host")
                shift
                export KBUILD_BUILD_HOST=${1} ;;

            "-ak"|"--anykernel")
                shift
                export ANYKERNEL_REPO=${1} ;
                export ANYKERNEL_BRANCH=${2} ;;

            "-c"|"--clang")
                shift
                export CLANG_URL=${1} ;
                export COMP_TYPE="clang" ;;

            "-gcc")
                shift
                export GCC_DIR=${1} ;;

            "-gcc32")
                shift
                export GCC32_DIR=${1} ;;

            "-ci")
                shift
                export CI=${1} ;;

            "-r"|"-regen")
                shift
                REGEN=${1} ;;

            "-d"|"-defconfig")
                shift
                DEFCONFIG=${1} ;;

            "-cn"|"-codename")
                shift
                CODENAME=${1} ;;

            *)
                echo "Invalid parameter!" ;;
        esac

        shift
    done

    if [[ "$CI" == "drone" ]]; then
        echo "Yeay running in drone ci!"
        export HOME=/drone/src
    fi

    if [[ -z "${KBUILD_BUILD_USER}" ]]; then
        export KBUILD_BUILD_USER=rzlamrr
    fi
    if [[ -z "${KBUILD_BUILD_HOST}" ]]; then
        export KBUILD_BUILD_HOST=dvstLab
    fi

    if [[ "${CLANG_URL}" == "proton" || -z "${CLANG_URL}" ]]; then
        echo "Using proton clang!"
        export CLANG_URL=https://github.com/kdrag0n/proton-clang
        export CLANG_DIR="$HOME/clang/proton"
    elif [[ "${CLANG_URL}" == "silont" ]]; then
        echo "Using silont clang!"
        export CLANG_DIR="$HOME/clang/silont"
        export CLANG_URL=https://github.com/silont-project/silont-clang
    elif [[ "${CLANG_URL}" == "sdclang" ]]; then
        echo "Using sdclang!"
        export CLANG_DIR="$HOME/clang/sdllvm"
        export CLANG_URL=https://github.com/ThankYouMario/proprietary_vendor_qcom_sdclang
    else
        echo -e "Using ${CLANG_URL}"
        export CLANG_DIR="$HOME/kernel/clang"
    fi

    if [[ "${COMP_TYPE}" == "clang" ]]; then
        export PATH="$CLANG_DIR/bin:${PATH}"
    else
        export PATH="${GCC_DIR}/bin:${GCC32_DIR}/bin:${PATH}"
    fi
    echo "$PATH"

    KERNEL_DIR="${PWD}"
    DTB_TYPE="" # define as "single" if want use single file
    KERN_IMG="${KERNEL_DIR}"/out/arch/arm64/boot/Image.gz-dtb             # if use single file define as Image.gz-dtb instead
    KERN_DTB="${KERNEL_DIR}"/out/arch/arm64/boot/dtbo.img # and comment this variable
    ANYKERNEL="${HOME}"/anykernel

    # Repo URL
    if [[ -z "${ANYKERNEL_REPO}" || -z "${ANYKERNEL_BRANCH}" ]]; then
        echo "Using default anykernel!"
        ANYKERNEL_REPO="https://github.com/rzlamrr/anykernel3"
        ANYKERNEL_BRANCH="master"
    fi

    # Defconfig
    # DEFCONFIG="silont-perf_defconfig"
    if [[ "$REGEN" == "true" ]]; then
        REGENERATE_DEFCONFIG="true" # unset if don't want to regenerate defconfig
    fi

    # Costumize
    KERNEL="SiLonT"
    DEVICE="Ginkgo"
    KERNELTYPE="${CODENAME}"
    KBRANCH="$(git rev-parse --abbrev-ref HEAD)"
    KERNELNAME="${KERNEL}-${DEVICE}-${KERNELTYPE}-${KBRANCH}-$(date +%y%m%d)"
    TEMPZIPNAME="${KERNELNAME}-unsigned.zip"
    ZIPNAME="${KERNELNAME}.zip"
    KERNELSYNC=${KERNEL}-${KERNELTYPE}

    # Sync name
    sed -i "50s/.*/CONFIG_LOCALVERSION=\"-${KERNELSYNC}\"/g" arch/arm64/configs/${DEFCONFIG}
}

param "$@"

# Export Telegram.sh
export CHATID="$CHATID" # Group/channel chatid (use rose/userbot to get it)
export TELEGRAM_TOKEN="$TOKED" # Get from botfather
export TELEGRAM_FOLDER="${HOME}"/telegram
if ! [ -d "${TELEGRAM_FOLDER}" ]; then
    echo Wget telegram.sh
    wget -q https://github.com/fabianonline/telegram.sh/raw/master/telegram -P "${TELEGRAM_FOLDER}"
    chmod +x "${TELEGRAM_FOLDER}"/telegram
fi
export TELEGRAM="${TELEGRAM_FOLDER}"/telegram

tg_cast() {
    "${TELEGRAM}" -t "${TELEGRAM_TOKEN}" -c "${CHATID}" -H \
    "$(
		for POST in "${@}"; do
			echo "${POST}"
		done
    )"
}

tg_log() {
    "${TELEGRAM}" -t "${TELEGRAM_TOKEN}" -c "${CHATID}" -f "${1}" -H "${2}"
}

# Regenerating Defconfig
regenerate() {
    cp out/.config arch/arm64/configs/"${DEFCONFIG}"
    git config user.name rzlamrr
    git config user.email rizal82rebel@gmail.com
    git add arch/arm64/configs/"${DEFCONFIG}"
    git commit -m "defconfig: Regenerate"
    git push ${OIRIGN}
}

# Building
makekernel() {
    rm -rf "${KERNEL_DIR}"/out/arch/arm64/boot # clean previous compilation
    mkdir -p out
    make O=out ARCH=arm64 ${DEFCONFIG}
    if [[ "${REGENERATE_DEFCONFIG}" == "true" ]]; then
        regenerate
    fi
    if [[ "${COMP_TYPE}" == "clang" ]]; then
        make -j$(nproc --all) O=out \
                                ARCH=arm64 \
                                LD=ld.lld \
                                CC=clang \
                                AS=llvm-as \
                                AR=llvm-ar \
                                NM=llvm-nm \
                                OBJCOPY=llvm-objcopy \
                                OBJDUMP=llvm-objdump \
                                STRIP=llvm-strip \
                                CROSS_COMPILE=aarch64-linux-gnu- \
                                CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
                                Image.gz-dtb dtbo.img
    else
	    make -j$(nproc --all) O=out ARCH=arm64 CROSS_COMPILE="${GCC_DIR}/bin/aarch64-elf-" CROSS_COMPILE_ARM32="${GCC32_DIR}/bin/arm-eabi-"
    fi
}

# Packing kranul
packingkernel() {
    # Copy compiled kernel
    if [ -d "${ANYKERNEL}" ]; then
        rm -rf "${ANYKERNEL}"
    fi
    echo Cloning anykernel
    if [ "${KBRANCH}" == "x11" ]; then
        ANYKERNEL_BRANCH=geleven
    elif [ "${KBRANCH}" == "x10" ]; then
        ANYKERNEL_BRANCH=gten
    fi
    git clone -qq "$ANYKERNEL_REPO" -b "$ANYKERNEL_BRANCH" "${ANYKERNEL}"
    cp "${KERN_IMG}" "${ANYKERNEL}"/Image.gz-dtb
    if [[ -z "${DTB_TYPE}" ]]; then
        cp "${KERN_DTB}" "${ANYKERNEL}"/dtbo.img
    fi

    # Zip the kernel, or fail
    cd "${ANYKERNEL}" || exit
    zip -r9 "${TEMPZIPNAME}" ./*

    # Sign the zip before sending it to Telegram
    curl -sLo zipsigner-3.0.jar https://raw.githubusercontent.com/baalajimaestro/AnyKernel2/master/zipsigner-3.0.jar
    java -jar zipsigner-3.0.jar "${TEMPZIPNAME}" "${ZIPNAME}"

    # Ship it to the CI channel
    END=$(date +"%s")
    DIFF=$(( END - START ))
    tg_log "$ZIPNAME" "${DEVICE} with ${COMPILER_STRING} <b>succeed</b> took $((DIFF / 60))m, $((DIFF % 60))s! @fakhiralkda"
}

# clone clang if not exist
if ! [ -d "${CLANG_DIR}" ]; then
    git clone -qq --depth=1 https://github.com/silont-project/aarch64-silont-linux-gnu "$HOME/gcc"
    git clone -qq --depth=1 https://github.com/silont-project/arm-silont-linux-gnueabi "$HOME/gcc32"
    export PATH="$HOME/gcc/bin:$HOME/gcc32/bin:${PATH}"
    git clone -qq "$CLANG_URL" --depth=1 "$CLANG_DIR"
fi
COMPILER_STRING="$($CLANG_DIR/bin/clang --version | head -n 1 | perl -pe 's/\((?:http|git).*?\)//gs')"
# Starting
tg_cast "<b>STARTING KERNEL BUILD</b>" \
    "Compiler: <code>${COMPILER_STRING}</code>" \
	"Kernel: <code>${KERNEL}-${DEVICE}-${KERNELTYPE}</code>" \
	"Version: <code>$(make kernelversion)</code>" \
    "Branch: $(git rev-parse --abbrev-ref HEAD)" \
	"Commit: <code>$(git log --pretty=format:"%s" -1)</code>"
START=$(date +"%s")
export CROSS_COMPILE="aarch64-silont-linux-gnu-"
export CROSS_COMPILE_ARM32="arm-silont-linux-gnueabi-"
makekernel 2>&1| tee mklog.txt
# Check If compilation is success
if ! [ -f "${KERN_IMG}" ]; then
	END=$(date +"%s")
	DIFF=$(( END - START ))
	echo -e "Kernel compilation failed, See buildlog to fix errors"
	tg_log "mklog.txt" "${DEVICE} $(git rev-parse --abbrev-ref HEAD) <b>failed</b> in $((DIFF / 60))m, $((DIFF % 60))s! @fakhiralkda"
	exit 1
fi
tg_log "mklog.txt"
packingkernel
