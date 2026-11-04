# proyecto-sqlserver-actions# Proyecto Integrador: Despliegue Automatizado con SQL Server y GitHub Actions

Este proyecto implementa una solución de integración continua (CI) que automatiza el despliegue de una base de datos Microsoft SQL Server utilizando contenedores Docker y GitHub Actions. Incluye la creación de la base de datos `EmpresaDB`, tablas transaccionales y de inventario, procedimientos almacenados y triggers.

## Análisis del Reto Principal

Para garantizar un rendimiento óptimo y evitar pérdida de información en transacciones masivas, la lógica de auditoría y control de inventario fue diseñada utilizando **procesamiento por conjuntos**.

### La Tabla Lógica `inserted`
Es una tabla virtual residente en la memoria de SQL Server, disponible exclusivamente durante la ejecución de los triggers `AFTER INSERT` y `AFTER UPDATE`. Actúa como un búfer temporal que almacena copias de todas las filas nuevas que están siendo insertadas en la transacción actual. 
* Si se inserta una sola fila, la tabla `inserted` contendrá un único registro.
* Si se ejecuta un `INSERT` múltiple (como en nuestro archivo `test_data.sql`), `inserted` agrupará todas las filas insertadas simultáneamente.

### Procesamiento por Conjuntos (Set-Based) vs. Operaciones Fila a Fila
El motor relacional de SQL Server está matemáticamente diseñado para operar sobre bloques de datos completos (teoría de conjuntos), haciéndolo exponencialmente más rápido y seguro que procesar datos de forma secuencial.

* **Operaciones Fila a Fila:** Utilizar variables escalares (`DECLARE @VentaID INT`) dentro de un trigger para leer la tabla `inserted` genera un fallo de diseño crítico. Si entran múltiples registros de golpe, la variable escalar sobreescribirá su valor iterativamente, capturando únicamente el último registro insertado y descartando (sin auditar) los demás.
* **Procesamiento Por Conjuntos (Set-Based):** En este proyecto, capturamos toda la tabla `inserted` mediante un `SELECT` directo y la volcamos dentro de una variable de tipo tabla (`@Ventas TipoVentas`). Al enviar esta tabla virtual al procedimiento almacenado, procesamos todos los registros simultáneamente mediante operaciones `JOIN` y comandos `UPDATE / INSERT` agrupados, garantizando la integridad de datos sin importar el volumen de la transacción.