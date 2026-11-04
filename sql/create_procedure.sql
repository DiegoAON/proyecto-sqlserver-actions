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

    -- 2. Descuento en Inventario (Reto Avanzado)
    UPDATE Inv
    SET Inv.Existencias = Inv.Existencias - V.Cantidad
    FROM Inventario Inv
    INNER JOIN @Ventas V ON Inv.Producto = V.Producto;
END;
GO