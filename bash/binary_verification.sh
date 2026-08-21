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
# DECLARACION DE RUTAS NEGOCIOS
# ==============================================================================
# BD-SIMF (POSTGRES PRIMARY, REPLICA Y EXPORTER)
IMAGE_PATH_PG_P="/app_psql/packague_bd/images/simf-primary.tar"
IMAGE_PATH_PG_R="/app_psql/packague_bd/images/simf_replica.tar"
IMAGE_PATH_PG_EXPORTER="/app_psql/packague_bd/images/postgres-exporter_v0.17.1.tar"

# PG-AGENT
IMAGE_PATH_PGAGENT="/app_psql/pgagent/pgagent.tar"

# KAFKITA
IMAGE_PATH_KAFKA="/kafka/kafka/images/projectsintel-kafka-simf-v7_1.0.2.tar"

# REST API & MS (SIMF)
IMAGE_PATH_SIMF_REST="/app_services/app_simf/image/simf_rest_api_0_2_2.tar"
IMAGE_PATH_SIMF_MS="/app_services/app_simf/image/simf_ms_0_2_2.tar"

# REST API & MS (SGLPAR)
IMAGE_PATH_SGLPAR_REST="/app_services/app_sglpar/image/sycom_sglpar_rest_api_0.2.4.tar" 
IMAGE_PATH_SGLPAR_MS="/app_services/app_sglpar/image/sycom_sglpar_ms_0.2.3.tar"

# ==============================================================================
# DECLARACION DE BINARIOS NEGOCIO
# ==============================================================================

# BD-SIMF (POSTGRES PRIMARY, REPLICA Y EXPORTER)
IMG_NAME_PG_P="bd-simf:latest"
IMG_NAME_PG_R="ibp_simf_replica:latest"
IMG_NAME_PG_EXPORTER="prometheuscommunity/postgres-exporter:v0.17.1"

# PG-AGENT
IMG_NAME_PGAGENT="pg_pgagent:latest"

# KAFKITA
IMG_NAME_KAFKA="projectsintel/kafka-simf-v7:1.0.2"

# REST API & MS (SIMF)
IMG_NAME_SIMF_REST="sycom/simf_rest_api:0.2.2"
IMG_NAME_SIMF_MS="sycom/simf_ms:0.2.2"

# REST API & MS (SGLPAR)
IMG_NAME_SGLPAR_REST="sycom/sglpar_rest_api:0.2.4"
IMG_NAME_SGLPAR_MS="sycom/sglpar_ms:0.2.3"



# ==============================================================================
# DECLARACION DE RUTAS METRICS
# ==============================================================================
# METRICS
IMAGE_PATH_ALLOY="/metrics/alloy/alloy.tar"
IMAGE_PATH_DISCOVERY="/metrics/service_discovery/serve-discovery.tar" 

# ==============================================================================
# DECLARACION DE BINARIOS METRICS
# ==============================================================================

# ALLOY & DISCOVERY
IMG_NAME_ALLOY="grafana/alloy:v1.16.1"

IMG_NAME_DISCOVERY="discovery-api:latest"



# ==============================================================================
# DECLARACION DE RUTAS BALANCEADOR
# ==============================================================================
# NGINX & EXPORTER
IMAGE_PATH_NGINX="/balancer/nginx/simf/nginx.tar"
IMAGE_PATH_NGINX_EXPORTER="/balancer/nginx/simf/nginx-exporter.tar"

# PGPOOL
IMAGE_PATH_POOL="/balancer/pgpool-conf/pgpool.tar"

# ==============================================================================
# DECLARACION DE BINARIOS BALANCEADOR
# ==============================================================================
# NGINX
IMG_NAME_NGINX="nginx:1.27"
IMG_NAME_NGINX_EXPORTER="nginx/nginx-prometheus-exporter:1.1.0"

# PGPOOL
IMG_NAME_POOL="pgpool/pgpool:latest"



# ==============================================================================
# DECLARACION DE RUTAS BALANCEADOR
# ==============================================================================
# PROMETHEUS
IMAGE_PATH_PROMETHEUS="/core/prometheus/images/prom-prometheus-v3.12.0.tar"

# ARGUS
IMAGE_PATH_ARGUS="/balancer/nginx/simf/argus/api/argus_api_v7_1_7_8.tar"

# MINIO
IMAGE_PATH_MINIO="/core/loki/images/minio-sha14cea498d.tar"

#LOKI
IMAGE_PATH_LOKI="/core/loki/images/grafana-loki-3.7.2.tar"

