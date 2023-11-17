#!/bin/bash



INVENTORIES="testing staging production"


ANSI_RESET="\033[0m"
ANSI_BOLD="\033[1m"
ANSI_RED="\033[31m"
ANSI_GREEN="\033[32m"
ANSI_YELLOW="\033[33m"


VAULT_PASSWD_FILE="$HOME/.ansible/vault_password"



setup() {
    mkdir -p $CMDB_ANSIBLE_PATH
    mkdir -p $CMDB_ANSIBLE_PATH/roles
    #mkdir -p $CMDB_ANSIBLE_PATH/playbooks
    mkdir -p $CMDB_ANSIBLE_PATH/library_utils
    mkdir -p $CMDB_ANSIBLE_PATH/filter_plugins
    mkdir -p $CMDB_ANSIBLE_PATH/inventories
    for i in $INVENTORIES; do
        mkdir -p $CMDB_ANSIBLE_PATH/inventories/$i
        mkdir -p $CMDB_ANSIBLE_PATH/inventories/$i/host_vars
        mkdir -p $CMDB_ANSIBLE_PATH/inventories/$i/group_vars
        touch $CMDB_ANSIBLE_PATH/inventories/$i/hosts
    done
}


check_vault_password_file() {
    [ -f $VAULT_PASSWD_FILE ] && return
    read -s -p "Vault password: " vault_password
    echo -n "$vault_password" > "$VAULT_PASSWD_FILE"
    chmod 600 "$VAULT_PASSWD_FILE"    
}

title() {
    echo -e $ANSI_GREEN $ANSI_BOLD
    command -v figlet >/dev/null && figlet -w `tput cols` $* || echo $*
    echo -e $ANSI_RESET
}


heading() {
    echo -e $ANSI_BOLD$*$ANSI_RESET
}

show_error() {
    echo -e $ANSI_RED"Error: "$*$ANSI_RESET
}

show_message() {
    echo -e $ANSI_YELLOW$*$ANSI_RESET
}

edit_file() {
    $EDITOR $*
    return $?
}

edit_inventory() {
    inventory=$1
    echo $inventory
    $EDITOR $inventory/hosts
    return $?
}


edit_vault_file() {
    vaultfile=$1
    check_vault_password_file
    [ -f $vaultfile ] && ANSIBLE_VAULT_PASSWORD_FILE="$VAULT_PASSWD_FILE" ansible-vault edit $vaultfile || ANSIBLE_VAULT_PASSWORD_FILE="$VAULT_PASSWD_FILE" ansible-vault create $vaultfile
    return $?
}


choose_inventory_then() {
    heading "Selecciona un entorno"
    PS3="Entorno (0 para cancelar)> "
    select inventory in $INVENTORIES ; do
        [ $REPLY == 0 ] && return
        $* $CMDB_ANSIBLE_PATH/inventories/$inventory
        [ $? == 0 ] && return
        REPLY=''
    done
}


choose_playbook_then() {
    heading "Selecciona un playbook"
    playbooks=$(find "$CMDB_ANSIBLE_PATH/." -maxdepth 1 -path '*.yml'|xargs -I{} basename {}) || return 1
    PS3="Playbook (0 para cancelar)> "
    select playbook in $playbooks ; do
        [ $REPLY == 0 ] && return
        $* "$CMDB_ANSIBLE_PATH/$playbook"
        [ $? == 0 ] && return
    done
}


run_playbook() {
    playbook=$1
    inventory=$2
    check_vault_password_file
    ANSIBLE_VAULT_PASSWORD_FILE="$VAULT_PASSWD_FILE" ansible-playbook -i $inventory $playbook
}


ask_new_filename_then() {
    prompt=$1
    prefix=$2
    suffix=$3
    shift
    shift
    shift
    while true ; do
        read -p "Nombre del nuevo playbook: " fname
        [ ! -f $prefix$fname$suffix ] && break
    done
    $* $prefix$fname$suffix
}


new_playbook() {
    playbookfile="$1"
    read -p "Descripción: " description
    read -p "Grupo de hosts: " grphosts
    roles=$(find "$CMDB_ANSIBLE_PATH/roles" -depth 1 -path '*' -type d |xargs basename) || return 1
    PS3="Incorporar rol (0 para terminar)> "
    roles_to_add=""
    select role in $roles ; do
        [ $REPLY == 0 ] && break
        roles_to_add="$roles_to_add\n      - $role"
        echo -e "Roles seleccionados: $roles_to_add"
    done
echo -e "
---
  - name: $description
    hosts: $grphosts
    become: yes
    become_user: root
    roles:$roles_to_add
    tasks:
      - name: sample task
        debug:
          msg: To be done
" > "$playbookfile"
    edit_file "$playbookfile"
}


edit_host_vars() {
    inventory=$1
    echo $inventory
    check_vault_password_file
    heading "Selecciona un host"
    hosts=$(ansible-inventory --list -i $inventory --vault-password-file $VAULT_PASSWD_FILE|jq -r '.[]|select(has("hosts"))|.[][]')
    #hosts=$(cat $inventory|grep -v '\['|cut -d' ' -f1|sort|uniq)
    PS3="Host (0 para cancelar)> "
    select host in $hosts ; do
        [ $REPLY == 0 ] && return
        edit_vault_file $inventory/host_vars/$host.yml
    done
}


