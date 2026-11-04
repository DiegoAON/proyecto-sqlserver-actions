USE EmpresaDB;
GO

CREATE TRIGGER trg_AuditarVenta
ON Ventas
AFTER INSERT
AS
BEGIN
    DECLARE @Ventas TipoVentas;

    -- Ahora extraemos también Producto y Cantidad
    INSERT INTO @Ventas (VentaID, Producto, Cantidad)
    SELECT VentaID, Producto, Cantidad
    FROM inserted;

    EXEC sp_RegistrarAuditoria @Ventas = @Ventas;
END;