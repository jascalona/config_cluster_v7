#!/bin/bash

# Instalacion automatizada para negocio valido para el servidor principal y replica 

# Puntos de montaje negocio
$MOUNT_APP_PSQ="/app_psql/simf-bd"
$MOUNT_APP_SERV="/app_services"
$MOUNT_KAFKA="/kafka/kafka/"

# repos
$DATA_DIR="/kafka/kafka/data"


# -- hay que definir que vamos a hacer con /metrics

# Declaracion dinamica de las imagenes (si hay cambios de verciones. ajuste la variable directamente)

# RUTAS IMAGENES 
$IMAGE_PATH_PG_P="/app_psql/bd-simf/simf-primary.tar"
$IMAGE_PATH_PG_R="/app_psql/replica-bd/simf_replica.tar"

$IMAGE_PATH_KAFKA="/kafka/kafka/images/projectsintel-kafka-simf-v7_1.0.2.tar"

$IMG_NAME_PG_P="bd-simf:latest"
$IMG_NAME_PG_R="ibp_simf_replica:latest"
$IMG_NAME_KAFKA="projectsintel/kafka-simf-v7:1.0.2"

# definicion de los secret
$NAME_POSTGRES="postgre_password"

# declaracion de host srv
$BUSINESS_01="negocio01"
$BUSINESS_02="negocio02"
$BUSINESS_03="negocio03"

echo "--- script de instalaccion automatizado valido para los servidores de negocio ---"

# --- verificacion del broker (principal o replica)
echo "--- Proceso de verificacion del broker ---"

