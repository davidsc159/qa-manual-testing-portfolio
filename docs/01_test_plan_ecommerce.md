# 📋 Plan de Pruebas de Software (Test Plan)
## Sistema E-Commerce: Módulos de Autenticación, Catálogo y Checkout

---

### Control de Versiones del Documento
| Versión | Fecha | Autor | Rol | Descripción del Cambio |
| :---: | :---: | :---: | :---: | :--- |
| **1.0.0** | 24/10/2026 | QA Junior / Trainee | QA Analyst | Versión inicial del Plan de Pruebas Funcionales y de Integridad de Datos |

---

## 1. Introducción y Objetivos

### 1.1 Propósito
El presente Plan de Pruebas define el alcance, la estrategia, los recursos, el cronograma y los entregables necesarios para garantizar la calidad funcional y la integridad de datos del flujo crítico de compra en la plataforma E-Commerce (**SauceDemo Web Store**).

### 1.2 Objetivos de Calidad
- **Asegurar la estabilidad funcional** de los flujos críticos: inicio de sesión, navegación de inventario, manipulación de carrito y finalización de compra (Checkout).
- **Identificar defectos tempranos** antes del paso a producción mediante técnicas de caja negra, análisis de valores límite y partición de equivalencia.
- **Validar la consistencia de datos** en la capa de persistencia relacional (SQL) para prevenir discrepancias financieras, productos huérfanos o usuarios duplicados.
- **Verificar la experiencia de usuario (UX/UI)** y el manejo adecuado de mensajes de error restrictivos.

---

## 2. Alcance de las Pruebas (Scope)

### 2.1 Módulos Dentro del Alcance (In-Scope)
1. **Módulo de Autenticación y Control de Acceso:**
   - Inicio de sesión con usuarios válidos (`standard_user`, `performance_glitch_user`).
   - Restricción de acceso para usuarios bloqueados (`locked_out_user`).
   - Validación de mensajes de error con credenciales vacías o erróneas.
   - Seguridad de URLs (impedir acceso a `/inventory.html` sin autenticación previa).
   - Cierre de sesión seguro e invalidación de token/sesión en navegador.

2. **Módulo de Catálogo y Carrito de Compras:**
   - Ordenamiento y filtros por precio (ascendente/descendente) y nombre (A-Z, Z-A).
   - Adición y eliminación de productos individuales y múltiples.
   - Sincronización del badge contador del carrito.
   - Persistencia del estado del carrito ante recarga de página (F5) o navegación atrás/adelante.

3. **Módulo de Checkout y Procesamiento de Órdenes:**
   - Formulario de información de envío (First Name, Last Name, Postal Code).
   - Validación de campos obligatorios y sanitización de caracteres especiales / espacios.
   - Cálculo correcto de subtotal de productos, impuestos (tax) y total general.
   - Pantalla de confirmación de orden (`Checkout: Complete!`) y vaciado de carrito.

4. **Auditoría de Integridad en Base de Datos (SQL):**
   - Detección de duplicidad de cuentas por correo electrónico.
   - Verificación de consistencia entre el monto total de la orden y la suma de ítems (`total_amount == sum(price * qty)`).
   - Integridad referencial: detección de órdenes huérfanas sin usuario asociado.

### 2.2 Fuera del Alcance (Out-of-Scope)
- Pruebas de rendimiento y estrés de carga masiva (> 5,000 usuarios concurrentes).
- Pruebas de integración con pasarelas de pago reales (Stripe, Visa, PayPal); se utilizan mocks de pasarela.
- Pruebas de compatibilidad con navegadores obsoletos (Internet Explorer 11 o anteriores).

---

## 3. Estrategia y Tipos de Pruebas

