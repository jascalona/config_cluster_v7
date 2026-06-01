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
BUSINESS_01="negocio01"
BUSINESS_02="negocio02"
BUSINESS_03="negocio03"

PACKAGUE_V7="/opt/packague_v7.zip"
MOUNT_APP_PSQ="/app_psql/"
MOUNT_APP_SERV="/app_services/"
MOUNT_KAFKA="/kafka/"
MOUNT_METRICS="/metrics/"
DATA_DIR="/kafka/kafka/data"

IMAGE_PATH_PG_P="/app_psql/packague_bd/images/simf-primary.tar"
IMAGE_PATH_PG_R="/app_psql/packague_bd/images/simf_replica.tar"
IMAGE_PATH_PGAGENT="/app_psql/pgagent/pgagent.tar"


IMAGE_PATH_SIMF_REST="/app_services/app_simf/image/simf_rest_api_0_2_2.tar"
IMAGE_PATH_SIMF_MS="/app_services/app_simf/image/simf_ms_0_2_2.tar"

IMAGE_PATH_SGLPAR_REST="/app_services/app_sglpar/image/sglpar_rest_api_0_2_2.tar"
IMAGE_PATH_SGLPAR_MS="/app_services/app_sglpar/image/sglpar_ms_0_2_2.tar"


IMAGE_PATH_KAFKA="/kafka/kafka/images/projectsintel-kafka-simf-v7_1.0.2.tar"

IMG_NAME_PG_P="bd-simf:latest"
IMG_NAME_PG_R="ibp_simf_replica:latest"
IMG_NAME_PGAGENT="pg_pgagent:latest"
IMG_NAME_KAFKA="projectsintel/kafka-simf-v7:1.0.2"

# MS
IMG_NAME_SIMF_REST="sycom/simf_rest_api:0.2.2"
IMG_NAME_SIMF_MS="sycom/simf_ms:0.2.2"

IMG_NAME_SGLPAR_REST="sycom/slgpar_rest_api:0.2.2"
IMG_NAME_SGLPAR_MS="sycom/slgpar_ms:0.2.2"


