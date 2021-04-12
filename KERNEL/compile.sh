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
                KBUILD_BUILD_USER=${1} ;;

            "-h"|"--host")
                shift
                KBUILD_BUILD_HOST=${1} ;;

            "-ak"|"--anykernel")
                shift
                ANYKERNEL_REPO=${1} ;;

            "-akb"|"--akbranch")
                shift
                ANYKERNEL_BRANCH=${1} ;;

            "-clang"|"--clang")
                shift
                COMP_URL=${1} ;
                COMPILER="clang" ;;

            "-gcc"|"--gcc")
                shift
                GCC=${1}
                COMPILER="gcc" ;;

            "-r"|"--regen")
                shift
                REGEN=${1} ;;

            "-d"|"--defconfig")
                shift
                DEFCONFIG=${1} ;;

            "-k"|"--kramel")
                shift
                KRAMEL=${1} ;;

            "-cn"|"--codename")
                shift
                CODENAME=${1} ;;

            *)
                echo "Invalid parameter!" ;;
        esac

        shift
    done


    if [[ -n "$CI" ]]; then
        if [[ -n "$DRONE" ]]; then
            BUILD_NUMBER="$DRONE_BUILD_NUMBER"
            PLATFORM="Drone CI"
            WORK_BRANCH="$DRONE_REPO_BRANCH"
            CI_URL=https://cloud.drone.io/"$DRONE_REPO"/"$DRONE_BUILD_NUMBER"
        elif [[ -n "$CIRCLECI" ]]; then
            BUILD_NUMBER="$CIRCLE_BUILD_NUM"
            PLATFORM="Circle CI"
            WORK_BRANCH="$CIRCLE_BRANCH"
            CI_URL="$CIRCLE_BUILD_URL"
        else
            PLATFORM="CI "
            WORK_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
        fi
    fi

    if [[ -z "${KBUILD_BUILD_USER}" ]]; then
        export KBUILD_BUILD_USER=rzlamrr
    fi

    if [[ -z "${KBUILD_BUILD_HOST}" ]]; then
        export KBUILD_BUILD_HOST=dvstLab
    fi

    if [[ "$COMPILER" == "clang" ]]; then
        if [[ "${COMP_URL}" == "proton" || -z "$COMP_URL" ]]; then
            echo "Using proton clang!"
            COMP_URL="https://github.com/kdrag0n/proton-clang"
            CLANG_DIR="$HOME/clang/proton"
        elif [[ "${COMP_URL}" == "silont" ]]; then
            echo "Using silont clang!"
            CLANG_DIR="$HOME/clang/silont"
            COMP_URL="https://github.com/silont-project/silont-clang"
        elif [[ "${COMP_URL}" == "sdclang" ]]; then
            echo "Using sdclang!"
            CLANG_DIR="$HOME/clang/sdllvm"
            COMP_URL="https://github.com/ThankYouMario/proprietary_vendor_qcom_sdclang"
        elif [[ "${COMP_URL}" == "azure" ]]; then
            echo "Using silont clang!"
            CLANG_DIR="$HOME/clang/azure"
            COMP_URL="https://github.com/Panchajanya1999/azure-clang"
        else
            echo -e "Using ${COMP_URL}"
            CLANG_DIR="$HOME/clang"
        fi
        PATH="$CLANG_DIR/bin:${PATH}"
    elif [[ "$COMPILER" == "gcc" ]]; then
        if [[ "$GCC" == "eva" ]]; then
            COMP_URL="https://github.com/mvaisakh/gcc-arm64"
            COMP32_URL="https://github.com/mvaisakh/gcc-arm"
            COMP_BRANCH="gcc-master"
            COMP32_BRANCH="gcc-master"
            CC="aarch64-elf-"
            CC32="arm-eabi-"
            GCC_DIR="$HOME/gcc/eva"
            GCC32_DIR="$HOME/gcc32/eva"
        elif [[ "$GCC" == "silont" ]]; then
            COMP_URL="https://github.com/silont-project/aarch64-elf-gcc"
            COMP32_URL="https://github.com/silont-project/arm-silont-linux-gnueabi"
            COMP_BRANCH="11.x"
            COMP32_BRANCH="arm64/11"
            CC="aarch64-silont-linux-gnu-"
            CC32="arm-silont-linux-gnueabi-"
            GCC_DIR="$HOME/gcc/silont"
            GCC32_DIR="$HOME/gcc32/silont"
        fi
        PATH="${GCC_DIR}/bin:${GCC32_DIR}/bin:${PATH}"
    else
        echo "Compiler is missing!"
        exit 1
    fi
    export PATH
    echo -e "$PATH"

    KERNEL_DIR="${PWD}"
    DTB_TYPE="" # define as "single" if want use single file
    IMG="${KERNEL_DIR}"/out/arch/arm64/boot/Image.gz-dtb # if use single file define as Image.gz-dtb instead
    DTB="${KERNEL_DIR}"/out/arch/arm64/boot/dtbo.img # and comment this variable
    ANYKERNEL="${HOME}"/anykernel

    # Defconfig
    if [[ ! -f "arch/arm64/configs/$DEFCONFIG" ]]; then
        echo "No defconfig!"
        exit 1
    fi

    KERNELNAME="SiLonT-Ginkgo-${CODENAME}-$(date +%y%m%d)"
    TEMPZIPNAME="${KERNELNAME}-unsigned.zip"
    ZIPNAME="${KERNELNAME}.zip"
    KERNELSYNC=${KERNEL}-${CODENAME}

    # Sync name
    sed -i "50s/.*/CONFIG_LOCALVERSION=\"-${KERNELSYNC}\"/g" arch/arm64/configs/"${DEFCONFIG}"
}

param "$@"

