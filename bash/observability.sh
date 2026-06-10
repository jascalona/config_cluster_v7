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
OBSERVABILITY="observabilidad"

# paquetes de configuracion
PACKAGE_OB="/opt/Install_v7/package_obser_and_balancer.zip"
METRICS_V7="/opt/Install_v7/metrics.zip"

# PUNTOS DE MONTAJE BALANCEADOR
MOUNT_BALANCER="/balancer/"
MOUNT_CORE="/core/"
MOUNT_MINIO="/storage_minio/"
MOUNT_METRICS="/metrics/"
MOUNT_IA="/storage_ia/"
MOUNT_LOGS="/logs/"
MOUNT_OVERLAY="/overlay/"

# ruta de la imagen
IMAGE_PATH_PROMETHEUS="/core/prometheus/images/prom-prometheus-v3.12.0.tar"
IMAGE_PATH_MINIO="/core/loki/images/minio-sha13582eff.tar"
IMAGE_PATH_LOKI="/core/loki/images/grafana-loki-3.7.2.tar" 
IMAGE_PATH_GRAFANA="/metrics/grafana/images/grafana-sycomv7_v1_12_4_4.tar"
IMAGE_PATH_ALERT="/metrics/alertmanager/alertmanager-sycomv7_v1_0_0.tar"
IMAGE_PATH_POOLEXPORTER="/metrics/pool-exporter/pgpool-exporter.tar"
IMAGE_PATH_KAFKA_EXPORTER="/metrics/alloy/kafka-exporter-v1.9.0.tar"
# nombre imagen
IMG_NAME_PROMETHEUS="prom/prometheus:v3.12.0"
IMG_NAME_LOKI="grafana/loki:3.7.2"
IMG_NAME_MINIO="minio/minio@sha256:13582eff79c6605a2d315bdd0e70164142ea7e98fc8411e9e10d089502a6d883"
IMG_NAME_GRAFANA="grafana/grafana:12.4.4-ubuntu"
IMG_NAME_ALERT="projectsintel/alertmanager-simf-v7:1.0.0.1"
IMG_NAME_POOLEXPORTER="pgpool/pgpool2_exporter:latest"


# ==============================================================================
# INTERFAZ DE CARGA (SPINNER)
# ==============================================================================
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr="|/-\\"
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

# Función para barra de progreso temporal en los sleeps
countdown() {
    local secs=$1
    local msg=$2
    while [ $secs -gt 0 ]; do
        printf "\r ${VIVID_YELLOW}${COLOR_RESET} $msg... Esperando %02ds " "$secs"
        sleep 1
        : $((secs--))
    done
    printf "\r ${NEON_GREEN}✔${COLOR_RESET} $msg... ¡Tiempo cumplido!     \n"
}


