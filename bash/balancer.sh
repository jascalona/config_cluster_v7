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
BALANCER="balancer"
OBSERVABILITY="observabilidad"


# paquetes de configuracion
PACKAGE_OB="/opt/Install_v7/package_obser_and_balancer.zip"


# PUNTOS DE MONTAJE BALANCEADOR
MOUNT_BALANCER="/balancer/"
MOUNT_METRICS="/metrics/"
MOUNT_LOGS="/logs/"
MOUNT_OVERLAY="/overlay/"

# ruta de la imagen
IMAGE_PATH_NGINX="/balancer/"

# nombre imagen
IMG_NAME_NGINX="bd-simf:latest"


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
# FASE 0: VALIDACIÓN DE CONFIGURACIÓN PREEXISTENTE E IDEMPOTENCIA
# ==============================================================================
clear
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}  ASISTENTE DE INSTALACIÓN AUTOMATIZADA - BALANCEADOR DE CARGA    ${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}  PREPARANDO EL ENTORNO DE TRABAJO...                              ${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

log_info "Ejecutando escaneo de integridad en puntos de montaje..."

TARGET_DIRS=(
    "${MOUNT_BALANCER}nginx"
    "${MOUNT_BALANCER}pgpool-conf"
    "${MOUNT_METRICS}alloy"
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

if [ -f "$PACKAGE_OB" ]; then
    log_success "Archivo comprimido detectado ($PACKAGE_OB). Iniciando extraccion..."

    # descompresion en el background mapeada al spinner
    sudo unzip -q -o "$PACKAGE_OB" -d /opt/Install_v7/ &
    spinner $!

    if [ -d "/opt/Install_v7/package_obser_and_balancer/" ];then 
        log_info "Distribuyendo los paquetes en volumenes persistentes..."

        sudo mv /opt/Install_v7/package_obser_and_balancer/nginx/ "${MOUNT_BALANCER}"
        sudo mv /opt/Install_v7/package_obser_and_balancer/pgpool-conf/ "{$MOUNT_BALANCER}"
        sudo mv /opt/Install_v7/package_obser_and_balancer/alloy/ {"$MOUNT_METRICS"}

        # Limpieza del residuo temporal del descompresion
        sudo rm -rf /opt/Install_v7/package_obser_and_balancer/

        log_success "Paquetería cargada y desplegada exitosamente en puntos de montaje."

    else 
        log_error "Fallo critico: El directorio extraido /opt/package_obser_and_balancer/ no existe o esta corrupto"
        exit 1
    fi
else 
    log_error "Error crítico: No se detectó el archivo fuente de paquetería en: $PACKAGE_OB"
    exit 1
fi 


# ==============================================================================
# INICIO DE LA CONFIGURACION PARA EL BALANCEADOR DE CARGA
# ==============================================================================
clear
    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}  FASE 1: ESCANEO Y VERIFICACIÓN DEL BALANCEADOR DE CARGA         ${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

    log_info "Verificando el punto de montaje balancer"
    if [ -d "$MOUNT_BALANCER" ]; then
        log_success "Punto de montaje detectado"

        # --- INYECCIÓN DE LABELS ---
        log_info "Injeccion de etiquetas (labels)"
        sudo docker node update --label-add type=balanceador "$BALANCER" 2> /dev/null 
        sudo docker node update --label-add type=balanceador "$OBSERVABILITY" 2> /dev/null
        log_success "Labels asignados a los nodos: $BALANCER, $OBSERVABILITY"
    
        # agregar logica para la configuracion de la ip virtual
    
    else 
        log_error "El punto de montaje "$MOUNT_BALANCER" no fue detectado"
        exit 1
    fi


        