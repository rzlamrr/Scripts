#!/usr/bin/env bash

if [[ -z "$job" ]]; then
  export job=$(nproc --all)
fi

if [[ -n "$setup" && -n "$lun" && -n "$compile" && -n "$depis" && -n "$rom" ]]; then
  echo tes
else
  read -p "Wut depis?(codename): " depis
  echo "Build type"
  read -p "(default userdebug): " type
  if [[ -z "$type" ]]; then
    export type=userdebug
  fi
  echo "Input rom vendor name"
  read -p "(This will be used for lunch): " rom
  echo "Input setup cmd"
  read -p "(default, bash build/envsetup.sh): " s
  echo "Input lunch cmd"
  read -p "(default, lunch "$rom"_"$depis"-"$type"): " l
  echo "Input compile cmd"
  read -p "(default, mka $depis -j$job): " c
  export setup=$s lun=$l comp=$c depis=$depis type=$type rom=$rom
  if [[ -z "$lun" ]]; then
    if [[ -z "$depis" || -z "$type" ]]; then
      echo "Unknown device and build type!!"
      exit
    else
      export lun="lunch "$rom"_"$depis"-"$type""
      echo $lun
    fi
  elif [[ -z "$s" ]]; then
    export setup="source build/envsetup.sh"
  fi
fi

build() {
  $setup
  $lun
  $comp
}

tg_doc() {
  curl -F name=document -F document=@log.txt -H "Content-Type:multipart/form-data" "https://api.telegram.org/$BOT_TOKEN/sendDocument?chat_id=1095222353"
}

build | tee build.txt
grep -iE 'crash|error|failed|fatal|fail' log.txt > btrim.txt
tg_doc log.txt
tg_doc trim.txt
