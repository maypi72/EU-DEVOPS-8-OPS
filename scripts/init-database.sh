#!/bin/bash

# Script para inicializar la base de datos con datos de prueba

set -e

echo "🗄️  Inicializando base de datos con datos de prueba..."
echo ""

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

NAMESPACE="la-huella-8"

# Esperar a que PostgreSQL esté listo
echo "⏳ Esperando a que PostgreSQL esté listo..."
kubectl wait --for=condition=Ready pod -l app=postgres -n $NAMESPACE --timeout=120s

echo -e "${GREEN}✅ PostgreSQL listo${NC}"
echo ""

# Verificar si ya hay datos
EXISTING_USERS=$(kubectl exec -n $NAMESPACE deployment/postgres -- psql -U lahuella -d lahuella -t -c "SELECT COUNT(*) FROM users;" 2>/dev/null | tr -d ' ' || echo "0")

if [ "$EXISTING_USERS" != "0" ] && [ "$EXISTING_USERS" != "" ]; then
    echo -e "${YELLOW}⚠️  La base de datos ya tiene $EXISTING_USERS usuarios${NC}"
    read -p "¿Deseas reinicializar la base de datos? (s/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo "Operación cancelada"
        exit 0
    fi
    echo ""
    echo "🗑️  Eliminando datos existentes..."
    kubectl exec -n $NAMESPACE deployment/postgres -- psql -U lahuella -d lahuella <<EOF
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS users CASCADE;
EOF
fi

echo "📝 Creando tablas y datos de prueba..."
echo ""

# Crear tablas y datos de prueba
kubectl exec -n $NAMESPACE deployment/postgres -- psql -U lahuella -d lahuella <<EOF

-- Tabla de usuarios
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    role VARCHAR(50) NOT NULL,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insertar usuarios de prueba
INSERT INTO users (name, email, role, active) VALUES
    ('Ana García', 'ana.garcia@lahuella.com', 'admin', true),
    ('Carlos Ruiz', 'carlos.ruiz@lahuella.com', 'user', true),
    ('María López', 'maria.lopez@lahuella.com', 'user', true),
    ('Juan Martínez', 'juan.martinez@lahuella.com', 'user', true),
    ('Laura Sánchez', 'laura.sanchez@lahuella.com', 'moderator', true),
    ('Pedro Fernández', 'pedro.fernandez@lahuella.com', 'user', true),
    ('Isabel Torres', 'isabel.torres@lahuella.com', 'user', false),
    ('Miguel Ángel Díaz', 'miguel.diaz@lahuella.com', 'user', true),
    ('Carmen Moreno', 'carmen.moreno@lahuella.com', 'user', true),
    ('Francisco Jiménez', 'francisco.jimenez@lahuella.com', 'user', true),
    ('Elena Romero', 'elena.romero@lahuella.com', 'moderator', true),
    ('David Navarro', 'david.navarro@lahuella.com', 'user', true),
    ('Lucía Muñoz', 'lucia.munoz@lahuella.com', 'user', true),
    ('Javier Álvarez', 'javier.alvarez@lahuella.com', 'user', false),
    ('Sara Castillo', 'sara.castillo@lahuella.com', 'user', true);

-- Tabla de productos
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    stock INTEGER NOT NULL,
    category VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insertar productos
INSERT INTO products (name, description, price, stock, category) VALUES
    ('Zapatillas Running Pro', 'Zapatillas profesionales para running con amortiguación avanzada', 89.99, 45, 'Calzado'),
    ('Camiseta Técnica Dry-Fit', 'Camiseta transpirable de secado rápido', 29.99, 120, 'Ropa'),
    ('Pantalón Deportivo Flex', 'Pantalón elástico para máxima movilidad', 49.99, 67, 'Ropa'),
    ('Gorra UV Protection', 'Gorra con protección UV50+', 19.99, 200, 'Accesorios'),
    ('Mochila Hidratación 2L', 'Mochila con sistema de hidratación integrado', 59.99, 34, 'Accesorios'),
    ('Reloj GPS Deportivo', 'Reloj con GPS y monitor de frecuencia cardíaca', 199.99, 15, 'Electrónica'),
    ('Botella Térmica 750ml', 'Mantiene bebidas frías 24h y calientes 12h', 24.99, 89, 'Accesorios'),
    ('Calcetines Running Pack 3', 'Pack de 3 pares de calcetines técnicos', 15.99, 156, 'Ropa'),
    ('Guantes Running Invierno', 'Guantes térmicos transpirables', 22.99, 43, 'Accesorios'),
    ('Chaqueta Cortavientos', 'Chaqueta ligera resistente al viento', 79.99, 28, 'Ropa');

