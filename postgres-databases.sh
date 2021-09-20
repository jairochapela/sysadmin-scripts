#!/bin/sh


ADMIN_USER=postgres


ANSI_RESET="\033[0m"
ANSI_BOLD="\033[1m"
ANSI_RED="\033[31m"
ANSI_GREEN="\033[32m"
ANSI_YELLOW="\033[33m"

heading() {
    clear
    echo $ANSI_GREEN $ANSI_BOLD
    command -v figlet >/dev/null && figlet -w `tput cols` $* || echo $*
    echo $ANSI_RESET
}

message() {
    echo $ANSI_YELLOW
    command -v cowsay >/dev/null && cowsay $* || echo $*
    echo $ANSI_RESET
}

error() {
    echo $ANSI_RED
    command -v cowsay >/dev/null && cowsay -e xx $* || echo "ERROR: $*"
    echo $ANSI_RESET
    return 1
}


choose_database_and_do() {
    echo $ANSI_BOLD "Seleccionar base de datos:" $ANSI_RESET
    sudo -u $ADMIN_USER psql -l -A -t|cut -d'|' -f1|nl
    read -p "Opción> " n

    test "$n" -gt 0 || return 1
    bd=$(sudo -u $ADMIN_USER psql -l -A -t|cut -d'|' -f1|head -n $n|tail -n 1)
    test -n "$bd" || return 2

    eval "$* $bd"
}


ask_new_database_name_and_do() {
    read -p "Nombre de la nueva base de datos: " bd && test -n "$bd" || return -1
    eval "$* $bd"
}


_create_database() {
    newdbname="$1"
    echo "Creando base de datos $newdbname..."
    sudo -u $ADMIN_USER psql -c "CREATE DATABASE $newdbname;" && \
        message "Base de datos $newdbname creada con éxito" || \
        error "Error creando la base de datos $newdbname"
}


new_database() {
    ask_new_database_name_and_do _create_database
}


new_user() {
    sudo -u $ADMIN_USER createuser --interactive && \
        message "Usuario creado" || \
        error "Error creando usuario"
}

grant_user() {
    dbname="$1"
    defaultuser=$(whoami)
    read -p "Usuario a autorizar [$defaultuser]: " username && test -n "$username" || username=$defaultuser
    sudo -u $ADMIN_USER psql -c "GRANT ALL PRIVILEGES ON DATABASE \"$dbname\" TO \"$username\""  && \
        message "Privilegios concedidos al usuario $username sobre la base de datos $dbname" || \
        error "Error otorgando privilegios"
}


ls_databases() {
    sudo -u $ADMIN_USER psql -l|more
}


sql_shell() {
    dbname="$1"
    sudo -u $ADMIN_USER psql $dbname
}

_dup_database() {
    dbname="$1"
    newdbname="$2"
    _create_database "$newdbname" && \
        (pg_dump "$dbname" | sudo -u $ADMIN_USER psql "$newdbname") && \
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
    pg_dump $dbname > $sqlfile && \
        message "Base de datos $dbname volcada en $sqlfile" && stat $sqlfile || \
        error "Error volcando la base de datos $dbname"
}

remove_database() {
    dbname="$1"
    message "Se va a eliminar la base de datos $dbname. ¿Estás completamente seguro?"
    read -p "Escribe $dbname para confirmar la operación: " confirm && test "$dbname" = "$confirm" || return 1
    sudo -u $ADMIN_USER psql -c "DROP DATABASE $dbname" && \
        message "Base de datos $dbname eliminada con éxito" || \
        error "Error eliminando la base de datos $dbname"
}

main_menu() {
    while true ; do
        heading "Postgres Databases"

        echo $ANSI_BOLD"\nSelecciona una opción:\n"$ANSI_RESET
        echo "new\t- Crear base de datos"
	echo "user\t- Crear usuario"
        echo "grant\t- Autorizar usuario"
	echo "ls\t- Listar bases de datos"
        echo "sql\t- Shell SQL"
        echo "dup\t- Duplicar base de datos"
        echo "bk\t- Volcado SQL de base de datos"
        echo "rm\t- Eliminar base de datos"
        echo "q\t- Salir"
        echo ""
        read -p "Comando> " c
        case "$c" in
            new)
            heading "Crear base de datos"
            new_database
            ;;
	    user)
	    heading "Crear usuario"
	    new_user
            ;;
            grant)
            heading "Autorizar usuario"
            choose_database_and_do grant_user
            ;;
	    ls)
	    heading "Bases de datos"
	    ls_databases
	    ;;
            sql)
            heading "Shell SQL"
            choose_database_and_do sql_shell
            ;;
            dup)
            heading "Duplicar base de datos"
            choose_database_and_do duplicate_database
            ;;
            bk)
            heading "Volcado de base de datos"
            choose_database_and_do dump_database
            ;;
            rm)
            heading "Eliminar base de datos"
            choose_database_and_do remove_database
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
main_menu 
