# Guía de Despliegue Automatizado - Clúster de Negocio (SIMF & Kafka V7)

Este repositorio contiene la suite de scripts en Bash diseñados para automatizar la validación del entorno, la carga de imágenes `.tar`, la inyección de labels en el clúster de Docker Swarm y la orquestación secuencial de los servicios de negocio y agentes exporters.

---

## Arquitectura del Despliegue

El despliegue se divide en tres capas críticas que deben ejecutarse en un orden específico:

1. **Infraestructura de Base de Datos y Mensajería (Kafka)** en servidores principales y réplicas.
2. **Suite de Observabilidad (Grafana Alloy)** para el scraping de métricas.
3. **Orquestación Global** para el ciclo de vida de los Microservicios.

---

## Requisitos Previos Antes de Iniciar

Antes de ejecutar los scripts, asegúrate de que los puntos de montaje existan en los servidores y que los archivos `.tar` de las imágenes estén en sus respectivas rutas:

| Componente | Punto de Montaje Requerido | Archivo `.tar` Esperado |
| :--- | :--- | :--- |
| **PostgreSQL Primario** | `/app_psql/packague_bd/` | `simf-primary.tar`, `simf_replica.tar` |
| **Kafka Broker** | `/kafka/kafka/` | `images/projectsintel-kafka-simf-v7_1.0.2.tar` |
| **Microservicios (SIMF)** | `/app_services/` | `app_simf/images/simf_rest_api_0_2_2.tar` <br> `app_simf/images/simf_ms_0_2_2.tar` |
| **Observabilidad** | `/metrics/` | `Observ/alloy.tar` |


> **IMPORTANTE:** Todos los scripts deben tener permisos de ejecución. Otórgalos con el comando:
> ```bash
> chmod +x *.sh
> ```

---

## Procedimiento de Instalación (Paso a Paso)

Sigue este orden para garantizar que las dependencias de red, secret y almacenamiento se creen correctamente.

### Paso 1: Configuración de Nodos de Negocio
Ajuste el valor de los hostnames según corresponda a cada servidor dentro del script de configuración.

**Ejemplo de configuración:**
```bash
BUSINESS_01="nombre_ejemplo_01"
BUSINESS_02="nombre_ejemplo_01"
BUSINESS_03="nombre_ejemplo_01"
```

### Paso 2: Ejecute el script business.sh:
```
sudo bash business.sh
```

### Paso 3: Seleccione en el menu el tipo de configuracion correspondiente a cada servidor

IMPORTANTE: Este script es unicamente para automatizar la configuracion.
existe un orquestador que se encarga de realizar los despliegues.
```
    1) Para la Instalacion srv principal
    2) Para la Instalacion srv replica
    3) Salir del flujo de instalacion
```


### Paso 4: Despliegue de los componentes
Una vez persista la configuracion en cada broker, invoque el script orquestador
```
sudo bash orchestra_business.sh
```

---

## Configuracion de la paqueteria para los srv de negocio

### PACKAGE BD

    # packgue bd-simf & pg_replica
    /app_psql

    |--- packague_bd/
        --- creacion-bd/
        --- desinstall-bd.sh
        --- failover.sh
        --- install-bd.sh
        --- install-infra.sh
        --- orden-bd.sh
        --- pool_passwd
        --- images/
            |--- simf-primary.tar
            |--- simf_replica.tar
        --- stack/
            |--- primary-stack.yml
            |--- replica-stack.yml


### PACKAGE KAFKA

    # packgue kafka
    /kafka

    |--- kafka/
        --- data/
        --- jmx/
            |--- jmx_prometheus_javaagent-1.4.0.jar
            |--- kafka-jmx.yml
        --- images/
            |--- projectsintel-kafka-simf-v7_1.0.2.tar
        --- stack/
            |--- kafka.yml


### PACKAGE MS

    # packgue simf

    /app_services/
    |--- app_simf/
        --- stack-simfcito.yml
        --- comunes/
        --- credito/
        --- debito/
        --- rest_api/
        --- image/
            |--- simf_ms_0_2_2.tar
            |--- simf_rest_api_0_2_2.tar

    # packague sglpar
    |--- app_sglpar/
        --- stack-sglparcito.yml
        --- comunes/
        --- credito/
        --- debito/
        --- rest_api/
        --- image/
            |--- sglpar_ms_0_2_2.tar
            |--- sglpar_rest_api_0_2_2.tar


### PACKAGE METRICS

    # packgue service_discovery & alloy

    /metrics/
    |--- alloy/
        --- observability.yml
        --- config.alloy
        --- alloy.tar
        --- README.txt


    # packague sglpar
    /metrics/
    |--- service_discovery/
        --- Dockerfile
        --- discovery-api
        --- discovery-stack.yml
        --- serve-discovery.tar











````
### IGNORAR DE AQUI HACIA ABAJO, YA QUE ES UNA CONFIG DE UN LABORATORIO DE JOSE
```
### LXD Laboratorio

LXD se mantiene y distribuye oficialmente de forma universal a través de snapd. Ejecuta estos comandos en tu terminal de Fedora para instalarlo:

# 1. Instalar Snap si no lo tienes
sudo dnf install -y snapd
sudo ln -s /var/lib/snapd/snap /snap

# 2. Instalar LXD
sudo snap install lxd

# 3. Inicializar el sistema LXD (Presiona ENTER a todas las preguntas por defecto)
sudo lxd init
```

```
### Paso 2: Configurar los límites de recursos (Igual que en tu VM)

Una de las maravillas de LXD es que puedes definir los límites de CPU y memoria RAM directo por comando de forma muy sencilla al momento de crear o modificar el contenedor.

Ejecuta los siguientes comandos para descargar la imagen oficial de Ubuntu 22.04 LTS y levantar tus 3 servidores con sus respectivos recursos:

# 1. Crear el Servidor Maestro (2 Cores, 4GB RAM)
sudo lxc launch ubuntu:22.04 srv-master
sudo lxc config set srv-master limits.cpu 2
sudo lxc config set srv-master limits.memory 4096MB

# 2. Crear el Worker 1 (2 Cores, 4GB RAM)
sudo lxc launch ubuntu:22.04 worker1
sudo lxc config set worker1 limits.cpu 2
sudo lxc config set worker1 limits.memory 4096MB

# 3. Crear el Worker 2 (2 Cores, 4GB RAM)
sudo lxc launch ubuntu:22.04 worker2
sudo lxc config set worker2 limits.cpu 2
sudo lxc config set worker2 limits.memory 4096MB

```

```
### Verificar que esten corriendo sudo lxc list

sudo lxc list
```

```
### Interaccion con los srv

sudo lxc exec srv-master bash
```

