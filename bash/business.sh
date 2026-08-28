#!/bin/bash

# ==============================================================================
# CONFIGURACIÓN VISUAL Y COLORES (CLI PROFESIONAL)
# ==============================================================================
COLOR_RESET="\e[0m"
NEON_GREEN="\e[38;5;82m"
DEEP_BLUE="\e[38;5;39m"
VIVID_YELLOW="\e[38;5;214m"
CRIMSON_RED="\e[38;5;196m"
CYAN_INFO="\e[38;5;51m"
BOLD="\e[1m"
MAGENTA='\033[1;35m'


log_info()    { echo -e " ${CYAN_INFO}➔${COLOR_RESET} $1"; }
log_success() { echo -e " ${NEON_GREEN}✔${COLOR_RESET} $1"; }
log_warning() { echo -e " ${VIVID_YELLOW}⚠${COLOR_RESET} ${BOLD}$1${COLOR_RESET}"; }
log_error()   { echo -e " ${CRIMSON_RED}✖${COLOR_RESET} ${BOLD}$1${COLOR_RESET}"; }

press_to_continue() {
    echo -e "\n${VIVID_YELLOW}➔ Presione [ENTER] para continuar con el siguiente bloque del despliegue...${COLOR_RESET}"
    read -r
}

# ==============================================================================
# VARIABLES DE ENTORNO
# ==============================================================================
BUSINESS_01="vasldiccs060"
BUSINESS_02="vasldiccs061"
BUSINESS_03="vasldiccs062"


ROUTE_CREATION_BD="/app_psql/packague_bd/creacion-bd"
NAME_POSTGRES_CONF="postgresql.conf"


# paquetes de configuracion
PACKAGUE_V7="/opt/Install_v7/package_business.zip"
METRICS_V7="/opt/Install_v7/metrics.zip"


MOUNT_APP_PSQ="/app_psql/"
MOUNT_APP_SERV="/app_services/"
MOUNT_KAFKA="/kafka/"
MOUNT_METRICS="/metrics/"
DATA_DIR="/kafka/kafka/data"

# PUNTOS DE MONTAJE PARA LOS TBLSPC
MOUNT_TBLSPC_HISTO="/tblspc_historico"
MOUNT_TBLSPC_TRAN="/tblspc_transaccional"
MOUNT_TBLSPC_VIS="/tblspc_vistas"
MOUNT_BACKUP="/backups"
MOUNT_LOGS="/logs"
MOUNT_OVERLAY="/overlay"




NAME_POSTGRES="postgre_password"
NAME_PGAGENT="pgagent_pass"

DAEMON_JSON="/etc/docker/daemon.json"

STARTING_POINT="/opt/Install_v7/bash"



# ==============================================================================
# INTERFAZ DE CARGA (SPINNER)
# ==============================================================================
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    tput civis  
    while [ "$(ps -p $pid -o pid=)" ]; do
        local temp=${spinstr#?}
        printf "\r ${DEEP_BLUE}[%c]${COLOR_RESET}  Procesando, por favor espere..." "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    tput cnorm 
    printf "\r\e[K ${NEON_GREEN}[OK]${COLOR_RESET}  Procesado con éxito.\n"
}


# ==============================================================================
# CONFIGURACION DEL DAEMON DE DOCKER LOCAL (ULIMITS, MTU, LOGS Y DATA-ROOT)
# ==============================================================================
echo -e "\n${MAGENTA}[PASO 0/4] Verificando configuración del daemon de Docker local..."

# Validamos si el archivo daemon.json ya contiene la configuración de logs y data-root
if [ -f "$DAEMON_JSON" ] && grep -q "data-root" "$DAEMON_JSON" && grep -q "max-size" "$DAEMON_JSON"; then
    echo -e "${YELLOW} La configuración de daemon.json ya contiene data-root y rotación de logs. Saltando..."
