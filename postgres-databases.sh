#!/bin/bash


ADMIN_USER=root
PG_USER=postgres


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


choose_database_and_do() {
    echo -e $ANSI_BOLD "Seleccionar base de datos (0 para cancelar):" $ANSI_RESET
    select bd in $(sudo -u $ADMIN_USER psql -U $PG_USER -l -A -t|cut -d'|' -f1) ; do
        test -n "$bd" || return 2
        eval "$* $bd"
        return $?
    done
#    read -p "Opción> " n

#    test "$n" -gt 0 || return 1
#    bd=$(sudo -u $ADMIN_USER psql -U $PG_USER -l -A -t|cut -d'|' -f1|head -n $n|tail -n 1)
}


ask_new_database_name_and_do() {
    read -p "Nombre de la nueva base de datos: " bd && test -n "$bd" || return -1
    eval "$* $bd"
}


_create_database() {
    newdbname="$1"
    echo "Creando base de datos $newdbname..."
    sudo -u $ADMIN_USER psql -U $PG_USER -c "CREATE DATABASE $newdbname;" && \
        message "Base de datos $newdbname creada con éxito" || \
        error "Error creando la base de datos $newdbname"
}


new_database() {
    ask_new_database_name_and_do _create_database
}


new_user() {
    sudo -u $ADMIN_USER createuser -U $PG_USER --interactive && \
        message "Usuario creado" || \
        error "Error creando usuario"
}

grant_user() {
    dbname="$1"
    defaultuser=$(whoami)
    read -p "Usuario a autorizar [$defaultuser]: " username && test -n "$username" || username=$defaultuser
    sudo -u $ADMIN_USER psql -U $PG_USER -c "GRANT ALL PRIVILEGES ON DATABASE \"$dbname\" TO \"$username\""  && \
        message "Privilegios concedidos al usuario $username sobre la base de datos $dbname" || \
        error "Error otorgando privilegios"
}


ls_databases() {
    sudo -u $ADMIN_USER psql -U $PG_USER -l|more
}


sql_shell() {
    dbname="$1"
    sudo -u $ADMIN_USER psql -U $PG_USER $dbname
}

_dup_database() {
    dbname="$1"
    newdbname="$2"
    _create_database "$newdbname" && \
        (sudo -u $ADMIN_USER pg_dump -U $PG_USER "$dbname" | sudo -u $ADMIN_USER psql -U $PG_USER "$newdbname") && \
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
    sudo -u $ADMIN_USER pg_dump -U $PG_USER $dbname > $sqlfile && \
        message "Base de datos $dbname volcada en $sqlfile" && stat $sqlfile || \
        error "Error volcando la base de datos $dbname"
}


restore_database() {
    dbname="$1"
    read -e -p "Nombre del fichero de entrada: " sqlfile
    test -f "$sqlfile" || error "No existe ese fichero"
    sudo -u $ADMIN_USER psql -U $PG_USER "$dbname" < "$sqlfile" && \
        message "Base de datos $dbname restaurada a partir de $sqlfile" || \
        error "No se pudo restaurar la base de datos $dbname"
}

remove_database() {
    dbname="$1"
    message "Se va a eliminar la base de datos $dbname. ¿Estás completamente seguro?"
    read -p "Escribe $dbname para confirmar la operación: " confirm && test "$dbname" = "$confirm" || return 1
    sudo -u $ADMIN_USER psql -U $PG_USER -c "DROP DATABASE $dbname" && \
        message "Base de datos $dbname eliminada con éxito" || \
        error "Error eliminando la base de datos $dbname"
}

main_menu() {
    while true ; do
        heading "Postgres Databases"

        echo -e "$ANSI_BOLD\nSelecciona una opción:\n$ANSI_RESET"

#        select c in \
#        "Crear base de datos" \
#        "Crear usuario" \
#        "Autorizar usuario" \
#        "Listado de bases de datos" \
#        "Shell SQL" \
#        "Duplicar base de datos" \
#        "Volcado SQL de base de datos" \
#        "Eliminar base de datos" ; do
#
#            heading $c
#            case $REPLY in
#            1) new_database ;;
#            2) new_user ;;
#            3) choose_database_and_do grant_user ;;
#            4) ls_databases ;;
#            5) choose_database_and_do sql_shell ;;
#            6) choose_database_and_do duplicate_database ;;
#            7) choose_database_and_do dump_database ;;
#            8) choose_database_and_do restore_database ;;
#            9) choose_database_and_do remove_database ;;
#            esac
#        done

        echo -e "new\t- Crear base de datos"
        echo -e "user\t- Crear usuario"
        echo -e "grant\t- Autorizar usuario"
        echo -e "ls\t- Listar bases de datos"
        echo -e "sql\t- Shell SQL"
        echo -e "dup\t- Duplicar base de datos"
        echo -e "bk\t- Volcado SQL de base de datos"
        echo -e "rm\t- Eliminar base de datos"
        echo -e "rst\t- Restaurar base de datos"
        echo -e "q\t- Salir"

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
	        rst)
	        heading "Restaurar base de datos"
	        choose_database_and_do restore_database
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
