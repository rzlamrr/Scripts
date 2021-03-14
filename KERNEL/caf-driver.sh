#!/bin/bash
#
# Copyright (C) 2020 azrim.
# Copyright (C) 2021 rzlamrr.
# All rights reserved.

# VAR
qcacld="https://source.codeaurora.org/quic/la/platform/vendor/qcom-opensource/wlan/qcacld-3.0"
fw_api="https://source.codeaurora.org/quic/la/platform/vendor/qcom-opensource/wlan/fw-api"
qca_wifi_host_cmn="https://source.codeaurora.org/quic/la/platform/vendor/qcom-opensource/wlan/qca-wifi-host-cmn"
audio="https://source.codeaurora.org/quic/la/platform/vendor/opensource/audio-kernel/"
data="https://source.codeaurora.org/quic/la/platform/vendor/qcom-opensource/data-kernel/"

merge() {
if [[ "${INITIAL}" =~ "true" ]]; then
    #just for initial merge
    /usr/lib/git-core/git-subtree add --prefix drivers/staging/qcacld-3.0 "${qcacld}" "${TAG}"
    /usr/lib/git-core/git-subtree add --prefix drivers/staging/fw-api "${fw_api}" "${TAG}"
    /usr/lib/git-core/git-subtree add --prefix drivers/staging/qca-wifi-host-cmn "${qca_wifi_host_cmn}" "${TAG}"
    /usr/lib/git-core/git-subtree add --prefix techpack/audio "${audio}" "${TAG}"
    /usr/lib/git-core/git-subtree add --prefix techpack/data "${data}" "${TAG}"
elif [[ "${INITIAL}" =~ "merge" ]]; then
    git fetch "${qcacld}" "${TAG}"
    git merge -s ours --no-commit --allow-unrelated-histories FETCH_HEAD && git read-tree --prefix=drivers/staging/qcacld-3.0 -u FETCH_HEAD
    git commit -m "qcacld: Initial merge from ${TAG}"
    git fetch "${fw_api}" "${TAG}"
    git merge -s ours --no-commit --allow-unrelated-histories FETCH_HEAD && git read-tree --prefix=drivers/staging/fw-api -u FETCH_HEAD
    git commit -m "fw-api: Initial merge from ${TAG}"
    git fetch "${qca_wifi_host_cmn}" "${TAG}"
    git merge -s ours --no-commit --allow-unrelated-histories FETCH_HEAD && git read-tree --prefix=drivers/staging/qca-wifi-host-cmn -u FETCH_HEAD
    git commit -m "qca-wifi-host-cmn: Initial merge from ${TAG}"
    git fetch "${audio}" "${TAG}"
    git merge -s ours --no-commit --allow-unrelated-histories FETCH_HEAD && git read-tree --prefix=techpack/audio -u FETCH_HEAD
    git commit -m "techpack/audio: Initial merge from ${TAG}"
    git fetch "${data}" "${TAG}"
    git merge -s ours --no-commit --allow-unrelated-histories FETCH_HEAD && git read-tree --prefix=techpack/data -u FETCH_HEAD
    git commit -m "techpack/data: Initial merge from ${TAG}"
else
    git fetch "${qcacld}" "${TAG}" && git merge -X subtree=drivers/staging/qcacld-3.0 FETCH_HEAD
    git fetch "${fw_api}" "${TAG}" && git merge -X subtree=drivers/staging/fw-api FETCH_HEAD
    git fetch "${qca_wifi_host_cmn}" "${TAG}" && git merge -X subtree=drivers/staging/qca_wifi_host_cmn FETCH_HEAD
    git fetch "${audio}" "${TAG}" && git merge -X subtree=techpack/audio FETCH_HEAD
    git fetch "${data}" "${TAG}" && git merge -X subtree=techpack/data FETCH_HEAD
    fi
}

function parse_parameters() {
    while [[ $# -ge 1 ]]; do
        case ${1} in
            "-i"|"--initial")
                shift
                INITIAL=${1}
                [[ $# -lt 1 ]] && INITIAL=true ;;

            "-t"|"--tag")
                shift
                TAG=${1}
                [[ $# -lt 1 ]] && echo "No tag provided!" && exit ;;

            "-h"|"--help")
                echo "Simple script to merge or updating CAF tags."
                echo
                echo "Usage: update [-option] arguments"
                echo "options:"
                echo "* -t | --tag"
                echo "     Your CAF tag"
                echo "  -i | --initial"
                echo "     Without argument: Initial (If you about to initial merge CAF tag)"
                echo "     With merge argument: Initial merge (Same as initial, just use git merge)"
                echo "  -h | --help"
                echo "     Print this Help"
                echo
                echo "ex: ./caf-driver.sh -i merge -t LA.UM.9.11.r1-03200-NICOBAR.0"
                echo
                echo "* is necessary, must be set" ;;
            *)
                echo "Invalid parameter!" && echo "Use -h for available options" && exit ;;
        esac

        shift
    done
}

parse_parameters "$@"
merge
