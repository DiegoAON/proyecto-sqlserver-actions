USE EmpresaDB;
GO

IF (SELECT COUNT(*) FROM Ventas) <> (SELECT COUNT(*) FROM AuditoriaVentas)
BEGIN
    THROW 50001, 'Error en la auditoria', 1;
END;

PRINT 'Prueba superada: las ventas y auditorias coinciden';
GO