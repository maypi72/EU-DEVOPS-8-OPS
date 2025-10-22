#!/bin/bash

set -e

echo "🚀 Configurando entorno para eu-devops-8-ops ..."
echo ""

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Verificar requisitos
echo "📋 Verificando requisitos previos..."

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl no está instalado${NC}"
    echo "Instálalo desde: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo -e "${RED}❌ Helm no está instalado${NC}"
    echo "Instálalo desde: https://helm.sh/docs/intro/install/"
    exit 1
fi

echo -e "${GREEN}✅ Todos los requisitos están instalados${NC}"
echo ""

# Verificar que hay un clúster disponible
echo "🔍 Verificando conexión al clúster Kubernetes..."
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ No se puede conectar a un clúster Kubernetes${NC}"
    echo ""
    echo "Por favor, asegúrate de tener un clúster funcionando:"
    echo "  - K3s: ./scripts/install-k3s.sh"
    echo "  - Minikube: minikube start"
    echo "  - OrbStack: Activa Kubernetes en la configuración"
    echo "  - Docker Desktop: Activa Kubernetes en preferencias"
    exit 1
fi

# Obtener información del clúster
CLUSTER_INFO=$(kubectl cluster-info | head -n 1)
echo -e "${GREEN}✅ Conectado al clúster${NC}"
echo "   $CLUSTER_INFO"
echo ""

# Advertencia sobre el contexto
CURRENT_CONTEXT=$(kubectl config current-context)
echo -e "${YELLOW}⚠️  Contexto actual: $CURRENT_CONTEXT${NC}"
echo ""
read -p "¿Deseas continuar con este clúster? (s/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "Operación cancelada"
    exit 0
fi
echo ""

# Verificar si ya existe una instalación previa
echo "🔍 Verificando instalación existente..."
EXISTING_PODS_LA_HUELLA=$(kubectl get pods -n la-huella-8 --no-headers 2>/dev/null | wc -l | tr -d ' ')
EXISTING_PODS_MONITORING=$(kubectl get pods -n monitoring-8 --no-headers 2>/dev/null | wc -l | tr -d ' ')

