# 🐛 Reportes de Defectos (Bug Reports) - Estándar Jira
## Proyecto: SauceDemo E-Commerce QA Suite

Este documento contiene los reportes de defectos redactados bajo el estándar formal utilizado en herramientas como Jira / Azure DevOps, derivados de la ejecución de la matriz de pruebas.

---

### 📌 Resumen de Defectos Detectados
| Issue ID | Resumen del Defecto | Severidad | Prioridad | Módulo | Estado |
| :---: | :--- | :---: | :---: | :---: | :---: |
| **BUG-001** | El usuario puede avanzar al flujo de checkout con el carrito de compras vacío | Minor (P3) | Low | Carrito / Checkout | OPEN |
| **BUG-002** | Código postal con espacios en blanco provoca fallo de validación no sanitizado | Major (P2) | Medium | Checkout Step One | IN REVIEW |
| **BUG-003** | Condición de carrera: El sistema permite completar la compra de un producto con stock 0 generando inventario negativo | Critical (P1) | High / Blocker | Checkout / Inventario | IN PROGRESS |

---

## 🐞 Bug Report 1: BUG-001

### **[BUG-001] El botón "Checkout" permite avanzar al formulario de envío teniendo 0 productos en el carrito**

- **Project:** SauceDemo Web Store (`SAUCE`)
- **Issue Type:** 🪲 Bug
- **Severity:** Minor (P3)
- **Priority:** Low (P3)
- **Component:** Shopping Cart (`/cart.html`)
- **Environment:**
  - SO: Windows 11 Pro 64-bit
  - Browser: Google Chrome v128.0.6613.138
  - Resolution: 1920x1080
  - Build Version: v1.4.2-staging
- **Reporter:** Erick Carbajal (QA Analyst)
- **Assignee:** Frontend Team Lead
- **Test Case Vinculado:** `TC-CART-013`

#### Precondiciones:
1. Tener una sesión iniciada con cualquier usuario válido (ej. `standard_user`).
2. El carrito de compras debe tener 0 ítems agregados (sin badge visible).

#### Pasos para Reproducir (Steps to Reproduce):
1. Iniciar sesión en la plataforma y dirigirse a `/inventory.html`.
2. Hacer clic en el icono del carrito en la esquina superior derecha para navegar a `https://www.saucedemo.com/cart.html`.
3. Verificar que la lista de productos se encuentre completamente vacía.
4. Hacer clic en el botón verde **"Checkout"**.

#### Resultado Actual (Actual Result):
El sistema permite la navegación sin restricciones y redirige al usuario a `https://www.saucedemo.com/checkout-step-one.html`, solicitando nombres y código postal para una orden vacía de $0.00.

#### Resultado Esperado (Expected Result):
El botón **"Checkout"** debe estar deshabilitado (`disabled`) mientras el carrito contenga 0 ítems, o al hacer clic debe mostrarse un mensaje informativo: *"Tu carrito de compras está vacío. Agrega productos para continuar."*, impidiendo la navegación.

#### Evidencia / Logs:
```json
// Estado de LocalStorage / Redux al momento del fallo
{
  "cart_contents": [],
  "cart_total_items": 0,
  "route_allowed": true // Defecto: no valida longitud > 0 antes de permitir redirección
}
```

#### Impacto en el Negocio:
Genera confusión en la experiencia de usuario (UX) y transacciones vacías que podrían consumir IDs de órdenes en la base de datos de manera innecesaria.

#### Sugerencia de Solución (Fix):
En el componente `CartPage`, agregar una validación de longitud al arreglo de ítems:
`const isCheckoutDisabled = cartItems.length === 0;`

---

## 🐞 Bug Report 2: BUG-002

### **[BUG-002] El campo 'Postal Code' no realiza `.trim()` a los datos de entrada, arrojando error de formato ante espacios en blanco accidentales**

- **Project:** SauceDemo Web Store (`SAUCE`)
- **Issue Type:** 🪲 Bug
- **Severity:** Major (P2)
- **Priority:** Medium (P2)
- **Component:** Checkout Information (`/checkout-step-one.html`)
- **Environment:**
  - SO: Windows 11 Pro / macOS Sonoma
  - Browser: Google Chrome v128 & Mozilla Firefox v129
  - Build Version: v1.4.2-staging
- **Reporter:** Erick Carbajal (QA Analyst)
- **Assignee:** Backend / Frontend Form Validation Team
- **Test Case Vinculado:** `TC-CHK-016`

