#!/bin/sh
##########################################################################################
# Config Flags
##########################################################################################

# Set to true if you do *NOT* want Magisk to mount
# any files for you. Most modules would NOT want
# to set this flag to true
SKIPMOUNT=false

# Set to true if you need to load system.prop
PROPFILE=true

# Set to true if you need post-fs-data script
POSTFSDATA=true

# Set to true if you need late_start service script
LATESTARTSERVICE=true

##########################################################################################
# Replace list
##########################################################################################

# List all directories you want to directly replace in the system
# Check the documentations for more info why you would need this

# Construct your list in the following format
# This is an example
# REPLACE_EXAMPLE="
# /system/app/Youtube
# /system/priv-app/SystemUI
# /system/priv-app/Settings
# /system/framework
# "

# Construct your own list here
REPLACE=""

##########################################################################################
#
# Function Callbacks
#
# The following functions will be called by the installation framework.
# You do not have the ability to modify update-binary, the only way you can customize
# installation is through implementing these functions.
#
# When running your callbacks, the installation framework will make sure the Magisk
# internal busybox path is *PREPENDED* to PATH, so all common commands shall exist.
# Also, it will make sure /data, /system, and /vendor is properly mounted.
#
##########################################################################################
##########################################################################################
#
# The installation framework will export some variables and functions.
# You should use these variables and functions for installation.
#
# ! DO NOT use any Magisk internal paths as those are NOT public API.
# ! DO NOT use other functions in util_functions.sh as they are NOT public API.
# ! Non public APIs are not guranteed to maintain compatibility between releases.
#
# Available variables:
#
# MAGISK_VER (string): the version string of current installed Magisk
# MAGISK_VER_CODE (int): the version code of current installed Magisk
# BOOTMODE (bool): true if the module is currently installing in Magisk Manager
# MODPATH (path): the path where your module files should be installed
# TMPDIR (path): a place where you can temporarily store files
# ZIPFILE (path): your module's installation zip
# ARCH (string): the architecture of the device. Value is either arm, arm64, x86, or x64
# IS64BIT (bool): true if $ARCH is either arm64 or x64
# API (int): the API level (Android version) of the device
#
# Availible functions:
#
# ui_print <msg>
#     print <msg> to console
#     Avoid using 'echo' as it will not display in custom recovery's console
#
# abort <msg>
#     print error message <msg> to console and terminate installation
#     Avoid using 'exit' as it will skip the termination cleanup steps
#
# set_perm <target> <owner> <group> <permission> [context]
#     if [context] is empty, it will default to "u:object_r:system_file:s0"
#     this function is a shorthand for the following commands
#       chown owner.group target
#       chmod permission target
#       chcon context target
#
# set_perm_recursive <directory> <owner> <group> <dirpermission> <filepermission> [context]
#     if [context] is empty, it will default to "u:object_r:system_file:s0"
#     for all files in <directory>, it will call:
#       set_perm file owner group filepermission context
#     for all directories in <directory> (including itself), it will call:
#       set_perm dir owner group dirpermission context
#
##########################################################################################x

# Set what you want to display when installing your module
print_modname()
{
    ui_print ""
    ui_print "* 作者: int萌新很新"
    ui_print "* 版本: v4R"
    ui_print "* 模块用途: 合并一加11、一加Ace2Pro、一加12的振动优化"
    ui_print "*"
    ui_print ""
}