NAME_POSTGRES="postgre_password"
NAME_PGAGENT="pgagent_pass"

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
# FASE 0: VALIDACIÓN DE CONFIGURACIÓN PREEXISTENTE E IDEMPOTENCIA
# ==============================================================================
clear
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}  ASISTENTE DE INSTALACIÓN AUTOMATIZADA - CLÚSTER DE NEGOCIO       ${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}  PREPARANDO EL ENTORNO DE TRABAJO...                              ${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

log_info "Ejecutando escaneo de integridad en puntos de montaje..."

PREEXISTING_CONFIG=true

# Validamos la existencia de las carpetas internas críticas en los destinos
[ ! -d "${MOUNT_APP_PSQ}packague_bd" ] && PREEXISTING_CONFIG=false
[ ! -d "${MOUNT_KAFKA}kafka" ] && PREEXISTING_CONFIG=false
[ ! -d "${MOUNT_METRICS}alloy" ] && PREEXISTING_CONFIG=false
[ ! -d "${MOUNT_METRICS}service_discovery" ] && PREEXISTING_CONFIG=false

if [ "$PREEXISTING_CONFIG" = true ]; then
    log_success "Entorno previamente configurado detectado en los puntos de montaje."
    log_info "Omitiendo descompresión de paquetería. Saltando directo al menú..."
    sleep 1.5
else
    log_warning "Paquetería ausente o incompleta en puntos de montaje. Verificando origen..."
    
    if [ -f "$PACKAGUE_V7" ]; then 
        log_success "Archivo comprimido detectado ($PACKAGUE_V7). Iniciando extracción..."
        
        # Descompresión en background mapeada al spinner
        sudo unzip -q -o "$PACKAGUE_V7" -d /opt/ &
        spinner $!

        if [ -d "/opt/packague_v7/" ]; then 
            log_info "Distribuyendo componentes del sistema en volúmenes persistentes..."
            
            # Corrección de sintaxis de variables de llaves corporativas a estándar Bash
            sudo mv /opt/packague_v7/packague_bd/ "${MOUNT_APP_PSQ}"
            sudo mv /opt/packague_v7/kafka/ "${MOUNT_KAFKA}"
            sudo mv /opt/packague_v7/alloy/ "${MOUNT_METRICS}"
            sudo mv /opt/packague_v7/service_discovery/ "${MOUNT_METRICS}"
            
            # Limpieza del residuo temporal de descompresión
            sudo rm -rf /opt/packague_v7/
            
            log_success "Paquetería cargada y desplegada exitosamente en puntos de montaje."
        else 
            log_error "Fallo crítico: El directorio extraído /opt/packague_v7/ no existe o está corrupto."
            exit 1
        fi
    else 
        log_error "Error crítico: No se detectó el archivo fuente de paquetería en: $PACKAGUE_V7"
        exit 1
    fi 
fi

# ==============================================================================
# INICIO DE BUCLE INTERACTIVO (MENÚ DE OPCIONES)
# ==============================================================================
while true; do
    echo -e "\n${BOLD}MENÚ DE OPCIONES DE CONFIGURACIÓN:${COLOR_RESET}"
    echo -e "  ${DEEP_BLUE}1)${COLOR_RESET} Inicializar Servidor Principal (Primary Node)"
    echo -e "  ${DEEP_BLUE}2)${COLOR_RESET} Inicializar Servidor Réplica (Replica Node)"
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
                
                # --- CARGA DE IMÁGENES BD ---
                echo -e "\n${BOLD}[Componente: Database Engine]${COLOR_RESET}"
                if [[ -z "$(sudo docker images -q $IMG_NAME_PG_P 2> /dev/null)" ]]; then
                    if [ -f "$IMAGE_PATH_PG_P" ]; then
                        echo -n "   Cargando imagen primaria ($IMG_NAME_PG_P)..."
                        sudo docker load -i "$IMAGE_PATH_PG_P" > /dev/null 2>&1 &
                        spinner $!
                    else 
                        log_error "Archivo no localizado en la ruta: $IMAGE_PATH_PG_P"
                        exit 1
                    fi
                else 
                    log_success "La imagen $IMG_NAME_PG_P ya se encuentra en el host."
                fi

                if [[ -z "$(sudo docker images -q $IMG_NAME_PG_R 2> /dev/null)" ]]; then
                    if [ -f "$IMAGE_PATH_PG_R" ]; then
                        echo -n "   Cargando imagen de réplica ($IMG_NAME_PG_R)..."
                        sudo docker load -i "$IMAGE_PATH_PG_R" > /dev/null 2>&1 &
                        spinner $!
                    else 
                        log_error "Archivo no localizado en la ruta: $IMAGE_PATH_PG_R"
                        exit 1
                    fi
                else 
                    log_success "La imagen $IMG_NAME_PG_R ya se encuentra en el host."
                fi

                # --- CONFIGURACIÓN E INYECCIÓN ---
                log_info "Ejecutando aprovisionamiento de tablespaces..."
                sudo bash "${MOUNT_APP_PSQ}packague_bd/install-bd.sh"
                
                log_info "Validando resistencia de secretos en Docker Swarm ($NAME_POSTGRES)..."
                if sudo docker secret inspect "$NAME_POSTGRES" >/dev/null 2>&1; then
                    log_success "Secret existente en el clúster. Omitiendo creación."
                else 
                    log_warning "Secret no detectado. Iniciando inyección..."
                    sudo printf '%s\n' '*:9997:*:postgres:PO$tgr3$.BD' '*:9997:*:simf_admin_user:simf' | sudo docker secret create postgre_password -
                    sudo docker secret inspect "$NAME_POSTGRES" > /dev/null
                    log_success "Secret creado exitosamente."
                fi

                log_info "Escaneando infraestructura de red del clúster (pg_net)..."
                if sudo docker network inspect pg_net >/dev/null 2>&1; then
                    log_success "Red overlay 'pg_net' detectada."
                else
                    log_warning "Red 'pg_net' ausente. Creando topología overlay..."
                    sudo docker network create --driver overlay --subnet 10.0.10.0/24 --gateway 10.0.10.1 --attachable pg_net
                    log_success "Red superpuesta distribuida creada correctamente."
                fi  

                log_info "Aprovisionando etiquetas (Labels) en nodos del Swarm..."
                sudo docker node update --label-add pg_role=primary "$BUSINESS_01" > /dev/null
                sudo docker node update --label-add role=bd-simf "$BUSINESS_01" > /dev/null
                sudo docker node update --label-add pg_role=replica "$BUSINESS_02" > /dev/null
                sudo docker node update --label-add pg_role=replica "$BUSINESS_03" > /dev/null
                log_success "Labels asignados a los nodos: $BUSINESS_01, $BUSINESS_02, $BUSINESS_03."

                # --- DESPLIEGUE BD ---
                log_info "Lanzando stack de base de datos..."
                if [ -f "${MOUNT_APP_PSQ}packague_bd/stack/primary-stack.yml" ]; then 
                    echo -n "   Desplegando stack 'bd-simf' en Swarm..."
                    sudo docker stack deploy -c "${MOUNT_APP_PSQ}packague_bd/stack/primary-stack.yml" bd-simf > /dev/null 2>&1 &
                    spinner $!
                    sudo docker stack ps --no-trunc bd-simf | head -n 5
                else 
                    log_error "Manifiesto 'primary-stack.yml' no encontrado."
                    exit 1
                fi 
            else 
                log_error "Punto de montaje de base de datos ausente de forma crítica. Abortando flujo."
                exit 1
            fi

            #  PAUSA 1: Finalización de la Base de Datos antes de Kafka
            press_to_continue

            # ---- CONFIGURACION DE PGAGENT ---
            clear
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}  FASE 2: CONFIGURACION DEL (PGAGENT)                             ${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

            log_info "Verificando punto de montaje para pgagent"
            if [ -d "$MOUNT_APP_PSQ" ]; then
                log_success "Punto de montaje detectado para pgagent..."
                
                if [[ -z "$(sudo docker images -q $IMG_NAME_PGAGENT 2> /dev/null)" ]]; then
                    if [ -f "$IMAGE_PATH_PGAGENT" ]; then 
                        echo -n "   Cargando imagen de pgagent ($IMG_NAME_PGAGENT)..."
                        sudo docker load -i "$IMG_NAME_PGAGENT" > /dev/null 2>&1 &
                        spinner $!
                    else 
                        log_error "Archivo no localizado en la ruta: $IMAGE_PATH_PGAGENT"
                        exit 1
                    fi
                else 
                    log_success "La imagen $IMG_NAME_PGAGENT ya existe en el host."
                fi 

                # --- CONFIGURACIÓN E INYECCIÓN ---
                log_info "Validando resistencia de secret en Docker Swarm ($NAME_PGAGENT)..."
                if sudo docker secret inspect "$NAME_PGAGENT" >/dev/null 2>&1; then
                    log_success "Secret existente en el clúster. Omitiendo creación."
                else 
                    log_warning "Secret no detectado. Iniciando inyección..."
                    sudo printf '%s\n' '*:9997:*:postgres:PO$tgr3$.BD' '*:9997:*:simf_admin_user:simf'| sudo docker secret create pgagent_pass -
                    sudo docker secret inspect "$NAME_PGAGENT" > /dev/null
                    log_success "Secret creado exitosamente."
                fi


                log_info "Aprovisionando etiquetas (Labels) en nodos del Swarm..."
                sudo docker node update --label-add pgagent=pgagent "$BUSINESS_01" > /dev/null
                sudo docker node update --label-add pgagent=pgagent "$BUSINESS_02" > /dev/null
                sudo docker node update --label-add pgagent=pgagent "$BUSINESS_03" > /dev/null
                log_success "Labels asignados a los nodos: $BUSINESS_01, $BUSINESS_02, $BUSINESS_03."

            else 
                log_error "El punto de montaje no fue localizado para este componente"
            fi 
            #  PAUSA PGAGENT
            press_to_continue


            # --- CONFIGURACION DE KAFKA ---
            clear
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}  FASE 3: CONFIGURACION BROKER (KAFKA)                            ${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

            log_info "Verificando punto de montaje para Kafka..."
            if [ -d "$MOUNT_KAFKA" ]; then
                log_success "Punto de montaje detectado en: $MOUNT_KAFKA"
                
                if [[ -z "$(sudo docker images -q $IMG_NAME_KAFKA 2> /dev/null)" ]]; then 
                    if [ -f "$IMAGE_PATH_KAFKA" ]; then 
                        echo -n "   Cargando imagen de Kafka ($IMG_NAME_KAFKA)..."
                        sudo docker load -i "$IMAGE_PATH_KAFKA" > /dev/null 2>&1 &
                        spinner $!
                    else 
                        log_error "Archivo no localizado en la ruta: $IMAGE_PATH_KAFKA"
                        exit 1
                    fi
                else 
                    log_success "La imagen $IMG_NAME_KAFKA ya existe en el host."
                fi 

                log_info "Validando infraestructura de red para telemetría y monitoreo..."
                if sudo docker network inspect monitoring >/dev/null 2>&1; then
                    log_success "Red overlay 'monitoring' activa."
                else
                    log_warning "Red 'monitoring' ausente. Creando segmento de red..."
                    sudo docker network create --driver overlay monitoring > /dev/null
                    log_success "Red superpuesta de monitoreo aislada correctamente."
                fi  

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

            #  PAUSA 2: Finalización de Kafka antes de Servicios SIMF
            press_to_continue

            # --- CONFIGURACIÓN DE SERVICIOS SIMF ---
            clear
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}  FASE 4: CONFIGURACION DE MS (SIMF)                              ${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

            log_info "Verificando punto de montaje de la capa de servicios..."
            if [ -d "$MOUNT_APP_SERV" ]; then 
                log_success "Punto de montaje detectado en: $MOUNT_APP_SERV"
                
                if [[ -z "$(sudo docker images -q $IMG_NAME_SIMF_REST 2> /dev/null)" || -z "$(sudo docker images -q $IMG_NAME_SIMF_MS 2> /dev/null)" ]]; then 
                    log_warning "Imágenes parciales o ausentes. Iniciando carga masiva..."

                    if [ -f "$IMAGE_PATH_SIMF_REST" ] && [ -f "$IMAGE_PATH_SIMF_MS" ]; then
                        echo -n "   Cargando paquete REST API ($IMG_NAME_SIMF_REST)..."
                        sudo docker load -i "$IMAGE_PATH_SIMF_REST" > /dev/null 2>&1 &
                        spinner $!

                        echo -n "   Cargando paquete Microservicios ($IMG_NAME_SIMF_MS)..."
                        sudo docker load -i "$IMAGE_PATH_SIMF_MS" > /dev/null 2>&1 &
                        spinner $!
                    else 
                        log_error "Falta uno o ambos archivos de distribución .tar en la ruta."            
                        exit 1
                    fi

                    log_info "Escaneando infraestructura balanceadora perimetral (nginx_lbnet)..."
                    if sudo docker network inspect nginx_lbnet >/dev/null 2>&1; then
                        log_success "Red balanceadora 'nginx_lbnet' existente."
                    else
                        log_warning "Red perimetral ausente. Creando red del balanceador..."
                        sudo docker network create --driver overlay nginx_lbnet > /dev/null
                        log_success "Segmentación perimetral configurada."
                    fi  
                else 
                    log_success "Las imágenes del ecosistema SIMF ya están sincronizadas."
                fi 


            # --- CONFIGURACIÓN DE SERVICIOS SGLPAR ---
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}  FASE 5: CONFIGURACION DE MS (SGLPAR)                            ${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
                log_info "Escaneando imagenes..."
                if [[ -z "$(sudo docker images -q $IMG_NAME_SGLPAR_REST 2> /dev/null)" || -z "$(sudo docker images -q $IMG_NAME_SGLPAR_MS 2> /dev/null)" ]]; then 
                    log_warning "Imágenes parciales o ausentes. Iniciando carga masiva..."

                    if [ -f "$IMAGE_PATH_SGLPAR_REST" ] && [ -f "$IMAGE_PATH_SGLPAR_MS" ]; then
                        echo -n "   Cargando paquete REST API ($IMG_NAME_SGLPAR_REST)..."
                        sudo docker load -i "$IMAGE_PATH_SGLPAR_REST" > /dev/null 2>&1 &
                        spinner $!

                        echo -n "   Cargando paquete Microservicios ($IMG_NAME_SGLPAR_MS)..."
                        sudo docker load -i "$IMAGE_PATH_SGLPAR_MS" > /dev/null 2>&1 &
                        spinner $!
                    else 
                        log_error "Falta uno o ambos archivos de distribución .tar en la ruta."            
                        exit 1
                    fi

                    log_info "Escaneando infraestructura balanceadora perimetral (nginx_lbnet)..."
                    if sudo docker network inspect nginx_lbnet >/dev/null 2>&1; then
                        log_success "Red balanceadora 'nginx_lbnet' existente."
                    else
                        log_warning "Red perimetral ausente. Creando red del balanceador..."
                        sudo docker network create --driver overlay nginx_lbnet > /dev/null
                        log_success "Segmentación perimetral configurada."
                    fi  
                else 
                    log_success "Las imagenes del ecosistema SGLPAR ya están sincronizadas."
                fi 

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

            # PAUSA 3: Finalización del despliegue completo de aplicaciones antes de Observabilidad
            press_to_continue

            # --- OBSERVABILIDAD Y MÉTRICAS ---
            clear
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}  FASE 5: INICIALIZACION DEL ENTORNO DE OBSERVABILIDAD            ${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            
            log_info "Buscando scripts del recolector de métricas..."
            if [ -f "/opt/bash/metrics.sh" ]; then
                log_info "Invocando la configuración de observabilidad..."
                sudo bash /opt/bash/metrics.sh
                log_success "Ecosistema de observabilidad en línea."
            else
                log_warning "Módulo de métricas omitido: /opt/bash/metrics.sh no existe."
            fi

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
                
                if [[ -z "$(sudo docker images -q $IMG_NAME_PG_R 2> /dev/null)" ]]; then
                    if [ -f "$IMAGE_PATH_PG_R" ]; then
                        echo -n "   Cargando imagen replicada ($IMG_NAME_PG_R)..."
                        sudo docker load -i "$IMAGE_PATH_PG_R" > /dev/null 2>&1 &
                        spinner $!
                    else 
                        log_error "Imagen de réplica no localizada en: $IMAGE_PATH_PG_R"
                        exit 1
                    fi
                else 
                    log_success "La imagen de réplica de la base de datos ya está presente."
                fi

                log_info "Configurando directorios y Storage Engine..."
                sudo bash "${MOUNT_APP_PSQ}packague_bd/install-bd.sh"
                log_success "Estructura de directorios de persistencia de base de datos lista."
            else 
                log_error "No se detectó el volumen requerido en la ruta: $MOUNT_APP_PSQ"
            fi

            #  PAUSA REPLICA 1
            press_to_continue

            # ---- CONFIGURACION DE PGAGENT ---
            clear
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}  FASE 2: CONFIGURACION DEL (PGAGENT)                             ${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

            log_info "Verificando punto de montaje para pgagent"
            if [ -d "$MOUNT_APP_PSQ" ]; then
                log_success "Punto de montaje detectado para pgagent..."
                
                if [[ -z "$(sudo images -q $IMG_NAME_PGAGENT 2> /dev/null)" ]]; then
                    if [ -f "$IMAGE_PATH_PGAGENT" ]; then 
                        echo -n "   Cargando imagen de pgagent ($IMG_NAME_PGAGENT)..."
                        sudo docker load -i "$IMG_NAME_PGAGENT" > /dev/null 2>&1 &
                        spinner $!
                    else 
                        log_error "Archivo no localizado en la ruta: $IMAGE_PATH_PGAGENT"
                        exit 1
                    fi
                else 
                    log_success "La imagen $IMG_NAME_PGAGENT ya existe en el host."
                fi 

                # --- CONFIGURACIÓN E INYECCIÓN ---
                log_info "Validando resistencia de secret en Docker Swarm ($NAME_PGAGENT)..."
                if sudo docker secret inspect "$NAME_PGAGENT" >/dev/null 2>&1; then
                    log_success "Secret existente en el clúster. Omitiendo creación."
                else 
                    log_warning "Secret no detectado. Iniciando inyección..."
                    sudo printf '%s\n' '*:9997:*:postgres:PO$tgr3$.BD' '*:9997:*:simf_admin_user:simf'| sudo docker secret create pgagent_pass -
                    sudo docker secret inspect "$NAME_PGAGENT" > /dev/null
                    log_success "Secret creado exitosamente."
                fi


                log_info "Aprovisionando etiquetas (Labels) en nodos del Swarm..."
                sudo docker node update --label-add pgagent=pgagent "$BUSINESS_01" > /dev/null
                sudo docker node update --label-add pgagent=pgagent "$BUSINESS_02" > /dev/null
                sudo docker node update --label-add pgagent=pgagent "$BUSINESS_03" > /dev/null
                log_success "Labels asignados a los nodos: $BUSINESS_01, $BUSINESS_02, $BUSINESS_03."

            else 
                log_error "El punto de montaje no fue localizado para este componente"
            fi 
            #  PAUSA PGAGENT
            press_to_continue


            # --- KAFKA RÉPLICA ---
            clear
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}  FASE 3: CONFIGURACION BROKER (KAFKA REPLICAS)                   ${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

            if [ -d "$MOUNT_KAFKA" ]; then
                log_success "Punto de montaje de Kafka verificado."
                
                if [[ -z "$(sudo docker images -q $IMG_NAME_KAFKA 2> /dev/null)" ]]; then 
                    if [ -f "$IMAGE_PATH_KAFKA" ]; then 
                        echo -n "   Cargando imagen distribuida ($IMG_NAME_KAFKA)..."
                        sudo docker load -i "$IMAGE_PATH_KAFKA" > /dev/null 2>&1 &
                        spinner $!
                    else 
                        log_error "Paquete Kafka ausente en la ruta: $IMAGE_PATH_KAFKA"
                        exit 1
                    fi
                else 
                    log_success "Imagen de Kafka ya sincronizada."
                fi 

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

                log_info "EL DESPLIEGUE DE KAFKA ESTÁ RESERVADO POR EL ORQUESTADOR CENTRAL"
                
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
                
                if [[ -z "$(sudo docker images -q $IMG_NAME_SIMF_REST 2> /dev/null)" || -z "$(sudo docker images -q $IMG_NAME_SIMF_MS 2> /dev/null)" ]]; then 
                    log_warning "Detectada falta de imágenes del Core. Extrayendo archivos..."

                    if [ -f "$IMAGE_PATH_SIMF_REST" ] && [ -f "$IMAGE_PATH_SIMF_MS" ]; then
                        echo -n "   Desempaquetando Micro-API..."
                        sudo docker load -i "$IMAGE_PATH_SIMF_REST" > /dev/null 2>&1 &
                        spinner $!

                        echo -n "   Desempaquetando Workers/MS..."
                        sudo docker load -i "$IMAGE_PATH_SIMF_MS" > /dev/null 2>&1 &
                        spinner $!
                    else 
                        log_error "Archivos .tar corruptos o no encontrados en las rutas especificadas."            
                        exit 1
                    fi

                    log_info "Comprobando red interna compartida (nginx_lbnet)..."
                    if sudo docker network inspect nginx_lbnet >/dev/null 2>&1; then
                        log_success "Estructura de red compartida activa."
                    else
                        log_warning "Red ausente. Construyendo topología overlay..."
                        sudo docker network create --driver overlay nginx_lbnet > /dev/null
                        log_success "Red superpuesta distribuida acoplada."
                    fi  
                else 
                    log_success "Servicios ya sincronizados en el host de réplica."
                fi 

                echo -e "\n${NEON_GREEN}${BOLD}==================================================================${COLOR_RESET}"
                echo -e "${NEON_GREEN}${BOLD}  PROCESO DE CONFIGURACIÓN DE RÉPLICA COMPLETADO CON ÉXITO        ${COLOR_RESET}"
                echo -e "${NEON_GREEN}${BOLD}==================================================================${COLOR_RESET}"
            else 
                log_error "Error del sistema de archivos en: $MOUNT_APP_SERV"
                exit 1
            fi

            break
            ;;
            
        3)
            echo -e "\n${CRIMSON_RED}➔ Finalizando el instalador y cerrando conexiones del asistente de clúster. ¡Adios!${COLOR_RESET}"
            exit 0 
            ;;
            
        *) 
            log_error "'$opcion' no coincide con ninguna opción disponible en el menú de clúster.\n"
            ;;
    esac
done