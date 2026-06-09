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
BALANCER="balancer"
OBSERVABILITY="observabilidad"


# paquetes de configuracion
PACKAGE_OB="/opt/Install_v7/package_obser_and_balancer.zip"
METRICS_V7="/opt/Install_v7/metrics.zip"


# SECRET
NAME_POOL="pgpool_passwd"
NAME_POOLKEY="pgpoolkey"


# PUNTOS DE MONTAJE BALANCEADOR
MOUNT_BALANCER="/balancer/"
MOUNT_METRICS="/metrics/"
MOUNT_LOGS="/logs/"
MOUNT_OVERLAY="/overlay/"

# ruta de la imagen

IMAGE_PATH_NGINX="/balancer/nginx/simf/nginx.tar"
IMAGE_PATH_POOL="/balancer/pgpool-conf/pgpool.tar"

# nombre imagen
IMG_NAME_NGINX="nginx:1.27"
IMG_NAME_POOL="pgpool/pgpool:latest"

DAEMON_JSON="/etc/docker/daemon.json"

MOUNT_VALIDATION="/core"


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
# CONFIGURACION DEL DAEMON DE DOCKER LOCAL (ULIMITS Y MTU)
# ==============================================================================
echo -e "\n${MAGENTA}[PASO 0/4] Verificando configuración del daemon de Docker local...${COLOR_RESET}"

# Validamos si el archivo daemon.json ya contiene la configuración de ulimits
if [ -f "$DAEMON_JSON" ] && grep -q "default-ulimits" "$DAEMON_JSON"; then
    echo -e "${VIVID_YELLOW} La configuración de ulimits/mtu ya existe en $DAEMON_JSON. Saltando..."
else
    echo "Aplicando optimización de nofile (65536) y MTU (1450) en el daemon local..."
    sudo echo '{ "default-ulimits": { "nofile": { "Name": "nofile", "Hard": 65536, "Soft": 65536 } }, "mtu": 1450 }' | sudo tee "$DAEMON_JSON" > /dev/null
    echo -e "${NEON_GREEN} Archivo $DAEMON_JSON actualizado con éxito.${COLOR_RESET}"

fi
echo -e "-----------------------------------------------------------------"