while true; do
    # MENU DE OPCIONES
    echo "=========================================="
    echo "HOLA PAPU, BIENVENIDO AL MENU DE OPCIONES"
    echo "=========================================="
    echo "1) Para la Instalacion srv principal"
    echo "2) Para la Instalacion srv replica"
    echo "3) Salir del flujo de instalacion"
    echo "------------------------------------------"
    
    read -p "Selecciona una opción válida (1-3): " opcion

    # switch de evaluacion 
    case $opcion in 
        1) 
            echo -e "\n[+] Iniciando flujo de instalacion para srv primario..."
            
            # flujo de validacion
            echo "==============================================================================================="
            echo "\nMI BRO, ANTES DE INICIAR VOY A REALIZAR UN SCANNER DEL AMBIEN PARA VERIFICAR EL ESTADO ACTUAL"
            echo "==============================================================================================="

            echo "\n[--] Verificando el punto de montaje y paqueteria de postgres"
            if [ -d "$MOUNT_APP_PSQ" ]; then 
                
                echo "\n[+] EL Punto de montaje y la paqueteria fueron detectadas con exito"
                echo "\n--------------------------------------------------------------------"
                
                echo "Iniciando el proceso de instalacion srv primario"
                
                echo "\n[+] Cargando Imagenes..."
                
                # imagen bd-primaria
                if [[ "$(sudo docker images -q $IMG_NAME_PG_P 2> /dev/null)" == "" ]]; then
                    echo "La imagen no existe, Iniciando proceso de carga..." 
                    if [ -f "$IMAGE_PATH_PG_P" ]; then
                        sudo docker load -i "$IMAGE_PATH_PG_P"
                    else 
                        echo "Error: La imagen no fue localizada en la ruta $IMAGE_PATH_PG_P"
                        exit 1
                    fi

                else 
                    echo "La imagen $IMG_NAME_PG_P ya existe. Omitiendo carga."
                fi

                # imagen de bd-replica
                if [[ "$(sudo docker images -q $IMG_NAME_PG_R 2> /dev/null)" == "" ]]; then
                    echo "La imagen no existe, Iniciando proceso de carg ..." 
                    if [ -f "$IMAGE_PATH_PG_R" ]; then
                        sudo docker load -i "$IMAGE_PATH_PG_R"
                    else 
                        echo "Error: La imagen no fue localizada en la ruta $IMAGE_PATH_PG_R"
                        exit 1
                    fi

                else 
                    echo "La imagen $IMG_NAME_PG_R ya existe. Omitiendo carga."
                fi

                echo "===================================================="
                echo "\n[+] Configurando los directorios para los tblspc"
                sudo bash install-bd.sh
                
                echo "===================================================="
                echo "\n[+] Verificando secret"MOUNT_POINT
                if sudo docker secret inspect "$NAME_POSTGRES" >/dev/null 2>&1; then
                    echo "El secret $NAME_POSTGRES ya fue creado, opmitiendo el este paso"
                else 
                    echo "El secret aun no esta creado"
                    echo "\n[+] Iniciando la creacion del secret $NAME_POSTGRES"
                    sudo printf '%s\n' '*:9997:*:postgres:PO$tgr3$.BD' '*:9997:*:simf_admin_user:simf'| sudo docker secret create postgre_password -
                    sudo docker secret inspect $NAME_POSTGRES                    
                    echo "El secret, ha sido creado con exito..."
                fi

                echo "===================================================="
                ehco "\n[--] Iniciando escaner de la red"
                if sudo docker network inspect pg_net >/dev/null 2>&1; then
                    echo "La red pg_net ya existe. Omitiendo paso"
                else
                    echo "La red no existe."
                    echo "\n[+] Creando la red pg_net"
                    sudo docker network create --driver overlay --subnet 10.0.10.0/24 --gateway 10.0.10.1  --attachable  pg_net
                    echo "La red ha sido creada con exito..."
                fi  


                # construccion de lables
                echo "===================================================="
                echo "\n[+] Cargando los lables (pg_role)"
                sudo docker node update --label-add pg_role=primary "$BUSINESS_01"
                sudo docker node update --label-add role=bd-simf "$BUSINESS_01"
                echo "Los Labels fueron creados con exito"

                # Despliegue BD-SIMF
                echo "===================================================="
                echo "\n[+] Iniciando el despliegue de BD-SIMF"
                if [ -f "/app_psql/bd-simf/primary-stack.yml" ]; then 
                    sudo docker stack deploy -c /app_psql/bd-simf/primary-stack.yml bd-simf
                    sudo docker stack ps --no-trunc bd-simf
                else 
                    echo "\nEl stack no esta en la ruta especificada"
                    exit 1
                fi 

            else 
                echo "MI BRO, NO LOGRAMOS DETECTAR EL PUNTO DE MONTAJE, VAMOS A ABORTAR EL FLUJO DE INSTALACION"


            # Instalacion de kafka
            echo "======================================="
            echo "\n[+] INICIANDO INSTALACION DE KAFKITA"
            echo "======================================="

            echo "\n[--] Verificando el punto de montaje y paqueteria de kafka"
            if [ -d "$MOUNT_KAFKA"]; then

                echo "\n[+] EL Punto de montaje y la paqueteria fueron detectadas con exito"
                echo "\n--------------------------------------------------------------------"
                
                echo "\n[+] Cargando Imagenes..."

                # imgenes kafka
                if [[ "$(sudo docker images -q $IMG_NAME_KAFKA 2> /dev/null)" == "" ]]; then 
                    echo "La imagen no existe, Iniciando proceso de carga..."
                    if [ -f "$MOUNT_KAIMAGE_PATH_KAFKA"]; then 
                        sudo docker laod -i "$MOUNT_KAIMAGE_PATH_KAFKA"
                    else 
                    echo "Error: La imagen no fue localizada en la ruta $MOUNT_KAIMAGE_PATH_KAFKA"
                    exit 1
                    fi

                else 
                    echo "La imagen $IMG_NAME_KAFKA ya existe. Omitiendo carga."
                fi 

                echo "===================================================="
                ehco "\n[--] Iniciando escaner de la red"
                if sudo docker network inspect monitoring >/dev/null 2>&1; then
                    echo "La red monitoring ya existe. Omitiendo paso"
                else
                    echo "La red no existe."
                    echo "\n[+] Creando la red pg_net"
                    sudo docker network create --driver overlay monitoring
                    echo "La red ha sido creada con exito..."
                fi  

                # Gestión del directorio data
                echo "===================================================="
                echo "\n[+] Configurando repo de Meta data"
                if [ -d "$DATA_DIR" ]; then 
                    echo "El directorio data ya existe"
                    echo "\n[+] Liberando espacio"
                    sudo rm -rf "/kafka/kafka/data/*"
                    ehco "\n [+] Espacio liberado"
                    echo "-------------------------------------------------------"
                    sudo df -h
                    echo "-------------------------------------------------------"
                else 
                    echo "\n[Verificando:] Repo data no localizado"
                    echo "\n[+] Creando directorio data..."
                    sudo mkdir -p "$DATA_DIR"
                fi

                # Aplicar permisos
                echo "===================================================="
                echo "\n[+] Aplicando los permisos necesarios"
                sudo chown -R 1000:1000 "$MOUNT_KAFKA"
                echo "Permisos aplicados con exito"
                echo "===================================================="

                # Inicio de despliegue
                echo "===================================================="
                echo "\n[+] Iniciando Despliegue"
                if [ -f "/kafka/kafka/stack/kafka.yml" ]; then 
                    sudo docker stack deploy -c /kafka/kafka/stack/kafka.yml kafka
                    sudo docker stack ps --no-trunc kafka
                else 
                    echo "\nEl stack no esta en la ruta especificada"
                    exit 1
                fi 

            fi

           





            break
            ;;
        2)
            echo -e "\n[+] Iniciando flujo de instalacion para srv replica..."
    
            break
            ;;
        3)
            echo -e "\n[-] Cerrando el asistente de instalacion. ¡Adios Papu!"
            exit 0 
            ;;
        *) 
            echo -e "\n[ERROR] '$opcion' no es una opción válida, papu. Inténtalo nuevamente.\n"
            ;;
    esac
done