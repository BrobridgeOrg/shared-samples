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
	echo -e "\t-o: OU name, default: K8S"
	echo -e "\t-d: Key valid days, default: 999"
	echo -e "\t-h: help"
	exit ${1:-1}
}

# get options
while getopts u:g:o:d: arg; do
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
		o) ou_name=$OPTARG
		   echo x"$ou_name" | egrep -q '^x-' && {
			echo "$0: Error: leading '-' found in the OU name."
			exit 1
		   }
		   ;;
		d) key_day=$OPTARG
		   echo x"$key_day" | egrep -q '^x-' && {
			echo "$0: Error: leading '-' found in the key days."
			exit 2
		   }
		   echo $key_day | egrep -q '[^0-9]' && {
			echo "$0: Error: key days '$key_day' is not a number."
		exit 3
		   }
		   ;;
	esac
done

[ "$user_set" = 1 -a "$group_set" = 1 ] && {
	echo "$0: Error: you can not set both User and Group at the same time, only one of them can be specified."
	show_usage 4
}

[ "$user_set" != 1 -a "group_set" != 1 ] && {
	echo "$0: Error: you must specify an User or a Group."
	show_usage 5
}

[ "$ou_name" ] || ou_name=K8S
[ "$key_day" ] || key_day=999

admin_conf_file=~/.kube/config
ca_crt=/etc/kubernetes/pki/ca.crt
ca_key=/etc/kubernetes/pki/ca.key
user_conf_dir="$user_dir"/${user_name}
user_confpack=confpack_${user_name}_${time_stamp}.tgz
user_conf=${user_name}_conf
user_key=${user_name}.key
user_csr=${user_name}.csr
user_crt=${user_name}.crt

[ -r $admin_conf_file ] || {
	echo "$0: Error: admin config file '$admin_conf_file' not found." 1>&2
	exit 6
}

[ -r $ca_crt ] || {
	echo "$0: Error: CA cert file '$ca_crt' not found." 1>&2
	exit 7
}

[ -r $ca_key ] || {
	echo "$0: Error: CA key file '$ca_key' not found." 1>&2
	exit 8
}

if [ -d "$user_conf_dir" ]; then
	echo "$0: Error: user config directory '$user_conf_dir' is exist, abort..." 1>&2
	exit 9
else
	rm -f "$user_conf_dir" 2>/dev/null
	mkdir -p "$user_conf_dir" || {
		echo "$0: Error: can not create directory '$user_conf_dir'." 1>&2
	exit 10
	}
fi

cd "$user_conf_dir"

openssl genrsa -out $user_key 2048 || genkey_fail=1
openssl req -new -key $user_key -out $user_csr -subj "/CN=${user_name}/O=${ou_name}" || genkey_fail=1
openssl x509 -req -in $user_csr -CA $ca_crt -CAkey $ca_key -CAcreateserial -out $user_crt -days $key_day || genkey_fail=1

[ "$genkey_fail" = 1 ] && {
	echo "$0: Error: something wrong with user key generating, abort..." 1>&2
	exit 11
}

cat "$admin_conf_file" | sed '/^users:/,$d' > $user_conf

mkdir .kube
cp $user_crt .kube/
cp $user_key .kube/
cp $user_conf .kube/config
cat > .kube/run.sh << END
chown -R \${USER}. ~/.kube
cluster_name=\$(kubectl config view --minify -o jsonpath='{.clusters[].name}')
kubectl config delete-context kubernetes-admin@kubernetes
kubectl config set-credentials ${user_name} --client-certificate ~/.kube/$user_crt --client-key ~/.kube/$user_key
kubectl config set-context ${user_name}-context --cluster=\${cluster_name:-kubernetes} --user=${user_name}
kubectl config use-context ${user_name}-context
echo
echo "All done! Your current kube config is as below:"
kubectl config view
END
chmod a+x .kube/run.sh

if tar -zcvf $user_confpack .kube; then
	echo "$0: user config files are located at '$user_conf_dir'."
	cat << END
	Please copy the user config package '$user_confpack' to user's home directory,
	then run (as the user):
		1. tar -zxvf $user_confpack
		2. ~/.kube/run.sh
	Enjoy!
END
else
	echo "$0: Error: something wrong with user config package generating." 1>&2
	exit 12
fi

