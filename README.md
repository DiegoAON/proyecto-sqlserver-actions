# Proyecto Integrador: Despliegue Automatizado con SQL Server y GitHub Actions

Este proyecto implementa una solución de integración continua (CI) que automatiza el despliegue de una base de datos Microsoft SQL Server utilizando contenedores Docker y GitHub Actions. Incluye la creación de la base de datos `EmpresaDB`, tablas transaccionales y de inventario, procedimientos almacenados y triggers.

## Estructura del Proyecto

El repositorio sigue una organización modular para separar la configuración de infraestructura del código SQL:

```text
proyecto-sqlserver-actions
│
├── .github
│   └── workflows
│       └── deploy.yml          # Flujo de GitHub Actions (levanta Docker y ejecuta scripts)
│
├── sql
│   ├── create_database.sql     # Crea la base de datos EmpresaDB
│   ├── create_tables.sql       # Define las tablas Ventas, AuditoriaVentas e Inventario
│   ├── create_procedure.sql    # Crea el TYPE de tabla y el procedimiento sp_RegistrarAuditoria
│   ├── create_trigger.sql      # Define el trigger trg_AuditarVenta
│   ├── test_data.sql           # Inicializa el inventario y ejecuta inserciones de prueba
│   └── verify_tests.sql        # Pruebas automáticas: fallan si los resultados no son correctos
│
└── README.md                   # Documentación del proyecto
```

## Configuración y Ejecución

1. **Configuración de secretos:** para ejecutar este flujo de manera segura, debes configurar la contraseña del administrador (`sa`) de SQL Server como un secret. En tu repositorio de GitHub, ve a **Settings > Secrets and variables > Actions > New repository secret**. Nombra el secret `MSSQL_SA_PASSWORD` y asígnale una contraseña fuerte de tu elección. La contraseña nunca debe escribirse en el workflow, en los scripts ni en este archivo: el workflow la lee con `${{ secrets.MSSQL_SA_PASSWORD }}`.
2. **Ejecución:** cada vez que realices un `git push` a la rama `main`, GitHub Actions iniciará el workflow automáticamente.
3. **Verificación:** entra a la pestaña **Actions** de tu repositorio y selecciona la ejecución más reciente:
   * El paso **"Ejecutar pruebas automaticas"** corre `verify_tests.sql`. Si la auditoría o el inventario no coinciden con lo esperado, el script lanza un error con `THROW` y el paso (y todo el job) falla.
   * El paso **"Verificar resultados en consola"** muestra el estado final de las tablas `Ventas`, `AuditoriaVentas` e `Inventario`.

### Resultado esperado

Con los datos de `test_data.sql` (inventario inicial de 50 unidades por producto y 4 ventas insertadas en una sola sentencia, incluidas dos ventas de Laptop):

| Producto | Existencias finales |
|----------|---------------------|
| Laptop   | 43 (50 - 3 - 4)     |
| Monitor  | 45                  |
| Teclado  | 48                  |

Además, `AuditoriaVentas` debe contener 4 registros, uno por cada venta.

---

## Análisis del Reto Principal: Tablas Lógicas y Procesamiento Set-Based

El diseño de la auditoría y la actualización de inventario exigen comprender el comportamiento de los triggers frente a transacciones múltiples. Un concepto crucial es que **un trigger se dispara una sola vez por sentencia, no una vez por fila**. Si se ejecuta un `INSERT` con 4 registros simultáneos, el trigger se invoca una única vez para manejar ese lote completo.

### Las Tablas Lógicas `inserted` y `deleted`

El motor de base de datos expone dos tablas virtuales exclusivas para el contexto de un trigger. Estas tablas no residen únicamente en la memoria RAM: se materializan en la base de datos del sistema `tempdb`, utilizando el almacén de versiones de filas (row versioning).

* **`inserted`**: contiene los valores nuevos. En un trigger de `INSERT`, almacena los registros recién creados. En un `UPDATE`, contiene los valores posteriores a la modificación. En un `DELETE`, está vacía.
* **`deleted`**: contiene los valores antiguos. En un trigger de `DELETE`, almacena los registros eliminados. En un `UPDATE`, conserva los valores previos a la modificación. En un `INSERT`, está vacía.

### Comparativa de Enfoques: Fila a Fila vs. Por Conjuntos

El motor relacional de SQL Server está optimizado para operar sobre conjuntos de datos completos. Abordar un trigger ignorando este principio lleva a errores de pérdida de datos o a problemas de rendimiento.

**1. Enfoque con variable escalar (incorrecto)**

El error más común es leer `inserted` asignando sus columnas a variables escalares, por ejemplo `SELECT @VentaID = VentaID FROM inserted;`. Si la sentencia afecta varias filas, SQL Server asigna los valores uno tras otro a la variable, en un orden no determinista (no existe un `ORDER BY`). Al final, la variable conserva un solo valor y el resto de los registros se pierde, dejando ventas sin auditar. En la primera versión de este proyecto, un `INSERT` de 4 filas generaba una sola fila de auditoría.

**2. Enfoque fila a fila con cursores (correcto, pero ineficiente)**

Una verdadera operación fila a fila implica declarar un `CURSOR` o un bucle `WHILE` para recorrer `inserted` y llamar al procedimiento almacenado una vez por cada fila. Este diseño no pierde datos, pero ejecuta el procedimiento N veces (dentro de la misma transacción del `INSERT` original), con el costo de CPU y de planes de ejecución que eso implica. A mayor volumen de filas, mayor degradación del rendimiento.

**3. Enfoque por conjuntos / set-based (correcto y eficiente)**

La solución implementada en este proyecto elimina la iteración:

* En el trigger, se copia toda la tabla `inserted` con un bloque `INSERT INTO ... SELECT` hacia un parámetro de tipo tabla (`@Ventas TipoVentas`).
* Ese conjunto completo se pasa al procedimiento almacenado en una sola llamada.
* Dentro del procedimiento, la auditoría (`INSERT`) y el descuento de inventario (`UPDATE`) se resuelven cruzando tablas con `JOIN` y una `CTE`.

Este modelo indica a SQL Server *qué* resultado se necesita en lugar de *cómo* recorrer cada fila, lo que permite al optimizador de consultas procesar el lote completo en una sola operación.

### Un detalle de "pensar por conjuntos": el `GROUP BY` del inventario

Un `UPDATE ... JOIN` directo entre `Inventario` y `@Ventas` tiene un problema sutil: si el mismo producto aparece varias veces en el mismo lote, SQL Server aplica el `UPDATE` **solo una vez** a esa fila del inventario, con una de las coincidencias y sin garantizar cuál. Por ejemplo, con dos ventas de Laptop de 3 y 4 unidades en un solo `INSERT`, el inventario descontaría solo una de las dos cantidades.

Para evitarlo, el procedimiento agrupa primero las ventas por producto con una `CTE` (`GROUP BY Producto` y `SUM(Cantidad)`), de modo que el `JOIN` reciba exactamente una fila por producto con el total vendido en el lote. El caso de las dos laptops está incluido en `test_data.sql` y es validado por `verify_tests.sql`.