# Export Telegram.sh
CHATID="$CHATID" # Group/channel chatid (use rose/userbot to get it)
TELEGRAM_TOKEN="$TOKED" # Get from botfather
TELEGRAM_FOLDER="${HOME}"/telegram
if [[ ! -d "${TELEGRAM_FOLDER}" ]]; then
    wget https://github.com/fabianonline/telegram.sh/raw/master/telegram -P "${TELEGRAM_FOLDER}" &> /dev/null
    chmod +x "${TELEGRAM_FOLDER}"/telegram
fi
TELEGRAM="${TELEGRAM_FOLDER}"/telegram

tg_cast() {
    "${TELEGRAM}" -t "${TELEGRAM_TOKEN}" -c "${CHATID}" -D -H \
    "$(
		for POST in "${@}"; do
			echo "${POST}"
		done
    )"
}

tg_log() {
    "${TELEGRAM}" -t "${TELEGRAM_TOKEN}" -c "${CHATID}" -f "${1}" -H "${2}"
}

clonecompiler() {
    # clone clang if not exist
    if [[ "$COMPILER" == "clang" ]]; then
        git clone --depth=1 ${COMP_URL} "${CLANG_DIR}"
        COMPILER_STRING="$("$CLANG_DIR"/bin/clang --version | head -n 1 | perl -pe 's/\((?:http|git).*?\)//gs')"
    elif [[ "$COMPILER" == "gcc" ]]; then
        git clone --depth=1 ${COMP_URL} -b ${COMP_BRANCH} "${GCC_DIR}"
        git clone --depth=1 ${COMP32_URL} -b ${COMP32_BRANCH} "${GCC32_DIR}"
        COMPILER_STRING="$("$GCC_DIR"/bin/${CC}gcc --version | head -n 1 | perl -pe 's/\((?:http|git).*?\)//gs')"
    fi
}

# Regenerating
regenerate() {
    cp out/.config arch/arm64/configs/"${DEFCONFIG}"
    git config user.name rzlamrr
    git config user.email rizal82rebel@gmail.com
    git add arch/arm64/configs/"${DEFCONFIG}"
    git commit -m "defconfig: Regenerate"
    git push
}

# Building
makekernel() {
    rm -rf "${KERNEL_DIR}"/out/arch/arm64/boot # clean previous compilation
    make O=out ARCH=arm64 "${DEFCONFIG}"
    if [[ "${REGEN}" == "true" ]]; then
        regenerate
    fi
    if [[ "${COMP_TYPE}" == "clang" ]]; then
        make -j"$(nproc --all)" O=out ARCH=arm64 \
                LD=ld.lld CC=clang \
                AS=llvm-as AR=llvm-ar NM=llvm-nm \
                OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump \
                STRIP=llvm-strip \
        		CROSS_COMPILE="aarch64-linux-gnu-" \
		        CROSS_COMPILE_ARM32="arm-linux-gnueabi-" \
                Image.gz-dtb dtbo.img
    else
	    make -j"$(nproc --all)" O=out ARCH=arm64 \
                CROSS_COMPILE="${GCC_DIR}/bin/${CC}" \
                CROSS_COMPILE_ARM32="${GCC32_DIR}/bin/${CC32}" \
                Image.gz-dtb dtbo.img
    fi
}

# Packing kranul
packingkernel() {
    # Copy compiled kernel
    if [[ -d "${ANYKERNEL}" ]]; then
        rm -rf "${ANYKERNEL}"
    fi

    ANYKERNEL_REPO="https://github.com/rzlamrr/anykernel3"
    if [[ "${KBRANCH}" == "x11" ]]; then
        ANYKERNEL_BRANCH="geleven"
    elif [[ "${KBRANCH}" == "x10" ]]; then
        ANYKERNEL_BRANCH="gten"
    else
        ANYKERNEL_BRANCH="geleven"
    fi

    git clone "$ANYKERNEL_REPO" -b "$ANYKERNEL_BRANCH" "${ANYKERNEL}" &> /dev/null

    cp "${IMG}" "${ANYKERNEL}"/Image.gz-dtb
    if [[ -z "${DTB_TYPE}" ]]; then
        cp "${DTB}" "${ANYKERNEL}"/dtbo.img
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
    tg_log "$ZIPNAME" "Ginkgo with ${COMPILER_STRING} <b>succeed</b> took $((DIFF / 60))m, $((DIFF % 60))s! @fakhiralkda"
}

clonecompiler
# Starting
tg_cast "<b>STARTING KERNEL BUILD ${PLATFORM} #${BUILD_NUMBER}</b>" \
	"Compiler: <code>${COMPILER_STRING}</code>" \
	"Name: <code>${KERNELNAME}</code>" \
	"Version: <code>$(make kernelversion)</code>" \
	"Branch: ${WORK_BRANCH}" \
	"Commit: <code>$(git log --pretty=format:"%s" -1)</code>" \
        "${CI_URL}"
START=$(date +"%s")
if [ "${KRAMEL}" == "qs" ]; then
cat <<'EOF' >> arch/arm64/configs/vendor/ginkgo-perf_defconfig
CONFIG_LTO_CLANG=y
CONFIG_THINLTO=y
CONFIG_LD_DEAD_CODE_DATA_ELIMINATION=y
EOF
fi
makekernel 2>&1| tee mklog.txt
# Check If compilation is success
if ! [ -f "${IMG}" ]; then
	END=$(date +"%s")
	DIFF=$(( END - START ))
	echo -e "Kernel compilation failed, See buildlog to fix errors"
	tg_log "mklog.txt" "Ginkgo ${WORK_BRANCH} <b>failed</b> in $((DIFF / 60))m, $((DIFF % 60))s! @fakhiralkda"
	exit 1
fi
packingkernel
