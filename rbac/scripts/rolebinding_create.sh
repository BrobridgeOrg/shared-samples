#! /usr/bin/env bash
# Version: 1.0.3
# Copyright: Brobridge Co. Ltd.
# Author: kenny@brobridge.com

# source functions
. functions

show_usage() {
	echo
	echo "Usage:"
	echo "$0 [-c|-n NAMESPACE] -b BIND_NAME -r ROLE_NAME {-u USER|-g GROUP}" 1>&2
	echo -e "\t-c: ClusterRoleBinding"
	echo -e "\t-n: RoleBding with namespace"
	echo -e "\t-b: binding name"
	echo -e "\t-r: role name"
	echo -e "\t-u: user name"
	echo -e "\t-g: group name"
	echo -e "\t-h: help"
	exit ${1:-1}
}

# get options
while getopts hcn:b:r:u:g: arg; do
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
		r) role_name=$OPTARG ;;
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

# check if binding conflict
[ "$clusterrolebinding_set" = 1 -a "$rolebinding_set" = 1 ] && {
	echo "$0: Error: you can not set both ClusterRoleBinding and RoleBinding at the same time, only one of them can be specified."
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

[ "$role_name" ] || {
	echo "$0: Error: Missing argument '-r ROLE'"
	show_usage 5
}

[ "$user_set" = 1 -a "$group_set" = 1 ] && {
	echo "$0: Error: you can not set both User and Group at the same time, only one of them can be specified."
	show_usage 6
}

[ "$user_set" != 1 -a "group_set" != 1 ] && {
	echo "$0: Error: you must specify an User or a Group."
	show_usage 7
}

if [ -n "$ns" ]; then
	get_rolebinding | grep -q "^${bind_name}$" && bind_exist=1
	get_role | grep -q "^${role_name}$" && role_exist=1
else
	get_clusterrolebinding | grep -q "^${bind_name}$" && bind_exist=1
	get_clusterrole | grep -q "^${role_name}$" && role_exist=1
fi

[ "$bind_exist" = 1 ] && {
	echo "$0: Error: the binding '$bind_name' is exist. Abort..." 1>&2
	exit 8
}

[ "$role_exist" = 1 ] || {
	echo "$0: Error: the role '$role_name' is not found. Abort..." 1>&2
	exit 9
}

yaml_file="$tmp_dir"/${kind,,}_${role_name}_${user_kind,,}:${user_name}.yaml
[ "$ns" ] && yaml_file="$tmp_dir"/${kind,,}_${role_name}_ns:${ns}_${user_kind,,}:${user_name}.yaml

cat > $yaml_file << END
kind: $kind
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: $bind_name
subjects:
- kind: $user_kind
  name: $user_name
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ${kind%Binding}
  name: $role_name
  apiGroup: rbac.authorization.k8s.io
END

[ "$kind" = RoleBinding ] && {
	sed -i "/^metadata:/a\ \ namespace: $ns" $yaml_file
}

if kubectl apply -f $yaml_file; then
	mv $yaml_file $yaml_dir
	echo "$0: yaml file is saved to '$yaml_dir/${yaml_filei##*/}'."
else
	echo "$0: Error: something wrong with yaml file: ${yaml_file}."
	exit 10
fi
