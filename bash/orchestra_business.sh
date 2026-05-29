#!/bin/bash

# ORQUESTADOP DE NEGOCIO 


  # Despliegue BD-SIMF
                echo "===================================================="
                echo "\n[+] Iniciando el despliegue de PG_REPLICA"
                if [ -f "/app_psql/bd-simf/primary-stack.yml" ]; then 
                    sudo docker stack deploy -c /app_psql/packague_bd/replica-stack.yml pg_replica
                    sudo docker stack ps --no-trunc pg_replica
                else 
                    echo "\nEl stack no esta en la ruta especificada"
                    exit 1
                fi 