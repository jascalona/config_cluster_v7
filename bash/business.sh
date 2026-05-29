#!/bin/bash

# Instalación automatizada para negocio válido para el servidor principal y réplica 

BUSINESS_01="negocio01"
BUSINESS_02="negocio02"
BUSINESS_03="negocio03"

# Puntos de montaje negocio
MOUNT_APP_PSQ="/app_psql/packague_bd/"
MOUNT_APP_SERV="/app_services/"
MOUNT_KAFKA="/kafka/kafka/"

# Repositorios
DATA_DIR="/kafka/kafka/data"

# Rutas de Imagenes
IMAGE_PATH_PG_P="/app_psql/packague_bd/images/simf-primary.tar"
IMAGE_PATH_PG_R="/app_psql/packague_bd/images/simf_replica.tar"

IMAGE_PATH_SIMF_REST="/app_services/app_simf/images/simf_rest_api_0_2_2.tar"
IMAGE_PATH_SIMF_MS="/app_services/app_simf/images/simf_ms_0_2_2.tar"

IMAGE_PATH_KAFKA="/kafka/kafka/images/projectsintel-kafka-simf-v7_1.0.2.tar"

# Nombre de las imagenes
IMG_NAME_PG_P="bd-simf:latest"
IMG_NAME_PG_R="ibp_simf_replica:latest"
IMG_NAME_KAFKA="projectsintel/kafka-simf-v7:1.0.2"
IMG_NAME_SIMF_REST="sycom/simf_rest_api:0.2.2"
IMG_NAME_SIMF_MS="sycom/simf_ms:0.2.2"

# secrets
NAME_POSTGRES="postgre_password"

echo "--- script de instalacion automatizado valido para los servidores de negocio ---"