# Copy/extract your module files into $MODPATH in on_install.
on_install()
{
    $BOOTMODE || abort "! It cannot be installed in recovery."

    print_modname
    
    ui_print "- Extracting module files"
    unzip -o "$ZIPFILE" -x 'META-INF/*' -d $MODPATH > /dev/null
    prjName=$(cat /proc/oplusVersion/prjName)
    target_data_index=''
    if [ "$prjName" = "22825" ];then
        target_data_index=22825
    else
        target_data_index=22811
    fi
    unzip -o $MODPATH/data_${target_data_index}.zip -d /data > /dev/null
    ui_print "- Installing"
    target_so=''
    if [ -f "/vendor/lib64/libqtivibratoreffect.so" ]; then
        target_so=libqtivibratoreffect.so
        main_dir=system/vendor
        mkdir -p $MODPATH/vendor/lib64/
        cp -f /vendor/lib64/libqtivibratoreffect.so $MODPATH/vendor/lib64/
        if [ "$KSU" != "true" ];
        then
            mkdir -p $MODPATH/system/vendor
            mv $MODPATH/vendor $MODPATH/system/
        fi
    elif [ -f "/odm/lib64/liboplusvibratoreffect.so" ]; then
        target_so=liboplusvibratoreffect.so
        main_dir=odm
        mkdir -p $MODPATH/odm/lib64/
        cp -f /odm/lib64/liboplusvibratoreffect.so $MODPATH/odm/lib64/
        echo 'mount --bind $MODDIR/odm/lib64/liboplusvibratoreffect.so /odm/lib64/liboplusvibratoreffect.so' >> $MODPATH/post-fs-data.sh
    else
        abort "不支持您的手机"
    fi
    set_perm_recursive  $MODPATH/bin       0     0       0755      0777
    $MODPATH/bin/magiskboot hexpatch $MODPATH/$main_dir/lib64/$target_so 2f6f646d2f6574632f7669627261746f722f7669627261746f725f6566666563742e6a736f6e 2f646174612f6f646d2f6574632f6773322f7669627261746f725f6566666563742e6a736f6e
    target_android_main_dir=/storage/emulated/0/Android/gs_vibrator
    mkdir -p $target_android_main_dir
    if [ -f "${target_android_main_dir}/efmap.txt" ]; then
        ui_print "- 检测到sdcard已存在配置文件！"
        current_time=$(date +"%Y%m%d_%H%M%S")
        backup_file="${target_android_main_dir}/efmap_${current_time}.txt.bak"
        ui_print "- 已经备份您的修改为${backup_file}"
        mv $target_android_main_dir/efmap.txt $backup_file
    fi
    rm -rf $target_android_main_dir/*.rc
    cp -f $MODPATH/gs/手动更新.rc $target_android_main_dir
    cp -f $MODPATH/gs/efmap.txt $target_android_main_dir
    clean_tmp
    set_permissions
}

# Only some special files require specific permissions
# This function will be called after on_install is done
# The default permissions should be good enough for most cases
set_permissions()
{
    # Here are some examples:
    # set_perm_recursive  $MODPATH/system/lib       0     0       0755      0644
    # set_perm  $MODPATH/system/bin/app_process32   0     2000    0755      u:object_r:zygote_exec:s0
    # set_perm  $MODPATH/system/bin/dex2oat         0     2000    0755      u:object_r:dex2oat_exec:s0
    # set_perm  $MODPATH/system/lib/libart.so       0     0       0644
    set_perm_recursive  $MODPATH/vendor             0     0         0755      0644      u:object_r:vendor_configs_file:s0
    set_perm_recursive  $MODPATH/odm             0     0         0755      0644      u:object_r:vendor_configs_file:s0
    set_perm_recursive $MODPATH/my_product/         0     0         0755      0644      u:object_r:system_file:s0
    set_perm /data/odm/gs2/etc/effect_waveform_override.xml         0     0         0755      0644      u:object_r:system_file:s0
    set_perm_recursive /data/odm                    0     0         0755      0644      u:object_r:vendor_configs_file:s0
    set_perm  $MODPATH/efmap_update.sh 0     0         0755
    return
}

# You can add more functions to assist your custom script code
clean_tmp()
{
    rm -rf $MODPATH/customize.sh
    rm -rf $MODPATH/data.zip
    rm -rf $MODPATH/bin
    rm -rf $MODPATH/gs
}

on_install
