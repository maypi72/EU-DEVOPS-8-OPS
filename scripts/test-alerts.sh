#!/bin/bash

# Script para probar las alertas configuradas
# Dispara condiciones que activan las 5 alertas obligatorias

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "🚨 Test de Alertas - Etapa 4"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Este script disparará las 5 alertas obligatorias para verificar"
echo "que tu sistema de alertas funciona correctamente."
echo ""
echo -e "${YELLOW}⚠️  IMPORTANTE:${NC}"
echo "1. Asegúrate de tener el webhook receiver corriendo:"
echo "   kubectl logs -f deployment/webhook-receiver -n monitoring-8"
echo ""
echo "2. Abre Prometheus en otra terminal:"
echo "   kubectl port-forward -n monitoring-8 svc/prometheus 9090:9090"
echo "   http://localhost:9090/alerts"
echo ""
read -p "¿Continuar? (s/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "Test cancelado"
    exit 0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 1/5: HighCPUUsage"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Creando pod que consume CPU..."
echo ""

kubectl apply -f ./stress-cpu-pod.yaml

echo -e "${GREEN}✅ Pod creado${NC}"
echo ""
echo "⏳ Esperando 5-7 minutos para que se dispare la alerta HighCPUUsage..."
echo "   (La alerta requiere CPU > 80% durante 5 minutos)"
echo ""
echo "Monitorea en:"
echo "  - Webhook logs: kubectl logs -f deployment/webhook-receiver -n monitoring-8"
echo "  - Prometheus: http://localhost:9090/alerts"
echo ""

for i in {1..7}; do
    echo -n "⏳ Minuto $i/7..."
    sleep 60
    echo " ✓"
done

echo ""
echo -e "${BLUE}ℹ️  La alerta HighCPUUsage debería estar en estado 'Firing' ahora${NC}"
echo ""
read -p "Presiona Enter para continuar con el siguiente test..."

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 2/5: HighMemoryUsage"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Creando pod que consume memoria..."
echo ""

kubectl apply -f ./stress-mem-pod.yaml

echo -e "${GREEN}✅ Pod creado${NC}"
echo ""
echo "⏳ Esperando 5-7 minutos para que se dispare la alerta HighMemoryUsage..."
echo "   (La alerta requiere Memoria > 85% durante 5 minutos)"
echo ""

for i in {1..7}; do
    echo -n "⏳ Minuto $i/7..."
    sleep 60
    echo " ✓"
done

echo ""
echo -e "${BLUE}ℹ️  La alerta HighMemoryUsage debería estar en estado 'Firing' ahora${NC}"
echo ""
read -p "Presiona Enter para continuar con el siguiente test..."

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 3/5: PodNotReady"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Creando deployment con imagen inexistente..."
echo ""

kubectl create deployment test-pod-fail -n la-huella-8 \
  --image=nginx:version-que-no-existe-12345

echo -e "${GREEN}✅ Deployment creado${NC}"
echo ""
echo "⏳ Esperando 5-7 minutos para que se dispare la alerta PodNotReady..."
echo "   (La alerta requiere pod no Running durante 5 minutos)"
echo ""

for i in {1..7}; do
    echo -n "⏳ Minuto $i/7..."
    sleep 60
    echo " ✓"
done

echo ""
echo -e "${BLUE}ℹ️  La alerta PodNotReady debería estar en estado 'Firing' ahora${NC}"
echo ""
read -p "Presiona Enter para continuar con el siguiente test..."

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 4/5: CertificateExpiringSoon"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${YELLOW}⚠️  Esta alerta requiere que tengas certificados configurados${NC}"
echo "   Si no tienes certificados, esta alerta no se disparará."
echo ""
echo "Verificando certificados..."
kubectl get certificates -n la-huella-8 2>/dev/null || echo "No hay certificados configurados"
echo ""
echo -e "${BLUE}ℹ️  Si tienes certificados próximos a expirar (<30 días), la alerta se disparará${NC}"
echo ""
read -p "Presiona Enter para continuar con el siguiente test..."

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 5/5: BackupJobFailed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${YELLOW}⚠️  Para probar esta alerta, necesitamos forzar un fallo en el backup${NC}"
echo ""
echo "Opciones:"
echo "1. Eliminar temporalmente el secret de postgres (forzará fallo)"
echo "2. Saltar este test"
echo ""
read -p "¿Quieres forzar un fallo de backup? (s/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo "Guardando secret actual..."
    kubectl get secret postgres-credentials -n la-huella-8 -o yaml > /tmp/postgres-secret-backup.yaml 2>/dev/null || true
    
    echo "Eliminando secret temporalmente..."
    kubectl delete secret postgres-credentials -n la-huella-8 2>/dev/null || echo "Secret no existe"
    
    echo "Creando job de backup manual..."
    kubectl create job --from=cronjob/postgres-backup test-backup-fail -n la-huella-8 2>/dev/null || \
        echo -e "${YELLOW}⚠️  No se pudo crear job (CronJob no existe)${NC}"
    
    echo ""
    echo "⏳ Esperando 2 minutos para que falle el job..."
    sleep 120
    
    echo ""
    echo "Estado del job:"
    kubectl get jobs -n la-huella-8 -l app=postgres-backup
    
    echo ""
    echo -e "${BLUE}ℹ️  La alerta BackupJobFailed debería estar en estado 'Firing' ahora${NC}"
    
    echo ""
    echo "Restaurando secret..."
    kubectl apply -f /tmp/postgres-secret-backup.yaml 2>/dev/null || echo "No se pudo restaurar secret"
    
    echo "Limpiando job de prueba..."
    kubectl delete job test-backup-fail -n la-huella-8 2>/dev/null || true
else
    echo "Test de BackupJobFailed omitido"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Tests completados"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Resumen de alertas probadas:"
echo "  ✅ HighCPUUsage - Pod stress-cpu-test"
echo "  ✅ HighMemoryUsage - Pod stress-mem-test"
echo "  ✅ PodNotReady - Deployment test-pod-fail"
echo "  ℹ️  CertificateExpiringSoon - Depende de certificados"
echo "  ℹ️  BackupJobFailed - Depende de si se ejecutó"
echo ""
echo "Verifica las alertas en:"
echo "  - Prometheus: http://localhost:9090/alerts"
echo "  - Webhook logs: kubectl logs -f deployment/webhook-receiver -n monitoring-8"
echo ""
echo -e "${YELLOW}⚠️  Limpieza de recursos de prueba:${NC}"
echo ""
read -p "¿Quieres limpiar los recursos de prueba ahora? (s/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo "Limpiando recursos..."
    kubectl delete pod stress-cpu-test -n la-huella-8 2>/dev/null || true
    kubectl delete pod stress-mem-test -n la-huella-8 2>/dev/null || true
    kubectl delete deployment test-pod-fail -n la-huella-8 2>/dev/null || true
    echo -e "${GREEN}✅ Recursos limpiados${NC}"
else
    echo ""
    echo "Para limpiar manualmente más tarde:"
    echo "  kubectl delete pod stress-cpu-test -n la-huella-8"
    echo "  kubectl delete pod stress-mem-test -n la-huella-8"
    echo "  kubectl delete deployment test-pod-fail -n la-huella-8"
fi

echo ""
echo -e "${GREEN}✅ Test de alertas completado${NC}"
echo ""