remote_shell() {
    inventory=$1
    #check_vault_password_file
    heading "Selecciona un host"
    #hosts=$(ansible-inventory --list -i $inventory --vault-password-file $VAULT_PASSWD_FILE|jq -r '.[]|select(has("hosts"))|.[][]')
    hosts=$(cat $inventory|grep -v '\['|cut -d' ' -f1|sort|uniq)
    PS3="Host (0 para cancelar)> "
    select host in $hosts ; do
        [ $REPLY == 0 ] && return
        ssh $host
    done
}


edit_group_vars() {
    inventory=$1
    check_vault_password_file
    heading "Selecciona un grupo"
    groups=$(ansible-inventory --list -i $inventory --vault-password-file $VAULT_PASSWD_FILE|jq -r '.all.children[]'|grep -v 'ungrouped')
    #$(cat $inventory|grep '^\[' |cut -f2 -d'['|cut -f1 -d']')
    #groups=$(cat $inventory|sed -n 's/^[ \t]*\[\(.*\)\].*/\1/p'|sort|uniq)
    PS3="Grupo (0 para cancelar)> "
    select group in $groups ; do
        [ $REPLY == 0 ] && return
        check_vault_password_file
        edit_vault_file $inventory/group_vars/$group.yml
    done
}


manage_roles() {
    fname="$CMDB_ANSIBLE_PATH/roles/requeriments.yml"
    [ -f "$fname" ] || echo "
## from galaxy
#- src: yatesr.timezone

## from GitHub
#- src: https://github.com/bennojoy/nginx

## from GitHub, overriding the name and specifying a specific tag
#- src: https://github.com/bennojoy/nginx
#  version: master
#  name: nginx_role

## from a webserver, where the role is packaged in a tar.gz
#- src: https://some.webserver.example.com/files/master.tar.gz
#  name: http-role

## from Bitbucket
#- src: git+http://bitbucket.org/willthames/git-ansible-galaxy
#  version: v1.4

## from Bitbucket, alternative syntax and caveats
#- src: http://bitbucket.org/willthames/hg-ansible-galaxy
#  scm: hg

## from GitLab or other git-based scm
#- src: git@gitlab.company.com:mygroup/ansible-base.git
#  scm: git
#  version: "0.1"  # quoted, so YAML doesn't parse this as a floating-point value

# Más información: https://galaxy.ansible.com/docs/using/installing.html
" > "$fname"
    heading "Instalando roles requeridos"
    edit_file "$fname" && ansible-galaxy install -r "$fname"
}


choose_file_then() {
    heading "Selecciona un fichero"
    PS3="Fichero (0 para cancelar)> "
    select file in $CMDB_ANSIBLE_PATH/files/* ; do
        [ $REPLY == 0 ] && return
        $* $file
        [ $? == 0 ] && return
    done
}

encrypt_vault_file() {
    file=$1
    check_vault_password_file
    [ -f "$file" ] && ANSIBLE_VAULT_PASSWORD_FILE="$VAULT_PASSWD_FILE" ansible-vault encrypt "$file" || show_error "No es posible cifrar el fichero $file."
}


main_menu() {
    while true ; do
        clear
        title "Ansible Manager"
        heading "Selecciona una opción"
        echo -e "p\t- Ejecutar playbook"
        echo -e "n\t- Crear nuevo playbook"
        echo -e "e\t- Editar playbook"
        echo -e "k\t- Eliminar playbook"
        echo -e "i\t- Inventario"
        echo -e "h\t- Variables de host"
        echo -e "g\t- Variables de grupo de hosts"
        echo -e "s\t- Shell remota"
    	echo -e "r\t- Gestionar roles"
        echo -e "v\t- Cifrar fichero con Ansible Vault"
        #echo -e "s\t- Copiar clave SSH"
        echo -e "0\t- Salir"
        read -p "Opción> " op

        case $op in
        p) choose_playbook_then choose_inventory_then run_playbook ;;
        n) ask_new_filename_then "Nombre del nuevo playbook: " "$CMDB_ANSIBLE_PATH/" ".yml" new_playbook ;;
        e) choose_playbook_then edit_file ;;
        k) choose_playbook_then rm -i ;;
        i) choose_inventory_then edit_inventory ;;
        h) choose_inventory_then edit_host_vars ;;
        g) choose_inventory_then edit_group_vars ;;
        s) choose_inventory_then remote_shell ;;
	    r) manage_roles ;;
        v) choose_file_then encrypt_vault_file ;;
        0) return ;;
        *) [ -z "$c" ] && show_message "Por favor, indica un comando." || show_error "Comando no reconocido." ;;
        esac

        [ "$?" == 0 ] || (show_error "Ocurrió un error." )

        read -p "Pulse intro para continuar." _k
        

    done    
}


# --- MAIN ---


# [ -n "$CMDB_ANSIBLE_PATH" ] || DATADIR="$HOME/AnsiblePlaybooks"

if [ -z "$CMDB_ANSIBLE_PATH" ] ; then
    show_error "Variable CMDB_ANSIBLE_PATH no establecida." 
    exit 1
fi


[ -n "$EDITOR" ] || EDITOR=vim



if [ ! -d "$CMDB_ANSIBLE_PATH/inventories" ] ; then
    read -e -p "Crear CMDB? [Y/N]" yn
    [[ "$yn" == [Yy]* ]] && setup || exit 1
fi

main_menu

rm -f $VAULT_PASSWD_FILE

show_message "Bye!"