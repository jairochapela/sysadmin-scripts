#!/bin/bash



INVENTORIES="testing staging production"


ANSI_RESET="\033[0m"
ANSI_BOLD="\033[1m"
ANSI_RED="\033[31m"
ANSI_GREEN="\033[32m"
ANSI_YELLOW="\033[33m"


VAULT_PASSWD_FILE="$HOME/.ansible/vault_password_$(openssl rand -hex 4)"



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


subtitle() {
    echo -e "$ANSI_BOLD$ANSI_YELLOW--- $* ---$ANSI_RESET\n"
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


confirm_and_do() {
    read -p "¿Estás seguro? [S/N] " yn
    [[ "$yn" == [Ss]* ]] && $* || return 1
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
        [ $REPLY == 0 ] && return -1
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
    inventory=$1
    playbook=$2
    shift 2
    check_vault_password_file
    ANSIBLE_VAULT_PASSWORD_FILE="$VAULT_PASSWD_FILE" ansible-playbook -i $inventory $playbook
    read -p "Pulse intro para continuar." _k
    return $?
}


ask_new_filename_then() {
    prompt=$1
    prefix=$2
    suffix=$3
    shift 3
    while true ; do
        read -p "Nombre del nuevo playbook: " fname
        [ ! -f $prefix$fname$suffix ] && break
    done
    $* $prefix$fname$suffix
}


choose_role_then() {
    heading "Selecciona un rol"
    roles=$(find "$CMDB_ANSIBLE_PATH/roles" -depth 1 -path '*' -type d |xargs -I{} basename {}) || return 1
    PS3="Rol (0 para cancelar)> "
    select role in $roles ; do
        [ $REPLY == 0 ] && return
        $* "$CMDB_ANSIBLE_PATH/roles/$role"
        [ $? == 0 ] && return
    done
}


new_playbook() {
    playbookfile="$1"
    read -p "Descripción: " description
    read -p "Grupo de hosts: " grphosts
    roles=$(find "$CMDB_ANSIBLE_PATH/roles" -depth 1 -path '*' -type d |xargs -I{} basename {}) || return 1
    PS3="Incorporar rol (0 para terminar)> "
    selected_roles=""
    roles_to_add=""
    select role in $roles ; do
        [ $REPLY == 0 ] && break
        [ -z "$role" ] && continue
        selected_roles="$selected_roles $role"
        roles_to_add="$roles_to_add\n      - $role"
        echo -e "Roles seleccionados: $roles_to_add"

    done
    #variables_to_add=$(for r in $selected_roles ; do find "$CMDB_ANSIBLE_PATH/roles/$r/defaults" |xargs cat|sed -e 's/^/        /' ; done)
    variables_to_add=$(for r in $selected_roles ; do test -f "$CMDB_ANSIBLE_PATH/roles/$r/defaults/main.yml" && cat "$CMDB_ANSIBLE_PATH/roles/$r/defaults/main.yml"|sed -e 's/^/        /'; done)
    #read
echo -e "
---
  - name: $description
    hosts: $grphosts
    become: yes
    become_user: root
    roles:$roles_to_add
    vars:
$variables_to_add
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
        [ $? == 0 ] && return
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
        [ $? == 0 ] && return
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
        [ $REPLY == 0 ] && return
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



playbook_actions_menu() {
    while true ; do
        clear
        title "Gestionar playbooks"
        heading "Selecciona una opción"
        echo -e "n\t- Crear nuevo playbook"
        echo -e "e\t- Editar playbook"
        echo -e "k\t- Eliminar playbook"
        #echo -e "r\t- Ejecutar playbook"
        echo -e "0\t- Volver"

        read -p "Opción> " op

        case $op in
        n) ask_new_filename_then "Nombre del nuevo playbook: " "$CMDB_ANSIBLE_PATH/" ".yml" new_playbook ;;
        e) choose_playbook_then edit_file ;;
        k) choose_playbook_then rm -i ;;
        #r) choose_inventory_then run_playbook -i $inventory -p ;;        
        0) return ;;
        *) [ -z "$c" ] && show_message "Por favor, indica un comando." || show_error "Comando no reconocido." ;;
        esac

        [ "$?" == 0 ] || (show_error "Ocurrió un error." )

        #read -p "Pulse intro para continuar." _k        
    done    
}


