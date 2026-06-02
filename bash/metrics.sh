#!/bin/bash

# ==============================================================================
# CONFIGURACIÓN VISUAL Y COLORES
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
    echo -e "\n${VIVID_YELLOW}➔ Presione [ENTER] para finalizar el asistente de telemetría...${COLOR_RESET}"
    read -r
}

# ==============================================================================
# DEFINICIÓN DE VARIABLES (PUNTOS DE MONTAJE E IMÁGENES)
# ==============================================================================
MOUNT_METRICS="/metrics/"

IMAGE_PATH_ALLOY="/metrics/alloy/alloy.tar"
IMAGE_PATH_DISCOVERY="/metrics/service_discovery/discovery-api.tar" 


IMG_NAME_ALLOY="grafana/alloy:v1.16.1"
IMG_NAME_DISCOVERY="discovery-api:latest"

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
        printf " ${DEEP_BLUE}[%c]${COLOR_RESET}  Procesando, por favor espere..." "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b" 
    done
    tput cnorm 
    printf " ${NEON_GREEN}[OK]${COLOR_RESET}\n"
}

# ==============================================================================
# FLUJO DE EJECUCIÓN
# ==============================================================================
clear
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}  COMPONENTES DE OBSERVABILIDAD - CONFIGURACIÓN DE AGENTES          ${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

log_info "Iniciando escaner del entorno para validación de Telemetría..."

log_info "Verificando punto de montaje y paquetes de Alloy..."
if [ -d "$MOUNT_METRICS" ]; then
    log_success "Punto de montaje localizado con éxito en: $MOUNT_METRICS"
    echo -e "${DEEP_BLUE}------------------------------------------------------------------${COLOR_RESET}"
            
    log_info "Sincronizando registro local de imágenes en Docker Engine..."
    
    # Validación de imágenes en caché de Docker
    if [[ -z "$(sudo docker images -q $IMG_NAME_ALLOY 2>/dev/null)" || -z "$(sudo docker images -q $IMG_NAME_DISCOVERY 2>/dev/null)" ]]; then 
        log_warning "Imágenes parciales o ausentes en el host. Iniciando carga masiva..."
        
        # Validamos que ambos archivos .tar existan en el disco antes de cargar
        if [ -f "$IMAGE_PATH_ALLOY" ] && [ -f "$IMAGE_PATH_DISCOVERY" ]; then
            echo -n "   Cargando Grafana Alloy ($IMG_NAME_ALLOY)..."
            sudo docker load -i "$IMAGE_PATH_ALLOY" > /dev/null 2>&1 &
            spinner $!
            
            echo -n "   Cargando Service Discovery API ($IMG_NAME_DISCOVERY)..."
            sudo docker load -i "$IMAGE_PATH_DISCOVERY" > /dev/null 2>&1 &
            spinner $!
        else 
            log_error "Falta uno o ambos archivos de distribución de métricas (.tar) en las rutas."
            exit 1
        fi
    else 
        log_success "Las imágenes del stack (Alloy y Discovery) ya se encuentran en el caché del sistema."
    fi

    # --- BANNER DE CIERRE PROFESIONAL ---
    echo -e "\n${NEON_GREEN}${BOLD}==================================================================${COLOR_RESET}"
    echo -e "${NEON_GREEN}${BOLD}  PROCESO DE PREPARACIÓN DE TELEMETRÍA FINALIZADO                 ${COLOR_RESET}"
    echo -e "${NEON_GREEN}${BOLD}==================================================================${COLOR_RESET}"
    echo -e " ${CYAN_INFO}➔${COLOR_RESET} Los agentes han sido configurados correctamente."
    echo -e " ${CYAN_INFO}➔${COLOR_RESET} La instalacion de estos componentes está reservado para el orquestador."
    
    # Pausa de control antes de retornar al menú o salir
    press_to_continue

else 
    log_error "Punto de montaje crítico no encontrado en el host: $MOUNT_METRICS"
    exit 1
fi