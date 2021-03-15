#!/usr/bin/env bash

author()
{
  git config user.name "rzlamrr"
  git config user.email "rizal82rebel@gmail.com"
  git config credential.name "rzlamrr"
  git config credential.email "rizal82rebel@gmail.com"
}

trinket-devs_hals()
{
  rm -rf hardware/qcom-caf/sm8150/display hardware/qcom-caf/sm8150/media
  git clone --depth=1 https://github.com/trinket-devs/hardware_qcom-caf_sm8150_display -b ten hardware/qcom-caf/sm8150/display
  git clone --depth=1 https://github.com/trinket-devs/hardware_qcom-caf_sm8150_media -b ten hardware/qcom-caf/sm8150/media
}

erfanoabdi_hals()
{
  rm -rf hardware/qcom-caf/sm8150/display
  git clone --depth=1 https://github.com/erfanoabdi/android_hardware_qcom_display -b lineage-17.1-caf-sm6125 hardware/qcom-caf/sm8150/display
}

var()
{
  # Check and prompt if all variables were not filled #
  if [[ -n "$repo" && -n "$branch" && -n "$depis" && -n "$hals" && -n "$dhal" && -n "$aver" ]]; then
    echo "All variables are filled, skipping prompt!"
  else
    read -rp "Enter manifest repo link: " a
    read -rp "Enter manifest branch: " b
    read -rp "Android version(9/10/11): " c
    read -rp "Input your local manifets link(blank for default): " d
    if [[ -z "$manifest" ]];then
      read -rp "Wut depis bro?(codename): " e
      if [[ "$e" == "ginkgo" ]]; then
        read -rp "Do you want to change hals? Y/N: " f
        if [[ "$f" = "${f#[Yy]}" ]];then
          echo "1. trinket-devs"
          echo "2. erfanoabdi"
          read -rp "Which hals'?(1/2) " g
        fi
      fi
    fi
    export repo=$a branch=$b aver=$c manifest=$d depis=$e hals=$f dhal=$g
  fi

  if [[ -z "$repo" || -z "$branch" || -z "$aver" || -z "$depis" || -z "$hals" && -z "$dhal" ]]; then
    echo """

One or more variables are not filled!!
repo: $repo
branch: $branch
android ver: $aver
custom manifest: $manifest
device: $depis
hals: $hals
dhal: $dhal

Check variables above, fix unfilled one!!"""
    exit
  fi
}

sync()
{
  # Init repository #
  if [[ -z "$repo" || -z "$branch" ]]; then
    echo "Nothing repo and/or branch to init" 
    exit
  else
    repo init --depth=1 -u $repo -b $branch
  fi

  # Some scripts #
  if [[ -n "$manifest" ]];then
    rm -rf .repo/local*
    wget "$manifest" -P .repo/local_manifests/
  else
    if [[ -z "$depis" ]]; then
      echo "Idk wut depis!!"
      exit
    else
      wget https://raw.githubusercontent.com/rzlamrr/local_manifests/master/$depis-$aver.xml -P .repo/local_manifests/
    fi
  fi

  # Start syncing #
  repo sync -c -q --force-sync --optimized-fetch --no-tags --no-clone-bundle --prune -j$(nproc --all)

  # Misc #
  if [[ "$depis" == "ginkgo" ]]; then
    if [[ "$dhal" == "1" ]];then
      trinket-devs_hals
    elif [[ "$dhal" == "2" ]];then
      erfanoabdi_hals
    fi
  fi

  # Author #
  cd device/xiaomi/$depis
  author
  cd ../../../vendor/xiaomi/$depis
  author
  cd ../../..
  echo "Done!!"
}

tg_doc()
{
  curl -F name=document -F document=@$1 -H "Content-Type:multipart/form-data" "https://api.telegram.org/$BOT_TOKEN/sendDocument?chat_id=1095222353"
}

main() {
  var
  sync
}

if [[ -z "$BOT_TOKEN" ]]; then
  echo "NO bot token!"
  exit
fi

main | tee sync.txt
grep -iE 'crash|error|failed|fatal|fail' sync.txt > strim.txt
tg_doc sync.txt
tg_doc strim.txt
