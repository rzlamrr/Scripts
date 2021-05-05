#!/usr/bin/env bash

OUT="$pwd/out/target/product/*"
FILE=$(basename "${OUT}"/*RELEASE*zip)

export TZ=":Asia/Jakarta"

function wkt() {
    DATELOG=$(date "+%H%M-%d%m%Y")
}

sink () {
    repo init --depth=1 -u https://github.com/Komodo-OS-Rom/manifest -b ten
    repo sync -c -j22 --force-sync --no-clone-bundle --no-tags --optimized-fetch
}

makan () {
    . build/envsetup.sh
    lunch komodo_riva-userdebug
}

memasak() {
    masak komodo -j$(nproc --all)
}

tg_doc() {
    curl -F name=document -F document=@"$1" -H "Content-Type:multipart/form-data" "https://api.telegram.org/bot$BOT_TOKEN/sendDocument?chat_id=1095222353"
}

mkdir komodo && cd komodo || exit
wkt
if sink | tee sink-"${DATELOG}".txt;then
#if echo "skip sink"; then
    $CLONE_PRIV
    export KOMODO_VARIANT=RELEASE
    export USE_CCACHE=1
    export CCACHE_EXEC=$(command -v ccache)
    ccache -M 50G
#    makan
#    python3 cloner.py
    cd ..
    du -sh komodo
    exit
    if memasak | tee masak-"${DATELOG}".txt;then
        FILEPATH=${OUT}/${FILE}
        sshpass -p "$SF_PASS" sftp -oBatchMode=no rzlamrr@frs.sourceforge.net:/home/frs/project/dvstLab/ > /dev/null 2>&1 <<EOF
cd komodo
put $FILEPATH
exit
EOF
    else
        grep -iE 'crash|error|failed|fatal|fail' masak-"${DATELOG}".txt > masaktrim-"${DATELOG}".txt
        tg_doc masak-"${DATELOG}".txt
        tg_doc masaktrim-"${DATELOG}".txt
    fi
else
    tg_doc sink-"${DATELOG}".txt
fi