#### Precondiciones:
1. Tener al menos un producto en el carrito de compras.
2. Estar en la pantalla de datos del cliente (`https://www.saucedemo.com/checkout-step-one.html`).

#### Pasos para Reproducir:
1. En el campo **"First Name"**, ingresar: `Juan`.
2. En el campo **"Last Name"**, ingresar: `Pérez`.
3. En el campo **"Zip/Postal Code"**, ingresar el código con un espacio antes o después (ejemplo común al copiar y pegar): `"  15036  "`.
4. Hacer clic en el botón **"Continue"**.

#### Resultado Actual:
El backend rechaza la petición con código `HTTP 400 Bad Request` o la validación en pantalla muestra: *"Error: Postal Code format is invalid"*, debido a que los espacios no son ignorados ni limpiados.

#### Resultado Esperado:
El frontend y backend deben aplicar automáticamente un filtro de sanitización (`input.trim()`) para eliminar espacios al inicio y final antes de evaluar la expresión regular del código postal, permitiendo avanzar exitosamente a `/checkout-step-two.html`.

#### Payload / Evidencia de Red:
```http
POST /api/v1/checkout/validate-shipping HTTP/1.1
Content-Type: application/json

{
  "firstName": "Juan",
  "lastName": "Pérez",
  "postalCode": "  15036  "
}

HTTP/1.1 400 Bad Request
{
  "success": false,
  "error": "INVALID_POSTAL_CODE_SYNTAX",
  "message": "Postal code fails regex ^[0-9A-Za-z]{3,10}$ due to whitespace"
}
```

#### Impacto en el Negocio:
Afecta la tasa de conversión en el embudo de ventas. Los usuarios móviles que autocompletan datos suelen introducir espacios residuales y abandonan el carrito al ver un error confuso.

---

## 🐞 Bug Report 3: BUG-003 (BLOCKER)

### **[BUG-003] [CRITICAL] Condición de carrera permite procesar orden de compra de un ítem con stock 0 generando balance negativo en la base de datos**

- **Project:** SauceDemo Web Store (`SAUCE`)
- **Issue Type:** 🪲 Bug
- **Severity:** Critical (P1)
- **Priority:** High / Blocker (P1)
- **Component:** Order Processing Service (`/checkout-step-two.html` / Database)
- **Environment:** Staging Cluster v1.4.2 / PostgreSQL 15 & SQLite
- **Reporter:** Erick Carbajal (QA Analyst)
- **Assignee:** Backend Core & Database Administrator
- **Test Case Vinculado:** `TC-CHK-020`

#### Precondiciones:
1. El producto `"Sauce Labs Fleece Jacket"` (ID `prod_004`) tiene únicamente **1 unidad** disponible en la tabla `products` (`stock = 1`).
2. El usuario A y el usuario B agregan el producto simultáneamente y llegan a la pantalla de confirmación (`/checkout-step-two.html`).

#### Pasos para Reproducir:
1. El usuario A hace clic en **"Finish"**. La orden se procesa y el stock se reduce a `0`.
2. Inmediatamente después (o en paralelo con diferencia de milisegundos), el usuario B hace clic en **"Finish"** para el mismo producto que ya no tiene inventario.

#### Resultado Actual:
La transacción del usuario B no es bloqueada ni rechazada. El sistema genera una orden confirmada (`order_id: 9942`), responde `200 OK` y actualiza la base de datos con un valor inconsistente:
`UPDATE products SET stock = stock - 1 WHERE id = 'prod_004';` -> **stock queda en `-1`**.

#### Resultado Esperado:
El sistema debe emplear bloqueos optimistas o pesimistas a nivel de base de datos (`SELECT ... FOR UPDATE` o transacciones atómicas con validación `stock >= quantity`).
La petición del usuario B debe ser rechazada con código `HTTP 409 Conflict` y un mensaje en pantalla: *"Lo sentimos, uno o más productos de tu carrito se han agotado."*, sin generar la orden ni alterar el stock.

#### Consulta SQL de Verificación de Falla:
```sql
-- Detección de la anomalía en base de datos
SELECT id, name, stock 
FROM products 
WHERE stock < 0;

-- Resultado obtenido:
-- id: prod_004 | name: Sauce Labs Fleece Jacket | stock: -1
```

#### Impacto en el Negocio:
**Crítico / Bloqueante para producción**. Provoca venta de productos inexistentes (sobreventa / stockout), reclamos de clientes, costos operativos de reembolso y descuadre entre inventario físico y contable.
