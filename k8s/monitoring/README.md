# Stack de Monitorización

Este directorio contiene la configuración completa del stack de monitorización para el proyecto.

## Componentes

### 1. Prometheus
- **Archivo principal**: `prometheus.yaml`
- **Configuración**: `prometheus-config-complete.yaml`
- **RBAC**: `prometheus-rbac.yaml`
- **Descripción**: Servidor de métricas que recopila datos de:
  - **cAdvisor**: Métricas de contenedores (CPU, memoria)
  - **kubelet**: Métricas de nodos
  - **kube-state-metrics**: Métricas de objetos de Kubernetes

### 2. kube-state-metrics
- **Archivo**: `kube-state-metrics.yaml`
- **Descripción**: Expone métricas sobre el estado de objetos de Kubernetes (pods, deployments, etc.)
- **Métricas clave**:
  - `kube_pod_status_phase`
  - `kube_pod_container_status_restarts_total`
  - `kube_deployment_status_replicas`

### 3. Grafana
- **Archivo**: `grafana.yaml`
- **Descripción**: Visualización de métricas
- **Acceso**: http://localhost:3000 (admin/admin)

### 4. Loki
- **Archivo**: `loki.yaml`
- **Descripción**: Agregación de logs

## Orden de Aplicación

El script `setup-cluster.sh` aplica los recursos en este orden:

1. **RBAC y ServiceAccounts**
   - `prometheus-rbac.yaml`
   - `kube-state-metrics.yaml` (incluye RBAC)

2. **ConfigMaps**
   - `prometheus-config-complete.yaml`

3. **Deployments y Services**
   - `prometheus.yaml`
   - `grafana.yaml`
   - `loki.yaml`

## Queries de Prometheus Útiles

### CPU por pod
```promql
sum(rate(container_cpu_usage_seconds_total{namespace="la-huella-8", pod!=""}[1m])) by (pod)
```

### Memoria por pod
```promql
sum(container_memory_working_set_bytes{namespace="la-huella-8", pod!=""}) by (pod)
```

### Pods en estado Running
```promql
kube_pod_status_phase{namespace="la-huella-8", phase="Running"}
```

### Reinicios de contenedores
```promql
kube_pod_container_status_restarts_total{namespace="la-huella-8"}
```

## Compatibilidad con K3s

Esta configuración está optimizada para funcionar en K3s/Orbstack:

- ✅ **cAdvisor**: Configurado para scrapear métricas de contenedores
- ✅ **RBAC**: Permisos necesarios para acceder al API server
- ✅ **kube-state-metrics**: Proporciona métricas de objetos de Kubernetes
- ⚠️ **Metrics Server**: Puede no funcionar completamente en K3s (limitación conocida)

## Troubleshooting

### Prometheus no tiene métricas de contenedores

Verificar que:
1. El ServiceAccount `prometheus` existe
2. El ClusterRole y ClusterRoleBinding están aplicados
3. Prometheus está usando el ServiceAccount (ver `serviceAccountName` en deployment)

```bash
kubectl get sa prometheus -n monitoring-8
kubectl get clusterrole prometheus
kubectl get clusterrolebinding prometheus
```

### kube-state-metrics no funciona

Verificar que el deployment está corriendo:
```bash
kubectl get pods -n monitoring-8 -l app=kube-state-metrics
kubectl logs -n monitoring-8 -l app=kube-state-metrics
```

### Ver targets de Prometheus

Acceder a Prometheus UI → Status → Targets
O ejecutar:
```bash
kubectl port-forward -n monitoring-8 svc/prometheus 9090:9090
# Abrir http://localhost:9090/targets
```
