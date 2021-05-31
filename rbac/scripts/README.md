# RBAC scripts

----

1. To create Role/ClusterRole, for example [with template]:

   ./role_create.sh -c -r net-admin -t na-role
 
If without template, you must answer the rule information when prompted:
* API Group
* Resource name
* Verbs list

The yaml files will be stored in directory "yaml_files".

----

2. To create RoleBinding/ClusterRoleBinding, for example:

   ./rolebinding_create.sh -c -b net-admin-kenny -r net-admin -u kenny

The yaml files will be stored in directory "yaml_files".

----

3. To create user configs, for example:

   ./user_create.sh -u kenny

If you don't specify the key valid period, default is 999 days. Config files will be stored in directory "user_files/kenny" for the sample above.

You must copy the config tarball, the name like "confpack_kenny_20210511-145612.tgz", to user's home directory,then run as the user:

    tar -zxvf confpack_kenny_20210511-145612.tgz

    ~/.kube/run.sh

----

4. To list all the active role and rolebindings, just ls the 'yaml_files' direcotry:

   ls yaml_files

----

5. To get help, run the script with "-h" option, for example:

    ./role_create.sh -h