#GRAFANA
IMAGE_PATH_GRAFANA="/metrics/grafana/images/grafana-sycomv7_v1_12_4_4.tar"

# ALERTMANAGER
IMAGE_PATH_ALERT="/metrics/alertmanager/alertmanager-sycomv7_v1_0_0.tar"

# POOL-EXPORTER
IMAGE_PATH_POOLEXPORTER="/metrics/pool-exporter/pgpool-exporter.tar"

# KAFKA-EXPORTER
IMAGE_PATH_KAFKA_EXPORTER="/metrics/alloy/kafka-exporter-v1.9.0.tar"


# ==============================================================================
# DECLARACION DE BINARIOS BALANCEADOR
# ==============================================================================
# PROMETHUS
IMG_NAME_PROMETHEUS="prom/prometheus:v3.12.0"

# ARGUS
IMG_NAME_ARGUS="argus_api_v7:1.7.8"

# LOKI
IMG_NAME_LOKI="grafana/loki:3.7.2"

# MINIO
IMG_NAME_MINIO="minio/minio:latest"

# GRAFANA
IMG_NAME_GRAFANA="grafana/grafana:12.4.4-ubuntu"

# ALERTMANAGER
IMG_NAME_ALERT="projectsintel/alertmanager-simf-v7:1.0.0.1"

# POOL-EXPORTER
IMG_NAME_POOLEXPORTER="pgpool/pgpool2_exporter:latest"

# NAME-KAFKA-EXPORTER
IMAGE_NAME_KAFKA_EXPORTER="danielqsj/kafka-exporter:v1.9.0"


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


binaries_postgres_and_exporter(){

    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}  INYECTANDO BINARIOS DE LA FASE: 1 (POSTGRES)                     ${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

   # --- CARGA DE IMÁGENES BD ---
    log_info -e "\n${BOLD}[Componente: Database Engine]${COLOR_RESET}"
    if [[ -z "$(sudo docker images -q $IMG_NAME_PG_P 2> /dev/null)" ]]; then
        log_warning "Imagenes parciales o ausentes. Iniciando carga..."

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

    # carga de imagen para postgres-exporter
    if [[ -z "$(sudo docker images -q $IMG_NAME_PG_EXPORTER 2> /dev/null)" ]]; then
        log_warning "Imagenes parciales o ausentes. Iniciando carga..."


        if [ -f "$IMAGE_PATH_PG_EXPORTER" ]; then
            echo -n "   Cargando imagen de réplica ($IMG_NAME_PG_EXPORTER)..."
            sudo docker load -i "$IMAGE_PATH_PG_EXPORTER" > /dev/null 2>&1 &
            spinner $!
        else 
            log_error "Archivo no localizado en la ruta: $IMAGE_PATH_PG_EXPORTER"
            exit 1
        fi
    else 
        log_success "La imagen $IMG_NAME_PG_EXPORTER ya se encuentra en el host."
    fi

    log_success "Binarios cargados con exito"
    log_info "NOTA: si la imagen no se renderiza al aplicar el filtro es por que no se cargo"
    sudo docker images | grep -E "$IMG_NAME_PG_P|$IMG_NAME_PG_R|$IMG_NAME_PG_EXPORTER"

}

binaries_pgagent(){

    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}  INYECTANDO BINARIOS DE LA FASE: 2 (PGAGENT)                     ${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"


    if [[ -z "$(sudo docker images -q $IMG_NAME_PGAGENT 2> /dev/null)" ]]; then
        log_warning "Imagenes parciales o ausentes. Iniciando carga..."

        if [ -f "$IMAGE_PATH_PGAGENT" ]; then 
            echo -n "   Cargando imagen de pgagent ($IMG_NAME_PGAGENT)..."
            sudo docker load -i "$IMAGE_PATH_PGAGENT" > /dev/null 2>&1 &
            spinner $!
        else 
            log_error "Archivo no localizado en la ruta: $IMAGE_PATH_PGAGENT"
            exit 1
        fi
    else 
        log_success "La imagen $IMG_NAME_PGAGENT ya existe en el host."
    fi 

    log_success "Binarios cargados con exito"
    log_info "NOTA:si la imagen no se renderiza al aplicar el filtro es por que no se cargo"
    sudo docker images | grep "$IMG_NAME_PGAGENT"
}

