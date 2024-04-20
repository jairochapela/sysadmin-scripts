#!/bin/bash


# ADMIN_USER=root
# DB_HOST=localhost


ANSI_RESET="\033[0m"
ANSI_BOLD="\033[1m"
ANSI_RED="\033[31m"
ANSI_GREEN="\033[32m"
ANSI_YELLOW="\033[33m"

heading() {
    clear
    echo -e $ANSI_GREEN $ANSI_BOLD
    command -v figlet >/dev/null && figlet -w `tput cols` $* || echo $*
    echo -e $ANSI_RESET
}

message() {
    echo -e $ANSI_YELLOW
    command -v cowsay >/dev/null && cowsay $* || echo $*
    echo -e $ANSI_RESET
}

error() {
    echo -e $ANSI_RED
    command -v cowsay >/dev/null && cowsay -e xx $* || echo "ERROR: $*"
    echo -e $ANSI_RESET
    return 1
}


edit() {
    editor=${EDITOR:-vi}
    $editor $1
}


check_client_config() {
    if test ! -f "$HOME/.my.cnf" ; then
        error "No se encontró el fichero de configuración de MySQL/MariaDB"
        read -p "¿Deseas crearlo ahora? [s/N] " c
        [[ "$c" == [YySs]* ]] || return 1
        touch "$HOME/.my.cnf"
        cat <<__EOF__ > "$HOME/.my.cnf"
[client]
user=johndoe
host=localhost
password=aaa
__EOF__
        edit ~/.my.cnf
        return 1
    fi
    return 0
}


choose_database_and_do() {
    echo -e $ANSI_BOLD "Seleccionar base de datos (0 para cancelar):" $ANSI_RESET
    select bd in $(echo "SHOW DATABASES" |mysql -r -B -s) ; do
        test -n "$bd" || return 2
        eval "$* $bd"
        return $?
    done
}


ask_new_database_name_and_do() {
    read -p "Nombre de la nueva base de datos: " bd && test -n "$bd" || return -1
    eval "$* $bd"
}


_create_database() {
    newdbname="$1"
    echo "Creando base de datos $newdbname..."
    echo "CREATE DATABASE $newdbname;" |mysql && \
        message "Base de datos $newdbname creada con éxito" || \
        error "Error creando la base de datos $newdbname"
}


new_database() {
    ask_new_database_name_and_do _create_database
}



ask_password_and_do() {
    read -sp "Contraseña: " password && test -n "$password" || return -1
    echo ""
    read -sp "Repetir contraseña: " repassword && test -n "$repassword" || return -1
    echo ""
    if [ "$password" != "$repassword" ] ; then
        error "Las contraseñas no coinciden"
        return -2
    fi
    eval "$* \"$password\""
}

_create_user() {
    username="$1"
    password="$2"
    echo -e "CREATE USER '$username'@'localhost' IDENTIFIED BY '$password'" |mysql && \
        message "Usuario creado" || \
        error "Error creando usuario"    
}


new_user() {
    defaultuser=$(whoami)
    read -p "Usuario a crear [$defaultuser]: " username && test -n "$username" || username="$defaultuser"
    ask_password_and_do _create_user "$username"
}

grant_user() {
    dbname="$1"
    defaultuser=$(whoami)
    read -p "Usuario a autorizar [$defaultuser]: " username && test -n "$username" || username=$defaultuser
    echo -e "GRANT ALL PRIVILEGES ON $dbname.* TO '$username'@'localhost'; FLUSH PRIVILEGES;" |mysql && \
        message "Privilegios concedidos al usuario $username sobre la base de datos $dbname" || \
        error "Error otorgando privilegios"
}



_change_passwd() {
    username="$1"
    password="$2"
    echo -e "ALTER USER '$username'@'localhost' IDENTIFIED BY '$password'; FLUSH PRIVILEGES;" |mysql && \
        message "Contraseña de $username modificada" || \
        error "Error modificando contraseña"
}

change_password() {
    defaultuser=$(whoami)
    read -p "Usuario a modificar [$defaultuser]: " username && test -n "$username" || username=$defaultuser
    ask_password_and_do _change_passwd "$username"
}