-- Tabla de pedidos
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    product_id INTEGER REFERENCES products(id),
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    total DECIMAL(10,2) NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insertar pedidos
INSERT INTO orders (user_id, product_id, quantity, unit_price, total, status) VALUES
    (2, 1, 2, 89.99, 179.98, 'completed'),
    (3, 2, 3, 29.99, 89.97, 'completed'),
    (4, 3, 1, 49.99, 49.99, 'completed'),
    (2, 5, 1, 59.99, 59.99, 'pending'),
    (5, 6, 1, 199.99, 199.99, 'completed'),
    (6, 7, 2, 24.99, 49.98, 'completed'),
    (3, 8, 1, 15.99, 15.99, 'shipped'),
    (7, 4, 3, 19.99, 59.97, 'completed'),
    (8, 9, 1, 22.99, 22.99, 'pending'),
    (9, 10, 1, 79.99, 79.99, 'shipped'),
    (10, 1, 1, 89.99, 89.99, 'completed'),
    (11, 2, 2, 29.99, 59.98, 'completed'),
    (12, 3, 1, 49.99, 49.99, 'pending');

EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Base de datos inicializada correctamente${NC}"
    echo ""
    
    # Mostrar resumen
    echo "📊 Resumen de datos creados:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    USERS_COUNT=$(kubectl exec -n $NAMESPACE deployment/postgres -- psql -U lahuella -d lahuella -t -c "SELECT COUNT(*) FROM users;" | tr -d ' ')
    PRODUCTS_COUNT=$(kubectl exec -n $NAMESPACE deployment/postgres -- psql -U lahuella -d lahuella -t -c "SELECT COUNT(*) FROM products;" | tr -d ' ')
    ORDERS_COUNT=$(kubectl exec -n $NAMESPACE deployment/postgres -- psql -U lahuella -d lahuella -t -c "SELECT COUNT(*) FROM orders;" | tr -d ' ')
    
    echo "  - Usuarios: $USERS_COUNT"
    echo "  - Productos: $PRODUCTS_COUNT"
    echo "  - Pedidos: $ORDERS_COUNT"
    echo ""
    
    # Calcular tamaño aproximado de la base de datos
    DB_SIZE=$(kubectl exec -n $NAMESPACE deployment/postgres -- psql -U lahuella -d lahuella -t -c "SELECT pg_size_pretty(pg_database_size('lahuella'));" | tr -d ' ')
    echo "  - Tamaño de la BD: $DB_SIZE"
    echo ""
    
    echo "💡 Comandos útiles:"
    echo "  # Ver usuarios"
    echo "  kubectl exec -n $NAMESPACE deployment/postgres -- psql -U lahuella -d lahuella -c 'SELECT * FROM users LIMIT 5;'"
    echo ""
    echo "  # Ver productos"
    echo "  kubectl exec -n $NAMESPACE deployment/postgres -- psql -U lahuella -d lahuella -c 'SELECT * FROM products LIMIT 5;'"
    echo ""
    echo "  # Ver pedidos"
    echo "  kubectl exec -n $NAMESPACE deployment/postgres -- psql -U lahuella -d lahuella -c 'SELECT * FROM orders LIMIT 5;'"
    echo ""
else
    echo -e "${RED}❌ Error al inicializar la base de datos${NC}"
    exit 1
fi
