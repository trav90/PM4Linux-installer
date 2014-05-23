#!/bin/bash
echoerr ()
{
	echo "$1" >& 2
}

case $(uname -m) in
i?86)
	mtype=i686
	;;
x86_64)
	mtype=x86_64
	;;
*)
	echoerr "Unsupported architecture."
	exit 1
	;;
esac

installer_dir=$(mktemp -d /tmp/pminstaller.XXXXXX)
if ! tail -n +__LINENUM__ "$0" | tar -xJf - -C "$installer_dir"; then
	echoerr "Self-extraction failure!"
	exit 2
fi

PATH="$installer_dir/bin/$mtype:$installer_dir/tools:$PATH"
runasroot "$installer_dir/installer.sh"
rm -rf "$installer_dir"
exit
