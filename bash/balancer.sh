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

        # Lista de paquetes verificar/instalar
        echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
        echo -r "\n${BOLD}Verificando keepalived"
        echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

        PACKAGES=(keepalived)

        echo "Iniciando verificación de los paquetes..."

        for pkg in "${PACKAGES[@]}"; do
            #  verifica si el comando existe en el sistema
            if ! command -v "$pkg" &> /dev/null; then
                echo "[-] $pkg no encontrado. Instalando..."
                sudo apt update
                sudo apt install -y "$pkg"
            
                log_success "Paquete instalado con exito"
                echo -e "${DEEP_BLUE}------------------------------------------------------------------${COLOR_RESET}"
                log_info "Iniciando el inicio del servicio"
                sudo systemctl enable --now keepalived
            else
                log_info "$pkg ya está instalado. Omitiendo este paso."
            fi
        done

        log_success "¡Proceso finalizado!"

        echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
        echo -r "\n${BOLD} INICIANDO APERTURA DEL FICHERO PARA EL AJUSTE DE LA INTERFAZ Y LA IP VIRTUAL"
        echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
        
        if [ -f "${MOUNT_BALANCER}nginx/keepalived/SRV01/keepalived.conf" ]; then

            log_info "Mostrando las propiedades de la interfaz, por favor preste y copie el nombre de su interfaz"
            sudo ip a
            countdown 30 "Delay agregado para que pueda copiar el nombre de su interfaz, esperando..."
            log_info "Iniciando la apertura del fichero para la actualizacion de su ip vertual y la interfaz de red"

            while true; do
                # apertura del fichero
                sudo nano "${MOUNT_BALANCER}nginx/keepalived/SRV01/keepalived.conf"

                # preguntar si fueron finalizados los cambios
                echo -e "\n¿Has terminado de ajustar el fichero? (y\n)"
                read -r respuesta

                # evaluacion de la respuesta 
                case "$respuesta" in
                    [Yy]* | "")
                    log_info "Edicion completada por el usuario continuando el flujo de configuracion"
                    break
                    ;;
                [Nn]*)
                    log_info "Aperturando nuevamente el fichero..."
                    clean
                    ;;
                *)
                    echo "Epale papa, '$respuesta'esta opcion no es valida \n"
                    ;;
                esac
            done
        
            log_info "Realizando replicado de la configuracion en /etc/"
            if [ -f "/etc/keepalived/" ]; then
                sudo cp "${MOUNT_BALANCER}nginx/keepalived/SRV01/keepalived.conf" /etc/keepalived
                sudo ls /etc/keepalived/
                log_success "Fichero replicado con exito"
            else 
                log_error "[Error]: No se detecto el directororio de (keepalived)"
            fi 

        else 
            log_info "[ERROR]: No fue localizado el fichero de configuracion en el punto de montaje"
        fi 
    
    else 
        log_error "El punto de montaje "$MOUNT_BALANCER" no fue detectado"
        exit 1
    fi

    
    log_info "IMPORTANTE: EL DESPLIEGUE DE ESTE COMPONENTE ESTA RESERVADO PARA EL ORQUESTADOR"
    echo -e "\n${NEON_GREEN}${BOLD}==================================================================${COLOR_RESET}"
    echo -e "${NEON_GREEN}${BOLD}  PROCESO DE CONFIGURACIÓN DEL NGINX FINALIZADO                     ${COLOR_RESET}"
    echo -e "${NEON_GREEN}${BOLD}====================================================================${COLOR_RESET}"

     #  PAUSA 2: Finalización del la configuracion del nginx
    press_to_continue

    