#!/usr/bin/env bash

OUT="$pwd/out/target/product/*"
FILE=$(basename ${OUT}/Cygnus*ginkgo*zip)

export TZ="Asia/Jakarta"

function wkt() {
    DATELOG=$(date "+%H%M-%d%m%Y")
}

sink () {
    repo init repo init -u https://github.com/cygnus-rom/manifest.git -b caf-11
    repo sync -c -j22 --force-sync --no-clone-bundle --no-tags --optimized-fetch
}

makan () {
    . build/envsetup.sh
    lunch cygnus_ginkgo-userdebug
}

masak() {
    make cygnus -j$(nproc --all)
}

tg_doc() {
    curl -F name=document -F document=@$1 -H "Content-Type:multipart/form-data" "https://api.telegram.org/bot$BOT_TOKEN/sendDocument?chat_id=1095222353"
}

mkdir cyg && cd cyg
wkt
if sink | tee sink-${DATELOG}.txt;then
    export KOMODO_VARIANT=RELEASE
    export USE_CCACHE=1
    export CCACHE_EXEC=$(command -v ccache)
    ccache -M 50G
    makan
    if masak | tee masak-${DATELOG}.txt;then
        FILEPATH=${OUT}/${FILE}
        sshpass -p "$SF_PASS" sftp -oBatchMode=no rzlamrr@frs.sourceforge.net:/home/frs/project/dvstLab/ > /dev/null 2>&1 <<EOF
cd komodo
put $FILEPATH
exit
EOF
    else
        grep -iE 'crash|error|failed|fatal|fail' masak-${DATELOG}.txt > masaktrim-${DATELOG}.txt
        tg_doc masak-${DATELOG}.txt
        tg_doc masaktrim-${DATELOG}.txt
    fi
else
    tg_doc sink-${DATELOG}.txt
fi
