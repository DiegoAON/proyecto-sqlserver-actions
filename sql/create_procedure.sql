USE EmpresaDB;
GO

-- 1. Crear nuestro tipo de tabla
CREATE TYPE TipoVentas AS TABLE (
    VentaID INT
);
GO

-- 2. Crear el procedimiento almacenado
CREATE PROCEDURE sp_RegistrarAuditoria
    @Ventas TipoVentas READONLY
AS
BEGIN
    INSERT INTO AuditoriaVentas (VentaID, Mensaje)
    SELECT
        VentaID,
        'Venta registrada automáticamente'
    FROM @Ventas;
END;
GO