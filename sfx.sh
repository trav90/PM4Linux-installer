#!/bin/bash

# Handle the verification/extraction of the installer

unset CDPATH

if [[ ! "$(sed -r s/[a-f0-9]{64}// "$0" | sha256sum)" =~ __CHECKSUM__ ]]; then
	echo "The installer is damaged!"
	exit 2
fi

case $(uname -m) in
i?86)
	mtype=i686
	;;
x86_64)
	mtype=x86_64
	;;
*)
	echo "Unsupported architecture."
	exit 1
	;;
esac

installer_dir=$(mktemp -d /tmp/pminstaller.XXXXXX)
tail -n +__LINENUM__ "$0" | tar -xJf - -C "$installer_dir" || exit 2

PATH="$installer_dir/bin/$mtype:$installer_dir/tools:$PATH"
runasroot "$installer_dir/installer.sh"
rm -rf "$installer_dir"
exit
