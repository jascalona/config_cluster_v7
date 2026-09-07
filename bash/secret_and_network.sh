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
# NODOS
# ==============================================================================
BUSINESS_01="vasldiccs060"
BUSINESS_02="vasldiccs061"
BUSINESS_03="vasldiccs062"



# VARIABLES DE ENTORNO
NAME_POSTGRES="postgre_password"
NAME_PGAGENT="pgagent_pass"

echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}  INICIALIZANDO CONFIGURACION DE SECRET                           ${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"


 # ---INYECCION DE SECRET ---
    log_info "Validando Persistencia del secret en el cluster ($NAME_POSTGRES)..."
    if sudo docker secret inspect "$NAME_POSTGRES" >/dev/null 2>&1; then
        log_success "Secret existente en el clúster. Omitiendo creación."
    else 
        log_warning "Secret no detectado. Iniciando inyección..."
        sudo printf '%s\n' '*:9997:*:postgres:PO$tgr3$.BD' '*:9997:*:simf_admin_user:simf' | sudo docker secret create "$NAME_POSTGRES" -
                    
        if sudo docker secret inspect "$NAME_POSTGRES" > /dev/null 2>&1; then
            log_success "Secret '$NAME_POSTGRES' creado exitosamente."
        else
            log_error "Error crítico al crear el secreto '$NAME_POSTGRES'."
            exit 1
        fi
    fi

    log_info "Validando Persistencia del secret en el cluster (pgagent_pass)..."
    if sudo docker secret inspect pgagent_pass >/dev/null 2>&1; then
        log_success "Secret existente en el clúster. Omitiendo creación."
    else 
        log_warning "Secret no detectado. Iniciando inyección..."
        sudo printf '%s\n' '*:9997:*:postgres:PO$tgr3$.BD' '*:9997:*:simf_admin_user:simf'| sudo docker secret create pgagent_pass -
                    
        if sudo docker secret inspect pgagent_pass > /dev/null 2>&1; then
            log_success "Secret 'pgagent_pass' creado exitosamente."
        else
            log_error "Error crítico al crear el secreto 'pgagent_pass'."
            exit 1
        fi
    fi



    log_success "RENDERIZANDO LISTA DE SECRET"
    sudo docker secret ls

echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}  INICIALIZANDO CONFIGURACION DE REDES                           ${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"


    # CONFIGURACION DE LA RED PG_NET
    echo "-----------------------------------------------------------------------------"
    log_info "INCIANDO CONFIGURACION DE REDES DE POSTGRES"
    echo "-----------------------------------------------------------------------------"
    log_info "Escaneando infraestructura de red del clúster (pg_net)..."
    if sudo docker network inspect pg_net >/dev/null 2>&1; then
        log_success "Red overlay 'pg_net' detectada."
    else
        log_warning "Red 'pg_net' ausente. Creando topología overlay..."
        sudo docker network create --driver overlay --subnet 10.0.10.0/24 --gateway 10.0.10.1 --opt com.docker.network.driver.mtu=1450 --attachable pg_net
        log_success "Red superpuesta distribuida creada correctamente."
    fi  

    # CONFIGURACION DE LA MONITORING
    log_info "Validando infraestructura de red para telemetría y monitoreo..."
    if sudo docker network inspect monitoring >/dev/null 2>&1; then
        log_success "Red overlay 'monitoring' activa."
    else
        log_warning "Red 'monitoring' ausente. Creando segmento de red..."
        sudo docker network create --driver overlay monitoring > /dev/null
        log_success "Red superpuesta de monitoreo aislada correctamente."
    fi  

    # CONFIGURACION DE NGINX_SIMF
    log_info "Escaneando infraestructura balanceadora perimetral (nginx_lbnet)..."
    if sudo docker network inspect nginx_lbnet >/dev/null 2>&1; then
        log_success "Red balanceadora 'nginx_lbnet' existente."
    else
        log_warning "Red perimetral ausente. Creando red del balanceador..."
        sudo docker network create --driver overlay nginx_lbnet > /dev/null
        log_success "Segmentación perimetral configurada."
    fi  

    log_success "RENDERIZANDO LISTA DE REDES"
    sudo docker network ls

echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}  INICIALIZANDO PARSEO DE LABELS                                 ${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

    log_info "Inyectanddo etiquetas (Labels) en los nodos de negocio"
    sudo docker node update --label-add pg_role=primary "$BUSINESS_01" > /dev/null
    sudo docker node update --label-add pg_role=replica "$BUSINESS_02" > /dev/null
    sudo docker node update --label-add pg_role=replica "$BUSINESS_03" > /dev/null
    log_success "Labels asignados a los nodos: $BUSINESS_01, $BUSINESS_02, $BUSINESS_03."

    log_info "Inyectanddo etiquetas (Labels) en nodos de negocio"
    sudo docker node update --label-add pgagent=pgagent "$BUSINESS_01" > /dev/null
    sudo docker node update --label-add pgagent=pgagent "$BUSINESS_02" > /dev/null
    sudo docker node update --label-add pgagent=pgagent "$BUSINESS_03" > /dev/null
    log_success "Labels asignados a los nodos: $BUSINESS_01, $BUSINESS_02, $BUSINESS_03."
