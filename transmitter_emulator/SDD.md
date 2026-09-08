### Tools client iperf3-server

# Ancho de Banda y Overheads de Red Overlay (VXLAN Encapsulation)


## Configuracion para la ejecucion del cliente local


# Lanzamos el cliente localmente en un nodo worker para medir el tráfico sin consultar al registry:

```
# Puedes customizar los argumentos segun sea el caso 

sudo docker service create \
  --name iperf3-server \
  --no-resolve-image \
  --network kafka_kafka-net \
  networkstatic/iperf3:latest -s

# Ejecutar el cliente emisor en el nodo interno

sudo docker run --rm -it \
  --network kafka_kafka-net \
  networkstatic/iperf3:latest -c iperf3-server -P 4 -t 30 -i 2
```

# Parametros de verificacion post-ejecucion


## Configuracion para la ejecucion de nodos cruzados

```

# Desde el un nodo x ejecute el siguiente comando para condicionar el servicio en el nodo deseado (ejmp: nodo 3) 

sudo docker service create \
  --name iperf3-server \
  --no-resolve-image \
  --network kafka_kafka-net \
  --constraint 'node.hostname == vasldiccs062' \
  networkstatic/iperf3:latest -s

# verifique la persistencia del servicio 
sudo docker ps | grep iperf3

# Desde el uno nodo manager definido como emisor ejecutar el caso el cliente emisor

sudo docker run --rm -it \
  --network kafka_kafka-net \
  networkstatic/iperf3:latest -c iperf3-server -P 4 -t 30 -i 2

```


```
# Fragmentación en el Kernel del Host: Estadísticas de transmisión

sudo netstat -s | grep -i "retransm\|fragment"

# Consulta  de interfaces y MTU 

sudo ip -s link show
```

 
