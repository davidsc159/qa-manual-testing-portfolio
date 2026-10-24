#!/usr/bin/env python3
"""
QA Database Validation Runner
Ejecuta las consultas SQL de aseguramiento de calidad sobre SQLite en memoria
y genera un reporte de auditoría de integridad de datos.
"""

import sqlite3
import os
import sys

# Asegurar compatibilidad de salida UTF-8 en consolas Windows
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

def run_qa_validations():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    schema_path = os.path.join(base_dir, "01_schema_and_mock_data.sql")
    
    if not os.path.exists(schema_path):
        print(f"[ERROR] No se encontró el archivo de esquema: {schema_path}")
        sys.exit(1)
        
    print("=" * 80)
    print("  QA DATABASE INTEGRITY AUDIT REPORT (SQLite Engine)")
    print("=" * 80)
    
    # 1. Inicializar base de datos en memoria
    conn = sqlite3.connect(":memory:")
    cursor = conn.cursor()
    
    # 2. Cargar esquema y datos mock
    # Nota QA: Desactivamos transitoriamente la verificación de FK al insertar datos mock
    # para permitir la inserción controlada de datos huérfanos/corruptos para las pruebas.
    print("[1/3] Cargando esquema de base de datos y datos mock con anomalías simuladas...")
    with open(schema_path, "r", encoding="utf-8") as f:
        schema_sql = f.read()
    cursor.executescript(schema_sql)
    print("      ✓ Tablas creadas: users, categories, products, orders, order_items")
    print("      ✓ Datos mock insertados con éxito.\n")
    
    # 3. Ejecutar las 7 validaciones de QA
    validations = [
        {
            "id": "VAL-01",
            "name": "Validación de Unicidad (Correos Electrónicos Duplicados)",
            "query": """
                SELECT email, COUNT(*) AS total_duplicados, GROUP_CONCAT(username, ', ') AS usuarios
                FROM users
                GROUP BY email
                HAVING COUNT(*) > 1;
            """,
            "expected_findings": 1,
            "check": lambda rows: len(rows) == 1 and rows[0][0] == "carlos.gomez@empresa.pe"
        },
        {
            "id": "VAL-02",
            "name": "Integridad Referencial (Ítems Huérfanos sin Producto Válido)",
            "query": """
                SELECT oi.item_id, oi.order_id, oi.product_id, oi.quantity, oi.unit_price
                FROM order_items oi
                LEFT JOIN products p ON oi.product_id = p.product_id
                WHERE p.product_id IS NULL;
            """,
            "expected_findings": 1,
            "check": lambda rows: len(rows) == 1 and rows[0][2] == 999
        },
        {
            "id": "VAL-03",
            "name": "Consistencia Financiera (Descuadre en Total de Órdenes vs Ítems)",
            "query": """
                SELECT o.order_id, o.total_amount, ROUND(SUM(oi.quantity * oi.unit_price), 2) AS total_calc,
                       ROUND(o.total_amount - SUM(oi.quantity * oi.unit_price), 2) AS diff
                FROM orders o
                INNER JOIN order_items oi ON o.order_id = oi.order_id
                GROUP BY o.order_id, o.total_amount
                HAVING ROUND(o.total_amount, 2) != ROUND(SUM(oi.quantity * oi.unit_price), 2);
            """,
            "expected_findings": 1,
            "check": lambda rows: len(rows) == 1 and rows[0][0] == 1003
        },
        {
            "id": "VAL-04",
            "name": "Regla de Negocio (Órdenes Entregadas sin Fecha de Entrega)",
            "query": """
                SELECT order_id, user_id, status, total_amount, delivered_at
                FROM orders
                WHERE status = 'DELIVERED' AND delivered_at IS NULL;
            """,
            "expected_findings": 1,
            "check": lambda rows: len(rows) == 1 and rows[0][0] == 1002
        },
        {
            "id": "VAL-05",
            "name": "Restricción de Dominio (Stock Negativo / Precios Inválidos - BUG-003)",
            "query": """
                SELECT product_id, name, price, stock,
                       CASE 
                           WHEN stock < 0 THEN 'FALLA CRÍTICA: Stock negativo'
                           WHEN price <= 0 THEN 'FALLA: Precio <= 0'
                       END AS anomalia
                FROM products
                WHERE stock < 0 OR price <= 0;
            """,
            "expected_findings": 2,
            "check": lambda rows: len(rows) == 2
        },
        {
            "id": "VAL-06",
            "name": "Integridad Referencial (Órdenes sin Cliente Asignado)",
            "query": """
                SELECT order_id, order_date, total_amount, status
                FROM orders
                WHERE user_id IS NULL;
            """,
            "expected_findings": 1,
            "check": lambda rows: len(rows) == 1 and rows[0][0] == 1005
        },
        {
            "id": "VAL-07",
            "name": "Cruce Multi-Tabla Consolidado (Trazabilidad End-to-End)",
            "query": """
                SELECT o.order_id, COALESCE(u.username, 'SIN_USUARIO'), COALESCE(p.name, 'PRODUCTO_INEXISTENTE'),
                       oi.quantity, oi.unit_price, o.status
                FROM orders o
                LEFT JOIN users u ON o.user_id = u.user_id
                INNER JOIN order_items oi ON o.order_id = oi.order_id
                LEFT JOIN products p ON oi.product_id = p.product_id
                LIMIT 5;
            """,
            "expected_findings": 5,
            "check": lambda rows: len(rows) == 5
        }
    ]
    
    print("[2/3] Ejecutando consultas de auditoría SQL...\n")
    all_passed = True
    
    for val in validations:
        cursor.execute(val["query"])
        rows = cursor.fetchall()
        passed = val["check"](rows)
        if not passed:
            all_passed = False
            
        status_tag = "✓ DETECTADO / VERIFICADO" if passed else "✗ FALLO EN VALIDACIÓN"
        print(f"[{val['id']}] {val['name']}")
        print(f"      Estado: {status_tag} (Filas obtenidas: {len(rows)})")
        
        # Imprimir filas obtenidas para auditoría visual
        for r in rows:
            print(f"      -> Registro: {r}")
        print()
        
    conn.close()
    
    print("=" * 80)
    if all_passed:
        print("  RESULTADO: 100% de las validaciones SQL se ejecutaron con éxito.")
        print("  Todas las anomalías de negocio e integridad referencial fueron detectadas.")
        print("=" * 80)
        return 0
    else:
        print("  RESULTADO: Algunas validaciones no produjeron el resultado esperado.")
        print("=" * 80)
        return 1

if __name__ == "__main__":
    sys.exit(run_qa_validations())
