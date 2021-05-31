#! /usr/bin/env bash
# Version: 1.0.1
# Copyright: Brobridge Co. Ltd.
# Author: kenny@brobridge.com

# source functions
. functions

show_usage() {
	echo
	echo "Usage:"
	echo "$0 [-c|-n NAMESPACE] -r ROLE_NAME" 1>&2
	echo -e "\t-c: ClusterRole"
	echo -e "\t-n: Role with namespace"
	echo -e "\t-r: role name"
	echo -e "\t-h: help"
	exit ${1:-1}
}

# get options
while getopts hcn:r: arg; do
	case $arg in
		h) show_usage 0 ;;
		c) kind=ClusterRole ;;
		n) kind=Role
		   ns=$OPTARG
		   echo x"$ns" | egrep -q '^x-' && {
			echo "$0: Error: leading '-' found in the namespace name."
			show_usage 1
		   }
		   kubectl get ns | awk '{print $1}' | egrep -q "^${ns}$" || {
			echo "$0: Error: namespace not found."
			show_usage 2
		   }
		   ;;
		r) role_name=$OPTARG ;;
	esac
done

# check if role conflict
[ "$clusterrole_set" = 1 -a "$role_set" = 1 ] && {
	echo "$0: Error: you can not specify both ClusterRole and Role at the same time, only one of them can be specified."
	show_usage 3
}

[ "$kind" = ClusterRole ] || {
	[ "$ns" ] || ns=default
}

[ "$role_name" ] || {
	echo "$0: Error: Missing argument '-r ROLE'"
	show_usage 4
}

if [ -n "$ns" ]; then
	get_role | grep -q "^${role_name}$" && role_exist=1
else
	get_clusterrole | grep -q "^${role_name}$" && role_exist=1
fi

[ "$role_exist" = 1 ] || {
	echo "$0: Error: the role '$role_name' is not found. Abort..." 1>&2
	exit 5
}

yaml_file="$yaml_dir"/${kind,,}_$role_name.yaml

if kubectl delete -f $yaml_file; then
	mv $yaml_file $old_dir
	echo "$0: the old yaml file is moved to '$old_dir/${yaml_file##*/}'."
else
	echo "$0: Error: something wrong with yaml file: ${yaml_file}."
	exit 6
fi