# ==============================================================================
# FASE 1: VALIDACIÓN DE CONFIGURACIÓN PREEXISTENTE E IDEMPOTENCIA
# ==============================================================================
clear
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}  ASISTENTE DE INSTALACIÓN AUTOMATIZADA - BALANCEADOR DE CARGA    ${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD} FASE 1: PREPARANDO EL ENTORNO DE TRABAJO...                              ${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

log_info "Ejecutando escaneo de integridad en puntos de montaje..."

TARGET_DIRS=(
    "${MOUNT_BALANCER}nginx"
    "${MOUNT_BALANCER}pgpool-conf"
    "${MOUNT_METRICS}alloy"
    "${MOUNT_METRICS}service_discovery"
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

        sudo mv /opt/Install_v7/package_obser_and_balancer/nginx/ "${MOUNT_BALANCER}"
        sudo mv /opt/Install_v7/package_obser_and_balancer/pgpool-conf/ "${MOUNT_BALANCER}"
        sudo mv /opt/Install_v7/metrics/alloy/ "${MOUNT_METRICS}"
        sudo mv /opt/Install_v7/metrics/service_discovery/ "${MOUNT_METRICS}"

        # Limpieza del residuo temporal del descompresion
        sudo rm -rf /opt/Install_v7/package_obser_and_balancer/

        log_success "Paquetería cargada y desplegada exitosamente en puntos de montaje."

    else 
        log_error "Fallo critico: El directorio extraido /opt/package_obser_and_balancer/ no existe o esta corrupto"
        exit 1
    fi
else 
    log_error "Error crítico: No se detectó el archivo fuente de paquetería en: $PACKAGE_OB y $METRICS_V7"
    exit 1
fi 

# ==============================================================================
# INICIO DE LA CONFIGURACION DEL NGINX
# ==============================================================================
clear
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}  FASE 2: CONFIGURACION DEL NGINX                                 ${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

log_info "Verificando paqueteria"
if [ -d "${MOUNT_BALANCER}nginx" ]; then
    log_success "Paqueteria detectada"

    log_info "Verificacion de imagen"
       if [[ -z "$(sudo docker image -q $IMG_NAME_NGINX 2> /dev/null)" ]]; then
           log_info "La imagen no existe en este nodo, verificando (.tar)"
           if [ -f "$IMAGE_PATH_NGINX" ]; then
               log_warning "Cargando Imagen" 
               sudo docker load -i "$IMAGE_PATH_NGINX" > /dev/null 2>&1 &
               spinner $!
           else
               log_error "[Error]: No fue localizada la imagen en la ruta especificada $IMAGE_PATH_NGINX"
           fi
       else 
           log_info "La imagen ($IMG_NAME_NGINX) ya existe, Omitiendo este paso..."
       fi


    # --- INYECCIÓN DE LABELS ---
    log_info "Inyeccion de etiquetas (labels)"
    sudo docker node update --label-add type=balanceador "$BALANCER" 2> /dev/null 
    sudo docker node update --label-add type=balanceador "$OBSERVABILITY" 2> /dev/null
    log_success "Labels asignados a los nodos: $BALANCER, $OBSERVABILITY"

    # Lista de paquetes verificar/instalar
    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
    echo -e "\n${BOLD}Verificando keepalived"
    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

    PACKAGES=(keepalived)
    
    # Determinar si necesitamos correr apt update (solo si falta algún paquete)
    NEED_UPDATE=false
    for pkg in "${PACKAGES[@]}"; do
        if ! command -v "$pkg" &> /dev/null; then
            NEED_UPDATE=true
            break
        fi
    done

    if [ "$NEED_UPDATE" = true ]; then
        log_info "Actualizando índices de paquetes..."
        sudo apt update -y
    fi

    for pkg in "${PACKAGES[@]}"; do
        if ! command -v "$pkg" &> /dev/null; then
            echo "[-] $pkg no encontrado. Instalando..."
            sudo apt install -y "$pkg"
        
            log_success "Paquete $pkg instalado con exito"
            echo -e "${DEEP_BLUE}------------------------------------------------------------------${COLOR_RESET}"
            log_info "Activando e iniciando el servicio de $pkg"
            sudo systemctl enable --now "$pkg"
        else
            log_info "$pkg ya está instalado. Omitiendo este paso."
        fi
    done

    log_success "¡Verificacion de paquetes finalizada!"

    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
    echo -e "\n${BOLD} INICIANDO APERTURA DEL FICHERO PARA EL AJUSTE DE LA INTERFAZ Y LA IP VIRTUAL"
    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

    PATH_KEEPALIVED_SRV01="${MOUNT_BALANCER}nginx/keepalived/SRV01/keepalived.conf"
    PATH_KEEPALIVED_SRV05="${MOUNT_BALANCER}nginx/keepalived/SRV05/keepalived.conf"

    if [ -d "/balancer/nginx/keepalived/" ]; then

        log_info "Mostrando las propiedades de la interfaz, por favor preste atención y copie el nombre de su interfaz"
        sudo ip -br a  
        
        countdown 15 "Delay agregado para que pueda copiar el nombre de su interfaz, esperando..."
        log_info "Iniciando la apertura del fichero para la actualizacion de su ip virtual y la interfaz de red"
        log_info "COPIE EL NOMBRE DE LA INTERFAZ DE SU IP FISICA"
        
        echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
        log_info "INICIANDO EVALUACION DEL AMBIENTE PARA LA DISTRIBUCION DE LA CONFIGURACION PARA KEEPALIVED"

        VG_NAME="vg-core"
        
        # Evaluacion del Grupo de volumen
        if ! sudo vgs "$VG_NAME" >/dev/null 2>&1; then
            log_info "EL ASISTENTE DETECTO QUE ESTE SERVIDOR ES DE TIPO: (BALANCEADOR DE CARGA)"
            FICHERO_TARGET="$PATH_KEEPALIVED_SRV01"
            TEXTO_REPLICA="SRV01"
        else 
            log_info "EL ASISTENTE DETECTO QUE ESTE SERVIDOR ES DE TIPO: (OBSERVABILIDAD)"
            FICHERO_TARGET="$PATH_KEEPALIVED_SRV05"
            TEXTO_REPLICA="SRV05"
        fi

        countdown 3

        # Bucle de validacion
        while true; do
            # Apertura del fichero determinado por la evaluación anterior
            sudo nano "$FICHERO_TARGET"

            # Bucle interno de confirmación
            while true; do
                echo -e "\n¿Has terminado de ajustar el fichero? (y/n): "
                read -r respuesta

                case "$respuesta" in
                    [Yy]* | "")
                        log_info "Edición completada por el usuario. Continuando el flujo."
                        break 2
                        ;;
                    [Nn]*)
                        log_info "Reaperturando el fichero..."
                        break 
                        ;;
                    *)
                        echo -e "Épale papá, \"$respuesta\" no es una opción válida. Intenta de nuevo.\n"
                        ;;
                esac
            done
        done

        log_info "Realizando replicado de la configuracion del ${TEXTO_REPLICA} en /etc/keepalived/"

        if [ ! -d "/etc/keepalived" ]; then
            log_info "Creando directorio /etc/keepalived estructural..."
            sudo mkdir -p /etc/keepalived
        fi

        sudo cp "$FICHERO_TARGET" /etc/keepalived/keepalived.conf
        sudo ls -la /etc/keepalived/
        log_success "Fichero replicado con éxito en el sistema"

    else 
        log_error "[ERROR]: No fue localizado el directorio de keepalive en el punto de montaje"
    fi

    log_info "IMPORTANTE: EL DESPLIEGUE DE ESTE COMPONENTE ESTA RESERVADO PARA EL ORQUESTADOR"
    echo -e "\n${NEON_GREEN}${BOLD}==================================================================${COLOR_RESET}"
    echo -e "${NEON_GREEN}${BOLD}  PROCESO DE CONFIGURACIÓN DEL NGINX FINALIZADO                     ${COLOR_RESET}"
    echo -e "${NEON_GREEN}${BOLD}====================================================================${COLOR_RESET}"

    # PAUSA 2: Finalización de la configuración
    press_to_continue

