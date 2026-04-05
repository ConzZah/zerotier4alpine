#!/usr/bin/env sh

### /// zerotier4alpine.sh // ConzZah // 2026-04-05 21:54 ///

## find out where the script is located
sp="$(cd "$(dirname "$0")" && pwd)" ## <-- sp = scriptpath

## cd to $sp if we are somewhere else
[ "$sp" != "$(pwd)" ] && { cd "$sp" || exit 1 ;}

## find out if we are root and set $doas accordingly
[ "$(whoami)" != "root" ] && doas="doas"

## install build deps
$doas apk add \
git \
sed \
7zip \
clang \
rust \
cargo \
build-base \
linux-headers \
openssl-dev \
nodejs-dev \
openssl-libs-static

## clone / update ZeroTierOne repo
[ ! -d ZeroTierOne ] && git clone https://github.com/zerotier/ZeroTierOne
[ -d ZeroTierOne ] && cd ZeroTierOne || exit 1
git pull

## find out what version we're building
zt_version="$(grep -m1 ZEROTIER_ONE_VERSION_MAJOR version.h | cut -d ' ' -f 3).$(grep -m1 ZEROTIER_ONE_VERSION_MINOR version.h | cut -d ' ' -f 3).$(grep -m1 ZEROTIER_ONE_VERSION_REVISION version.h | cut -d ' ' -f 3)"

## BUILD ##
$doas make clean
make ZT_STATIC="1"
$doas make install

## ensure that tun is enabled
echo "tun" > zerotier-one.conf 
$doas mv -f zerotier-one.conf /usr/lib/modules-load.d/
$doas modprobe tun

## start zerotier-one
$doas zerotier-one -d >/dev/null 2>&1

## prep package
mkdir -p ZeroTierOne
mkdir -p ZeroTierOne/ext/installfiles/linux
cp -r -- zerotier-* Makefile *.mk doc/ ZeroTierOne
cp ext/installfiles/linux/zerotier-one.te ZeroTierOne/ext/installfiles/linux/zerotier-one.te

## write install.sh
# shellcheck disable=SC2016
# REASON: expressions shouldn't expand, this is intentional.
echo '#!/usr/bin/env sh

### /// zerotier4alpine - install.sh // ConzZah ///

## find out where the script is located
sp="$(cd "$(dirname "$0")" && pwd)" ## <-- sp = scriptpath

## cd to $sp if we are somewhere else
[ "$sp" != "$(pwd)" ] && { cd "$sp" || exit 1 ;}

## find out if we are root and set $doas accordingly
[ "$(whoami)" != "root" ] && doas="doas"

## ensure that tun is enabled
echo tun > zerotier-one.conf
$doas mv -f zerotier-one.conf /usr/lib/modules-load.d/
$doas modprobe tun

## install zerotier
$doas make install

## start zerotier-one
$doas zerotier-one -d >/dev/null 2>&1
' > ZeroTierOne/install.sh

## add version string to install.sh so the user knows what version they're installing
sed -i "4i echo \"INSTALLING: ZeroTierOne-$zt_version-$(uname -m)\"" ZeroTierOne/install.sh

## create archive and remove the packaging dir
7z a "ZeroTierOne-$(uname -m).7z" "ZeroTierOne"
mv "ZeroTierOne-$(uname -m).7z" "$sp"
rm -rf "ZeroTierOne"