ls_databases() {
    mysqlshow|more
}


sql_shell() {
    dbname="$1"
    command -v pspg >/dev/null && pager=pspg || pager=more
    command -v mycli >/dev/null && client=mycli || client=mysql
    PAGER=$pager $client $dbname
}

_dup_database() {
    dbname="$1"
    newdbname="$2"
    _create_database "$newdbname" && \
        (mysqldump "$dbname" |mysql "$newdbname") && \
        message "Base de datos $dbname duplicada en $newdbname"
}

duplicate_database() {
    dbname="$1"
    ask_new_database_name_and_do _dup_database $dbname
}


dump_database() {
    dbname="$1"
    defaultfname="${dbname}_`date +%Y-%m-%d_%H%M`.sql"
    read -p "Nombre del fichero de salida [$defaultfname]: " sqlfile && test -n "$sqlfile" || sqlfile="$defaultfname"
    mysqldump $dbname > $sqlfile && \
        message "Base de datos $dbname volcada en $sqlfile" && stat $sqlfile || \
        error "Error volcando la base de datos $dbname"
}


restore_database() {
    dbname="$1"
    read -e -p "Nombre del fichero de entrada: " sqlfile
    test -f "$sqlfile" || error "No existe ese fichero"
    mysql "$dbname" < "$sqlfile" && \
        message "Base de datos $dbname restaurada a partir de $sqlfile" || \
        error "No se pudo restaurar la base de datos $dbname"
}

remove_database() {
    dbname="$1"
    message "Se va a eliminar la base de datos $dbname. ¿Estás completamente seguro?"
    read -p "Escribe $dbname para confirmar la operación: " confirm && test "$dbname" = "$confirm" || return 1
    echo "DROP DATABASE $dbname" |mysql && \
        message "Base de datos $dbname eliminada con éxito" || \
        error "Error eliminando la base de datos $dbname"
}

main_menu() {
    while true ; do
        heading "MySQL/MariaDB Databases"

        echo -e "$ANSI_BOLD\nSelecciona una opción:\n$ANSI_RESET"

        echo -e "n\t- Crear base de datos"
        echo -e "u\t- Crear usuario"
        echo -e "p\t- Cambiar contraseña de usuario"
        echo -e "g\t- Autorizar usuario"
        echo -e "l\t- Listar bases de datos"
        echo -e "s\t- Shell SQL"
        echo -e "d\t- Duplicar base de datos"
        echo -e "b\t- Volcado SQL de base de datos"
        echo -e "e\t- Eliminar base de datos"
        echo -e "r\t- Restaurar base de datos"
        echo -e "c\t- Configuración"
        echo -e "q\t- Salir"

        read -p "Comando> " c
        case "$c" in
            n)
            heading "Crear base de datos"
            new_database
            ;;
	        u)
	        heading "Crear usuario"
	        new_user
            ;;
            p)
	        heading "Cambiar contraseña"
	        change_password
            ;;
            g)
            heading "Autorizar usuario"
            choose_database_and_do grant_user
            ;;
	        l)
	        heading "Bases de datos"
	        ls_databases
	        ;;
            s)
            heading "Shell SQL"
            choose_database_and_do sql_shell
            ;;
            d)
            heading "Duplicar base de datos"
            choose_database_and_do duplicate_database
            ;;
            b)
            heading "Volcado de base de datos"
            choose_database_and_do dump_database
            ;;
	        r)
	        heading "Restaurar base de datos"
	        choose_database_and_do restore_database
            ;;
            e)
            heading "Eliminar base de datos"
            choose_database_and_do remove_database
            ;;
            c)
            heading "Configuracion"
            check_client_config && edit "$HOME/.my.cnf"
            ;;
            q)
            message "Bye!"
            exit 0
            ;;
            *)
            [ -z "$c" ] && message "Por favor, indica un comando." || error "Comando no reconocido."
            ;;
        esac

        #[ "$?" = 0 ] || error "Ocurrió un error."

        read -p "Pulsa intro para continuar." _k
    done
}

sudo -u $ADMIN_USER true
check_client_config
main_menu 
