#!/bin/bash

#CUSTOM
xrandr --newmode "1440x1080_165"  393.00  1440 1568 1720 2000  1080 1083 1087 1192 -hsync +vsync
xrandr --addmode eDP-1 1440x1080_165
xrandr --output eDP-1 --mode 1440x1080_165 --set "scaling mode" "Full"

# figure out the absolute path to the script being run a bit
# non-obvious, the ${0%/*} pulls the path out of $0, cd's into the
# specified directory, then uses $PWD to figure out where that
# directory lives - and all this in a subshell, so we don't affect
# $PWD

GAMEROOT=$(cd "${0%/*}" && echo $PWD)

#determine platform
UNAME=`uname`
if [ "$UNAME" == "Darwin" ]; then
   # Workaround OS X El Capitan 10.11 System Integrity Protection (SIP) which does not allow
   # DYLD_INSERT_LIBRARIES to be set for system processes.
   if [ "$STEAM_DYLD_INSERT_LIBRARIES" != "" ] && [ "$DYLD_INSERT_LIBRARIES" == "" ]; then
      export DYLD_INSERT_LIBRARIES="$STEAM_DYLD_INSERT_LIBRARIES"
   fi
   # prepend our lib path to LD_LIBRARY_PATH
   export DYLD_LIBRARY_PATH="${GAMEROOT}"/bin:"${GAMEROOT}"/bin/osx64:$DYLD_LIBRARY_PATH
elif [ "$UNAME" == "Linux" ]; then
    # CS:GO requires the scout container runtime
    if [ -z "$STEAM_RUNTIME" ]; then
        # a dialog box (zenity?) would be nice, but at this point we do not really know what is available to us
        echo
        echo "FATAL: It appears CS:GO was not launched within the Steam for Linux scout runtime environment."
        echo "FATAL: Please consult documentation to ensure correct configuration."
        echo
        exit 1
    fi

   # prepend our lib path to LD_LIBRARY_PATH
   export LD_LIBRARY_PATH="${GAMEROOT}"/bin:"${GAMEROOT}"/bin/linux64:$LD_LIBRARY_PATH
fi

if [ -z $GAMEEXE ]; then
	if [ "$UNAME" == "Darwin" ]; then
		GAMEEXE=csgo_osx64
	elif [ "$UNAME" == "Linux" ]; then
		GAMEEXE=csgo_linux64
	fi
fi

ulimit -n 2048

# enable nVidia threaded optimizations
export __GL_THREADED_OPTIMIZATIONS=1
# enable Mesa threaded shader compiles
export multithread_glsl_compiler=1

# and launch the game
cd "$GAMEROOT"

STATUS=42
while [ $STATUS -eq 42 ]; do
	if [ "${DEBUGGER}" == "gdb" ] || [ "${DEBUGGER}" == "cgdb" ]; then
		ARGSFILE=$(mktemp $USER.s1.gdb.XXXX)

		# Set the LD_PRELOAD varname in the debugger, and unset the global version.
		: "${LD_PRELOAD=}"
		if [ "$LD_PRELOAD" ]; then
			echo set env LD_PRELOAD=$LD_PRELOAD >> "$ARGSFILE"
			echo show env LD_PRELOAD >> "$ARGSFILE"
			unset LD_PRELOAD
		fi

		# Ditto with LD_LIBRARY_PATH, avoids this below:
		# gdb: /home/plagman/src/valve/Steam/main/client/ubuntu12_32/steam-runtime/pinned_libs_64/libcurl.so.4: version `CURL_OPENSSL_4' not found (required by /usr/lib/libdebuginfod.so.1)
		: "${LD_LIBRARY_PATH=}"
		if [ "$LD_LIBRARY_PATH" ]; then
			echo set env LD_LIBRARY_PATH=$LD_LIBRARY_PATH >> "$ARGSFILE"
			echo show env LD_LIBRARY_PATH >> "$ARGSFILE"
			unset LD_LIBRARY_PATH
		fi

		echo set print pretty on >> "$ARGSFILE"
		echo set breakpoint pending on >> "$ARGSFILE"
		echo set confirm off >> "$ARGSFILE"

		# Append your own args file with optional DEBUGGER_ARGS ("-x /home/<me>/myargs.gdb")
		: "${DEBUGGER_ARGS=}"
		echo "gdb/cgdb launch:"
		echo $DEBUGGER -x "$ARGSFILE" $DEBUGGER_ARGS --args "${GAMEROOT}/${GAMEEXE}" "$@"

		$DEBUGGER -x "$ARGSFILE" $DEBUGGER_ARGS --args "${GAMEROOT}/${GAMEEXE}" "$@"

		rm "$ARGSFILE"
	elif [ "${DEBUGGER}" == "lldb" ]; then
		ARGSFILE=$(mktemp $USER.hl2.lldb.XXXX)
		echo "b main" > "$ARGSFILE"
		echo "env DYLD_LIBRARY_PATH=$DYLD_LIBRARY_PATH" > "$ARGSFILE"
		${DEBUGGER} -s "$ARGSFILE" -- "${GAMEROOT}"/${GAMEEXE} "$@"
		rm $ARGSFILE
	else
		${DEBUGGER} "${GAMEROOT}"/${GAMEEXE} "$@"
	fi
	STATUS=$?
done
#REVERT
xrandr --output eDP-1 --mode 1920x1080
exit $STATUS
