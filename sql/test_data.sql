USE EmpresaDB;
GO

INSERT INTO Inventario (Producto, Existencias)
VALUES 
    ('Laptop', 50),
    ('Monitor', 50),
    ('Teclado', 50);
GO

INSERT INTO Ventas (Producto, Cantidad)
VALUES 
    ('Laptop', 3),
    ('Monitor', 5),
    ('Laptop', 4), 
    ('Teclado', 2);
GO