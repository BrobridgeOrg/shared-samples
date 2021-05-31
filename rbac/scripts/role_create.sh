#! /usr/bin/env bash
# Version: 1.0.2
# Copyright: Brobridge Co. Ltd.
# Author: kenny@brobridge.com

# source functions
. functions

show_usage() {
	echo
	echo "Usage:"
	echo "$0 [-c|-n NAMESPACE] -r ROLE_NAME" [-t TEMPLATE_NAME] 1>&2
	echo -e "\t-c: ClusterRole"
	echo -e "\t-n: Role with namespace"
	echo -e "\t-r: role name"
	echo -e "\t-t: template name"
	echo -e "\t-h: help"
	exit ${1:-1}
}

# get options
while getopts hcn:r:t: arg; do
	case $arg in
		h) show_usage 0 ;;
		c) kind=ClusterRole
		   clusterrole_set=1
		   ;;
		n) kind=Role
		   role_set=1
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
		t) tmplt_name=$OPTARG ;;
	esac
done

# check if role conflict
[ "$clusterrole_set" = 1 -a "$role_set" = 1 ] && {
	echo "$0: Error: you can not specify both clusterrole and role at the same time, only one of them can be accepted."
	show_usage 3
}

[ "$clusterrole_set" != 1 -a "$role_set" != 1 ] && {
	kind=Role
	[ "$ns" ] || ns=default
}

[ "$role_name" ] || {
	echo "$0: Error: Missing argument '-r ROLE'"
	show_usage 4
}

# check role if existing
if [ -n "$ns" ]; then
	get_role | grep -q "^${role_name}$" && role_exist=1
else
	get_clusterrole | grep -q "^${role_name}$" && role_exist=1
fi

[ "$role_exist" = 1 ] && {
	echo "$0: Error: the role '$role_name' is existed. Abort..." 1>&2
	exit 5
}

# function to ask for rules
ask_rule() {
	read -p "API Group (Enter for none): " api_grp
	read -p "Resource name (src1,src2,src3,... Enter for all): " rsc_name
	if [ -z "$rsc_name" ]; then
		rsc_name='"*"'
	else
		_rsc_name=${rsc_name//\"}
		unset rsc_name 
		for v in ${_rsc_name//,/ }; do
			rsc_name=$rsc_name,\ \"$v\"
		done
		rsc_name=${rsc_name/,}
	fi
	read -p "Verbs list (verb1,verb2,verb3,... Enter for all): " verb_list
	if [ -z "$verb_list" ]; then
		verb_list='"*"'
	else
		_verb_list=${verb_list//\"}
		unset verb_list
		for v in ${_verb_list//,/ }; do
			verb_list=$verb_list,\ \"$v\"
		done
		verb_list=${verb_list/,}
	fi
	cat << END
  - apiGroups: ["$api_grp"]
    resources: [$rsc_name]
    verbs: [$verb_list]
END

}

# if template is specified, use tamplate, otherwise create new yaml

yaml_file="$tmp_dir"/${kind,,}_$role_name.yaml

get_template_name() {
	for f in "$tmplt_dir"/roles/*.yaml; do
		echo -n "$f:"
		sed '/^metadata:/,/^rules:/!d' $f | awk '/name:/{print $2}'
	done
}

if [ -n "$tmplt_name" ]; then
	all_tmplt=$(get_template_name)
	tmplt_file=$(echo "$all_tmplt" | grep ":${tmplt_name}$" | cut -d: -f1)
	file_num=$(echo "$mplt_file" | wc -l)

	# abort if more than one tmplate files found
	if [ "$file_num" -eq 0 ]; then
		echo "$0: Error: the role tamplate file for '$tmplt_name' is not found. Abort..." 1>&2
		exit 6
	elif [ "$file_num" -gt 1 ]; then
		echo "$0: Error: the role tamplate files for '$tmplt_name' is more than one. Abort..." 1>&2
		exit 7
	fi

	# abort if resource kind is not matched
	tmplt_kind=$(awk '/^kind: /{print $2}' "$tmplt_file")
	[ "${tmplt_kind}" = "${kind}" ] || {
		echo "$0: Error: the tamplate kind '${tmplt_kind}' doesn't match the role kind '$kind'. Abort..." 1>&2
		exit 8
	}

	# abort if the role name not found in the template file
	if echo "$all_tmplt" | cut -d: -f2 | egrep -q "^${tmplt_name}$"; then
		sed "/^metadata:/,/^rules:/s/name: .*/name: ${role_name}/" "${tmplt_file}" > "${yaml_file}"
	else
		echo "$0: Error: the role tamplate '$tmplt_name' is not found. Abort..." 1>&2
		exit 9
	fi
else
	cat > $yaml_file << END
apiVersion: rbac.authorization.k8s.io/v1
kind: $kind
metadata:
  name: $role_name
rules:
END

	ask_rule >> $yaml_file
fi

# to ask to insert more rules
while yesNo "Do you want add more rules?"; do
	ask_rule >> $yaml_file
done

# add namespace if the kind is Role
[ "$kind" = Role ] && {
	sed -i "/^metadata:/a\ \ namespace: $ns" $yaml_file
}

# apply yaml
if kubectl apply -f $yaml_file; then
	mv $yaml_file $yaml_dir
	echo "$0: yaml file is saved to '$yaml_dir/${yaml_filei##*/}'."
else
	echo "$0: Error: something wrong with yaml file: ${yaml_file}."
	exit 10
fi