binaries_kafkita(){

    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}  INYECTANDO BINARIOS DE LA FASE: 3 (KAFKITA)                     ${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"


    if [[ -z "$(sudo docker images -q $IMG_NAME_KAFKA 2> /dev/null)" ]]; then 
        log_warning "Imagenes parciales o ausentes. Iniciando carga..."
        
        if [ -f "$IMAGE_PATH_KAFKA" ]; then 
            echo -n "Cargando imagen de Kafka ($IMG_NAME_KAFKA)..."
            sudo docker load -i "$IMAGE_PATH_KAFKA" > /dev/null 2>&1 &
            spinner $!
        else 
            log_error "Archivo no localizado en la ruta: $IMAGE_PATH_KAFKA"
            exit 1
        fi
    else 
        log_success "La imagen $IMG_NAME_KAFKA ya existe en el host."
    fi 
    
    log_success "Binarios cargados con exito"
    log_info "NOTA: si la imagen no se renderiza al aplicar el filtro es por que no se cargo"
    sudo docker images | grep "$IMG_NAME_KAFKA"
}

binaries_simf(){

    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}  INYECTANDO BINARIOS DE LA FASE: 4 (SIMF)                     ${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

     if [[ -z "$(sudo docker images -q $IMG_NAME_SIMF_REST 2> /dev/null)" || -z "$(sudo docker images -q $IMG_NAME_SIMF_MS 2> /dev/null)" ]]; then 
        log_warning "Imagenes parciales o ausentes. Iniciando carga..."

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
    else 
        log_success "Las imágenes del ecosistema SIMF ya están sincronizadas."
    fi 

    log_success "Binarios cargados con exito"
    log_info "NOTA: si la imagen no se renderiza al aplicar el filtro es por que no se cargo"
    sudo docker images | grep -E "$IMG_NAME_SIMF_MS|$IMG_NAME_SIMF_REST"

}

binaries_sglpar(){
    
    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}  INYECTANDO BINARIOS DE LA FASE: 5 (SGLPAR)                     ${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

    if [[ -z "$(sudo docker images -q $IMG_NAME_SGLPAR_REST 2> /dev/null)" || -z "$(sudo docker images -q $IMG_NAME_SGLPAR_MS 2> /dev/null)" ]]; then 
        log_warning "Imagenes parciales o ausentes. Iniciando carga..."

        if [ -f "$IMAGE_PATH_SGLPAR_REST" ] && [ -f "$IMAGE_PATH_SGLPAR_MS" ]; then
            echo -n "   Cargando paquete REST API ($IMAGE_PATH_SGLPAR_REST)..."
            sudo docker load -i "$IMAGE_PATH_SGLPAR_REST" > /dev/null 2>&1 &
            spinner $!

            echo -n "   Cargando paquete Microservicios ($IMAGE_PATH_SGLPAR_REST)..."
            sudo docker load -i "$IMAGE_PATH_SGLPAR_MS" > /dev/null 2>&1 &
            spinner $!
        else 
            log_error "Falta uno o ambos archivos de distribución .tar en la ruta."            
            exit 1
        fi
    else 
        log_success "Las imágenes del ecosistema SGLPAR ya están sincronizadas."
    fi 

    log_success "Binarios cargados con exito"
    log_info "NOTA: si la imagen no se renderiza al aplicar el filtro es por que no se cargo"
    sudo docker images | grep -E "$IMG_NAME_SGLPAR_REST|$IMG_NAME_SGLPAR_MS"

}

binaries_metrics(){

    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}  INYECTANDO BINARIOS UNIVERSALES FASE: METRICS                     ${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

    log_info "INICIANDO CARGA DE GRAFANA-ALLOY"

    if [[ -z "$(sudo docker images -q "$IMG_NAME_ALLOY" 2>/dev/null)" ]]; then
        log_warning "La imagen esta ausente en el host. Verificando distribucion..."

        if [ -f "$IMAGE_PATH_ALLOY" ]; then
            echo -n "   Cargando Grafana Alloy ($IMG_NAME_ALLOY)..."
            sudo docker load -i "$IMAGE_PATH_ALLOY" > /dev/null 2>&1 &
            spinner $!
        else
            log_error "Archivo critico ausente: $IMAGE_PATH_ALLOY"
            exit 1
        fi
    else
          log_success "Las imagenes del ecosistema alloy ya estan sincronizadas."
    fi

    log_info "INICIANDO CARGA DEL DISCOVERY"

    if [[ -z "$(sudo docker images -q "$IMG_NAME_DISCOVERY" 2>/dev/null)" ]]; then
        log_warning "La imagen esta ausente en el host. Verificando distribución..."
        if [ -f "$IMAGE_PATH_DISCOVERY" ]; then
            echo -n "   Cargando Service Discovery API ($IMG_NAME_DISCOVERY)..."
            sudo docker load -i "$IMAGE_PATH_DISCOVERY" > /dev/null 2>&1 &
            spinner $!
        else
            log_error "Archivo crítico ausente: $IMAGE_PATH_DISCOVERY"
            exit 1
        fi
    else
        log_success "Service Discovery API ya se encuentra en el caché del sistema."
    fi
    
    log_success "Binarios cargados con exito"
    log_info "NOTA: si la imagen no se renderiza al aplicar el filtro es por que no se cargo"
    sudo docker images | grep -E "$IMG_NAME_ALLOY|$IMG_NAME_DISCOVERY"

}


