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
base_url="__BASE_URL__"
PATH="$installer_dir/bin/$mtype:$installer_dir/tools:$PATH"
pm_archive="$installer_dir/palemoon.tar.bz2"

dlg ()
{
  yad --window-icon=system-installer --title "Pale Moon for Linux installer v__VERSION__" "$@"
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

# Check if Pale Moon is already installed
pm_is_installed ()
{
  which palemoon || [[ -d /opt/palemoon ]] || [[ -d /usr/lib/palemoon ]]
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

  if [[ $pref_req -lt 1 ]]; then
    echo "setalternatives: Priority too low!"
  else
    update-alternatives --install "/usr/bin/$1" "$1" /usr/bin/palemoon $pref_req
  fi
}

# Configure Pale Moon with update-alternatives
pmaltset ()
{
  ch="$(dlg_q "'update-alternatives' determines the most preferred applications on your computer. Among all your installed browsers, how preferred should Pale Moon be?" --entry "Most preferred browser" "Least preferred browser" "Skip configuration")" || return
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

# Display (non-critical) warnings regarding potential Pale Moon problems depending on system configuration.
display_install_warnings ()
{
  # Older versions of the oxygen-gtk theming engine are known to cause stability issues when used with Pale Moon. Warn the user if the lib is found on the system. 
  oxygen_gtk_presence=0
  oxygen_gtk_palemoon_absence=0

  while read file; do
    oxygen_gtk_presence=1
    if ! grep -q palemoon "$file"; then
       oxygen_gtk_palemoon_absence=1
       break
    fi
  done < <(find /usr/lib /usr/lib64 /lib -type f -name 'liboxygen-gtk.so' 2>/dev/null)

  if [[ $oxygen_gtk_presence -eq 1 ]] && [[ $oxygen_gtk_palemoon_absence -eq 1 ]]; then
    dlg_i "<b>Important note:</b> The oxygen-gtk/gtk2-engines-oxygen package has been detected on your system. Some versions of this package may conflict with Pale Moon and cause crashes. Please either upgrade the package, or switch to a different theming engine if you have problems with Pale Moon."
  fi
}

# Install Pale Moon
pminstall_main ()
{
  echo "Extracting archive..."
  mkdir -p /opt
  if ! tar -xvf "$pm_archive" -C /opt; then
    dlg_e "An error occurred while extracting the archive, possibly because it is corrupted. Please try again."
    return
  fi

  echo "Creating symlink..."
  ln -vs /opt/palemoon/palemoon /usr/bin/palemoon

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

  # Only create hunspell symlink if language packages have been installed
  if [[ "$(ls /usr/share/hunspell)" ]]; then
    rm -vrf /opt/palemoon/dictionaries
    ln -vs /usr/share/hunspell /opt/palemoon/dictionaries
  fi

  dlg_i "Pale Moon has been successfully installed on your computer!"
  display_install_warnings
}

# Uninstall Pale Moon
pmremove_main ()
{
  echo "Closing all running instances of Pale Moon..."
  killall -v palemoon palemoon-bin
  echo "Removing file associations..."
  rm -vf /home/*/.local/share/applications/userapp-Pale\ Moon-*.desktop /home/*/.local/share/applications/mimeinfo.cache
  if update-alternatives --display x-www-browser | grep /usr/bin/palemoon; then
    update-alternatives --remove x-www-browser /usr/bin/palemoon
  fi
  if update-alternatives --display gnome-www-browser | grep /usr/bin/palemoon; then
    update-alternatives --remove gnome-www-browser /usr/bin/palemoon
  fi
  echo "Deleting files..."
  rm -vrf /usr/bin/palemoon /opt/palemoon /usr/share/applications/palemoon.desktop /usr/share/icons/hicolor/*/apps/palemoon.png
}

# Update Pale Moon
pmupdate_main ()
{
  mkdir /tmp/pm4linux
  echo "Extracting archive..."
  if ! tar -xvf "$pm_archive" -C /tmp/pm4linux; then
    dlg_e "An error occurred while extracting the archive, possibly because it is corrupted. Please try again."
    return
  fi
  echo "Closing all running instances of Pale Moon..."
  killall -v palemoon palemoon-bin 2>/dev/null

  echo "Deleting files from the old version..."
  rm -vrf /opt/palemoon
  echo "Installing the new version..."
  mv -v /tmp/pm4linux/palemoon /opt
  echo "Creating new symbolic links..."
  rm /usr/bin/palemoon
  ln -vs /opt/palemoon/palemoon /usr/bin/palemoon
  if [[ "$(ls /usr/share/hunspell)" ]]; then
    rm -vrf /opt/palemoon/dictionaries
    ln -vs /usr/share/hunspell /opt/palemoon/dictionaries
  fi
  rm -r /tmp/pm4linux
  dlg_i "Pale Moon has been updated successfully!"
}

# Retrieve Pale Moon archive
archive_download ()
{
  gwget "$base_url/?component=pminstaller&function=download&architecture=$mtype&version=$1" "$pm_archive"
}

# Retrieve latest version info
get_latest_version ()
{
  gwget "$base_url/?component=pminstaller&function=latest" "$installer_dir/latest"
  cat "$installer_dir/latest"
}

# Check version number validity
is_version_valid ()
{
  [[ "$1" =~ ^([0-9]+\.)+[0-9ab]+$ ]]
}

# User facing install operations
pminstall ()
{
  if pm_is_installed; then
    dlg_e "Another version of Pale Moon is already installed. Please remove the installed version and try again."
    return
  fi
  while true; do
    pm_ver="$(dlg_q "Press OK to download and install the latest version of Pale Moon." --entry --entry-text "Latest version" --button=gtk-ok:0 --button=gtk-cancel:1 --button="Archived versions...":2)"
    errorlevel=$?
    case $errorlevel in
    0)
      case "$pm_ver" in
      Latest*)
        pm_ver="$(get_latest_version)"

        if ! is_version_valid "$pm_ver"; then
          dlg_e "The latest version number could not be retrieved. Please check your network connection and try again."
        else
          break
        fi
        ;;
      *)
        dlg_e "Only the latest version can be installed with this script."
        ;;
      esac
    ;;
    1)
      return
      ;;   
    2)
      xdg-open https://www.palemoon.org/archived.shtml
      ;;
    esac
  done

  if archive_download "$pm_ver"; then
    pminstall_main >& 1 | stdoutparser | dlg_pw "Installing Pale Moon..." applications-system
  else
    dlg_e "The installation was aborted because the necessary files could not be retrieved. Please check your network connection and try again."
  fi
}

# User facing uninstall operations
pmremove ()
{
  if ! pm_is_installed; then
    dlg_e "Pale Moon is not installed on your computer."
    return
  fi
  dlg_q "Are you sure you want to uninstall Pale Moon from your computer?" --button=gtk-yes --button=gtk-no || return
  pmremove_main >& 1 | stdoutparser | dlg_pw "Uninstalling Pale Moon..." gtk-delete
  dlg_i "Pale Moon has been uninstalled from your computer."
}

# View pminstaller license file (/files/LICENSE)
view_license ()
{
  xdg-open "$installer_dir/files/LICENSE"
}

# View pminstaller readme file (/userdocs/README)
view_readme ()
{
  xdg-open "$installer_dir/userdocs/README"
}

# User facing update operations
pmupdate ()
{
  if ! pm_is_installed; then
    dlg_e "Pale Moon is not installed on your computer."
    return
  else
    pm_ver="$(get_latest_version)"
    pm_ver_inst="$(grep -E '^Version=' /opt/palemoon/application.ini | grep -Eo '([0-9]+\.)+[0-9ab]+$')"
    if ! is_version_valid "$pm_ver"; then
      dlg_e "The latest version number could not be retrieved. Please check your network connection and try again."
      return
    elif [[ -z "$pm_ver_inst" ]]; then
      dlg_e "Could not determine the version of Pale Moon currently installed. Please reinstall Pale Moon."
    elif [[ "$pm_ver_inst" != "$pm_ver" ]]; then
      dlg_q "Version $pm_ver is available, would you like to update Pale Moon now?" --button=gtk-yes --button=gtk-no || return
      if archive_download "$pm_ver"; then
        pmupdate_main >& 1 | stdoutparser | dlg_pw "Updating Pale Moon..." system-software-update
      else
        dlg_e "The update was aborted because the necessary files could not be retrieved. Please check your network connection and try again."
      fi
    else
      dlg_i "You already have the latest version of Pale Moon."
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
if ! grep sse2 /proc/cpuinfo >/dev/null; then
  dlg_e "Pale Moon requires a processor that supports the SSE2 instruction set."
fi

while true; do
  ch="$(dlg_w --image=preferences-system --list --text "<b>Welcome to the Pale Moon for Linux installer\!</b>

Select an action to perform:" --column "" "Install Pale Moon" "Uninstall Pale Moon" "Update Pale Moon" "View readme" "View license" "Exit Pale Moon for Linux installer")" || break

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
  *readme*)
    view_readme
    ;;
  *license*)
    view_license
    ;;
  *)
    break
    ;;
  esac
done

cleanup
