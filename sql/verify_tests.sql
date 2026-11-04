USE EmpresaDB;
GO

-- 1. Validar Reto Principal: Filas de Ventas vs Auditoría
IF (SELECT COUNT(*) FROM Ventas) <> (SELECT COUNT(*) FROM AuditoriaVentas)
BEGIN
    THROW 50001, 'Error de prueba: Las ventas y las auditorías no coinciden.', 1;
END;

-- 2. Validar Reto Avanzado: Cálculo exacto del Inventario
-- Compara las existencias actuales contra la fórmula matemática: 50 - (Suma de Ventas)
IF EXISTS (
    SELECT I.Producto
    FROM Inventario I
    LEFT JOIN (
        SELECT Producto, SUM(Cantidad) AS TotalVendido
        FROM Ventas
        GROUP BY Producto
    ) V ON I.Producto = V.Producto
    WHERE I.Existencias <> (50 - ISNULL(V.TotalVendido, 0))
)
BEGIN
    THROW 50002, 'Error de prueba: El inventario no descontó las cantidades correctas de la tabla Ventas.', 1;
END;

PRINT 'Todas las pruebas superadas: Auditoría e Inventario son consistentes y exactos.';
GO