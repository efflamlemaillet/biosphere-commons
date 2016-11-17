# Sripts

Here are scripts in various languages that you might want to wget/ git clone and use in your recipe

Example can be found in nuv.la [in a single vm script](https://nuv.la/module/cyclone/neo4j/script_tester#5-application-workflows+4-deployment) and [a deployment using this vm](https://nuv.la/module/cyclone/neo4j/allows_access_example/6553#1-application-components)

## allows_other_to_access_me.sh

### gen_key_for_user

generate the id_rsa key for the user given in parameter, if the user is missing, the user is created

### publish_pubkey

publish in pubkey variable of the vm the pubkey of every user that we can find

### allow_others

apply the rules specified in allowed_components

#### Example: 
* Host **alice**
 * allowed_components="bob:root:root, vpn:edugain:visitor"
* Host **bob**
 * allowed_components="vpn:edugain:visitor"
* Host **vpn**
 * allowed_components="none"

With this configuration :
* user **edugain** on host **vpn** can do `ssh visitor@alice`
* user **edugain** on host **vpn** can do `ssh visitor@bob`
* user **root** on host **bob** can do `ssh root@alice`


## complex.conf

## edugain_access_tool_shed.sh

### add_email_for_edugain_acces_to_user

usage:
```
source /scripts/edugain_access_tool_shed.sh --dry-run
init_edugain_acces_to_user edugain
add_email_for_edugain_acces_to_user $(echo_owner_email) edugain
add_email_for_edugain_acces_to_user john.doe@nowhere.com edugain
```

### echo_owner_email

usage:
```
source /scripts/edugain_access_tool_shed.sh --dry-run
OWNER_EMAIL=$(echo_owner_email)
```

### init_edugain_acces_to_user

usage:
```
source /scripts/edugain_access_tool_shed.sh --dry-run
init_edugain_acces_to_user edugain
```


## json_tool_shed.py

used by other scripts

## populate_hosts_with_components_name_and_ips.sh

populate file /etc/hosts with component name and ips to allow you to do `ssh visitor@my-component`

#### example:
* Component alice : Two of them
* Component bob : one of them
* Component vpn : one of them

```
source /scripts/populate_hosts_with_components_name_and_ips.sh --dry-run
populate_hosts_with_components_name_and_ips hostname
```
content added in /etc/hosts : 
```
134.158.74.135    bob
134.158.74.134    vpn
134.158.74.132    alice-1
134.158.74.133    alice-2
```

```
source /scripts/populate_hosts_with_components_name_and_ips.sh --dry-run
populate_hosts_with_components_name_and_ips vpn.address
```
content added in /etc/hosts : 
```
10.10.10.1    bob
10.10.10.2    vpn
10.10.10.3    alice-1
10.10.10.4    alice-2
```

