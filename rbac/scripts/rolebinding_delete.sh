#! /usr/bin/env bash
# Version: 1.0.1
# Copyright: Brobridge Co. Ltd.
# Author: kenny@brobridge.com

# source functions
. functions

show_usage() {
	echo
	echo "Usage:"
	echo "$0 [-c|-n NAMESPACE] -b BIND_NAME" 1>&2
	echo -e "\t-c: ClusterRoleBinding"
	echo -e "\t-n: RoleBding with namespace"
	echo -e "\t-b: binding name"
	echo -e "\t-h: help"
	exit ${1:-1}
}

# get options
while getopts hcn:b: arg; do
	case $arg in
		h) show_usage 0;;
		c) kind=ClusterRoleBinding
		   clusterrolebinding_set=1
		   ;;
		n) kind=RoleBinding
		   rolebinding_set=1
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
		b) bind_name=$OPTARG ;;
	esac
done

# check if binding conflict
[ "$clusterrolebinding_set" = 1 -a "$rolebinding_set" = 1 ] && {
	echo "$0: Error: you can not set both ClusterRole and Role at the same time, only one of them can be specified."
	show_usage 3
}

[ "$clusterrolebinding_set" != 1 -a "$rolebinding_set" != 1 ] && {
	kind=RoleBinding
	[ "$ns" ] || ns=default
}

[ "$bind_name" ] || {
	echo "$0: Error: Missing argument '-b BINDING'"
	show_usage 4
}

if [ -n "$ns" ]; then
	get_rolebinding | grep -q "^${bind_name}$" && bind_exist=1
else
	get_clusterrolebinding | grep -q "^${bind_name}$" && bind_exist=1
fi

[ "$bind_exist" = 1 ] || {
	echo "$0: Error: the binding '$bind_name' is not found. Abort..." 1>&2
	exit 5
}

yaml_file=$( grep -l "^  name: ${bind_name}$" "$yaml_dir"/${kind,,}_*.yaml )
file_no=$(echo "$yaml_file" | wc -l)
if [ $file_no -eq 0 ]; then
	echo "$0: Error: can not find yaml file. Please run kubeclt command manually." 1>&2
	exit 6
elif [ $file_no -gt 1 ]; then
	echo "$0: Error: mote than one yaml files found. Please fix it or run kubectl command manually."
	exit 7
else
	if kubectl delete -f $yaml_file; then
		mv $yaml_file $old_dir
		echo "$0: the old yaml file is moved to '$old_dir/${yaml_file##*/}'."
	else
		echo "$0: Error: something wrong with yaml file: ${yaml_file}."
		exit 8
	fi
fi

