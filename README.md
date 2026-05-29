# Guia de Despliegue Automatizado - Cluster de Negocio (SIMF & Kafka V7)

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
| **PostgreSQL Primario** | `/app_psql/packague_bd/` | `simf-primary.tar` |
| **PostgreSQL Réplica** | `/app_psql/packague_bd/` | `simf_replica.tar` |
| **Kafka Broker** | `/kafka/kafka/` | `images/projectsintel-kafka-simf-v7_1.0.2.tar` |
| **Microservicios (SIMF)** | `/app_services/` | `app_simf/images/simf_rest_api_0_2_2.tar` <br> `app_simf/images/simf_ms_0_2_2.tar` |
| **Observabilidad** | `/metrics/` | `Observ/alloy.tar` |


> **IMPORTANTE:** Todos los scripts deben tener permisos de ejecución. Otórgalos con el comando:
> ```bash
> chmod +x *.sh
> 
```

## Paso a Paso para el Procedimiento de Instalación

Sigue estrictamente este orden para garantizar que las dependencias de red, secretos y almacenamiento se creen correctamente.

```
### Paso 1: Configuración de Nodos de Negocio: 

Debe ajustar el valor de los hostname segun corresponda a cada srv

Ejemplo: 

-- BUSINESS_01="bcvnegocio01"
-- BUSINESS_02="bcvnegocio02"
-- BUSINESS_03="bcvnegocio03"

```
### Paso 2: Ejecute el script business.sh:

--- sudo bash business.sh
```


```
### Paso 3: Seleccione en el menu el tipo de configuracion correspondiente a cada servidor

    1) Para la Instalacion srv principal
    2) Para la Instalacion srv replica
    3) Salir del flujo de instalacion

IMPORTANTE: Este script es unicamente para automatizar la configuracion.
existe un orquestador que se encarga de realizar los despliegues.
```

```
### Paso 4: Despliegue
Una vez persista la configuracion en cada broker, invoque el script orquestador

--- sudo bash orchestra_business.sh
```

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

