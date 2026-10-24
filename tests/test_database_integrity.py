"""
Test Suite: Database Quality & Integrity Tests (unittest)
Permite validar las reglas de integridad de datos mediante el framework de testing estándar de Python.
"""

import unittest
import sqlite3
import os

class TestDatabaseIntegrity(unittest.TestCase):
    
    @classmethod
    def setUpClass(cls):
        """Inicializa la base de datos en memoria y ejecuta el script de esquema y datos."""
        cls.conn = sqlite3.connect(":memory:")
        cls.cursor = cls.conn.cursor()
        
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        schema_path = os.path.join(base_dir, "sql", "01_schema_and_mock_data.sql")
        
        with open(schema_path, "r", encoding="utf-8") as f:
            cls.cursor.executescript(f.read())

    @classmethod
    def tearDownClass(cls):
        """Cierra la conexión a la base de datos."""
        cls.conn.close()

    def test_01_detect_duplicate_emails(self):
        """VAL-01: Debe identificar cuentas duplicadas por correo."""
        query = """
            SELECT email, COUNT(*) 
            FROM users 
            GROUP BY email 
            HAVING COUNT(*) > 1;
        """
        self.cursor.execute(query)
        results = self.cursor.fetchall()
        self.assertEqual(len(results), 1, "Debe existir exactamente 1 email duplicado en el set de prueba")
        self.assertEqual(results[0][0], "carlos.gomez@empresa.pe")

    def test_02_detect_orphan_order_items(self):
        """VAL-02: Debe detectar ítems que apuntan a productos inexistentes."""
        query = """
            SELECT oi.item_id, oi.product_id 
            FROM order_items oi
            LEFT JOIN products p ON oi.product_id = p.product_id
            WHERE p.product_id IS NULL;
        """
        self.cursor.execute(query)
        results = self.cursor.fetchall()
        self.assertEqual(len(results), 1, "Debe existir 1 ítem huérfano")
        self.assertEqual(results[0][1], 999, "El product_id huérfano debe ser 999")

    def test_03_detect_order_total_discrepancies(self):
        """VAL-03: Debe detectar descuadres entre el total de la orden y la suma de ítems."""
        query = """
            SELECT o.order_id, o.total_amount, ROUND(SUM(oi.quantity * oi.unit_price), 2)
            FROM orders o
            INNER JOIN order_items oi ON o.order_id = oi.order_id
            GROUP BY o.order_id, o.total_amount
            HAVING ROUND(o.total_amount, 2) != ROUND(SUM(oi.quantity * oi.unit_price), 2);
        """
        self.cursor.execute(query)
        results = self.cursor.fetchall()
        self.assertEqual(len(results), 1, "Debe existir 1 orden con descuadre contable")
        self.assertEqual(results[0][0], 1003, "La orden con descuadre debe ser la 1003")

    def test_04_detect_delivered_orders_missing_delivery_date(self):
        """VAL-04: Órdenes en estado 'DELIVERED' deben tener 'delivered_at'."""
        query = """
            SELECT order_id 
            FROM orders 
            WHERE status = 'DELIVERED' AND delivered_at IS NULL;
        """
        self.cursor.execute(query)
        results = self.cursor.fetchall()
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0][0], 1002)

    def test_05_detect_negative_stock_and_prices(self):
        """VAL-05: Valida la captura de anomalías de dominio (stock < 0 y precio <= 0)."""
        query = """
            SELECT product_id, stock, price 
            FROM products 
            WHERE stock < 0 OR price <= 0;
        """
        self.cursor.execute(query)
        results = self.cursor.fetchall()
        self.assertEqual(len(results), 2, "Debe detectar 2 productos fuera de dominio permitido")

    def test_06_detect_orders_without_assigned_user(self):
        """VAL-06: Debe detectar órdenes sin usuario asociado (user_id IS NULL)."""
        query = """
            SELECT order_id 
            FROM orders 
            WHERE user_id IS NULL;
        """
        self.cursor.execute(query)
        results = self.cursor.fetchall()
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0][0], 1005)

    def test_07_validate_multi_table_join_traceability(self):
        """VAL-07: Comprueba la consistencia del cruce relacional de órdenes con ítems."""
        query = """
            SELECT COUNT(*) 
            FROM orders o
            INNER JOIN order_items oi ON o.order_id = oi.order_id;
        """
        self.cursor.execute(query)
        count = self.cursor.fetchone()[0]
        self.assertGreaterEqual(count, 6, "Deben existir al menos 6 líneas de orden vinculadas")

if __name__ == "__main__":
    unittest.main()
