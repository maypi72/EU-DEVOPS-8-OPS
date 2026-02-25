#!/bin/bash
# scripts/restore-backup.sh

NAMESPACE="la-huella-8"
PVC_NAME="postgres-backups"
POSTGRES_POD=$(kubectl get pods -n $NAMESPACE -l app=postgres -o jsonpath='{.items[0].metadata.name}')

echo "--- RESTAURACIÓN DE POSTGRES ---"

# 1. Listar backups disponibles en el PVC de backups
# Usamos un pod temporal para listar los archivos si el PVC no está montado en el pod principal
echo "[1] Buscando backups disponibles..."
BACKUPS=$(kubectl exec -n $NAMESPACE $POSTGRES_POD -- ls /backups | grep .sql)

if [ -z "$BACKUPS" ]; then
    echo "ERROR: No se encontraron archivos de backup en /backups"
    exit 1
fi

# 2. Mostrar menú de selección
echo "Seleccione el archivo a restaurar:"
select BACKUP_FILE in $BACKUPS; do
    if [ -n "$BACKUP_FILE" ]; then
        echo "Has seleccionado: $BACKUP_FILE"
        break
    else
        echo "Selección no válida."
    fi
done

# 3. Confirmación
read -p "ADVERTENCIA: Esto sobrescribirá los datos actuales. ¿Continuar? (s/n): " CONFIRM
if [[ $CONFIRM != "s" ]]; then
    echo "Operación cancelada."
    exit 0
fi

# 4. Restaurar el seleccionado
echo "[2] Restaurando..."
# Leemos el archivo del volumen y lo pasamos por tubería a psql
kubectl exec -it -n $NAMESPACE $POSTGRES_POD -- /bin/sh -c \
    "psql -U lahuella -d lahuella < /backups/$BACKUP_FILE"

# 5. Verificar éxito
if [ $? -eq 0 ]; then
    echo "-------------------------------------------"
    echo "✅ RESTAURACIÓN EXITOSA: $BACKUP_FILE"
    echo "-------------------------------------------"
else
    echo "❌ ERROR durante la restauración."
    exit 1
fi
