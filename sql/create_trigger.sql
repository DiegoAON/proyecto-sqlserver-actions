USE EmpresaDB;
GO
CREATE TRIGGER trg_AuditarVenta
ON Ventas
AFTER INSERT
AS
BEGIN
    DECLARE @Ventas TipoVentas;

    INSERT INTO @Ventas (VentaID)
    SELECT VentaID
    FROM inserted;

    EXEC sp_RegistrarAuditoria @Ventas = @Ventas;
END;