while true; do
    # MENU DE OPCIONES
    echo "=========================================="
    echo "HOLA PAPU, BIENVENIDO AL MENU DE OPCIONES"
    echo "=========================================="
    echo "1) Para la Instalacion srv principal"
    echo "2) Para la Instalacion srv replica"
    echo "3) Salir del flujo de instalacion"
    echo "------------------------------------------"
    
    read -p "Selecciona una opción valida (1-3): " opcion

    case $opcion in 
        1) 
            echo -e "\n[+] Iniciando flujo de instalacion para srv primario..."
            
            echo "==============================================================================================="
            echo -e "\nMI BRO, ANTES DE INICIAR VOY A REALIZAR UN SCANNER DEL AMBIENTE PARA VERIFICAR EL ESTADO ACTUAL"
            echo "==============================================================================================="

            echo -e "\n[--] Verificando el punto de montaje y paqueteria de postgres"
            if [ -d "$MOUNT_APP_PSQ" ]; then 
                
                echo -e "\n[+] EL Punto de montaje y la paqueteria fueron detectadas con exito"
                echo "--------------------------------------------------------------------"
                echo "Iniciando el proceso de instalacion srv primario"
                
                echo -e "\n[+] Cargando Imagenes de Base de Datos..."
                
                # Imagen bd-primaria
                if [[ -z "$(sudo docker images -q $IMG_NAME_PG_P 2> /dev/null)" ]]; then
                    echo "La imagen primaria no existe, Iniciando proceso de carga..." 
                    if [ -f "$IMAGE_PATH_PG_P" ]; then
                        sudo docker load -i "$IMAGE_PATH_PG_P"
                    else 
                        echo "Error: La imagen no fue localizada en la ruta $IMAGE_PATH_PG_P"
                        exit 1
                    fi
                else 
                    echo "La imagen $IMG_NAME_PG_P ya existe. Omitiendo carga."
                fi

                # Imagen de bd-replica
                if [[ -z "$(sudo docker images -q $IMG_NAME_PG_R 2> /dev/null)" ]]; then
                    echo "La imagen de replica no existe, Iniciando proceso de carga..." 
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
                echo -e "\n[+] Configurando los directorios para los tblspc"
                sudo bash "${MOUNT_APP_PSQ}install-bd.sh"
                
                echo "===================================================="
                echo -e "\n[+] Verificando secret: $NAME_POSTGRES"
                if sudo docker secret inspect "$NAME_POSTGRES" >/dev/null 2>&1; then
                    echo "El secret $NAME_POSTGRES ya fue creado, omitiendo este paso"
                else 
                    echo "El secret aun no esta creado"
                    echo -e "\n[+] Iniciando la creacion del secret $NAME_POSTGRES"
                    sudo printf '%s\n' '*:9997:*:postgres:PO$tgr3$.BD' '*:9997:*:simf_admin_user:simf' | sudo docker secret create postgre_password -
                    sudo docker secret inspect "$NAME_POSTGRES"                    
                    echo "El secret ha sido creado con exito..."
                fi

                echo "===================================================="
                echo -e "\n[--] Iniciando escaner de la red pg_net"
                if sudo docker network inspect pg_net >/dev/null 2>&1; then
                    echo "La red pg_net ya existe. Omitiendo paso"
                else
                    echo "La red no existe."
                    echo -e "\n[+] Creando la red pg_net"
                    sudo docker network create --driver overlay --subnet 10.0.10.0/24 --gateway 10.0.10.1 --attachable pg_net
                    echo "La red ha sido creada con exito..."
                fi  

                # Construccion de labels en el Swarm
                echo "===================================================="
                echo -e "\n[+] Cargando los labels (pg_role)"
                sudo docker node update --label-add pg_role=primary "$BUSINESS_01"
                sudo docker node update --label-add role=bd-simf "$BUSINESS_01"

                echo "============================================================"
                echo -e "\n[+] Inyeccion de labels para los nodos de replica"
                sudo docker node update --label-add pg_role=replica "$BUSINESS_02"
                sudo docker node update --label-add pg_role=replica "$BUSINESS_03"
                echo "Los Labels fueron creados con exito"

                # Despliegue BD-SIMF
                echo "===================================================="
                echo -e "\n[+] Iniciando el despliegue de BD-SIMF"
                if [ -f "/app_psql/packague_bd/primary-stack.yml" ]; then 
                    sudo docker stack deploy -c /app_psql/packague_bd/primary-stack.yml bd-simf
                    sudo docker stack ps --no-trunc bd-simf
                else 
                    echo -e "\nEl stack no esta en la ruta especificada"
                    exit 1
                fi 
            else 
                echo "MI BRO, NO LOGRAMOS DETECTAR EL PUNTO DE MONTAJE DE BD, VAMOS A ABORTAR EL FLUJO"
                exit 1
            fi

            # Instalación de kafka
            echo "========================================"
            echo -e "\n[+] INICIANDO CONFIGURACION DE KAFKITA"
            echo "========================================"

            echo -e "\n[--] Verificando el punto de montaje y paqueteria de kafka"
            if [ -d "$MOUNT_KAFKA" ]; then

                echo -e "\n[+] EL Punto de montaje y la paqueteria fueron detectadas con exito"
                echo "--------------------------------------------------------------------"
                echo -e "\n[+] Cargando Imagenes de Kafka..."

                # Imagenes kafka
                if [[ -z "$(sudo docker images -q $IMG_NAME_KAFKA 2> /dev/null)" ]]; then 
                    echo "La imagen no existe, Iniciando proceso de carga..."
                    if [ -f "$IMAGE_PATH_KAFKA" ]; then 
                        sudo docker load -i "$IMAGE_PATH_KAFKA"
                    else 
                        echo "Error: La imagen no fue localizada en la ruta $IMAGE_PATH_KAFKA"
                        exit 1
                    fi
                else 
                    echo "La imagen $IMG_NAME_KAFKA ya existe. Omitiendo carga."
                fi 

                echo "===================================================="
                echo -e "\n[--] Iniciando escaner de la red monitoring"
                if sudo docker network inspect monitoring >/dev/null 2>&1; then
                    echo "La red monitoring ya existe. Omitiendo paso"
                else
                    echo "La red no existe. Creando..."
                    sudo docker network create --driver overlay monitoring
                    echo "La red ha sido creada con exito..."
                fi  

                # Gestion del directorio data
                echo "===================================================="
                echo -e "\n[+] Configurando repo de Meta data"
                if [ -d "$DATA_DIR" ]; then 
                    echo "El directorio data ya existe. Liberando espacio..."
                    sudo rm -rf "$DATA_DIR"
                    sudo mkdir -p "$DATA_DIR"
                    echo -e "\n[+] Espacio liberado"
                    echo "-------------------------------------------------------"
                    sudo df -h
                    echo "-------------------------------------------------------"
                else 
                    echo -e "\n[Verificando:] Repo data no localizado. Creando..."
                    sudo mkdir -p "$DATA_DIR"
                fi

                # Aplicar permisos
                echo "===================================================="
                echo -e "\n[+] Aplicando los permisos al repo de metadatos"
                sudo chown -R 1000:1000 "$MOUNT_KAFKA"
                echo "Permisos aplicados con exito"
                echo "===================================================="
            else 
                echo "MI BRO, NO LOGRAMOS DETECTAR EL PUNTO DE MONTAJE DE KAFKA, VAMOS A ABORTAR"
                exit 1
            fi
            
            echo "===================================================="
            echo -e "\n[+] INVOCANDO LA CONFIGURACION DE OBSERVABILIDAD"
            echo "===================================================="
            if [ -f "/opt/bash/metrics.sh" ]; then
                sudo bash /opt/bash/metrics.sh
            else
                echo "Advertencia: El script de metricas no se encontró en /opt/bash/metrics.sh"
            fi

            break
            ;;
            
        2)
            echo -e "\n[+] Iniciando flujo de instalacion para srv replica..."
            
            echo "====================================================================================================="
            echo -e "\nMI BRO, ANTES DE INICIAR VOY A REALIZAR UN SCANNER DEL AMBIENTE PARA VERIFICAR EL ESTADO ACTUAL"
            echo "====================================================================================================="

            echo -e "\n[--] Verificando el punto de montaje y paqueteria de postgres"
            if [ -d "$MOUNT_APP_PSQ" ]; then 
                
                echo -e "\n[+] EL Punto de montaje y la paqueteria fueron detectadas con exito"
                echo "--------------------------------------------------------------------"
                echo "Iniciando el proceso de instalacion srv replica"
                
                echo -e "\n[+] Cargando Imagenes..."
                
                if [[ -z "$(sudo docker images -q $IMG_NAME_PG_R 2> /dev/null)" ]]; then
                    echo "La imagen de replica no existe, Iniciando proceso de carga..." 
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
                echo -e "\n[+] Configurando los directorios para los tblspc"
                sudo bash "${MOUNT_APP_PSQ}install-bd.sh"
    
                echo "==================================================================="
                echo "CONFIGURACION FINALIZADA, DESPLIEGUE RESERVADO PARA EL ORQUESTADOR"
                echo "==================================================================="
            else 
                echo "MI BRO, NO LOGRAMOS DETECTAR EL PUNTO DE MONTAJE DE BD"
            fi

            # Instalación de kafka en Réplica
            echo "======================================================="
            echo -e "\n[+] INICIANDO CONFIGURACION DE KAFKITA (REPLICA)"
            echo "======================================================="

            if [ -d "$MOUNT_KAFKA" ]; then
                echo -e "\n[+] EL Punto de montaje y la paqueteria fueron detectadas con exito"
                echo "--------------------------------------------------------------------"
                echo -e "\n[+] Cargando Imagenes de Kafka..."

                if [[ -z "$(sudo docker images -q $IMG_NAME_KAFKA 2> /dev/null)" ]]; then 
                    echo "La imagen no existe, Iniciando proceso de carga..."
                    if [ -f "$IMAGE_PATH_KAFKA" ]; then 
                        sudo docker load -i "$IMAGE_PATH_KAFKA"
                    else 
                        echo "Error: La imagen no fue localizada en la ruta $IMAGE_PATH_KAFKA"
                        exit 1
                    fi
                else 
                    echo "La imagen $IMG_NAME_KAFKA ya existe. Omitiendo carga."
                fi 

                # Gestion del directorio data
                echo "===================================================="
                echo -e "\n[+] Configurando repo de Meta data"
                if [ -d "$DATA_DIR" ]; then 
                    echo "El directorio data ya existe. Liberando espacio..."
                    sudo rm -rf "$DATA_DIR"
                    sudo mkdir -p "$DATA_DIR"
                    echo -e "\n[+] Espacio liberado"
                    echo "-------------------------------------------------------"
                    sudo df -h
                    echo "-------------------------------------------------------"
                else 
                    echo -e "\n[Verificado:] Repo data no localizado. Creando..."
                    sudo mkdir -p "$DATA_DIR"
                fi

                # Aplicar permisos
                echo "===================================================="
                echo -e "\n[+] Aplicando los permisos necesarios"
                sudo chown -R 1000:1000 "$MOUNT_KAFKA"
                echo "Permisos aplicados con exito"
                echo "===================================================="

                # Inicio de despliegue Kafka
                echo "===================================================="
                echo -e "\n[+] Iniciando Despliegue de Kafka"
                if [ -f "/kafka/kafka/stack/kafka.yml" ]; then 
                    sudo docker stack deploy -c /kafka/kafka/stack/kafka.yml kafka
                    sudo docker stack ps --no-trunc kafka
                else 
                    echo -e "\nEl stack de Kafka no esta en la ruta especificada"
                    exit 1
                fi
            else 
                echo "MI BRO, NO LOGRAMOS DETECTAR EL PUNTO DE MONTAJE DE KAFKA, VAMOS A ABORTAR EL FLUJO"
                exit 1
            fi

            # Configuración de Servicios SIMF
            echo "======================================="
            echo -e "\n[+] INICIANDO CONFIGURACION DE SIMF"
            echo "======================================="

            if [ -d "$MOUNT_APP_SERV" ]; then 
                echo -e "\n[+] EL Punto de montaje y la paqueteria fueron detectadas con exito"
                echo "--------------------------------------------------------------------"
                echo -e "\n[+] Cargando Imagenes SIMF..."

                if [[ -z "$(sudo docker images -q $IMG_NAME_SIMF_REST 2> /dev/null)" || -z "$(sudo docker images -q $IMG_NAME_SIMF_MS 2> /dev/null)" ]]; then 
                    echo "Al menos una de las imagenes no existe. Iniciando el proceso de Carga..."

                    if [ -f "$IMAGE_PATH_SIMF_REST" ] && [ -f "$IMAGE_PATH_SIMF_MS" ]; then
                        echo "[->] Cargando REST API..."
                        sudo docker load -i "$IMAGE_PATH_SIMF_REST"

                        echo "[->] Cargando MS..."
                        sudo docker load -i "$IMAGE_PATH_SIMF_MS"
                    else 
                        echo "Error: Uno o ambos archivos .tar no fueron localizados en las rutas."            
                        exit 1
                    fi

                    echo "===================================================="
                    echo -e "\n[--] Iniciando escaner de la red nginx_lbnet"
                    if sudo docker network inspect nginx_lbnet >/dev/null 2>&1; then
                        echo "La red nginx_lbnet ya existe. Omitiendo paso"
                    else
                        echo "La red no existe."
                        echo -e "\n[+] Creando la red nginx_lbnet"
                        sudo docker network create --driver overlay nginx_simf
                        echo "La red ha sido creada con exito..."
                    fi  

                else 
                    echo "Las imagenes ($IMG_NAME_SIMF_REST y $IMG_NAME_SIMF_MS) ya existen en el sistema. Omitiendo carga."
                fi 

                echo "========================================================="
                echo -e "\n[+] Proceso de configuracion srv replica finalizado"
                echo "=========================================================================================================="
                echo -e "\n[--] POR FAVOR REPLIQUE EL MISMO FLUJO DE CONFIGURACION EN EL SEGUNDO SRV REPLICA"
                echo -e "[--] LUEGO DE HABER CONFIRMADO LA PERSISTENCIA DE LA CONFIGURACION EJECUTE EL ORQUESTADOR DE DESPLIEGUE"
                echo "=========================================================================================================="
                echo "[--] EJECUTE EL SIGUIENTE COMANDO PARA ACTIVAR EL ORQUESTADOR:"
                echo -e "\nsudo bash ./orchest_business.sh"
                echo "=================================================="
                echo "DETALLES DEL ORQUESTADO (COMPONENTES DESPLEGADOS)"
                echo "----------"
                echo "[1] REPLICA"
                echo "----------"
                echo "[2] KAFKITA"
                echo "----------"
                echo "[3] MS"
                echo "=================================================="
            else 
                echo "Error: El punto de montaje no fue encontrado: $MOUNT_APP_SERV"
                exit 1
            fi

            break
            ;;
            
        3)
            echo -e "\n[-] Cerrando el asistente de instalacion. ¡Adios Papu!"
            exit 0 
            ;;
            
        *) 
            echo -e "\n[ERROR] '$opcion' no es una opcion valida, papu. Intentalo nuevamente.\n"
            ;;
    esac
done