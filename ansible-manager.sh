#!/bin/bash


[ -n "$DATADIR" ] || DATADIR="$HOME/AnsiblePlaybooks"
[ -n "$EDITOR" ] || EDITOR=vim


INVENTORIES="testing staging production"


ANSI_RESET="\033[0m"
ANSI_BOLD="\033[1m"
ANSI_RED="\033[31m"
ANSI_GREEN="\033[32m"
ANSI_YELLOW="\033[33m"


VAULT_PASSWD_FILE="$HOME/.ansible/vault_password"



setup() {
    mkdir -p $DATADIR
    mkdir -p $DATADIR/roles
    mkdir -p $DATADIR/inventories
    mkdir -p $DATADIR/inventories/host_vars
    mkdir -p $DATADIR/inventories/group_vars
}


check_vault_password_file() {
    [ -f $VAULT_PASSWD_FILE ] && return
    read -s -p "Vault password: " vault_password
    echo -n "$vault_password" > $VAULT_PASSWD_FILE
    chmod 600 $VAULT_PASSWD_FILE    
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


edit_vault_file() {
    vaultfile=$1
    check_vault_password_file
    [ -f $vaultfile ] && ansible-vault --vault-password-file $VAULT_PASSWD_FILE edit $vaultfile || ansible-vault --vault-password-file $VAULT_PASSWD_FILE create $vaultfile
    return $?
}


choose_inventory_then() {
    heading "Selecciona un entorno"
    PS3="Entorno (0 para cancelar)> "
    select inventory in $INVENTORIES ; do
        [ $REPLY == 0 ] && return
        $* $DATADIR/inventories/$inventory.ini
        [ $? == 0 ] && return
        REPLY=''
    done
}


choose_playbook_then() {
    heading "Selecciona un playbook"
    playbooks=$(find "$DATADIR" -maxdepth 1 -path '*.yml') || return 1
    PS3="Playbook (0 para cancelar)> "
    select playbook in $playbooks ; do
        [ $REPLY == 0 ] && return
        $* $playbook
        [ $? == 0 ] && return
    done
}


run_playbook() {
    playbook=$1
    inventory=$2
    check_vault_password_file
    ansible-playbook --vault-password-file $VAULT_PASSWD_FILE -i $inventory $playbook
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
echo "
---
  - name: $description
    hosts: $grphosts
    become: yes
    become_user: root
    roles:
      - rol1
      - rol2
    tasks:
      - name: sample task
        debug:
          msg: To be done
" > "$playbookfile"
    edit_file "$playbookfile"
}


edit_inventory() {
    choose_inventory_then edit_file
}


edit_host_vars() {
    inventory=$1
    #check_vault_password_file
    heading "Selecciona un host"
    #hosts=$(ansible-inventory --list -i $inventory --vault-password-file $VAULT_PASSWD_FILE|jq -r '.[]|select(has("hosts"))|.[][]')
    hosts=$(cat $inventory|grep -v '\['|cut -d' ' -f1|sort|uniq)
    PS3="Host (0 para cancelar)> "
    select host in $hosts ; do
        [ $REPLY == 0 ] && return
        check_vault_password_file
        edit_vault_file $DATADIR/inventories/host_vars/$host.yml
    done
}

edit_group_vars() {
    inventory=$1
    #check_vault_password_file
    heading "Selecciona un grupo"
    #groups=$(ansible-inventory --list -i $inventory --vault-password-file $VAULT_PASSWD_FILE|jq -r '.all.children[]'|grep -v 'ungrouped')
    #$(cat $inventory|grep '^\[' |cut -f2 -d'['|cut -f1 -d']')
    groups=$(cat $inventory|sed -n 's/^[ \t]*\[\(.*\)\].*/\1/p'|sort|uniq)
    PS3="Grupo (0 para cancelar)> "
    select group in $groups ; do
        [ $REPLY == 0 ] && return
        check_vault_password_file
        edit_vault_file $DATADIR/inventories/group_vars/$group.yml
    done
}


manage_roles() {
    fname="$DATADIR/roles/requeriments.yml"
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
	echo -e "r\t- Gestionar roles"
        #echo -e "s\t- Copiar clave SSH"
        echo -e "0\t- Salir"
        read -p "Opción> " op

        case $op in
        p) choose_playbook_then choose_inventory_then run_playbook ;;
        n) ask_new_filename_then "Nombre del nuevo playbook: " "$DATADIR/" ".yml" new_playbook ;;
        e) choose_playbook_then edit_file ;;
        k) choose_playbook_then rm -i ;;
        i) choose_inventory_then edit_file ;;
        h) choose_inventory_then edit_host_vars ;;
        g) choose_inventory_then edit_group_vars ;;
	r) manage_roles ;;
        0) return ;;
        *) [ -z "$c" ] && show_message "Por favor, indica un comando." || show_error "Comando no reconocido." ;;
        esac

        [ "$?" == 0 ] || (show_error "Ocurrió un error." )

        read -p "Pulse intro para continuar." _k
        

    done    
}




setup
main_menu

rm -f $VAULT_PASSWD_FILE
