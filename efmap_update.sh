#!/bin/sh
export PATH=/bin:$PATH
cd /storage/emulated/0/Android/gs_vibrator/
# 获取efmap.txt文件的总行数，用于计算进度
TOTAL_LINES=$(wc -l <efmap.txt)
CURRENT_LINE=0
# 文件标志
FILE_FLAG=0
# 单个文件权限设定
function set_perm() {
  chown $2:$3 $1 || return 1
  chmod $4 $1 || return 1
  local CON=$5
  [ -z $CON ] && CON=u:object_r:system_file:s0
  chcon $CON $1 || return 1
}
# 递归文件权限设定
function set_perm_recursive() {
  find $1 -type d 2>/dev/null | while read dir; do
    set_perm $dir $2 $3 $4 $6
  done
  find $1 -type f -o -type l 2>/dev/null | while read file; do
    set_perm $file $2 $3 $5 $6
  done
}
# 重启服务
function restart_service() {
  stop $1
  start $1
}
# 文件测试
function test_file() {
  if [ -f "/data/odm/etc/gs2/efmap.txt.last" ]; then
    sort -u efmap.txt >/cache/a_tmp.txt
    sed -i "/^#/d" /cache/a_tmp.txt
    sort -u /data/odm/etc/gs2/efmap.txt.last >/cache/b_tmp.txt
    sed -i "/^#/d" /cache/b_tmp.txt
    diff /cache/a_tmp.txt /cache/b_tmp.txt | grep -E "< .+" | sed "s/^..//g" >a_only.txt
    comm -3 /cache/a_tmp.txt /cache/b_tmp.txt | grep -v ''$'\t''' >a_only.txt
    FILE_FLAG=1
    rm -rf /cache/a_tmp.txt
    rm -rf /cache/b_tmp.txt
  else
    cp efmap.txt a_only.txt
    sort -u efmap.txt >a_only.txt
    sed -i "/^#/d" a_only.txt
    FILE_FLAG=1
  fi
  TOTAL_LINES=$(wc -l <a_only.txt)

}

test_file

while IFS= read -r line || [[ -n "$line" ]]; do
  # 忽略注释行
  if [[ $line != \#* ]]; then
    # 分割行并提取effect_id和新的effect_value
    effect_id=$(echo "$line" | cut -d'=' -f1 | sed 's/effect_//')
    effect_value=$(echo "$line" | cut -d'=' -f2)
    if [ -f "/data/odm/etc/gs2/9999/def/effect_$effect_id.bin" ]; then
      # echo 存在data/odm/etc/gs2/9999/def/effect_$effect_id.nin
      # 匹配包含指定effect_id的行，然后替换紧接着的effect_file行中的文件编号
      sed -i -e "/\"effect_id\" : $effect_id,/!b; n; s|effect_[0-9]*\.bin|effect_$effect_value.bin|" /data/odm/etc/gs2/vibrator_effect.json
    elif [ "$effect_id" = "strength_notification" ]; then
      echo $effect_value >/sys/class/qcom-haptics/vmax
    elif [ "$effect_id" = "strength_hapticFeedbackCl" ]; then
      echo 修改$effect_id到$effect_value
      echo $effect_value >/sys/class/qcom-haptics/cl_vmax
    elif [ "$effect_id" = "strength_hapticFeedbackFifo" ]; then
      echo 修改$effect_id到$effect_value
      echo $effect_value >/sys/class/qcom-haptics/fifo_vmax
    fi
  fi

  # 更新当前行数并打印进度条
  ((CURRENT_LINE++))
done <a_only.txt
rm -rf a_only.txt
echo # 打印最后的换行符以结束进度条
cp efmap.txt /data/odm/etc/gs2/efmap.txt.last
set_perm_recursive /data/odm/etc/gs2/vibrator_effect.json 0 0 0644 0644 u:object_r:vendor_configs_file:s0
version_flag=$(getprop | grep vendor.oplus.vibrator)
if [ -z "$version_flag" ]; then
  restart_service vendor.qti.vibrator
else
  restart_service vendor.oplus.vibrator
fi