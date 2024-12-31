#!/bin/bash

## Step 0.  Print some info.  Useful on the target but not on the host
uname -r
head -n 1 /etc/nv_tegra_release

## Step 1. Ok, Lets download the necessary source and toolchain.

mkdir 36.3
cd 36.3
#make a folder for outputfiles and mod installs
mkdir kernel_out
mkdir -p rootfs/boot

#save our dirs
export SRC_PATH=$PWD
export OUT_PATH=$PWD/kernel_out
export INSTALL_MOD_PATH=$PWD/rootfs


#download the source and extract other sources
wget https://developer.nvidia.com/downloads/embedded/l4t/r36_release_v3.0/sources/public_sources.tbz2
tar xf public_sources.tbz2

cd Linux_for_Tegra/source/

tar xf kernel_src.tbz2
tar xf kernel_oot_modules_src.tbz2
tar xf nvidia_kernel_display_driver_source.tbz2

# back to 36.3 Directory
cd $SRC_PATH

#download the tool chain and extract, only needed if cross compiling, but what the hey.
wget https://developer.nvidia.com/downloads/embedded/l4t/r36_release_v3.0/toolchain/aarch64--glibc--stable-2022.08-1.tar.bz2
tar xf aarch64--glibc--stable-2022.08-1.tar.bz2 
export CROSS_COMPILE=$SRC_PATH/aarch64--glibc--stable-2022.08-1/bin/aarch64-buildroot-linux-gnu-
export ARCH=arm64

#get the current systems config file (Assuming you are on the target) and put it in the output directory
#the make command looks there for the .config
#zcat /proc/config.gz > jetson_config
#cp jetson_config $OUT_PATH/.config

#since we are going to cross_compile, lets say that our config is in the current dir we are running the script from
#You will need to copy it from the target to the host for your system
cp $SRC_PATH/../config_36.3_JP6.1_canusb_modules $OUT_PATH/.config

# Step 2. Ok, everything should be downloaded and environmental variables are set.  Lets compile the kernel

cd $SRC_PATH/Linux_for_Tegra/source
#enable the RT patch bc we are cool.  
./generic_rt_build.sh "enable"

# 2a. if you want to modify the config run this first, which stores the config in the OUT_PATH directory
#make O=$OUT_PATH -C $SRC_PATH/Linux_for_Tegra/source/kernel/kernel-jammy-src menuconfig

# 2b. if you want to build the config that is now in the OUT_PATH directory.  We copied it over so we are just gunna go with it
make O=$OUT_PATH -C $SRC_PATH/Linux_for_Tegra/source/kernel/kernel-jammy-src

# 2c. If you just want to build in-tree modules, you can prepare the modules, then build just the modules
#youll need to run both these steps and dont need step 2b.  Running 2b builds both kernel and modules
#make O=$OUT_PATH -C $SRC_PATH/Linux_for_Tegra/source/kernel/kernel-jammy-src modules_prepare
make O=$OUT_PATH -C $SRC_PATH/Linux_for_Tegra/source/kernel/kernel-jammy-src modules -j90
make O=$OUT_PATH -C $SRC_PATH/Linux_for_Tegra/source/kernel/kernel-jammy-src modules_install -j90 

# 2d.  After the kernel is built at least once, you can compile just the modules. Example
# make O=$OUT_PATH -C $SRC_PATH/Linux_for_Tegra/source/kernel/kernel-jammy-src M=drivers/net/can/usb modules

# OTHER NOTES
# If you want to copy over an in-tree module to the target system you can just do this. 
# This is for host to target, usb can drivers, assuming module folders match
#scp -r $INSTALL_MOD_PATH/lib/modules/5.15.136-tegra/kernel/drivers/net/can/usb username@target:/home/username/
#ssh username@target
#sudo cp -r /home/username/usb /lib/modules/5.15.136-tegra/kernel/drivers/net/can/
#sudo chmod -R +755 /lib/modules/5.15.136-tegra/kernel/drivers/net/can/usb
#sudo depmod -a.
#rm -rf /home/username/usb