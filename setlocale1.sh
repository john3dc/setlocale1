#!/bin/sh

PREFIX=
: ${LIBDIR=$PREFIX/lib}
. "$LIBDIR/libalpine.sh"

METHOD="org.freedesktop.locale1"
OBJPATH="/org/freedesktop/locale1"
GDSTART="gdbus call --system --dest $METHOD --object-path $OBJPATH --method $METHOD"

ensure_permission() {
	if [ "$(id -u)" -ne 0 ]; then
	    echo "Please run as root"
	    exit 1
	fi
}

ensure_openrc_settingsd_started() {
    STATUS=$(rc-service "openrc-settingsd" status)
    [ "$(echo "$STATUS" | grep "started")" ] && return
    echo "Error: openrc-settingsd not active"
    read -p "Do you want to start the openrc-settingsd service (y/n)? " ANSW
    case "$ANSW" in
        y|yes) 
            ensure_permission
            rc-update add openrc-settingsd boot
            rc-service openrc-settingsd start
            exit
            ;;
        *) exit 1 ;;
    esac
}

ensure_keyboard_conf_exists() {
    local conf_path="/etc/X11/xorg.conf.d/30-keyboard.conf"
    [ -f "$conf_path" ] && return
    ensure_permission
    mkdir -p "/etc/X11/xorg.conf.d/" 2>/dev/null
    touch "$conf_path" 2>/dev/null
    [ -f "$conf_path" ] || { echo "Error: file access to '$conf_path'"; exit 1; }
}

show_help() {
    cat <<- EOH
    
                setlocale1 options:
-----------------------------------------------------
  -l [lang]                        Set locale lang
  -v [lang] [toggle]               Set VConsole kb
  -x [lang] [model] [var] [option] Set X11 keyboard
  -a                               Display all locals
  -h                               Display this help
            If no value, specify as ''
-----------------------------------------------------
                    by john3dc
                    
EOH
}

prompt_settings() {
    ensure_permission
    echo ""
    echo "              setlocale1"
    echo "-----------------------------------------"
    read -p "Enter your locale language (de_DE): " ANSW1
    [ "$ANSW1" ] && echo "LANG=$ANSW1" > /etc/locale.conf && $GDSTART.SetLocale "['LANG=$ANSW1']" false 2>&1 | grep -v "usr/sbin/env-update"
    read -p "Enter your vconsole-kb-layout (de): " ANSW2
    [ "$ANSW2" ] && echo "KEYMAP=$ANSW2" > /etc/vconsole.conf && $GDSTART.SetVConsoleKeyboard "$ANSW2" "" false false 2>&1 | grep -Ev '^..$'
    read -p "Enter your x-keyboard-layout  (de): " ANSW3
    [ "$ANSW3" ] && $GDSTART.SetX11Keyboard "$ANSW3" "" "" "" false false 2>&1 | grep -Ev '^..$'
    echo "-----------------------------------------"
    echo "Please restart your system to take effect."
    echo ""
}

ensure_openrc_settingsd_started
ensure_keyboard_conf_exists

[ $# -eq 0 ] && prompt_settings

while [ "$1" ]; do
    case "$1" in
        -h) show_help; exit 0 ;;
        -l) shift; ensure_permission && echo "LANG=$1" > /etc/locale.conf && $GDSTART.SetLocale "['LANG=$1']" false 2>&1 | grep -v "usr/sbin/env-update"; echo "Restart your system to take effect."; shift ;;
        -v) shift; ensure_permission && echo "KEYMAP=$1" > /etc/vconsole.conf && $GDSTART.SetVConsoleKeyboard "$1" "$2" false false 2>&1 | grep -Ev '^..$'; shift 2 ;;
        -x) shift; ensure_permission && $GDSTART.SetX11Keyboard "$1" "$2" "$3" "$4" false false 2>&1 | grep -Ev '^..$'; shift 4 ;;
        -a) echo ""
            echo " Current Locale Properties:"
            echo "---------------------------"
            gdbus introspect -p --system --dest org.freedesktop.locale1 --object-path $OBJPATH 2>&1 | sed -E 's/[;{}]//g; s/      //g; s/readonly (as|s)//g' | awk 'length >= 5' | grep -vE 'freedesktop|properties';
            echo "---------------------------"
            echo ""
            exit 0
            ;;
            
        *) echo "Unknown Option: $1"; shift ;;
    esac
done