if [ "$EXISTING_PODS_LA_HUELLA" -gt 0 ] || [ "$EXISTING_PODS_MONITORING" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Se detectó una instalación existente${NC}"
    echo "   Pods en la-huella-8: $EXISTING_PODS_LA_HUELLA"
    echo "   Pods en monitoring-8: $EXISTING_PODS_MONITORING"
    echo ""
    read -p "¿Deseas limpiar y reinstalar? (s/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        echo "🧹 Limpiando instalación anterior..."
        
        # Eliminar todos los recursos en la-huella-8
        kubectl delete all --all -n la-huella-8 2>/dev/null || true
        kubectl delete ingress --all -n la-huella-8 2>/dev/null || true
        kubectl delete configmap --all -n la-huella-8 2>/dev/null || true
        kubectl delete secret --all -n la-huella-8 2>/dev/null || true
        kubectl delete pvc --all -n la-huella-8 2>/dev/null || true
        kubectl delete pv -l namespace=la-huella-8 2>/dev/null || true
        
        # Eliminar todos los recursos en monitoring-8
        kubectl delete all --all -n monitoring-8 2>/dev/null || true
        kubectl delete configmap --all -n monitoring-8 2>/dev/null || true
        kubectl delete secret --all -n monitoring-8 2>/dev/null || true
        kubectl delete pvc --all -n monitoring-8 2>/dev/null || true
        kubectl delete pv -l namespace=monitoring-8 2>/dev/null || true
        
        # Eliminar ClusterRole y ClusterRoleBinding de Prometheus
        kubectl delete clusterrole prometheus 2>/dev/null || true
        kubectl delete clusterrolebinding prometheus 2>/dev/null || true
        
        # Limpiar marcador de problemas
        rm -f /tmp/mf8-problems-configured 2>/dev/null || true
        
        sleep 5
        echo -e "${GREEN}✅ Limpieza completada${NC}"
        echo ""
    else
        echo "Actualizando instalación existente..."
        echo ""
    fi
fi

# Crear namespaces (idempotente)
echo "📦 Creando/verificando namespaces..."
kubectl create namespace la-huella-8 --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true
kubectl create namespace monitoring-8 --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true
echo -e "${GREEN}✅ Namespaces configurados${NC}"
echo ""

# Desplegar aplicación base (idempotente)
echo "🚀 Desplegando aplicación base..."
kubectl apply -f k8s/base/ 2>&1 | grep -v "unchanged" || true
echo ""

# Crear certificado TLS autofirmado
echo "🔐 Creando certificado TLS autofirmado..."

# Eliminar recursos de cert-manager si existen (para forzar certificado manual)
kubectl delete certificate app-certificate -n la-huella-8 2>/dev/null || true
kubectl delete certificaterequest -n la-huella-8 --all 2>/dev/null || true

# Eliminar certificado existente si existe
kubectl delete secret app-tls -n la-huella-8 2>/dev/null || true

# Esperar a que se eliminen completamente
sleep 2

# Generar certificado autofirmado con fecha de expiración en 40 días
openssl req -x509 -nodes -days 40 -newkey rsa:2048 \
    -keyout /tmp/tls.key -out /tmp/tls.crt \
    -subj "/CN=app.la-huella-8.local/O=LaHuella" 2>/dev/null

# Crear secret TLS
kubectl create secret tls app-tls \
    --cert=/tmp/tls.crt \
    --key=/tmp/tls.key \
    -n la-huella-8

# Limpiar archivos temporales
rm -f /tmp/tls.key /tmp/tls.crt

echo -e "${GREEN}✅ Certificado TLS creado${NC}"
echo ""

# Esperar a que los deployments estén disponibles
echo "⏳ Esperando a que los deployments estén listos..."
kubectl rollout status deployment/app -n la-huella-8 --timeout=120s 2>/dev/null || echo -e "${YELLOW}⚠️  App deployment aún no está listo${NC}"
kubectl rollout status deployment/postgres -n la-huella-8 --timeout=120s 2>/dev/null || echo -e "${YELLOW}⚠️  PostgreSQL deployment aún no está listo${NC}"

echo -e "${GREEN}✅ Aplicación base desplegada${NC}"
echo ""

# Inicializar base de datos con datos de prueba
echo "🗄️  Inicializando base de datos..."
./scripts/init-database.sh || echo -e "${YELLOW}⚠️  No se pudo inicializar la base de datos${NC}"
echo ""

# Desplegar stack de monitoring (idempotente)
echo "📊 Desplegando stack de monitorización..."

# Aplicar en orden: RBAC -> ConfigMaps -> Deployments
echo "  → Aplicando RBAC y ServiceAccounts..."
kubectl apply -f k8s/monitoring/prometheus-rbac.yaml 2>&1 | grep -v "unchanged" || true
kubectl apply -f k8s/monitoring/kube-state-metrics.yaml 2>&1 | grep -v "unchanged" || true

echo "  → Aplicando ConfigMaps..."
kubectl apply -f k8s/monitoring/prometheus-config-complete.yaml 2>&1 | grep -v "unchanged" || true

echo "  → Aplicando Deployments y Services..."
kubectl apply -f k8s/monitoring/grafana-dashboard-configmap.yaml 2>&1 | grep -v "unchanged" || true
kubectl apply -f k8s/monitoring/prometheus.yaml 2>&1 | grep -v "unchanged" || true
kubectl apply -f k8s/monitoring/grafana.yaml 2>&1 | grep -v "unchanged" || true
kubectl apply -f k8s/monitoring/loki.yaml 2>&1 | grep -v "unchanged" || true

echo ""

# Esperar a que los deployments de monitoring estén disponibles
echo "⏳ Esperando a que los deployments de monitoring estén listos..."
kubectl rollout status deployment/grafana -n monitoring-8 --timeout=120s 2>/dev/null || echo -e "${YELLOW}⚠️  Grafana deployment aún no está listo${NC}"
kubectl rollout status deployment/prometheus -n monitoring-8 --timeout=120s 2>/dev/null || echo -e "${YELLOW}⚠️  Prometheus deployment aún no está listo${NC}"
kubectl rollout status deployment/loki -n monitoring-8 --timeout=120s 2>/dev/null || echo -e "${YELLOW}⚠️  Loki deployment aún no está listo${NC}"
kubectl rollout status deployment/kube-state-metrics -n monitoring-8 --timeout=120s 2>/dev/null || echo -e "${YELLOW}⚠️  kube-state-metrics deployment aún no está listo${NC}"

echo -e "${GREEN}✅ Stack de monitorización desplegado (incluye kube-state-metrics)${NC}"
echo ""

# Instalar Metrics Server (necesario para HPA y kubectl top)
echo "📊 Instalando Metrics Server..."
if ! kubectl get deployment metrics-server -n kube-system &> /dev/null; then
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml 2>&1 | grep -v "unchanged" || true
    
    # Parchear para funcionar con Kind (certificados auto-firmados)
    echo "⏳ Esperando a que Metrics Server esté disponible..."
    sleep 5
    kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
      {
        "op": "add",
        "path": "/spec/template/spec/containers/0/args/-",
        "value": "--kubelet-insecure-tls"
      }
    ]' 2>&1 | grep -v "unchanged" || true
    
    echo -e "${GREEN}✅ Metrics Server instalado${NC}"
