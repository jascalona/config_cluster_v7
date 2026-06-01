#!/bin/bash

# ORQUESTADOR DE NEGOCIO 

echo "========================================="
echo "[+] Iniciando el Orquestador de Negocio"
echo "========================================="

while true; do 

    # MENU DE OPCIONES
    echo "=============================================="
    echo "HOLA PAPU, BIENVENIDO AL MENU DE ORQUESTACION"
    echo "=============================================="
    echo "1) PARA EL DESPLIEGUE PG_ROLE (REPLICA)"
    echo "2) PARA EL DESPLIEGUE DE KAFKA"
    echo "3) PARA EL DESPLIEGUE DE LOS MS"
    echo "4) PARA EL DESPLIEGUE GLOBAL (SECUENCIAL CON PAUSAS)"
    echo "5) SALIR DEL FLUJO DE INSTALACION"
    echo "----------------------------------------------"

    read -p "Seleccione una opcion valida (1-5): " opcion

    case $opcion in 
        1)
            echo "===================================================="
            echo "[+] INICIANDO EL DESPLIEGUE DEL COMPONENTE PG_REPLICA"
            echo "===================================================="
            if [ -f "/app_psql/packague_bd/stack/replica-stack.yml" ]; then 
                sudo docker stack deploy -c /app_psql/packague_bd/stack/replica-stack.yml pg_replica
                sudo docker stack ps --no-trunc pg_replica
            else 
                echo -e "\n[x] EL STACK NO SE ENCONTRO EN LA RUTA ESPECIFICADA"
                exit 1
            fi
            echo -e "\n[+] Mostrando logs iniciales (Presione Ctrl+C si desea salir del log, el servicio seguira corriendo)..."
            sudo docker service logs -f pg_replica_replica
            break
            ;;
        
        2)
            echo "===================================================="
            echo "[+] INICIANDO EL DESPLIEGUE DEL COMPONENTE KAFKA"
            echo "===================================================="
            if [ -f "/kafka/kafka/stack/kafka.yml" ]; then 
                sudo docker stack deploy -c /kafka/kafka/stack/kafka.yml kafka
                sudo docker stack ps --no-trunc kafka
            else 
                echo -e "\n[x] EL STACK NO SE ENCONTRO EN LA RUTA ESPECIFICADA"
                exit 1
            fi
            echo -e "\n[+] Mostrando logs iniciales (Presione Ctrl+C si desea salir del log)..."
            sudo docker service logs -f kafka_kafka1
            break
            ;;

        3)
            echo "===================================================="
            echo "[+] INICIANDO EL DESPLIEGUE DEL COMPONENTE MS"
            echo "===================================================="
            if [ -f "/app_services/app_simf/stack-simfcito.yml" ]; then 
                sudo docker stack deploy -c /app_services/app_simf/stack-simfcito.yml simf
                sudo docker stack ps --no-trunc simf
            else 
                echo -e "\n[x] EL STACK NO SE ENCONTRO EN LA RUTA ESPECIFICADA"
                exit 1
            fi
            echo -e "\n[+] Mostrando logs iniciales (Presione Ctrl+C si desea salir del log)..."
            sudo docker service logs -f simf_rest_api
            break
            ;;

        4)
            echo "====================================================================="
            echo "[+] INICIANDO EL DESPLIEGUE COMPLETO (FLUJO GLOBAL CON PAUSAS DE TIEMPO)"
            echo "====================================================================="
            
            # Despliegue pg_replica 
            echo -e "\n[1/3] Desplegando Base de Datos Replica..."
            if [ -f "/app_psql/packague_bd/stack/replica-stack.yml" ]; then 
                sudo docker stack deploy -c /app_psql/packague_bd/stack/replica-stack.yml pg_replica
            else 
                echo -e "\n[x] EL STACK DE BD NO SE ENCONTRO"
                exit 1
            fi
            
            # Pausa de tiempo para estabilizacion de BD
            echo "Esperando 30 segundos para que PostgreSQL inicie y asigne TableSpaces..."
            sleep 30
            echo -e "\n[+] Estado actual de la BD:"
            sudo docker stack ps pg_replica --no-trunc | head -n 5


            # Despliegue Kafkita
            echo -e "\n[2/3] Desplegando Cluster de Kafka..."
            if [ -f "/kafka/kafka/stack/kafka.yml" ]; then 
                sudo docker stack deploy -c /kafka/kafka/stack/kafka.yml kafka
            else 
                echo -e "\n[x] EL STACK DE KAFKA NO SE ENCONTRO"
                exit 1
            fi
            
            # Pausa de tiempo para Kafka 
            echo "Esperando 30 segundos para dar estabilidad a cada Broker de kafka..."
            sleep 30
            echo -e "\n[+] Estado actual de kafka:"
            sudo docker stack ps kafka --no-trunc | head -n 5


            # Despliegue Microservicios
            echo -e "\n[3/3] Desplegando MS (SIMF)..."
            if [ -f "/app_services/app_simf/stack-simfcito.yml" ]; then 
                sudo docker stack deploy -c /app_services/app_simf/stack-simfcito.yml simf
            else 
                echo -e "\n[x] EL STACK DE MICROSERVICIOS NO SE ENCONTRO"
                exit 1
            fi
            
            echo "Esperando 10 segundos para dar estabilidad a los ms"
            sleep 30
            echo -e "\n[+] Estado actual de kafka:"
            sudo docker stack ps simf --no-trunc | head -n 5

            echo "====================================================================="
            echo -e "\n[+] DESPLIEGUE GLOBAL FINALIZADO CON EXITO"
            echo "A continuación se muestra un resumen de los servicios levantados:"
            echo "====================================================================="
            sudo docker service ls
            break
            ;;
            
        5)      
            echo -e "\n[-] Cerrando el asistente de orquestacion. ¡Adios Papu!"
            exit 0 
            ;;
        
        *)
            echo -e "\n[ERROR] '$opcion' no es una opcion valida, papu. Intentalo nuevamente.\n"
            ;;
    esac
done