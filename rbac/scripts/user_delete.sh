#! /usr/bin/env bash
# Version: 1.0
# Copyright: Brobridge Co. Ltd.
# Author: kenny@brobridge.com

# source functions
. functions

show_usage() {
	echo
	echo "Usage:"
	echo "$0 {-u USER|-g GROUP} [-o OU_NAME] [-d DAYS]" 1>&2
	echo -e "\t-u: User name"
	echo -e "\t-g: Group name"
	echo -e "\t-h: help"
	exit ${1:-1}
}

# get options
while getopts u:g: arg; do
	case $arg in
		h) show_usage 0 ;;
		u) user_kind=User
		   user_name=$OPTARG
		   user_set=1
		   ;;
		g) user_kind=Group
		   user_name=$OPTARG
		   group_set=1
		   ;;
	esac
done

[ "$user_set" = 1 -a "$group_set" = 1 ] && {
	echo "$0: Error: you can not set both User and Group at the same time, only one of them can be specified."
	show_usage 1
}

[ "$user_set" != 1 -a "group_set" != 1 ] && {
	echo "$0: Error: you must specify an User or a Group."
	show_usage 2
}


user_conf_dir="$user_dir"/${user_name}

[ -d "$user_conf_dir" ] || {
	echo "$0: Error: user config directory '$user_conf_dir' is not found, abort..." 1>&2
	exit 3
}

rm -rf $old_dir/${user_conf_dir##*/} &>/dev/null
if mv -f "$user_conf_dir" $old_dir/; then
	echo "$0: user config directory is moved to '$old_dir/${user_conf_dir##*/}'."
else
	echo "$0: Error: something wrong while moving user config directory." 1>&2
	exit 4
fi