binaries_nginx(){

    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}  INYECTANDO BINARIOS DE LA FASE: 1 NGINX                     ${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

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

    if [[ -z "$(sudo docker image -q $IMG_NAME_NGINX_EXPORTER 2> /dev/null)" ]]; then
        log_info "La imagen no existe en este nodo, verificando (.tar)"
        if [ -f "$IMAGE_PATH_NGINX_EXPORTER" ]; then
            log_warning "Cargando Imagen" 
            sudo docker load -i "$IMAGE_PATH_NGINX_EXPORTER" > /dev/null 2>&1 &
            spinner $!
        else
            log_error "[Error]: No fue localizada la imagen en la ruta especificada $IMAGE_PATH_NGINX"
        fi
    else 
        log_info "La imagen ($IMG_NAME_NGINX_EXPORTER) ya existe, Omitiendo este paso..."
    fi

    log_success "Binarios cargados con exito"
    log_info "NOTA: si la imagen no se renderiza al aplicar el filtro es por que no se cargo"
    sudo docker images | grep -E "$IMG_NAME_NGINX|$IMG_NAME_NGINX_EXPORTER"
}

binaries_pool(){
    
    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}  INYECTANDO BINARIOS DE LA FASE: 2 POOL                     ${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"


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
   
    log_success "Binarios cargados con exito"
    log_info "NOTA: si la imagen no se renderiza al aplicar el filtro es por que no se cargo"
    sudo docker images | grep "$IMG_NAME_POOL"

}

binaries_prometheus(){

    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}  INYECTANDO BINARIOS DE LA FASE: 1 PROMETHEUS                     ${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

    if [[ -z "$(sudo docker image -q "$IMG_NAME_PROMETHEUS" 2> /dev/null)" ]]; then
        log_info "La imagen no existe en este nodo, verificando (.tar)"
        if [ -f "$IMAGE_PATH_PROMETHEUS" ]; then
            log_warning "Cargando Imagen..." 
            sudo docker load -i "$IMAGE_PATH_PROMETHEUS" > /dev/null 2>&1 &
            spinner $!
        
        else
            log_error "[Error]: No fue localizada la imagen en la ruta especificada $IMAGE_PATH_PROMETHEUS"
            press_to_continue
            exit 1
        fi
    else 
        log_info "La imagen ($IMG_NAME_PROMETHEUS) ya existe, Omitiendo este paso..."
    fi

    log_success "Binarios cargados con exito"
    log_info "NOTA: si la imagen no se renderiza al aplicar el filtro es por que no se cargo"
    sudo docker images | grep "$IMG_NAME_PROMETHEUS"
}

binaries_loki(){

    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}  INYECTANDO BINARIOS DE LA FASE: 2 LOKI                     ${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

    if [[ -z "$(sudo docker images -q $IMG_NAME_LOKI 2> /dev/null)" || -z "$(sudo docker images -q $IMG_NAME_MINIO 2> /dev/null)" ]]; then
        log_info "Las imagenes no existe en este nodo, verificando binarios (.tar)"
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


    log_success "Binarios cargados con exito"
    log_info "NOTA: si la imagen no se renderiza al aplicar el filtro es por que no se cargo"
    sudo docker images | grep -E "$IMG_NAME_LOKI|$IMG_NAME_MINIO"
}

binaries_grafana(){

    echo -e "\n${NEON_GREEN}${BOLD}==================================================================${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}  INYECTANDO BINARIOS DE LA FASE: 3 GRAFANA                      ${COLOR_RESET}"
    echo -e "${NEON_GREEN}${BOLD}====================================================================${COLOR_RESET}"

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

    log_success "Binarios cargados con exito"
    log_info "NOTA: si la imagen no se renderiza al aplicar el filtro es por que no se cargo"
    sudo docker images | grep "$IMG_NAME_GRAFANA"
}

