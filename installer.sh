#!/bin/bash
unset CDPATH
case $(uname -m) in
i?86)
	mtype="i686"
;;
x86_64)
	mtype="x86_64"
;;
esac

cd "$(dirname "$0")"

installer_dir="$(pwd)"
lockfile_name="/tmp/pminstaller.lock"
pm_hostname="__HOSTNAME__"
PATH="$installer_dir/bin/$mtype:$installer_dir/tools:$PATH"
pm_archive="$installer_dir/palemoon.tar.bz2"

dlg ()
{
	yad --window-icon=system-installer --title "Pale Moon installer" "$@"
}

# Error dialog
dlg_e ()
{
	dlg --image=gtk-dialog-error --geometry=500 --button=gtk-ok --text "$@"
}

# Question dialog
dlg_q ()
{
	dlg --image=gtk-dialog-question --geometry=500 --text "$@"
}

# Info dialog
dlg_i ()
{
	dlg --image=gtk-dialog-info --geometry=500 --button=gtk-ok --text "$@"
}

# 'Wizard' dialog
dlg_w ()
{
	dlg --geometry=600x400 "$@"
}

# 'Wizard' progress dialog
dlg_pw ()
{
	dlg_w --progress --pulsate --text "$1" --enable-log="Details" --log-expanded --no-buttons --auto-close --image "$2"
}

# stdout parser for yad - prefix # on each line of stdout
stdoutparser ()
{
	sed -ur 's/^(.*)$/#\1/g'
}

# Checks if Pale Moon is installed
pmcheck ()
{
	if which palemoon || [[ -d /opt/palemoon ]] || [[ -d /usr/lib/palemoon ]]; then
		return 0
	else
		return 1
	fi
}

# Return priority list of applications registered with update-alternatives
getalternatives ()
{
	update-alternatives --display "$1" | grep priority | grep -Eo '[0-9]+$' | sort -un
}

# Register a program with update-alternatives with required priority
setalternatives ()
{
	case "$2" in
		min)
			pref_req=$(getalternatives "$1" | head -n 1)
			if [[ -z $pref_req ]]; then
				pref_req=1
			else
				# This form is used so that bash_obfus can obfuscate properly
				pref_req=$(($pref_req-1))
			fi
			;;
		max)
			pref_req=$(getalternatives "$1" | tail -n 1)
			if [[ -z $pref_req ]]; then
				pref_req=1
			else
				# This form is used so that bash_obfus can obfuscate properly
				pref_req=$(($pref_req+1))
			fi
			;;
		*)
			return 1
			;;
	esac

	if [[ $pref_req < 1 ]]; then
		echo "setalternatives: Priority too low!"
	else
		update-alternatives --install "/usr/bin/$1" "$1" /usr/bin/palemoon $pref_req
	fi
}

# Configure Pale Moon with update-alternatives
pmaltset ()
{
	ch="$(dlg_q "'update-alternatives' is a system to help determine the most preferred application. Amongst all your installed browsers, how preferred should Pale Moon be?" --entry "Most preferred browser" "Least preferred browser" "Skip configuration")" || return
	case "$ch" in
	Most*)
		setalternatives gnome-www-browser max
		setalternatives x-www-browser max
		;;
	Least*)
		setalternatives gnome-www-browser min
		setalternatives x-www-browser min
		;;
	*)
		return
		;;
	esac
}

# Install Pale Moon
pminstall_main ()
{
	echo "Extracting archive..."
	if ! tar -xvf "$pm_archive" -C /opt; then
		dlg_e "An error occured during the extraction of the archive, possibly because it was corrupted."
		return
	fi

	echo "Creating launch script..."
	cp "$installer_dir/files/palemoon" /usr/bin/palemoon

	echo "Creating icons..."
	ln -vs /opt/palemoon/browser/chrome/icons/default/default16.png /usr/share/icons/hicolor/16x16/apps/palemoon.png
	ln -vs /opt/palemoon/browser/chrome/icons/default/default32.png /usr/share/icons/hicolor/32x32/apps/palemoon.png
	ln -vs /opt/palemoon/browser/chrome/icons/default/default48.png /usr/share/icons/hicolor/48x48/apps/palemoon.png
	ln -vs /opt/palemoon/browser/icons/mozicon128.png /usr/share/icons/hicolor/128x128/apps/palemoon.png

	echo "Creating menu entry..."
	cp "$installer_dir/files/palemoon.desktop" /usr/share/applications/palemoon.desktop
	
	echo "Updating the icon cache..."
	gtk-update-icon-cache -f /usr/share/icons/hicolor

	# It makes sense to do this only on Debian-based distros so...
	if which update-alternatives && [[ -d /var/lib/dpkg ]]; then
		pmaltset
	fi

	if [[ -d /usr/share/hunspell ]] && dlg_q "Would you like Pale Moon to use hunspell for spell checking?" --button=gtk-yes --button=gtk-no; then
		rm -vrf /opt/palemoon/dictionaries
		ln -vs /usr/share/hunspell /opt/palemoon/dictionaries 
	fi

	dlg_i "Pale Moon was successfully installed on your computer."
}

