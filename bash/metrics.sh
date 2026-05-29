#!/bin/bash

# definicion de los puntos de montaje 
MOUNT_METRICS="/metrics/"

# definicion de imagenes
IMAGE_PATH_ALLOY="/metrics/Observ/alloy.tar"
IMG_NAME_ALLOY="grafana/alloy:v1.16.1"

IMAGE_PATH_DISCOVERY="/metrics/service_discovery/discovery-api.tar" 
IMG_NAME_DISCOVERY="discovery-api:latest"

echo "--- script de configuracion automatica (validacion y carga de imagenes) ---"
echo -e "\n[+] Iniciando flujo de instalación Agentes exporters..."
        
echo "======================================================================================================"
echo -e "\nMI BRO, ANTES DE INICIAR VOY A REALIZAR UN SCANNER DEL AMBIENTE PARA VERIFICAR EL ESTADO ACTUAL"
echo "======================================================================================================"

echo -e "\n[--] Verificando el punto de montaje y paquetería de Observ/alloy"

# Validacion del punto de montaje
if [ -d "$MOUNT_METRICS" ]; then
    echo "El punto de montaje y la paqueteria fueron detectados"
    echo -e "\n--------------------------------------------------------------------"
            
    echo -e "\n[+] Verificando existencia de imagenes en Docker..."
    
    # validacion de imagenes
    if [[ -z "$(sudo docker images -q $IMG_NAME_ALLOY 2>/dev/null)" || -z "$(sudo docker images -q $IMG_NAME_DISCOVERY 2>/dev/null)" ]]; then 
        echo "Al menos una de las imagenes no existe. Iniciando el proceso de Carga..."
        
        # Validamos que ambos archivos .tar existan en el disco antes de cargar
        if [ -f "$IMAGE_PATH_ALLOY" ] && [ -f "$IMAGE_PATH_DISCOVERY" ]; then
            echo "[->] Cargando Alloy..."
            sudo docker load -i "$IMAGE_PATH_ALLOY"
            
            echo "[->] Cargando Discovery..."
            sudo docker load -i "$IMAGE_PATH_DISCOVERY"
        else 
            echo "Error: Uno o ambas imagenes no fueron localizados en las rutas especificadas."
            exit 1
        fi
    else 
        echo "Las imagenes ($IMG_NAME_ALLOY y $IMG_NAME_DISCOVERY) ya existen en el sistema. Omitiendo carga."
    fi

    echo "============================================================================================================================"
    echo -e "\n[+] Proceso de configuracion para (Observabilidad) finalizado, el deploy esta reservado para el bash de Observabilidad"
    echo "============================================================================================================================"

else 
    echo "Error: El punto de montaje no fue encontrado: $MOUNT_METRICS"
    exit 1
fi