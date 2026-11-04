USE EmpresaDB;
GO

CREATE TYPE TipoVentas AS TABLE (
    VentaID INT,
    Producto VARCHAR(100),
    Cantidad INT
);
GO

CREATE PROCEDURE sp_RegistrarAuditoria
    @Ventas TipoVentas READONLY
AS
BEGIN
    -- 1. Registro de auditoría (como ya lo tenías)
    INSERT INTO AuditoriaVentas (VentaID, Mensaje)
    SELECT VentaID, 'Venta registrada automáticamente'
    FROM @Ventas;

    -- 2. Descuento en Inventario (Corregido para múltiples ventas del mismo producto)
    WITH VentasAgrupadas AS (
        SELECT Producto, SUM(Cantidad) AS TotalVendido
        FROM @Ventas
        GROUP BY Producto
    )
    UPDATE Inv
    SET Inv.Existencias = Inv.Existencias - VA.TotalVendido
    FROM Inventario Inv
    INNER JOIN VentasAgrupadas VA ON Inv.Producto = VA.Producto;
END;
GO