else
    echo -e "${YELLOW}ℹ️  Metrics Server ya está instalado${NC}"
fi
echo ""


# Instalar cert-manager
echo "🔐 Instalando cert-manager..."
if ! kubectl get deployment cert-manager -n cert-manager &> /dev/null; then
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml 2>&1 | grep -v "unchanged" || true
    echo "⏳ Esperando a que cert-manager esté listo..."
    kubectl wait --for=condition=available --timeout=120s deployment/cert-manager -n cert-manager 2>/dev/null || echo -e "${YELLOW}⚠️  cert-manager aún no está listo${NC}"
    echo -e "${GREEN}✅ cert-manager instalado${NC}"
else
    echo -e "${YELLOW}ℹ️  cert-manager ya está instalado${NC}"
fi
echo ""

# Configurar monitoreo de cert-manager en Prometheus
echo "📊 Configurando monitoreo de cert-manager..."
if ! kubectl get svc cert-manager-metrics -n cert-manager &> /dev/null; then
    # Crear servicio para exponer métricas
    kubectl apply -f k8s/monitoring/cert-manager-servicemonitor.yaml 2>&1 | grep -v "unchanged" || true
    
    # Actualizar configuración de Prometheus para incluir cert-manager
    CURRENT_CONFIG=$(kubectl get configmap prometheus-config -n monitoring-8 -o jsonpath='{.data.prometheus\.yml}' 2>/dev/null || echo "")
    
    if [ -n "$CURRENT_CONFIG" ] && ! echo "$CURRENT_CONFIG" | grep -q "job_name: 'cert-manager'"; then
        # Agregar job de cert-manager a la configuración
        cat <<EOF | kubectl apply -f - 2>&1 | grep -v "unchanged" || true
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring-8
data:
  prometheus.yml: |
$(echo "$CURRENT_CONFIG" | sed 's/^/    /')

      # Scrape cert-manager metrics
      - job_name: 'cert-manager'
        static_configs:
          - targets: ['cert-manager-metrics.cert-manager.svc.cluster.local:9402']
EOF
        
        # Reiniciar Prometheus para aplicar cambios
        kubectl rollout restart deployment/prometheus -n monitoring-8 2>/dev/null || true
    fi
    
    # Importar dashboard de Grafana (ya incluido en grafana-dashboard-configmap.yaml)
    kubectl apply -f k8s/monitoring/grafana-dashboard-configmap.yaml 2>&1 | grep -v "unchanged" || true
    
    # Reiniciar Grafana para cargar el nuevo dashboard
    kubectl rollout restart deployment/grafana -n monitoring-8 2>/dev/null || true
    
    echo -e "${GREEN}✅ Monitoreo de cert-manager configurado${NC}"
else
    echo -e "${YELLOW}ℹ️  Monitoreo de cert-manager ya está configurado${NC}"
fi
echo ""

# Verificar estado de los pods
echo "🔍 Verificando estado de los pods..."
echo ""
echo "Pods en la-huella-8:"
kubectl get pods -n la-huella-8 2>/dev/null || echo "No hay pods todavía"
echo ""
echo "Pods en monitoring-8:"
kubectl get pods -n monitoring-8 2>/dev/null || echo "No hay pods todavía"
echo ""



# Resumen
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Configuración completada${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Accesos:"
echo "  - Grafana: http://localhost:30000 (admin/admin)"
echo "    Dashboard: 'cert-manager Certificates' (monitoreo de certificados)"
echo "  - Prometheus: http://localhost:30001"
echo "  - Aplicación: Configurar Ingress o port-forward"
echo ""
echo "🔧 Herramientas instaladas:"
echo "  - Grafana, Prometheus, Loki (Observabilidad)"
echo "  - Metrics Server (Métricas de recursos)"
echo "  - cert-manager (Gestión de certificados + monitoreo)"
echo ""
echo "🔍 Comandos útiles:"
echo "  kubectl get pods -n la-huella-8"
echo "  kubectl get pods -n monitoring-8"
echo "  kubectl get pods -n cert-manager"
echo "  kubectl logs -n la-huella-8 <pod-name>"
echo "  kubectl port-forward -n la-huella-8 svc/app 8080:80"
echo "  ./scripts/cluster-status.sh (Ver estado del cluster)"
echo ""