else
    echo "Aplicando optimizaciones en $DAEMON_JSON (data-root=/overlay, ulimits, mtu y log-opts)..."

    cat <<'EOF' | sudo tee "$DAEMON_JSON" > /dev/null
{
  "data-root": "/overlay",
  "mtu": 1450,
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65536,
      "Soft": 65536
    }
  },
  "log-driver": "json-file",
  "log-opts": {
    "mode": "non-blocking",
    "max-buffer-size": "4m",
    "max-size": "10m",
    "max-file": "3",
    "compress": "true"
  },
  "shutdown-timeout": 15
}

EOF

    echo "Reiniciando el servicio de Docker para aplicar cambios..."
    sudo systemctl restart docker
    echo  "${NEON_GREEN} Archivo $DAEMON_JSON actualizado e integrado con éxito."
fi


echo -e "-----------------------------------------------------------------"

# ==============================================================================
# CONFIGURACION CRONJOB PARA LA DEPURACION DE LOGS DE POSTGRES
# ==============================================================================
if [ -d "$MOUNT_LOGS" ]; then 
  0 /12 * * * ls -t /logs/postgres_logs/ 2>/dev/null | tail -n +2 | xargs -r rm -f
  log_success "CRONJOB CREADO CONEXITO"
else
  log_error "Lo sentimos, no fue localizo el punto de montaje en esto broker para la creacion del cronjob"
  log_info "Continuando Ciclo de configuracion"
fi