binaries_pool_exporter(){
    
    echo -e "\n${NEON_GREEN}${BOLD}==================================================================${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}  INYECTANDO BINARIOS DE LA FASE: 4 POOL-EXPORTER                      ${COLOR_RESET}"
    echo -e "${NEON_GREEN}${BOLD}====================================================================${COLOR_RESET}"

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

    log_success "Binarios cargados con exito"
    log_info "NOTA: si la imagen no se renderiza al aplicar el filtro es por que no se cargo"
    sudo docker images | grep "$IMG_NAME_POOLEXPORTER"
}

binaries_alertmanager(){

    echo -e "\n${NEON_GREEN}${BOLD}==================================================================${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}  INYECTANDO BINARIOS DE LA FASE: 5 ALERTMANAGER                      ${COLOR_RESET}"
    echo -e "${NEON_GREEN}${BOLD}====================================================================${COLOR_RESET}"

    if [[ -z "$(sudo docker image -q $IMG_NAME_ALERT 2> /dev/null)" ]]; then
        log_info "La imagen no existe en este nodo, verificando paqueteria"
        if [ -f "$IMAGE_PATH_ALERT" ]; then
            log_warning "Cargando Imagen..." 
            sudo docker load -i "$IMAGE_PATH_ALERT" > /dev/null 2>&1 &
            spinner $!
        else
            log_error "[Error]: No fue localizada la imagen (.tar) en la ruta especificada $IMAGE_PATH_ALERT"
        fi
    else 
        log_info "La imagen ($IMG_NAME_ALERT) ya existe, Omitiendo este paso..."
    fi

    log_success "Binarios cargados con exito"
    log_info "NOTA: si la imagen no se renderiza al aplicar el filtro es por que no se cargo"
    sudo docker images | grep "$IMG_NAME_ALERT"
}

binaries_argus(){

    echo -e "\n${NEON_GREEN}${BOLD}==================================================================${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}  INYECTANDO BINARIOS DE LA FASE: 6 ARGUS                            ${COLOR_RESET}"
    echo -e "${NEON_GREEN}${BOLD}====================================================================${COLOR_RESET}"

    if [[ -z "$(sudo docker image -q "$IMG_NAME_ARGUS" 2> /dev/null)" ]]; then 
        log_info "La imagen no existe en este nodo, verificando la existencia del .tar"
        
        if [ -n "$IMAGE_PATH_ARGUS" ] && [ -f "$IMAGE_PATH_ARGUS" ]; then 
            log_warning "Cargando imagen..."
            sudo docker load -i "$IMAGE_PATH_ARGUS" > /dev/null 2>&1 &
            spinner $!
        else 
            log_error "[Error]: No fue localizada la imagen (.tar) en la ruta especificada: '${IMAGE_PATH_ARGUS:-[RUTA VACÍA]}'"
            exit 1
        fi
    else 
        log_info "La imagen ($IMG_NAME_ARGUS) ya existe, Omitiendo este paso..."
    fi 

    log_success "Binarios cargados con exito"
    log_info "NOTA: si la imagen no se renderiza al aplicar el filtro es por que no se cargo"
    sudo docker images | grep "$IMG_NAME_ARGUS"

}

binaries_kafkita_exporter(){

    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}  INYECTANDO BINARIOS DE LA FASE: 7 KAFKA-EXPORTER                 ${COLOR_RESET}"
    echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"


    if [[ -z "$(sudo docker image -q $IMAGE_NAME_KAFKA_EXPORTER 2> /dev/null)" ]]; then
        log_info "La imagen no existe en este nodo, verificando (.tar)"
        if [ -f "$IMAGE_PATH_KAFKA_EXPORTER" ]; then
            log_warning "Cargando Imagen" 
            sudo docker load -i "$IMAGE_PATH_KAFKA_EXPORTER" > /dev/null 2>&1 &
            spinner $!
        else
            log_error "[Error]: No fue localizada la imagen en la ruta especificada $IMAGE_NAME_KAFKA_EXPORTER"
        fi
    else 
        log_info "La imagen ($IMAGE_NAME_KAFKA_EXPORTER) ya existe, Omitiendo este paso..."
    fi

    log_success "Binarios cargados con exito"
    log_info "NOTA: si la imagen no se renderiza al aplicar el filtro es por que no se cargo"
    sudo docker images | grep "$IMAGE_NAME_KAFKA_EXPORTER"
}




$@

