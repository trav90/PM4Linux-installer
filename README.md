# README for pminstaller source

---

## Compiling from source

To compile from source, type in the following:

	./compile

You can use a custom hostname/IP address instead of always having to contact
Sourceforge:

	./compile 10.0.2.2

You can also specify a directory in this manner:

	./compile 10.0.2.2/foo

## Technical details

The source distribution is arranged in the following manner:

- `/bin/{arch}` - Binaries specific to a specific architecture which are not
commonly found in (major) Linux distros.

- `/tools/` - Executable scripts used in the installer meant for general usage.

  `*.wrapper` are taken from Debian and used for terminal emulators that do not
  handle `-e` arguments properly.

- `/files` - Contains files to be deployed on to the target system.

- `/userdocs` - Documentation for use by the end-user.

Please refer to the files themselves for more info.

The installer, when compiled, generates a shell script with data arranged in the
following manner:

	+-----------------------------------+
	| <--minified contents of sfx.sh--> |
	+-----[xz compressed tar data]------|
	|bin/                               |
	|    [...]                          |
	|tools/                             |
	|    [...]                          |
	|files/                             |
	|    [...]                          |
	+-----------------------------------+

## Licensing information

Licensing information is available in the `LICENSE` file contained in the source
distribution.

The `files/LICENSE` file only relates to the files bundled into the installer.
For example `bash_obfus.plx` is not bundled in the installer and the
`files/LICENSE` file leaves out the licensing terms for `bashobfus`. (The
following was valid at the time of this writing.)