# ==============================================================================
# FASE 0: VALIDACIÓN DE CONFIGURACIÓN PREEXISTENTE E IDEMPOTENCIA
# ==============================================================================
clear
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}  ASISTENTE DE INSTALACIÓN AUTOMATIZADA - CLÚSTER DE NEGOCIO       ${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}  PREPARANDO EL ENTORNO DE TRABAJO...                              ${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

log_info "Ejecutando escaneo de integridad en puntos de montaje..."

# Definimos las rutas 
TARGET_DIRS=(
    "${MOUNT_APP_PSQ}packague_bd"
    "${MOUNT_APP_PSQ}pgagent"
    "${MOUNT_APP_SERV}app_simf"
    "${MOUNT_APP_SERV}app_sglpar"
    "${MOUNT_KAFKA}kafka"
    "${MOUNT_METRICS}alloy"
    "${MOUNT_METRICS}service_discovery"
)

PREEXISTING_CONFIG=false
DIRS_TO_CLEAN=()

# Escaneo preciso de qué existe y qué no
for dir in "${TARGET_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        PREEXISTING_CONFIG=true
        DIRS_TO_CLEAN+=("$dir")
    fi
done

if [ "$PREEXISTING_CONFIG" = true ]; then
    log_warning "Se detectaron componentes de una configuracion previa. Iniciando depuración..."
    
    # depuracion de los paquetes parceados
    for dir in "${DIRS_TO_CLEAN[@]}"; do
        # Validación de seguridad: Evitar borrar la raíz si la variable está vacía
        if [ -n "$dir" ] && [ "$dir" != "/" ]; then
            log_info "Eliminando residuos en: $dir"
            sudo rm -rf "$dir"
        fi
    done
    
    log_success "Depuración completada con éxito."
    sleep 1.5
else
    log_info "Entorno limpio. No se encontraron configuraciones previas en los puntos de montaje."
fi

echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}  INICIANDO ENVIO DE PAQUETES                                     ${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

if [[ -f "$PACKAGUE_V7" && -f "$METRICS_V7" ]]; then 
    log_success "Archivos comprimidos detectados. Iniciando extracción..."
    
    # Descompresión en paralelo
    sudo unzip -q -o "$PACKAGUE_V7" -d /opt/Install_v7/ &
    pid1=$!
    sudo unzip -q -o "$METRICS_V7" -d /opt/Install_v7/ &
    pid2=$!

    # Esperamos por ambos procesos mapeados al spinner (pasando ambos PIDs si tu función lo soporta, o esperando con wait)
    wait $pid1 $pid2

    if [[ -d "/opt/Install_v7/package_business/" ]]; then 
        log_info "Distribuyendo los paquetes en volúmenes persistentes..."
        
        # Mover Base de Datos y agentes
        sudo mv /opt/Install_v7/package_business/packague_bd/ "${MOUNT_APP_PSQ}"
        sudo mv /opt/Install_v7/package_business/pgagent/ "${MOUNT_APP_PSQ}"
        
        # Mover Servicios de aplicación
        sudo mv /opt/Install_v7/package_business/app_simf/ "${MOUNT_APP_SERV}"
        sudo mv /opt/Install_v7/package_business/app_sglpar/ "${MOUNT_APP_SERV}"

        # Mover Infraestructura y Observabilidad (Kafka y Grafana Alloy / SD)
        sudo mv /opt/Install_v7/package_business/kafka/ "${MOUNT_KAFKA}"
        sudo mv /opt/Install_v7/metrics/alloy/ "${MOUNT_METRICS}"
        sudo mv /opt/Install_v7/metrics/service_discovery/ "${MOUNT_METRICS}"
        
        # Limpieza del residuo temporal de descompresión de forma segura
        sudo rm -rf /opt/Install_v7/package_business
        sudo rm -rf /opt/Install_v7/metrics
        
        log_success "Paquetería cargada y desplegada exitosamente en puntos de montaje."
    else 
        log_error "Fallo crítico: El directorio extraído /opt/Install_v7/package_business/ no existe o está corrupto."
        exit 1
    fi
else 
    log_error "Error crítico: No se detectaron los archivos fuente de paquetería en: $PACKAGUE_V7 o $METRICS_V7"
    exit 1
fi


# ==============================================================================
# INICIO DE BUCLE INTERACTIVO (MENÚ DE OPCIONES)
# ==============================================================================
while true; do
    echo -e "\n${BOLD}MENÚ DE OPCIONES DE CONFIGURACIÓN:${COLOR_RESET}"
    echo -e "  ${DEEP_BLUE}1)${COLOR_RESET} Inicializar Servidor Principal (Primary Node)"
    echo -e "  ${DEEP_BLUE}2)${COLOR_RESET} Inicializar Servidor Replica (Replica Node)"
    echo -e "  ${DEEP_BLUE}3)${COLOR_RESET} Salir del Asistente"
    echo -e "${DEEP_BLUE}------------------------------------------------------------------${COLOR_RESET}"
    
    read -p "Seleccione una opción (1-3): " opcion

case $opcion in 
      1) 
            clear
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}  FASE 1: ESCANEO Y VERIFICACIÓN DEL SERVIDOR PRINCIPAL           ${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

            log_info "Verificando puntos de montaje para PostgreSQL Swarm..."
            if [ -d "$MOUNT_APP_PSQ" ]; then 
                log_success "Punto de montaje detectado en: $MOUNT_APP_PSQ"

                # Invocando la configuración del binario
                log_info "INVOCANDO LA CONFIGURACION MAESTRA (Carga de binarios)"
                sudo bash $STARTING_POINT/binary_verification.sh binaries_postgres_and_exporter

                # --- CONFIGURACIÓN E INYECCIÓN ---
                log_info "Ejecutando aprovisionamiento de tablespaces..."
                log_warning "VERIFICANDO LA EXISTENCIA DE LOS PUNTOS DE MONTAJE PARA LOS TBLSPC"
                
                TARGET_TBLSPC=(
                    "$MOUNT_TBLSPC_HISTO"
                    "$MOUNT_TBLSPC_TRAN"
                    "$MOUNT_TBLSPC_VIS"
                    "$MOUNT_BACKUP"
                    "$MOUNT_LOGS"
                    "$MOUNT_OVERLAY"
                )

                for mount_tblspc in "${TARGET_TBLSPC[@]}"; do 
                    if [ ! -d "$mount_tblspc" ]; then
                        log_error "[ERROR]: No se encontro el punto de montaje $mount_tblspc"
                        exit 1
                    fi 
                done         

                log_success "Puntos de montaje detectados para los tblspc "
                sudo bash "${MOUNT_APP_PSQ}packague_bd/install-bd.sh"
                log_success "TBPLSCP CREADOS CON EXITO"

          

                while true; do 
                    echo -e "\n${BOLD}MENÚ DE OPCIONES DE CONFIGURACIÓN POSTGRESQL.CONF:${COLOR_RESET}"
                    echo -e "  ${DEEP_BLUE}1)${COLOR_RESET} Infraestructura Básica (24GB)"
                    echo -e "  ${DEEP_BLUE}2)${COLOR_RESET} Infraestructura Media (32GB)"
                    echo -e "  ${DEEP_BLUE}3)${COLOR_RESET} Infraestructura Extendida (512GB)"
                    echo -e "${DEEP_BLUE}------------------------------------------------------------------${COLOR_RESET}"
                    
                    read -p "Seleccione el tipo de Infraestructura (1-3): " environment
                    echo -e "${DEEP_BLUE}------------------------------------------------------------------${COLOR_RESET}"
                    
                    SRC_FILE=""
                    INFRA_NAME=""

                    case $environment in 
                        1)
                            SRC_FILE="postgresql_para24GB.conf"
                            INFRA_NAME="Básica (24GB)"
                            break
                            ;;
                        2)
                            SRC_FILE="postgresql_para32GB.conf"
                            INFRA_NAME="Mediana (32GB)"
                            break
                            ;;
                        3)
                            SRC_FILE="postgresql_para512GB.conf"
                            INFRA_NAME="Extendida (512GB)"
                            break
                            ;;
                        *)
                            log_error "'$environment' no coincide con ninguna opción disponible.\n"
                            ;;
                    esac
                done 

                # ==================================================================
                # (LÓGICA CENTRALIZADA)
                # ==================================================================
                log_info "Has seleccionado una Infraestructura ${INFRA_NAME}"
                log_info "Renombrando el fichero de configuración..."

                sudo mv "${ROUTE_CREATION_BD}/${SRC_FILE}" "${ROUTE_CREATION_BD}/${NAME_POSTGRES_CONF}"
                log_info "¡Fichero renombrado correctamente a ${NAME_POSTGRES_CONF}!"
                    
                log_success "CONFIGURACION FINALIZADA CON EXITO!"
            else 
                log_error "Punto de montaje de base de datos ausente de forma crítica. Abortando flujo."
                exit 1
            fi

            # PAUSA 1
            press_to_continue

            # ---- CONFIGURACION DE PGAGENT ---
            clear
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}  FASE 2: CONFIGURACION DEL (PGAGENT)                             ${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

            log_info "Verificando punto de montaje para pgagent"
            if [ -d "$MOUNT_APP_PSQ" ]; then
                log_success "Punto de montaje detectado para pgagent..."
                
                log_info "INVOCANDO LA CONFIGURACION MAESTRA (Carga de binarios)"
                sudo bash $STARTING_POINT/binary_verification.sh binaries_pgagent

            else 
                log_error "El punto de montaje no fue localizado para este componente"
            fi 
            
            # PAUSA PGAGENT
            press_to_continue

            # --- CONFIGURACION DE KAFKA ---
            clear
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}  FASE 3: CONFIGURACION BROKER (KAFKA)                            ${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

            log_info "Verificando punto de montaje para Kafka..."
            if [ -d "$MOUNT_KAFKA" ]; then
                log_success "Punto de montaje detectado en: $MOUNT_KAFKA"
                
                log_info "INVOCANDO LA CONFIGURACION MAESTRA (Carga de binarios)"
                sudo bash $STARTING_POINT/binary_verification.sh binaries_kafkita

                echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
                log_info "AJUSTE EL HOSTNAME (node.hostname) en la configuracion de kafka"
        
                log_info "INCIANDO CONFIGURACION DE REPO-DATA"
                log_info "Estructurando repositorios persistentes de Meta Data..."
                if [ -d "$DATA_DIR" ]; then 
                    log_warning "Datos antiguos detectados en $DATA_DIR. Purgando volumen..."
                    sudo rm -rf "$DATA_DIR"
                    sudo mkdir -p "$DATA_DIR"
                    log_success "Volumen limpiado y reformateado."
                else 
                    log_info "Creando nuevo directorio para el volumen de datos de Kafka..."
                    sudo mkdir -p "$DATA_DIR"
                fi

                log_info "Aplicando ACL y permisos de propietario (UID 1000:1000)..."
                sudo chown -R 1000:1000 "$MOUNT_KAFKA"
                log_success "Permisos del sistema de archivos aplicados."
            else 
                log_error "Punto de montaje de Kafka no localizado. Abortando."
                exit 1
            fi

            # PAUSA 2
            press_to_continue

            # --- CONFIGURACIÓN DE SERVICIOS SIMF Y SGLPAR ---
            clear
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}  FASE 4: CONFIGURACION DE MS (SIMF)                              ${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

            log_info "Verificando punto de montaje de la capa de servicios..."
            if [ -d "$MOUNT_APP_SERV" ]; then 
                log_success "Punto de montaje detectado en: $MOUNT_APP_SERV"
                
                log_info "INVOCANDO LA CONFIGURACION MAESTRA (Carga de binarios)"
                sudo bash $STARTING_POINT/binary_verification.sh binaries_simf

                echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
                echo -e "${DEEP_BLUE}${BOLD}  FASE 5: CONFIGURACION DE MS (SGLPAR)                            ${COLOR_RESET}"
                echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

                log_info "INVOCANDO LA CONFIGURACION MAESTRA (Carga de binarios)"
                sudo bash $STARTING_POINT/binary_verification.sh binaries_sglpar

                echo -e "\n${NEON_GREEN}${BOLD}==================================================================${COLOR_RESET}"
                echo -e "${NEON_GREEN}${BOLD}  PROCESO DE CONFIGURACIÓN DEL NODO PRINCIPAL COMPLETADO            ${COLOR_RESET}"
                echo -e "${NEON_GREEN}${BOLD}==================================================================${COLOR_RESET}"
                echo -e " ${CYAN_INFO}➔${COLOR_RESET} REPLIQUE ESTE FLUJO EXACTO EN LOS NODOS DE RÉPLICA."
                echo -e " ${CYAN_INFO}➔${COLOR_RESET} COMANDO DE INVOCACIÓN PARA EL ORQUESTADOR CENTRAL:"
                echo -e "    ${VIVID_YELLOW}sudo bash ./orchest_business.sh${COLOR_RESET}\n"
            else 
                log_error "Montaje crítico no encontrado: $MOUNT_APP_SERV"
                exit 1
            fi 

            # PAUSA 3
            press_to_continue

            # --- OBSERVABILIDAD Y MÉTRICAS ---
            clear
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}  FASE 5: INICIALIZACION DEL ENTORNO DE OBSERVABILIDAD            ${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            
            log_info "Buscando scripts del recolector de métricas..."
            if [ -f "/opt/Install_v7/bash/metrics.sh" ]; then
                log_info "Invocando la configuración de observabilidad..."
                sudo bash /opt/Install_v7/bash/metrics.sh
                log_success "Ecosistema de observabilidad en línea."
            else
                log_warning "Módulo de métricas omitido: /opt/Install_v7/bash/metrics.sh no existe."
            fi

            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            log_success "LISTANDO IMAGENES"
            sudo docker image ls
 
            break
            ;;

        2)
            clear
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}  FASE 1: CONFIGURACIÓN DEL NODO SECUNDARIO (REPLICA)             ${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

            log_info "Evaluando punto de montaje del almacén de datos..."
            if [ -d "$MOUNT_APP_PSQ" ]; then 
                log_success "Punto de montaje localizado en: $MOUNT_APP_PSQ"
                
                log_info "INVOCANDO LA CONFIGURACION MAESTRA (Carga de binarios)"
                sudo bash $STARTING_POINT/binary_verification.sh binaries_postgres_and_exporter

                log_info "Ejecutando aprovisionamiento de tablespaces..."
                log_warning "VERIFICANDO LA EXISTENCIA DE LOS PUNTOS DE MONTAJE PARA LOS TBLSPC"

                TARGET_TBLSPC=(
                    "$MOUNT_TBLSPC_HISTO"
                    "$MOUNT_TBLSPC_TRAN"
                    "$MOUNT_TBLSPC_VIS"
                    "$MOUNT_BACKUP"
                    "$MOUNT_LOGS"
                    "$MOUNT_OVERLAY"
                )

                for mount_tblspc in "${TARGET_TBLSPC[@]}"; do 
                    if [ ! -d "$mount_tblspc" ]; then
                        log_error "[ERROR]: No se encontro el punto de montaje $mount_tblspc"
                        exit 1
                    fi 
                done         

                log_success "Puntos de montaje detectados para los tblspc "
                sudo bash "${MOUNT_APP_PSQ}packague_bd/install-bd.sh"
                log_success "TBPLSCP CREADOS CON EXITO"


                while true; do 
                    echo -e "\n${BOLD}MENÚ DE OPCIONES DE CONFIGURACIÓN POSTGRESQL.CONF: (SE REALIZA ESTE PROCESO PARA LA REPLICA DE LOS CONFIG DE POSTGRES)${COLOR_RESET}"
                    echo -e "  ${DEEP_BLUE}1)${COLOR_RESET} Infraestructura Básica (24GB)"
                    echo -e "  ${DEEP_BLUE}2)${COLOR_RESET} Infraestructura Media (32GB)"
                    echo -e "  ${DEEP_BLUE}3)${COLOR_RESET} Infraestructura Extendida (512GB)"
                    echo -e "${DEEP_BLUE}------------------------------------------------------------------${COLOR_RESET}"
                    
                    read -p "Seleccione el tipo de Infraestructura (1-3): " environment
                    echo -e "${DEEP_BLUE}------------------------------------------------------------------${COLOR_RESET}"
                    
                    SRC_FILE=""
                    INFRA_NAME=""

                    case $environment in 
                        1)
                            SRC_FILE="postgresql_para24GB.conf"
                            INFRA_NAME="Básica (24GB)"
                            break
                            ;;
                        2)
                            SRC_FILE="postgresql_para32GB.conf"
                            INFRA_NAME="Mediana (32GB)"
                            break
                            ;;
                        3)
                            SRC_FILE="postgresql_para512GB.conf"
                            INFRA_NAME="Extendida (512GB)"
                            break
                            ;;
                        *)
                            log_error "'$environment' no coincide con ninguna opción disponible.\n"
                            ;;
                    esac
                done 

            else 
                log_error "No se detectó el volumen requerido en la ruta: $MOUNT_APP_PSQ"
            fi

            # PAUSA REPLICA 1
            press_to_continue

            # ---- CONFIGURACION DE PGAGENT ---
            clear
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}  FASE 2: CONFIGURACION DEL (PGAGENT)                             ${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

            log_info "Verificando punto de montaje para pgagent"
            if [ -d "$MOUNT_APP_PSQ" ]; then
                log_success "Punto de montaje detectado para pgagent..."
                
                log_info "INVOCANDO LA CONFIGURACION MAESTRA (Carga de binarios)"
                sudo bash $STARTING_POINT/binary_verification.sh binaries_pgagent

            else 
                log_error "El punto de montaje no fue localizado para este componente"
            fi 

            # PAUSA PGAGENT
            press_to_continue

            # --- KAFKA RÉPLICA ---
            clear
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}  FASE 3: CONFIGURACION BROKER (KAFKA REPLICAS)                   ${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

            if [ -d "$MOUNT_KAFKA" ]; then
                log_success "Punto de montaje de Kafka verificado."
                
                log_info "INVOCANDO LA CONFIGURACION MAESTRA (Carga de binarios)"
                sudo bash $STARTING_POINT/binary_verification.sh binaries_kafkita


                log_info "Preparando partición física y metadatos..."
                if [ -d "$DATA_DIR" ]; then 
                    log_warning "Directorio ocupado. Purgando datos antiguos..."
                    sudo rm -rf "$DATA_DIR"
                    sudo mkdir -p "$DATA_DIR"
                else 
                    sudo mkdir -p "$DATA_DIR"
                fi

                log_info "Alineando políticas de acceso y propiedad (Chown)..."
                sudo chown -R 1000:1000 "$MOUNT_KAFKA"
                log_success "Políticas aplicadas con éxito."

                log_info "EL DESPLIEGUE DE KAFKA ESTA RESERVADO POR EL ORQUESTADOR CENTRAL"
            else 
                log_error "Punto de montaje de Kafka ausente. Abortando flujo."
                exit 1
            fi

            # PAUSA RÉPLICA 2
            press_to_continue

            # --- SERVICIOS RÉPLICA ---
            clear
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}  FASE 4: CONFIGURACION DE MS (SIMF)                              ${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

            if [ -d "$MOUNT_APP_SERV" ]; then 
                log_success "Punto de montaje verificado para servicios SIMF."

                log_info "INVOCANDO LA CONFIGURACION MAESTRA (Carga de binarios)"
                sudo bash $STARTING_POINT/binary_verification.sh binaries_simf
                
                # --- CONFIGURACIÓN DE SERVICIOS SGLPAR ---
                echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
                echo -e "${DEEP_BLUE}${BOLD}  FASE 5: CONFIGURACION DE MS (SGLPAR)                            ${COLOR_RESET}"
                echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
              
                log_info "INVOCANDO LA CONFIGURACION MAESTRA (Carga de binarios)"
                sudo bash $STARTING_POINT/binary_verification.sh binaries_sglpar
            else 
                log_error "No se pudo localizar el punto de montaje $MOUNT_APP_SERV"
                exit 1
            fi

            echo -e "\n${NEON_GREEN}${BOLD}==================================================================${COLOR_RESET}"
            echo -e "${NEON_GREEN}${BOLD}  PROCESO DE CONFIGURACIÓN DE RÉPLICA COMPLETADO CON ÉXITO        ${COLOR_RESET}"
            echo -e "${NEON_GREEN}${BOLD}==================================================================${COLOR_RESET}"

            # --- OBSERVABILIDAD Y MÉTRICAS ---
            clear
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}  FASE 5: INICIALIZACION DEL ENTORNO DE OBSERVABILIDAD            ${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
                
            log_info "Buscando scripts del recolector de métricas..."
            if [ -f "/opt/Install_v7/bash/metrics.sh" ]; then
                log_info "Invocando la configuración de observabilidad..."
                sudo bash /opt/Install_v7/bash/metrics.sh
                log_success "Ecosistema de observabilidad en línea."
            else
                log_warning "Módulo de métricas omitido: /opt/Install_v7/bash/metrics.sh no existe."
            fi

            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            log_success "LISTANDO IMAGENES"
            sudo docker image ls
            break
            ;;

        3)
            echo -e "\n${CRIMSON_RED}➔ Finalizando el instalador y cerrando conexiones del asistente de clúster. ¡Cerrando la configuracion!${COLOR_RESET}"
            exit 0 
            ;;

        *) 
            log_error "'$opcion' no coincide con ninguna opción disponible en el menú de clúster.\n"
            ;;
    esac
done