else 
    log_error "La paquetería de nginx en '${MOUNT_BALANCER}nginx' no fue detectada"
    exit 1
fi


# ==============================================================================
# INICIO DE LA CONFIGURACION DEL POOL
# ==============================================================================
clear
    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}  FASE 3: CONFIGURACION DEL POOL                                  ${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

    log_info "Verificando paqueteria"
    if [ -d "${MOUNT_BALANCER}pgpool-conf/" ]; then
        log_success "Paqueteria detectada"
        
        log_info "Verificacion de imagen"
        if [[ -z "$(sudo docker image -q $IMG_NAME_POOL 2> /dev/null)" ]]; then
            log_info "La imagen no existe en este nodo, verificando"
            if [ -f "$IMAGE_PATH_POOL" ]; then
                log_warning "Cargando Imagen" 
                sudo docker load -i "$IMAGE_PATH_POOL" > /dev/null 2>&1 &
                spinner $!
            else
                log_error "[Error]: No fue localizada la imagen en la ruta especificada $IMAGE_PATH_POOL"
            fi
        else 
            log_info "La imagen ($IMG_NAME_POOL) ya existe, Omitiendo este paso..."
        fi

        # --- CONFIGURACIÓN E INYECCIÓN ---
        log_info "Validando existencia de secrets en Docker Swarm..."
        if sudo docker secret inspect "$NAME_POOL" >/dev/null 2>&1 \
            && sudo docker secret inspect "$NAME_POOLKEY" >/dev/null 2>&1; then
            log_success "Secrets existentes en el clúster. Omitiendo creación."
        else
            log_warning "Secrets no detectados. Iniciando inyección..."
            if ! sudo docker secret inspect "$NAME_POOL" >/dev/null 2>&1; then
                sudo cat "${MOUNT_BALANCER}pgpool-conf/pool_passwd" | sudo docker secret create "$NAME_POOL" -
            fi
            if ! sudo docker secret inspect "$NAME_POOLKEY" >/dev/null 2>&1; then
                sudo cat "${MOUNT_BALANCER}pgpool-conf/.pgpoolkey" | sudo docker secret create "$NAME_POOLKEY" -
            fi

            if sudo docker secret inspect "$NAME_POOL" >/dev/null 2>&1 \
                && sudo docker secret inspect "$NAME_POOLKEY" >/dev/null 2>&1; then
                log_success "Secrets '$NAME_POOL' y '$NAME_POOLKEY' creados exitosamente."
            else
                log_error "Error crítico al crear el secret '$NAME_POOL' y/o '$NAME_POOLKEY'."
                exit 1
            fi
        fi

        # INJECCION DE LABELS
        log_info "Injeccion de etiquetas (Labels) en nodos del Swarm..."
        sudo docker node update --label-add pg_role=pool "$BALANCER" > /dev/null
        sudo docker node update --label-add pg_role=pool "$OBSERVABILITY" > /dev/null
        log_success "Labels asignados a los nodos: $BALANCER, $OBSERVABILITY."
        log_info "Listando labels..."
        sudo docker secret ls


        log_info "IMPORTANTE: EL DESPLIEGUE DE ESTE COMPONENTE ESTA RESERVADO PARA EL ORQUESTADOR"
        echo -e "\n${NEON_GREEN}${BOLD}==================================================================${COLOR_RESET}"
        echo -e "${NEON_GREEN}${BOLD}  PROCESO DE CONFIGURACIÓN DEL POOL FINALIZADO                     ${COLOR_RESET}"
        echo -e "${NEON_GREEN}${BOLD}====================================================================${COLOR_RESET}"

        #  PAUSA 2: Finalización del la configuracion del pool
        press_to_continue

    else
        log_error "La paqueteria '${MOUNT_BALANCER}pgpool-conf' no fue detectada"
    fi

    # --- OBSERVABILIDAD Y MÉTRICAS ---
    clear
    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}  FASE 4: INICIALIZACION DEL ENTORNO DE OBSERVABILIDAD            ${COLOR_RESET}"
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
    echo -e "\n${NEON_GREEN}${BOLD}==================================================================${COLOR_RESET}"
    echo -e "${NEON_GREEN}${BOLD}  PROCESO DE CONFIGURACIÓN DEL BALANCEADOR FINALIZADO               ${COLOR_RESET}"
    echo -e "${NEON_GREEN}${BOLD}==================================================================${COLOR_RESET}"
        