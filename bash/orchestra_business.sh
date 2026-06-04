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
# FLUJO PRINCIPAL - ORQUESTADOR
# ==============================================================================
clear
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}  ORQUESTADOR CENTRAL DE DESPLIEGUE - CLUSTER DE NEGOCIO           ${COLOR_RESET}"
echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"

while true; do 
    echo -e "\n${BOLD}MENÚ DE ORQUESTACIÓN Y DESPLIEGUE:${COLOR_RESET}"
    echo -e "  ${DEEP_BLUE}1)${COLOR_RESET} Lanzar Stack PostgreSQL (Modo Réplica)"
    echo -e "  ${DEEP_BLUE}2)${COLOR_RESET} Lanzar Stack Pgagent (Pgagent)"
    echo -e "  ${DEEP_BLUE}3)${COLOR_RESET} Lanzar Stack kafka(Cluster Kafka)"
    echo -e "  ${DEEP_BLUE}4)${COLOR_RESET} Lanzar Stack MS (SIMF)"
    echo -e "  ${DEEP_BLUE}5)${COLOR_RESET} Lanzar Stack MS (SGLPAR)"
    echo -e "  ${DEEP_BLUE}6)${COLOR_RESET} Lanzamiento Global Secuencial (Pipeline Automatizado)"
    echo -e "  ${DEEP_BLUE}7)${COLOR_RESET} Salir del Orquestador"
    echo -e "${DEEP_BLUE}------------------------------------------------------------------${COLOR_RESET}"

    read -p "Seleccione una opción de control (1-7): " opcion

    case $opcion in 
        1)
            clear
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}  INICIALIZANDO COMPONENTE: POSTGRESQL REPLICA                     ${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            
            if [ -f "/app_psql/packague_bd/stack/replica-stack.yml" ]; then 
                log_info "Desplegando topología en Swarm..."
                sudo docker stack deploy -c /app_psql/packague_bd/stack/replica-stack.yml pg_replica
                echo -e "\n${BOLD}[Estado actual del Stack 'pg_replica']${COLOR_RESET}"
                sudo docker stack ps --no-trunc pg_replica | head -n 6
            else 
                log_error "El manifiesto 'replica-stack.yml' no se encontró en la ruta especificada."
                exit 1
            fi
            
            log_warning "Enganchando stdout al streaming de logs en tiempo real..."
            log_info "Presione [Ctrl + C] para salir del visor de logs. El servicio continuará corriendo."
            echo -e "${DEEP_BLUE}------------------------------------------------------------------${COLOR_RESET}\n"
            sleep 2

            countdown 60 "Estabilizando la replica"

            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            log_success "VERIFICACION DE LA REPLICA"
            
            log_info "VERIFICANDO EL ESTADO DE LA BD"
            PGPASSWORD='simf' psql -h localhost -p 5445 -U simf_admin_user -d simf -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'REPLICA (Standby - Solo Lectura)' ELSE 'PRINCIPAL (Primary - Lectura y Escritura)' END AS rol_servidor;"


            sudo docker service logs -f pg_replica_replica
            break
            ;;
        

        2) 
            clear
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}  INICIALIZANDO COMPONENTE: PGAGENT                               ${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            
            if [ -f "/app_psql/pgagent/pgagent-stack.yml" ]; then 
                log_info "Desplegando servicio en Swarm..."
                sudo docker stack deploy -c /app_psql/pgagent/pgagent-stack.yml pgagent
                echo -e "\n${BOLD}[Estado actual del Stack 'pgagent']${COLOR_RESET}"
                sudo docker stack ps --no-trunc pgagent | head -n 6
            else 
                log_error "El manifiesto 'pgagent-stack.yml' no se encontró en la ruta especificada."
                exit 1
            fi
            
            log_warning "Enganchando stdout al streaming de logs en tiempo real..."
            log_info "Presione [Ctrl + C] para salir del visor de logs. El servicio continuará corriendo."
            echo -e "${DEEP_BLUE}------------------------------------------------------------------${COLOR_RESET}\n"
            sleep 2
            sudo docker service logs -f pgagent_pgagent
            break
            ;;


        3)
            clear
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}  INICIALIZANDO COMPONENTE: DISTRIBUTED KAFKA CLUSTER              ${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            
            if [ -f "/kafka/kafka/stack/kafka.yml" ]; then 
                log_info "Desplegando topología en Swarm..."
                sudo docker stack deploy -c /kafka/kafka/stack/kafka.yml kafka
                echo -e "\n${BOLD}[Estado actual del Stack 'kafka']${COLOR_RESET}"
                sudo docker stack ps --no-trunc kafka | head -n 6
            else 
                log_error "El manifiesto 'kafka.yml' no se encontró en la ruta especificada."
                exit 1
            fi
            
            log_warning "Enganchando stdout al streaming de logs en tiempo real..."
            log_info "Presione [Ctrl + C] para salir del visor de logs. El servicio continuará corriendo."
            echo -e "${DEEP_BLUE}------------------------------------------------------------------${COLOR_RESET}\n"
            sleep 2
            sudo docker service logs -f kafka_kafka1
            break
            ;;

        4)
            clear
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}  INICIALIZANDO COMPONENTE: MICROSERVICIOS CORE (SIMF)            ${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            
            if [ -f "/app_services/app_simf/stack-simf.yml" ]; then 
                log_info "Desplegando topología en Swarm..."
                sudo docker stack deploy -c /app_services/app_simf/stack-simf.yml simf
                echo -e "\n${BOLD}[Estado actual del Stack 'simf']${COLOR_RESET}"
                sudo docker stack ps --no-trunc simf | head -n 6
            else 
                log_error "El manifiesto 'stack-simf.yml' no se encontró en la ruta especificada."
                exit 1
            fi
            
            log_warning "Enganchando stdout al streaming de logs en tiempo real..."
            log_info "Presione [Ctrl + C] para salir del visor de logs. El servicio continuará corriendo."
            echo -e "${DEEP_BLUE}------------------------------------------------------------------${COLOR_RESET}\n"
            sleep 2
            sudo docker service logs -f simf_rest_api
            break
            ;;


        5) 
            clear
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}  INICIALIZANDO COMPONENTE: SGLPAR                                ${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            
            if [ -f "/app_services/app_sglpar/stack-sglpar.yml" ]; then 
                log_info "Desplegando servicio en Swarm..."
                sudo docker stack deploy -c /app_services/app_sglpar/stack-sglpar.yml sglpar
                echo -e "\n${BOLD}[Estado actual del Stack 'pgagent']${COLOR_RESET}"
                sudo docker stack ps --no-trunc sglpar | head -n 6
            else 
                log_error "El manifiesto 'stack-sglpar.yml' no se encontró en la ruta especificada."
                exit 1
            fi
            
            log_warning "Enganchando stdout al streaming de logs en tiempo real..."
            log_info "Presione [Ctrl + C] para salir del visor de logs. El servicio continuará corriendo."
            echo -e "${DEEP_BLUE}------------------------------------------------------------------${COLOR_RESET}\n"
            sleep 2
            sudo docker service logs -f sglpar_rest_api
            break
            ;;

        6)
            clear
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}  PIPELINE DE DESPLIEGUE GLOBAL (SECUENCIAL AUTOMATIZADO)          ${COLOR_RESET}"
            echo -e "${DEEP_BLUE}${BOLD}==================================================================${COLOR_RESET}"
            
            # --- STEP 1: DATABASE REPLICA ---
            log_info "[Paso 1/5] Lanzando Base de Datos Réplica..."
            if [ -f "/app_psql/packague_bd/stack/replica-stack.yml" ]; then 
                sudo docker stack deploy -c /app_psql/packague_bd/stack/replica-stack.yml pg_replica > /dev/null
                log_success "Instrucción de despliegue enviada a la API de Swarm."
            else 
                log_error "Manifiesto crítico ausente: 'replica-stack.yml'"
                exit 1
            fi
            
            countdown 60 "Estabilizando la replica"
            echo -e "\n${BOLD} Verificando replica):${COLOR_RESET}"
            sudo docker stack ps pg_replica ndoo-trunc | head -n 4
            echo -e "${DEEP_BLUE}------------------------------------------------------------------${COLOR_RESET}"

            
            # --- STEP 2: PGAGENT BROKERS ---
            log_info "[Paso 2/5] Lanzando Clúster Distribuido de pgagent..."        
            if [ -f "/app_psql/pgagent/pgagent-stack.yml" ]; then 
                sudo docker stack deploy -c /app_psql/pgagent/pgagent-stack.yml pgagent
                log_success "Instrucción de despliegue enviada a la API de Swarm."
            else 
                log_error "El manifiesto 'pgagent-stack.yml' no se encontró en la ruta especificada."
                exit 1
            fi
            
            countdown 30 "Estabilizando servicio e inicializando PGAGENT"
            echo -e "\n${BOLD} Verificación de salud (PGAGENT):${COLOR_RESET}"
            sudo docker stack ps pgagent --no-trunc | head -n 4
            echo -e "${DEEP_BLUE}------------------------------------------------------------------${COLOR_RESET}"


            # --- STEP 3: KAFKA BROKERS ---
            log_info "[Paso 3/5] Lanzando Clúster Distribuido de Kafka..."
            if [ -f "/kafka/kafka/stack/kafka.yml" ]; then 
                sudo docker stack deploy -c /kafka/kafka/stack/kafka.yml kafka > /dev/null
                log_success "Instrucción de despliegue enviada a la API de Swarm."
            else 
                log_error "Manifiesto crítico ausente: 'kafka.yml'"
                exit 1
            fi
            
            countdown 30 "Sincronizando la topología y cuórum de Brokers (Zookeeper/Kafka)"
            echo -e "\n${BOLD} Verificación de salud (Kafka Cluster):${COLOR_RESET}"
            sudo docker stack ps kafka --no-trunc | head -n 4
            echo -e "${DEEP_BLUE}------------------------------------------------------------------${COLOR_RESET}"

            # --- STEP 4: CORE MICROSERVICES ---
            log_info "[Paso 4/5] Lanzando Ecosistema de Microservicios (SIMF)..."
            if [ -f "/app_services/app_simf/stack-simf.yml" ]; then 
                sudo docker stack deploy -c /app_services/app_simf/stack-simf.yml simf > /dev/null
                log_success "Instrucción de despliegue enviada a la API de Swarm."
            else 
                log_error "Manifiesto crítico ausente: 'stack-simf.yml'"
                exit 1
            fi
            
            countdown 30 "Esperando el levantamiento y self-healing de las API Rest y Workers"
            echo -e "\n${BOLD} Verificación de salud (SIMF Microservices):${COLOR_RESET}"
            sudo docker stack ps simf --no-trunc | head -n 4


            # --- STEP 5: CORE MICROSERVICES ---
            log_info "[Paso 5/5] Lanzando Ecosistema de Microservicios (SIMF)..."
            if [ -f "/app_services/app_sglpar/stack-sglpar.yml" ]; then 
                sudo docker stack deploy -c /app_services/app_sglpar/stack-sglpar.yml sglpar > /dev/null
                log_success "Instrucción de despliegue enviada a la API de Swarm."
            else 
                log_error "Manifiesto crítico ausente: 'stack-sglpar.yml'"
                exit 1
            fi
            
            countdown 30 "Esperando el levantamiento y self-healing de las API Rest y Workers"
            echo -e "\n${BOLD} Verificación de salud (SGLPAR Microservices):${COLOR_RESET}"
            sudo docker stack ps sglpar --no-trunc | head -n 4


            # --- RESUMEN DE ENTREGA ---
            echo -e "\n${NEON_GREEN}${BOLD}==================================================================${COLOR_RESET}"
            echo -e "${NEON_GREEN}${BOLD}  Pipeline Ejecutado: DESPLIEGUE GLOBAL EXITOSO                   ${COLOR_RESET}"
            echo -e "${NEON_GREEN}${BOLD}==================================================================${COLOR_RESET}"
            log_info "A continuación se renderiza el estado global de servicios activos:"
            echo -e "${DEEP_BLUE}------------------------------------------------------------------${COLOR_RESET}"
            sudo docker service ls
            break
            ;;
            
        
        7)      
            echo -e "\n${CRIMSON_RED}➔ Desconectando del Gestor de Swarm. Saliendo del flujo de orquestación. ¡Adiós Papu!${COLOR_RESET}"
            exit 0 
            ;;
        
        *)
            log_error "'$opcion' no es una directiva válida de orquestación. Intente de nuevo.\n"
            ;;
    esac
done