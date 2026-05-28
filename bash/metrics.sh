#!/bin/bash

# Instalacion automatizada para la integracion de observabilidad en el cluster

# definicion de los puntos de montaje
$MOUNT_METRICS="/metrics/Observ"

# definicion de imagenes
$IMAGE_PATH_ALLOY="alloy.tar"
$IMG_NAME_ALLOY="grafana/alloy:v1.16.1"

echo "--- script de instalaccion automatizado valido para los servidores de negocio ---"


    echo -e "\n[+] Iniciando flujo de instalacion Metricas..."
            
    # flujo de validacion
    echo "==============================================================================================="
    echo "\nMI BRO, ANTES DE INICIAR VOY A REALIZAR UN SCANNER DEL AMBIEN PARA VERIFICAR EL ESTADO ACTUAL"
    echo "==============================================================================================="
    
    echo "\n[--] Verificando el punto de montaje y paqueteria de Observ/alloy"

    