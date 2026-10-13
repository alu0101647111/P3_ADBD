-- PRIMERO CREAMOS UN USUARIO ADMIN
CREATE USER admin_vivero WITH PASSWORD 'admin123';

-- CREAMOS LA BASE DE DATOS
CREATE DATABASE viveros OWNER admin_vivero;

-- Y LE DAMOS PERMISOS AL USUARIO
GRANT ALL PRIVILEGES ON DATABASE viveros TO admin_vivero;

\c viveros


CREATE TABLE VIVERO (
    ID_vivero SERIAL PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL,
    Latitud NUMERIC(9,6) NOT NULL,
    Longitud NUMERIC(9,6) NOT NULL
);

CREATE TABLE PRODUCTO (
    ID_producto SERIAL PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL,
    Precio NUMERIC(10,2) NOT NULL,
    CONSTRAINT chk_precio_positivo CHECK (Precio > 0)
);

CREATE TABLE EMPLEADO (
    ID_empleado SERIAL PRIMARY KEY,
    Nombre VARCHAR(50) NOT NULL,
    Apellidos VARCHAR(100) NOT NULL,
    Fecha_alta DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE TAREA (
    ID_tarea SERIAL PRIMARY KEY,
    Nombre VARCHAR(50) NOT NULL,
    Descripcion VARCHAR(200)
);

CREATE TABLE CLIENTE (
    ID_cliente SERIAL PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL
);

-- Entidad Débil: Si el vivero se borra, sus zonas también (CASCADE)
CREATE TABLE ZONA (
    ID_vivero INT NOT NULL,
    ID_zona INT NOT NULL,
    Nombre VARCHAR(100) NOT NULL,
    Tipo VARCHAR(50),
    Latitud NUMERIC(9,6),
    Longitud NUMERIC(9,6),
    PRIMARY KEY (ID_vivero, ID_zona),
    FOREIGN KEY (ID_vivero) REFERENCES VIVERO(ID_vivero) ON DELETE CASCADE ON UPDATE CASCADE
);

-- Cliente Plus ES UN Cliente. Si se borra el cliente, se borra el plus (CASCADE)
CREATE TABLE CLIENTE_PLUS (
    ID_cliente INT PRIMARY KEY,
    Fecha_ingreso DATE NOT NULL,
    Fecha_baja DATE,
    FOREIGN KEY (ID_cliente) REFERENCES CLIENTE(ID_cliente) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_fechas_plus CHECK (Fecha_baja IS NULL OR Fecha_baja >= Fecha_ingreso)
);

-- Entidad Débil: Depende del Cliente_Plus (CASCADE)
CREATE TABLE BONIFICACION (
    ID_cliente INT NOT NULL,
    ID_bonificacion INT NOT NULL,
    Mes VARCHAR(20) NOT NULL,
    Importe NUMERIC(10,2) NOT NULL,
    PRIMARY KEY (ID_cliente, ID_bonificacion),
    FOREIGN KEY (ID_cliente) REFERENCES CLIENTE_PLUS(ID_cliente) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_importe_positivo CHECK (Importe > 0)
);

CREATE TABLE PEDIDO (
    ID_pedido SERIAL PRIMARY KEY,
    ID_cliente INT NOT NULL,
    ID_empleado INT,
    Fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    -- Si se borra el cliente, impedimos borrarlo si tiene pedidos (RESTRICT). 
    FOREIGN KEY (ID_cliente) REFERENCES CLIENTE(ID_cliente) ON DELETE RESTRICT ON UPDATE CASCADE,
    -- Si el empleado es despedido, mantenemos el pedido pero sin empleado (SET NULL).
    FOREIGN KEY (ID_empleado) REFERENCES EMPLEADO(ID_empleado) ON DELETE SET NULL ON UPDATE CASCADE
);

-- Relación N:M
CREATE TABLE STOCK (
    ID_vivero INT NOT NULL,
    ID_zona INT NOT NULL,
    ID_producto INT NOT NULL,
    Cantidad INT NOT NULL DEFAULT 0,
    PRIMARY KEY (ID_vivero, ID_zona, ID_producto),
    FOREIGN KEY (ID_vivero, ID_zona) REFERENCES ZONA(ID_vivero, ID_zona) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (ID_producto) REFERENCES PRODUCTO(ID_producto) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_stock_no_negativo CHECK (Cantidad >= 0)
);

CREATE TABLE HISTORICO_DESTINO (
    ID_empleado INT NOT NULL,
    ID_tarea INT NOT NULL,
    ID_vivero INT NOT NULL,
    ID_zona INT NOT NULL,
    Fecha_inicio DATE NOT NULL,
    Fecha_fin DATE,
    Puesto VARCHAR(50),
    Productividad NUMERIC(5,2),
    PRIMARY KEY (ID_empleado, ID_tarea, ID_vivero, ID_zona, Fecha_inicio),
    FOREIGN KEY (ID_empleado) REFERENCES EMPLEADO(ID_empleado) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (ID_tarea) REFERENCES TAREA(ID_tarea) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (ID_vivero, ID_zona) REFERENCES ZONA(ID_vivero, ID_zona) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_fechas_destino CHECK (Fecha_fin IS NULL OR Fecha_fin >= Fecha_inicio)
);

-- Relación N:M sale de la relación rombo CONTIENE
CREATE TABLE LINEA_PEDIDO (
    ID_pedido INT NOT NULL,
    ID_producto INT NOT NULL,
    Cantidad INT NOT NULL,
    Precio_venta NUMERIC(10,2) NOT NULL,
    PRIMARY KEY (ID_pedido, ID_producto),
    FOREIGN KEY (ID_pedido) REFERENCES PEDIDO(ID_pedido) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (ID_producto) REFERENCES PRODUCTO(ID_producto) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_linea_cantidad CHECK (Cantidad > 0),
    CONSTRAINT chk_linea_precio CHECK (Precio_venta >= 0)
);


-- ATRIBUTOS DERIVADOS (VISTAS) - ATRIBUTOS QUE CALCULAMOS DIRECTAMENTE PARA EVITAR ERRORES

-- Vista para el "Importe_total" del PEDIDO
CREATE VIEW v_pedido_importe AS
SELECT p.ID_pedido, p.Fecha, p.ID_cliente, p.ID_empleado, 
       COALESCE(SUM(lp.Cantidad * lp.Precio_venta), 0) AS Importe_Total
FROM PEDIDO p
LEFT JOIN LINEA_PEDIDO lp ON p.ID_pedido = lp.ID_pedido
GROUP BY p.ID_pedido;

-- Vista para el "Volumen_compra" del CLIENTE
CREATE VIEW v_cliente_volumen AS
SELECT c.ID_cliente, c.Nombre, 
       COALESCE(SUM(v.Importe_Total), 0) AS Volumen_Compras
FROM CLIENTE c
LEFT JOIN v_pedido_importe v ON c.ID_cliente = v.ID_cliente
GROUP BY c.ID_cliente;


-- INSERCIÓN DE DATOS (Mínimo 5 por tabla)

INSERT INTO VIVERO (Nombre, Latitud, Longitud) VALUES 
('Vivero Central', 28.4682, -16.2546),
('Vivero Norte', 28.4123, -16.5432),
('Vivero Sur', 28.0567, -16.7189),
('Vivero Este', 28.3214, -16.3456),
('Vivero Oeste', 28.2890, -16.8123);

INSERT INTO TAREA (Nombre, Descripcion) VALUES 
('Riego', 'Riego manual y automático de plantaciones'),
('Poda', 'Mantenimiento y poda estacional'),
('Abonado', 'Aplicación de fertilizantes y sustratos'),
('Venta', 'Atención directa al público'),
('Supervisión', 'Gestión integral del área');

INSERT INTO PRODUCTO (Nombre, Precio) VALUES 
('Rosal', 12.50),
('Ficus', 25.00),
('Abono Universal 5L', 8.99),
('Maceta terracota', 5.50),
('Semillas de tomate', 1.20);

INSERT INTO EMPLEADO (Nombre, Apellidos, Fecha_alta) VALUES 
('Carlos', 'Gómez Pérez', '2020-01-15'),
('Ana', 'López Silva', '2021-03-22'),
('Luis', 'Martínez Ruiz', '2022-06-10'),
('Marta', 'Sánchez Gil', '2023-02-05'),
('Jorge', 'Díaz Castro', '2023-11-20');

INSERT INTO CLIENTE (Nombre) VALUES 
('Juan Pérez'),
('Empresa Jardines Sur SL'),
('María García'),
('Ayuntamiento Local'),
('Pedro Sánchez');

INSERT INTO CLIENTE_PLUS (ID_cliente, Fecha_ingreso, Fecha_baja) VALUES 
(2, '2021-01-01', NULL),
(4, '2019-05-15', NULL),
(1, '2022-10-10', '2023-10-10'),
(3, '2023-01-20', NULL),
(5, '2023-06-01', NULL);

INSERT INTO ZONA (ID_vivero, ID_zona, Nombre, Tipo, Latitud, Longitud) VALUES 
(1, 1, 'Invernadero A', 'Cubierta', 28.4683, -16.2545),
(1, 2, 'Exterior B', 'Aire libre', 28.4681, -16.2547),
(2, 1, 'Zona Semillas', 'Almacén', 28.4124, -16.5431),
(3, 1, 'Exposición', 'Venta', 28.0568, -16.7188),
(4, 1, 'Cuarentena', 'Cerrada', 28.3215, -16.3455);

INSERT INTO BONIFICACION (ID_cliente, ID_bonificacion, Mes, Importe) VALUES 
(2, 1, 'Enero 2024', 50.00),
(2, 2, 'Febrero 2024', 45.50),
(4, 1, 'Enero 2024', 120.00),
(3, 1, 'Marzo 2024', 15.00),
(5, 1, 'Abril 2024', 20.00);

INSERT INTO PEDIDO (ID_cliente, ID_empleado, Fecha) VALUES 
(2, 4, '2024-01-10'),
(1, 4, '2024-01-12'),
(4, 5, '2024-02-05'),
(3, 2, '2024-03-15'),
(5, 1, '2024-04-20');

INSERT INTO STOCK (ID_vivero, ID_zona, ID_producto, Cantidad) VALUES 
(1, 1, 1, 50),
(1, 2, 2, 20),
(2, 1, 5, 200),
(3, 1, 4, 80),
(4, 1, 3, 150);

INSERT INTO HISTORICO_DESTINO (ID_empleado, ID_tarea, ID_vivero, ID_zona, Fecha_inicio, Fecha_fin, Puesto, Productividad) VALUES 
(1, 1, 1, 1, '2020-01-15', '2021-12-31', 'Regador', 8.5),
(1, 5, 1, 1, '2022-01-01', NULL, 'Supervisor', 9.2),
(2, 4, 3, 1, '2021-03-22', NULL, 'Vendedora', 9.0),
(3, 2, 1, 2, '2022-06-10', '2023-06-10', 'Podador', 7.8),
(4, 4, 1, 1, '2023-02-05', NULL, 'Vendedora', 8.8);

INSERT INTO LINEA_PEDIDO (ID_pedido, ID_producto, Cantidad, Precio_venta) VALUES 
(1, 2, 10, 24.00),
(1, 4, 10, 5.00),
(2, 1, 2, 12.50),
(3, 3, 20, 8.50),
(4, 5, 5, 1.20);


-- EJEMPLOS REPRESENTATIVOS DE OPERACIONES DELETE

-- EJEMPLO A: ON DELETE CASCADE
-- Al eliminar el Vivero 4, se eliminará automáticamente su ZONA 1 (Cuarentena) 
-- y el STOCK asociado a esa zona, manteniendo la integridad referencial.
DELETE FROM VIVERO WHERE ID_vivero = 4;

-- EJEMPLO B: ON DELETE SET NULL
-- Al despedir al Empleado 1 (Carlos), este se borra. Sin embargo, su PEDIDO (ID=5)
-- NO se borra. El campo ID_empleado en la tabla PEDIDO pasará a ser NULL.
-- También se borrarán sus registros en HISTORICO_DESTINO por su CASCADE.
DELETE FROM EMPLEADO WHERE ID_empleado = 1;

-- EJEMPLO C: ON DELETE RESTRICT (Fallará a propósito si lo intentas)
-- Intentar borrar al Cliente 2 ('Empresa Jardines Sur SL') dará un ERROR 
-- porque tiene Pedidos asociados y la restricción está en RESTRICT para proteger facturas.
-- DELETE FROM CLIENTE WHERE ID_cliente = 2;