# ==============================================================================
# FASE 1: VALIDACIÓN DE CONFIGURACIÓN PREEXISTENTE E IDEMPOTENCIA
# ==============================================================================
clear
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}  ASISTENTE DE INSTALACIÓN AUTOMATIZADA - OBSERVABILIDAD          ${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD} FASE 1: PREPARANDO EL ENTORNO DE TRABAJO...                              ${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

log_info "Ejecutando escaneo de integridad en puntos de montaje..."


TARGET_DIRS=(
    "${MOUNT_CORE}prometheus"
    "${MOUNT_CORE}loki"
    "${MOUNT_MINIO}minio_data"
    "${MOUNT_METRICS}grafana"
    "${MOUNT_METRICS}alertmanager"
    "${MOUNT_METRICS}pool-exporter"
    "${MOUNT_IA}qdrant/"
    "${MOUNT_IA}storage-ia/"
)   


PREEXISTING_CONFIG=false
DIRS_TO_CLEAN=()

# Escaneo de paquetes
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
        # validacion de seguridad: evitar borrar la raiz si la variable esta vacia
        if [ -n "$dir" ] && [ "$dir" != "/" ]; then
        log_info "Eliminando residuos en: $dir"
        sudo rm -rf "$dir"
        fi
    done
    log_success "Depuracion completada con exito."
    sleep 1.5
else
    log_info "Entorno limpio. No se encontraron configuraciones previas en los puntos de montaje."
fi

echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}  INICIANDO ENVIO DE PAQUETES                                     ${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"


if [[ -f "$PACKAGE_OB" && -f "$METRICS_V7" ]]; then
    log_success "Archivos comprimidos detectados. Iniciando extracción..."

    # descompresion en el background mapeada al spinner
    sudo unzip -q -o "$PACKAGE_OB" -d /opt/Install_v7/ &
    pid1=$!
    sudo unzip -q -o "$METRICS_V7" -d /opt/Install_v7/ &
    pid2=$!

    wait $pid1 $pid2

    if [ -d "/opt/Install_v7/package_obser_and_balancer/" ];then 
        log_info "Distribuyendo los paquetes en volumenes persistentes..."
        
        sudo mv /opt/Install_v7/package_obser_and_balancer/pool-exporter/ "${MOUNT_METRICS}"
        sudo mv /opt/Install_v7/package_obser_and_balancer/alertmanager/ "${MOUNT_METRICS}"
        sudo mv /opt/Install_v7/package_obser_and_balancer/grafana/ "${MOUNT_METRICS}"

        sudo mv /opt/Install_v7/package_obser_and_balancer/prometheus/ "${MOUNT_CORE}"
        sudo mv /opt/Install_v7/package_obser_and_balancer/loki/ "${MOUNT_CORE}"


        # Limpieza del residuo temporal del descompresion
        sudo rm -rf /opt/Install_v7/package_obser_and_balancer/
        sudo rm -rf /opt/Install_v7/metrics/

        log_success "Paquetería cargada y desplegada exitosamente en puntos de montaje."

    else 
        log_error "Fallo critico: El directorio extraido /opt/package_obser_and_balancer/ no existe o esta corrupto"
        exit 1
    fi
else 
    log_error "Error crítico: No se detectó el archivo fuente de paquetería en: $PACKAGE_OB y $METRICS_V7"
    exit 1
fi 

countdown 3

# ==============================================================================
# INVOCANDO LA CONFIGURACION DEL BALANCEADOR PARA ALTA DISPONIBILIDAD
# ==============================================================================
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
log_info "REPLICANDO CONFIGURACION DEL BALANCEADOR"
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
if [ -f "/opt/Install_v7/bash/balancer.sh" ]; then
    log_info "Script de configuracion (balancer.sh) localizado. Iniciando la configuracion"
    sudo bash /opt/Install_v7/bash/balancer.sh
    log_success "Configuracion persistida en el servidor con exito"
else 
    log_error "No fue localizado el script (balancer.sh) en el directorio bash"
    exit 1
fi

# ==============================================================================
# CONFIGURACION DE PROMETHEUS
# ==============================================================================
clear
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD} FASE 2: INICIANDO CONFIGURACION DE PROMETHEUS                    ${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
log_warning "Verificando paqueteria"
if [ -d "${MOUNT_CORE}prometheus" ]; then 
    log_success "Paqueteria detectada"

    log_info "Verificacion de imagen"
    if [[ -z "$(sudo docker image -q "$IMG_NAME_PROMETHEUS" 2> /dev/null)" ]]; then
        log_info "La imagen no existe en este nodo, verificando (.tar)"
        if [ -f "$IMAGE_PATH_PROMETHEUS" ]; then
            log_warning "Cargando Imagen..." 
            sudo docker load -i "$IMAGE_PATH_PROMETHEUS" > /dev/null 2>&1 &
            spinner $!
        
            # Validamos si el docker load fue exitoso
            wait $!
            if [ $? -eq 0 ]; then
                log_success "Imagen cargada exitosamente"
            else
                log_error "[Error]: Falló la carga de la imagen desde $IMAGE_PATH_PROMETHEUS"
                press_to_continue
                exit 1 # O un return si está dentro de una función
            fi
        else
            log_error "[Error]: No fue localizada la imagen en la ruta especificada $IMAGE_PATH_PROMETHEUS"
            press_to_continue
            exit 1
        fi
    else 
        log_info "La imagen ($IMG_NAME_PROMETHEUS) ya existe, Omitiendo este paso..."
    fi

    # --- PERMISOS PROMETHEUS ---
    sudo mkdir "${MOUNT_CORE}prometheus/data"
    if [ -d "${MOUNT_CORE}prometheus/data" ]; then
        log_success "Repo creado"
    else 
        log_error "Ocurrio un error al crear el repo data"
    fi
    
    log_info "Aplicando permisos de infraestructura al directorio prometheus"
    sudo chown -R 65534:65534 "${MOUNT_CORE}prometheus" && sudo chmod -R 755 "${MOUNT_CORE}prometheus"
    log_info "Creando repo data"
    
    if [ $? -eq 0 ]; then
        log_success "--- Permisos asignados correctamente ---"
    else
        log_error "[Error]: No se pudieron aplicar los permisos al directorio"
    fi

    # --- INYECCIÓN DE LABELS ---
    if [ -n "$OBSERVABILITY" ]; then
        log_info "Inyeccion de etiqueta 'role=observability' en el nodo: $OBSERVABILITY"
        if sudo docker node update --label-add role=observability "$OBSERVABILITY" > /dev/null; then
            log_success "Etiqueta inyectada correctamente"
        else
            log_error "[Error]: No se pudo aplicar la etiqueta al nodo de Docker Swarm"
        fi
    else
        log_error "[Error]: La variable \$OBSERVABILITY está vacía, no se puede etiquetar el nodo"
    fi

    log_info "IMPORTANTE: EL DESPLIEGUE DE ESTE COMPONENTE ESTA RESERVADO PARA EL ORQUESTADOR"
    echo -e "\n${NEON_GREEN}${BOLD}==================================================================${COLOR_RESET}"
    echo -e "${NEON_GREEN}${BOLD}  PROCESO DE CONFIGURACIÓN PROMETHEUS FINALIZADO                     ${COLOR_RESET}"
    echo -e "${NEON_GREEN}${BOLD}====================================================================${COLOR_RESET}"

else 
    log_error "No fue localizada la paqueteria en el punto de montaje: ${MOUNT_CORE}prometheus"
fi

# PAUSA 1: Finalización de la configuración de prometheus
press_to_continue


# ==============================================================================
# CONFIGURACION DE LOKI/MINIO 
# ==============================================================================
clear
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD} FASE 3: INICIANDO CONFIGURACION DE LOKI Y MINIO                  ${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"


log_warning "Verificando paqueteria"
if [ -d ${MOUNT_CORE}loki ]; then
    log_info "Paqueteria detectada"

    log_info "Verificacion de imagenes"
    if [[ -z "$(sudo docker images -q $IMG_NAME_LOKI 2> /dev/null)" || -z "$(sudo docker images -q $IMG_NAME_MINIO 2> /dev/null)" ]]; then
        log_info "Las imagen no existe en este nodo, verificando (.tar)"
        if [ -f "$IMAGE_PATH_LOKI" ] && [ -f "$IMAGE_PATH_MINIO" ] ; then
            log_warning "Cargando Imagenes..." 
            
            sudo docker load -i "$IMAGE_PATH_LOKI" > /dev/null 2>&1 &
            spinner $!

            sudo docker load -i "$IMAGE_PATH_MINIO" > /dev/null 2>&1 &
            spinner $!

        else
            log_error "[Error]: No fueron localizadas la imagen en la ruta especificada $IMAGE_PATH_LOKI y $IMAGE_PATH_MINIO"
            exit 1
        fi
    else 
        log_info "Las imagen ($IMAGE_PATH_LOKI y $IMAGE_PATH_MINIO) ya existen, Omitiendo este paso..."
    fi    

    # --- LOKI ---
    log_info "Ajustando el repo data para loki"
    if [ -d "${MOUNT_CORE}loki" ]; then 
        echo "Punto de montaje detectado"
        sudo mkdir -p "${MOUNT_CORE}loki/loki_data"
        sudo chown -R 10001:10001 "${MOUNT_CORE}loki/loki_data"
        echo "Permisos asignados"
    else
        echo "ERROR: No se encontro el punto de montaje $MOUNT_CORE"
    fi


    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
    log_info "AJUSTANDO DISTRIBUCION DE MINIO"
    # --- MINIO ---
    log_info "Ajustando el repo data para minio"
    if [ -d "$MOUNT_MINIO" ]; then 
        log_info "Punto de montaje detectado"
        sudo mkdir -p ${MOUNT_MINIO}minio_data
        sudo chown -R 10001:10001 ${MOUNT_MINIO}minio_data
        log_success "Permisos asignados"
    else
        log_error "ERROR: No se encontro el punto de montaje $MOUNT_MINIO"
    fi

    log_info "IMPORTANTE: EL DESPLIEGUE DE ESTE COMPONENTE ESTA RESERVADO PARA EL ORQUESTADOR"
    echo -e "\n${NEON_GREEN}${BOLD}==================================================================${COLOR_RESET}"
    echo -e "${NEON_GREEN}${BOLD}  CONFIGURACIÓN DE LOKI/MINIO FINALIZADO                 ${COLOR_RESET}"
    echo -e "${NEON_GREEN}${BOLD}====================================================================${COLOR_RESET}"

    # PAUSA 3: Finalización de la configuración loki/minio
    press_to_continue

else 
    log_error "No fue localizada la paqueteria en el punto de montaje"
fi


# ==============================================================================
# INICIO DE LA CONFIGURACION DEL GRAFANA
# ==============================================================================
clear
echo -e "\n${NEON_GREEN}${BOLD}==================================================================${COLOR_RESET}"
echo -e "${NEON_GREEN}${BOLD}  FASE 4: PROCESO DE CONFIGURACIÓN DE GRAFANA                     ${COLOR_RESET}"
echo -e "${NEON_GREEN}${BOLD}====================================================================${COLOR_RESET}"

log_info "Verificando paqueteria"
if [ -d "${MOUNT_METRICS}grafana" ]; then
    log_success "Paqueteria detectada"
        
    log_info "Verificacion de imagen"
    if [[ -z "$(sudo docker image -q $IMG_NAME_GRAFANA 2> /dev/null)" ]]; then
        log_info "La imagen no existe en este nodo, verificando paqueteria"
        if [ -f "$IMAGE_PATH_GRAFANA" ]; then
            log_warning "Cargando Imagen..." 
            sudo docker load -i "$IMAGE_PATH_GRAFANA" > /dev/null 2>&1 &
            spinner $!
        else
            log_error "[Error]: No fue localizada la imagen en la ruta especificada $IMAGE_PATH_GRAFANA"
        fi
    else 
        log_info "La imagen ($IMG_NAME_GRAFANA) ya existe, Omitiendo este paso..."
    fi

    # --- GRAFANA ---
    log_info "Aignando permisos al repo de grafana"
    log_warning "Asignando permisos"
    sudo chmod -R 775 "${MOUNT_METRICS}grafana"
    log_success "permisos agregados"
  

    log_info "IMPORTANTE: EL DESPLIEGUE DE ESTE COMPONENTE ESTA RESERVADO PARA EL ORQUESTADOR"
    echo -e "\n${NEON_GREEN}${BOLD}==================================================================${COLOR_RESET}"
    echo -e "${NEON_GREEN}${BOLD}  CONFIGURACIÓN DE GRAFANA FINALIZADA                     ${COLOR_RESET}"
    echo -e "${NEON_GREEN}${BOLD}====================================================================${COLOR_RESET}"

    #  PAUSA 2: Finalización del la configuracion del pool
    press_to_continue

else 
    log_error "[Error]: No fue localizada la paqueteria en el punto de montaje"
fi

# ==============================================================================
# INICIO DE LA CONFIGURACION DE POOL-EXPORTER
# ==============================================================================
clear
echo -e "\n${NEON_GREEN}${BOLD}==================================================================${COLOR_RESET}"
echo -e "${NEON_GREEN}${BOLD}  FASE 5: PROCESO DE CONFIGURACIÓN DE POOL-EXPORTER                          ${COLOR_RESET}"
echo -e "${NEON_GREEN}${BOLD}====================================================================${COLOR_RESET}"

log_info "Verificando paqueteria"
if [ -d "${MOUNT_METRICS}pool-exporter" ]; then
    log_success "Paqueteria detectada"
        
    log_info "Verificacion de imagen"
    if [[ -z "$(sudo docker image -q $IMG_NAME_POOLEXPORTER 2> /dev/null)" ]]; then
        log_info "La imagen no existe en este nodo, verificando paqueteria"
        if [ -f "$IMAGE_PATH_POOLEXPORTER" ]; then
            log_warning "Cargando Imagen..." 
            sudo docker load -i "$IMAGE_PATH_POOLEXPORTER" > /dev/null 2>&1 &
            spinner $!
        else
            log_error "[Error]: No fue localizada la imagen en la ruta especificada $IMAGE_PATH_ALERT"
        fi
    else 
        log_info "La imagen ($IMG_NAME_POOLEXPORTER) ya existe, Omitiendo este paso..."
    fi

    log_info "IMPORTANTE: EL DESPLIEGUE DE ESTE COMPONENTE ESTA RESERVADO PARA EL ORQUESTADOR"
    echo -e "\n${NEON_GREEN}${BOLD}==================================================================${COLOR_RESET}"
    echo -e "${NEON_GREEN}${BOLD}  CONFIGURACIÓN DE ALERTMANAGER FINALIZADA                     ${COLOR_RESET}"
    echo -e "${NEON_GREEN}${BOLD}====================================================================${COLOR_RESET}"

    #  PAUSA 2: Finalización del la configuracion del ppol-exporter
    press_to_continue

else 
    log_error "[Error]: No fue localizada la paqueteria en el punto de montaje"
fi



# ==============================================================================
# INICIO DE LA CONFIGURACION DEL ALERTMANAGER
# ==============================================================================
clear
echo -e "\n${NEON_GREEN}${BOLD}==================================================================${COLOR_RESET}"
echo -e "${NEON_GREEN}${BOLD}  FASE 6: PROCESO DE CONFIGURACIÓN DE ALERTMANAGER                  ${COLOR_RESET}"
echo -e "${NEON_GREEN}${BOLD}====================================================================${COLOR_RESET}"

log_info "Verificando paqueteria"
if [ -d "${MOUNT_METRICS}alertmanager" ]; then
    log_success "Paqueteria detectada"
        
    log_info "Verificacion de imagen"
    if [[ -z "$(sudo docker image -q $IMG_NAME_ALERT 2> /dev/null)" ]]; then
        log_info "La imagen no existe en este nodo, verificando paqueteria"
        if [ -f "$IMAGE_PATH_ALERT" ]; then
            log_warning "Cargando Imagen..." 
            sudo docker load -i "$IMAGE_PATH_ALERT" > /dev/null 2>&1 &
            spinner $!
        else
            log_error "[Error]: No fue localizada la imagen en la ruta especificada $IMAGE_PATH_ALERT"
        fi
    else 
        log_info "La imagen ($IMG_NAME_ALERT) ya existe, Omitiendo este paso..."
    fi

    log_info "IMPORTANTE: EL DESPLIEGUE DE ESTE COMPONENTE ESTA RESERVADO PARA EL ORQUESTADOR"
    echo -e "\n${NEON_GREEN}${BOLD}==================================================================${COLOR_RESET}"
    echo -e "${NEON_GREEN}${BOLD}  CONFIGURACIÓN DE ALERTMANAGER FINALIZADA                     ${COLOR_RESET}"
    echo -e "${NEON_GREEN}${BOLD}====================================================================${COLOR_RESET}"

    #  PAUSA 2: Finalización del la configuracion del alertmanager
    press_to_continue

else 
    log_error "[Error]: No fue localizada la paqueteria en el punto de montaje"
fi


echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
log_success "LISTANDO IMAGENES"
    
sudo docker image ls
echo -e "\n${NEON_GREEN}${BOLD}==================================================================${COLOR_RESET}"
echo -e "${NEON_GREEN}${BOLD}  PROCESO DE CONFIGURACIÓN OBSERVABILIDAD FINALIZADO               ${COLOR_RESET}"
echo -e "${NEON_GREEN}${BOLD}==================================================================${COLOR_RESET}"
        