| Tipo de Prueba | Técnica / Enfoque | Objetivo |
| :--- | :--- | :--- |
| **Pruebas Funcionales (Caja Negra)** | Partición de Equivalencia y Valores Límite | Validar que cada botón, formulario y navegación cumpla con las reglas de negocio. |
| **Smoke Testing (Humo)** | Happy Paths críticos | Verificar tras cada despliegue que las funciones vitales estén operativas antes de pruebas profundas. |
| **Pruebas Negativas** | Inyección de datos erróneos y campos vacíos | Evaluar la tolerancia a fallos del sistema y la claridad de los mensajes de error. |
| **Pruebas de Regresión** | Re-ejecución de suite principal | Confirmar que las correcciones de bugs previos no rompieron funcionalidades existentes. |
| **Pruebas de Base de Datos (SQL Testing)** | Consultas de integridad relacional y consistencia | Garantizar que los datos guardados en backend sean 100% íntegros y no generen descuadres contables. |

---

## 4. Criterios de Entrada y Salida (Entry & Exit Criteria)

### 4.1 Criterios de Entrada (Entry Criteria)
- [x] Despliegue exitoso en el ambiente de Staging / Pruebas sin errores de infraestructura.
- [x] Base de datos de prueba poblada con datos representativos (usuarios activos, catálogo de productos con stock).
- [x] Matriz de casos de prueba revisada y aprobada por el QA Lead.
- [x] Credenciales de acceso y herramientas de captura de evidencias listas.

### 4.2 Criterios de Salida (Exit Criteria)
- [x] **100%** de los casos de prueba de prioridad Alta (High) ejecutados.
- [x] **0 defectos de severidad Crítica (Blocker)** abiertos en el backlog.
- [x] **Tasa mínima de aprobación:** 90% de casos totales en estado `PASS`.
- [x] Todos los defectos encontrados debidamente documentados en el sistema de seguimiento (Jira) con pasos de reproducción y evidencias.
- [x] Scripts de validación SQL ejecutados con reporte de hallazgos emitido.

---

## 5. Criterios de Severidad y Prioridad de Defectos

| Nivel | Severidad (Impacto Técnico) | Prioridad (Urgencia de Negocio) |
| :--- | :--- | :--- |
| **Critical / Blocker (P1)** | Cuelgue del sistema, caída de base de datos, pérdida de transacciones financieras o imposibilidad total de comprar. | Corrección inmediata requerida; bloquea la salida a producción. |
| **Major (P2)** | Funcionalidad principal rota sin alternativa disponible para el usuario (ej. error 500 al procesar código postal válido). | Corrección requerida en el sprint actual. |
| **Minor (P3)** | Defecto funcional leve o cosmético que cuenta con solución alternativa (workaround) y no impide finalizar el flujo. | Corrección planificada para sprints posteriores. |

---

## 6. Entorno de Pruebas (Test Environment)

- **Plataforma Web bajo Prueba:** [SauceDemo Web Application](https://www.saucedemo.com/)
- **Navegadores:**
  - Google Chrome (v128+ en Windows 11 / macOS)
  - Mozilla Firefox (v129+)
  - Vista responsiva móvil (Chrome DevTools: iPhone 14 & Samsung Galaxy S22)
- **Motor de Base de Datos:** SQLite / PostgreSQL
- **Herramientas de Soporte:** Jira (Gestión de bugs), Git / GitHub (Versionamiento y CI/CD), Python 3.12 (Ejecución de scripts de auditoría SQL).

---

## 7. Gestión de Riesgos y Mitigación

| Riesgo Identificado | Probabilidad | Impacto | Estrategia de Mitigación |
| :--- | :---: | :---: | :--- |
| Inestabilidad o latencia en el ambiente de Staging | Media | Alto | Contar con scripts de verificación de disponibilidad y mock de datos local. |
| Inconsistencias no detectadas por la UI en los totales calculados | Baja | Crítico | Validación directa vía queries SQL cruzando líneas de orden con montos facturados. |
| Concurrencia de stock al comprar el último producto disponible | Media | Alto | Diseñar casos de prueba específicos de condición de carrera con usuarios simultáneos. |
