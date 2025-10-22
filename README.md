# 🚀 eu-devops-8-ops

Este proyecto configura un entorno de producción completo con aplicación web, base de datos PostgreSQL, stack de observabilidad (Grafana, Prometheus, Loki), gestión de certificados SSL/TLS, y herramientas de monitoreo avanzado.

## 📋 Requisitos Previos

### Herramientas Necesarias

- **kubectl** - Cliente de Kubernetes ([instalación](https://kubernetes.io/docs/tasks/tools/))
- **Helm** - Gestor de paquetes de Kubernetes ([instalación](https://helm.sh/docs/intro/install/))

### Cluster Kubernetes

Uno de los siguientes clusters funcionando:

- **K3s** (recomendado para desarrollo)
- **Minikube**
- **OrbStack**
- **Docker Desktop** con Kubernetes habilitado
- **Kind** u otro cluster Kubernetes

## 🚀 Inicio Rápido

### 1. Instalar K3s (opcional pero recomendado)

```bash
./scripts/install-k3s.sh
```

### 2. Configurar el cluster completo

```bash
./scripts/setup-cluster.sh
```

Este script automáticamente:

- Verifica requisitos y conexión al cluster
- Crea namespaces (`la-huella-8`, `monitoring-8`)
- Despliega aplicación web + PostgreSQL
- Inicializa base de datos con datos de prueba
- Instala stack completo de observabilidad
- Configura certificados SSL/TLS autofirmados
- Instala cert-manager y Metrics Server

### 3. Verificar estado del cluster

```bash
./scripts/cluster-status.sh
```

## 🔐 Accesos y Servicios

### Aplicación Web

- **URL:** Configurar Ingress o usar port-forward
- **Port-forward:** `kubectl port-forward -n la-huella-8 svc/app 8080:80`
- **Certificado SSL:** Autofirmado (válido por 40 días)

### Observabilidad

| Servicio       | URL                    | Credenciales | Descripción                |
| -------------- | ---------------------- | ------------ | -------------------------- |
| **Grafana**    | http://localhost:30000 | admin/admin  | Dashboards y visualización |
| **Prometheus** | http://localhost:30001 | -            | Métricas y alertas         |
| **Loki**       | http://localhost:30002 | -            | Logs centralizados         |

### Port-forwards útiles

```bash
# Grafana
kubectl port-forward -n monitoring-8 svc/grafana 3000:3000

# Prometheus
kubectl port-forward -n monitoring-8 svc/prometheus 9090:9090

# Aplicación
kubectl port-forward -n la-huella-8 svc/app 8080:80
```

## 🗄️ Base de Datos

### PostgreSQL

- **Namespace:** `la-huella-8`
- **Usuario:** `lahuella`
- **Base de datos:** `lahuella`
- **Datos de prueba:** 15 usuarios, 10 productos, 13 pedidos

### Inicialización manual (si es necesario)

```bash
./scripts/init-database.sh
```

### Conexión a PostgreSQL

```bash
# Conexión interactiva
kubectl exec -it -n la-huella-8 deployment/postgres -- psql -U lahuella -d lahuella

# Ver usuarios
kubectl exec -n la-huella-8 deployment/postgres -- psql -U lahuella -d lahuella -c "SELECT * FROM users LIMIT 5;"

# Ver productos
kubectl exec -n la-huella-8 deployment/postgres -- psql -U lahuella -d lahuella -c "SELECT * FROM products LIMIT 5;"

# Ver pedidos
kubectl exec -n la-huella-8 deployment/postgres -- psql -U lahuella -d lahuella -c "SELECT * FROM orders LIMIT 5;"
```

## 📊 Stack de Observabilidad

### Herramientas Instaladas

- **Grafana 10.0.0** - Dashboards y visualización
- **Prometheus** - Recolección de métricas y alertas
- **Loki** - Sistema de logs centralizado
- **kube-state-metrics** - Métricas de estado del cluster
- **cert-manager v1.13.0** - Gestión automática de certificados
- **Metrics Server** - Métricas de recursos para `kubectl top`

### Dashboards Incluidos

- **Cert-manager Certificates** - Monitoreo de certificados SSL/TLS
- Dashboards de Kubernetes y aplicación

## 📁 Estructura del Proyecto

```
eu-devops-8-ops/
├── scripts/
│   ├── setup-cluster.sh          # Script principal de configuración
│   ├── install-k3s.sh           # Instalación de K3s
│   ├── init-database.sh         # Inicialización de BD
│   └── cluster-status.sh        # Verificación de estado
├── k8s/
│   ├── base/                    # Aplicación y BD base
│   │   ├── app.yaml            # Deployment de aplicación web
│   │   ├── postgres.yaml       # PostgreSQL con persistencia
│   │   ├── postgres-init-configmap.yaml
│   │   └── namespace.yaml
│   └── monitoring/             # Stack de observabilidad
│       ├── grafana.yaml        # Grafana con dashboards
│       ├── prometheus.yaml     # Prometheus y configuración
│       ├── loki.yaml          # Loki para logs
│       ├── kube-state-metrics.yaml
│       ├── cert-manager-servicemonitor.yaml
│       ├── grafana-dashboard-configmap.yaml
│       └── README.md           # Documentación específica
└── README.md                   # Este archivo
```

## 🔧 Comandos Útiles

### Gestión de Pods

```bash
# Ver pods por namespace
kubectl get pods -n la-huella-8
kubectl get pods -n monitoring-8
kubectl get pods -n cert-manager

# Ver logs
kubectl logs -n la-huella-8 <pod-name>
kubectl logs -f -n la-huella-8 <pod-name>  # Follow logs

# Acceder a un pod
kubectl exec -it -n la-huella-8 <pod-name> -- /bin/bash
```

### Debugging

```bash
# Información del cluster
kubectl cluster-info
kubectl get nodes -o wide
kubectl top nodes
kubectl top pods -A

# Ver eventos
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Ver recursos
kubectl get pvc -n <namespace>
kubectl get pv
```

### Certificados

```bash
# Ver certificados
kubectl get certificate -n <namespace>
kubectl describe certificate <cert-name> -n <namespace>
kubectl get secret -n <namespace> | grep tls
```

### Limpieza

```bash
# Limpiar namespace completo
kubectl delete all --all -n <namespace>

# Reiniciar deployment
kubectl rollout restart deployment/<deployment-name> -n <namespace>
```

## 🚨 Solución de Problemas

### Problema: No puedo conectar a Grafana

```bash
# Verificar que el pod esté corriendo
kubectl get pods -n monitoring-8 -l app=grafana

# Verificar servicio
kubectl get svc -n monitoring-8 -l app=grafana

# Hacer port-forward
kubectl port-forward -n monitoring-8 svc/grafana 3000:3000

# Acceder en: http://localhost:3000 (admin/admin)
```

### Problema: Base de datos no inicializada

```bash
# Verificar estado de PostgreSQL
kubectl get pods -n la-huella-8 -l app=postgres

# Inicializar datos de prueba
./scripts/init-database.sh
```

**¡Feliz DevOps!** 🚀
