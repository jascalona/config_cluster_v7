### Flujo de instalacion automatizado

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