# Uninstall Pale Moon
pmremove_main ()
{
	echo "Closing running instances of Pale Moon..."
	killall -v palemoon palemoon-bin
	echo "Removing file associations..."
	rm -vf /home/*/.local/share/applications/userapp-Pale\ Moon-*.desktop /home/*/.local/share/applications/mimeinfo.cache
	if update-alternatives --display x-www-browser | grep -E /usr/bin/palemoon; then
		update-alternatives --remove x-www-browser /usr/bin/palemoon
	fi
	if update-alternatives --display gnome-www-browser | grep -E /usr/bin/palemoon; then
		update-alternatives --remove gnome-www-browser /usr/bin/palemoon
	fi
	echo "Deleting files..."
	rm -vrf /usr/bin/palemoon /opt/palemoon /usr/share/applications/palemoon.desktop /usr/share/icons/hicolor/*/apps/palemoon.png
}

# Update Pale Moon
pmupdate_main ()
{
	mkdir /opt/palemoon.temp
	echo "Extracting archive..."
	if ! tar -xvf "$pm_archive" -C /opt/palemoon.temp; then
		dlg_e "An error occured during the extraction of the archive, possibly because it was corrupted."
		return
	fi
	echo "Closing running instances of Pale Moon..."
	killall -v palemoon palemoon-bin
	echo "Deleting files from the old version..."
	rm -vrf /opt/palemoon
	echo "Installing new version..."
	mv -v /opt/palemoon.temp/palemoon /opt
	rm -vrf /opt/palemoon.temp
	dlg_i "Pale Moon has been updated successfully."
}

# Retrieve latest version info
showlatest ()
{
	gwget "http://$pm_hostname/installer/latest.php" "$installer_dir/latest"
	cat "$installer_dir/latest"
}

# Check version number validity
versionvalid ()
{
	[[ "$1" =~ ^([0-9]+\.)+[0-9ab]+$ ]]
}

# User facing install operations
pminstall ()
{
	if pmcheck; then
		dlg_e "Another version of Pale Moon is already installed. Please uninstall it first and then install the version you need."
		return
	fi
	while true; do
		pm_ver="$(dlg_q "Please type in the version you would like to install:" --entry "Latest version" --editable --button="Show versions...":2 --button=gtk-cancel:1 --button=gtk-ok:0)"

		errorlevel=$?
		case $errorlevel in
		2)
			xdg-open http://sourceforge.net/p/pm4linux/files &
			;;
		1)
			return
			;;
		0)
			case "$pm_ver" in
			Latest*)
				pm_ver="$(showlatest)"

				if ! versionvalid "$pm_ver"; then
					dlg_e "The latest version number could not be retrieved!"
				else
					break
				fi
				;;
			*)
				if ! versionvalid "$pm_ver"; then
					dlg_e "The indicated version number is invalid."
				else
					break
				fi
				;;
			esac
		;;
		esac
	done

	if gwget "http://$pm_hostname/installer/download.php?v=$pm_ver&a=$mtype" "$pm_archive"; then
		pminstall_main >& 1 | stdoutparser | dlg_pw "Installing Pale Moon..." applications-system
	else
		dlg_e "The installation was aborted as the necessary files could not be retrieved."
	fi
}

# User facing uninstall operations
pmremove ()
{
	if ! pmcheck; then
		dlg_e "Pale Moon is not installed on your computer."
		return
	fi
	dlg_q "Are you sure to uninstall Pale Moon from your computer?" --button=gtk-yes --button=gtk-no || return
	pmremove_main >& 1 | stdoutparser | dlg_pw "Uninstalling Pale Moon..." gtk-delete
	dlg_i "Pale Moon was uninstalled from your computer."
}

# User facing update operations
pmupdate ()
{
	if ! pmcheck; then
		dlg_e "Pale Moon is not installed on your computer."
		return
	else
		pm_ver="$(showlatest)"
		pm_ver_inst="$(grep -E '^Version=' /opt/palemoon/application.ini | grep -Eo '([0-9]+\.)+[0-9ab]+$')"
		if ! versionvalid "$pm_ver"; then
			dlg_e "The latest version number could not be retrieved!"
			return
		elif [[ -z "$pm_ver_inst" ]]; then
			dlg_e "The version information for the installed version of Pale Moon could not be retrieved. Please reinstall Pale Moon."
		elif [[ "$pm_ver_inst" != "$pm_ver" ]]; then
			dlg_q "Version $pm_ver is available, would you like to update Pale Moon now?" --button=gtk-yes --button=gtk-no || return
			if gwget "http://$pm_hostname/installer/download.php?v=$pm_ver&a=$mtype" "$pm_archive"; then
				pmupdate_main >& 1 | stdoutparser | dlg_pw "Updating Pale Moon..." system-software-update
			fi
		else
			dlg_i "You have the latest version of Pale Moon."
		fi
	fi
}

# Create lock so that multiple instances can't be run
mklock ()
{
	exec 9>$lockfile_name
	flock -nx 9 || return 1
}

# Clean up lock
cleanup ()
{
	flock -u 9
	exit 0
}

if ! mklock; then
	dlg_e "An instance of the installer is already running!"
	exit 0
fi

# Processor check
if ! grep sse2 /proc/cpuinfo; then
	dlg_e "Pale Moon requires a processor that supports the SSE2 instruction set."
fi

while true; do
	ch="$(dlg_w --image=preferences-system --list --text "<b>Welcome to the Pale Moon installer\!</b>

Select an action to perform:" --column "" "Install Pale Moon" "Uninstall Pale Moon" "Update Pale Moon" "Exit Pale Moon installer")" || break

	case "$ch" in
	Install*)
		pminstall
		;;
	Uninstall*)
		pmremove
		;;
	Update*)
		pmupdate
		;;
	*)
		break
		;;
	esac
done

cleanup