choose_file_from_and_do() {
    dir="$1"
    shift
    heading "Selecciona un fichero"
    PS3="Fichero (0 para cancelar)> "
    select file in $dir/* ; do
        [ $REPLY == 0 ] && return
        $* $file
        [ $? == 0 ] && return
    done
}


edit_role_actions_menu() {
    role=$1
    while true ; do
        clear
        title "Editar rol"
        subtitle "Rol: $(basename $role)"
        heading "Selecciona una opción"
        echo -e "t\t- Editar tareas"
        echo -e "j\t- Crear plantilla"
        echo -e "p\t- Editar plantilla"
        echo -e "v\t- Editar variables por defecto"
        #echo -e "k\t- Eliminar fichero"
        #echo -e "n\t- Crear nuevo fichero de tareas"
        echo -e "0\t- Volver"

        read -p "Opción> " op

        case $op in
        t) edit_file "$role/tasks/main.yml" ;;
        v) edit_file "$role/defaults/main.yml" ;;
        j) ask_new_filename_then "Nombre de la nueva plantilla: " "$role/templates" ".j2" edit_file ;;
        p) choose_file_from_and_do "$role/templates" edit_file ;;
        #k) confirm_and_do rm -rf "$role" ;;
        0) return ;;
        *) [ -z "$c" ] && show_message "Por favor, indica un comando." || show_error "Comando no reconocido." ;;
        esac

        [ "$?" == 0 ] || (show_error "Ocurrió un error." )

        #read -p "Pulse intro para continuar." _k        
    done        
}


new_role() {
    role=$1
    mkdir -p $role/{tasks,handlers,templates,files,vars,defaults,meta}
    touch $role/{tasks,handlers,templates,files,vars,defaults,meta}/main.yml
    cat > "$role/tasks/main.yml" << __EOF__
---
- name: sample task
  debug:
    msg: To be done    
__EOF__
    edit_file "$role/tasks/main.yml"
}


role_actions_menu() {
    while true ; do
        clear
        title "Gestionar roles"
        heading "Selecciona una opción"
        echo -e "n\t- Crear nuevo rol"
        echo -e "e\t- Editar rol"
        echo -e "k\t- Eliminar rol"
        echo -e "m\t- Gestionar roles externos"
        echo -e "0\t- Volver"

        read -p "Opción> " op

        case $op in
        n) ask_new_filename_then "Nombre del nuevo playbook: " "$CMDB_ANSIBLE_PATH/roles/" "" new_role ;;
        e) choose_role_then edit_role_actions_menu ;;
        k) choose_role_then confirm_and_do rm -rf ;;
        m) manage_roles ;;
        #r) choose_inventory_then run_playbook -i $inventory -p ;;        
        0) return ;;
        *) [ -z "$c" ] && show_message "Por favor, indica un comando." || show_error "Comando no reconocido." ;;
        esac

        [ "$?" == 0 ] || (show_error "Ocurrió un error." )

        #read -p "Pulse intro para continuar." _k        
    done        
}

environment_actions_menu() {
    inventory=$1
    while true ; do
        clear
        title "Despliegue e inventario"
        subtitle "Entorno de despliegue: $(basename $inventory)"
        heading "Selecciona una opción"
        echo -e "r\t- Ejecutar playbook"
        echo -e "i\t- Editar inventario"
        echo -e "h\t- Variables de host"
        echo -e "g\t- Variables de grupo de hosts"
        #echo -e "s\t- Shell remota"
        echo -e "0\t- Volver"

        read -p "Opción> " op

        case $op in
        r) choose_playbook_then run_playbook $inventory ;;        
        i) edit_inventory $inventory ;;
        h) edit_host_vars $inventory ;;
        g) edit_group_vars $inventory ;;
        #s) remote_shell $inventory ;;
        0) return ;;
        *) [ -z "$c" ] && show_message "Por favor, indica un comando." || show_error "Comando no reconocido." ;;
        esac

        [ "$?" == 0 ] || (show_error "Ocurrió un error." )
                
    done
}



main_menu() {
    while true ; do
        clear
        title "Ansible Manager"
        # title "Entorno: $(basename $inventory)"
        heading "Selecciona una opción"
        echo -e "p\t- Gestionar playbooks"
        echo -e "d\t- Despliegue e inventario"
        #echo -e "s\t- Copiar clave SSH"
        echo -e "r\t- Gestionar roles"
        #echo -e "v\t- Cifrar fichero con Ansible Vault"
        echo -e "0\t- Salir"
        read -p "Opción> " op

        case $op in
        p) playbook_actions_menu ;;
        d) choose_inventory_then environment_actions_menu ;;
	    r) role_actions_menu ;;
        #v) choose_file_then encrypt_vault_file ;;
        0) return ;;
        *) [ -z "$c" ] && show_message "Por favor, indica un comando." || show_error "Comando no reconocido." ;;
        esac

        [ "$?" == 0 ] || (show_error "Ocurrió un error." )

        #read -p "Pulse intro para continuar." _k
        

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