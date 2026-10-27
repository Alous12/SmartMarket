-- Sucursales de la fase piloto: una por cada modelo 3D de la app.
-- Coordenadas de referencia en Cochabamba.
INSERT INTO `branches` (`name`, `address`, `latitude`, `longitude`, `model_3d_url`)
SELECT 'Supermercado Natural', 'Cochabamba, Bolivia', -17.393800, -66.157000, 'Modelos_3D/supermercado_1.glb'
WHERE NOT EXISTS (SELECT 1 FROM `branches` WHERE `name` = 'Supermercado Natural');

INSERT INTO `branches` (`name`, `address`, `latitude`, `longitude`, `model_3d_url`)
SELECT 'SmartMarket Piloto', 'Cochabamba, Bolivia', -17.383700, -66.164800, 'Modelos_3D/supermercado_2.glb'
WHERE NOT EXISTS (SELECT 1 FROM `branches` WHERE `name` = 'SmartMarket Piloto');

-- Ingredientes genéricos con los que se identifica cada elemento de la lista.
-- La colación utf8mb4_unicode_ci ignora mayúsculas y tildes al compararlos.
INSERT IGNORE INTO `ingredients` (`name`) VALUES
    ('Tomate'), ('Lechuga'), ('Zanahoria'), ('Cebolla'), ('Pimentón'),
    ('Brócoli'), ('Papa'), ('Choclo'), ('Arveja'), ('Ajo'),
    ('Perejil'), ('Cilantro'), ('Albahaca'), ('Limón'), ('Manzana'),
    ('Plátano'), ('Naranja'), ('Frutilla'), ('Huevo'), ('Leche'),
    ('Mantequilla'), ('Crema de leche'), ('Queso'), ('Yogur'), ('Jamón'),
    ('Carne molida'), ('Carne de res'), ('Pollo'), ('Chorizo'), ('Pescado'),
    ('Camarón'), ('Arroz'), ('Quinua'), ('Lenteja'), ('Frejol'),
    ('Garbanzo'), ('Fideo'), ('Harina'), ('Maicena'), ('Pan'),
    ('Aceite'), ('Sal'), ('Azúcar'), ('Pimienta'), ('Comino'),
    ('Orégano'), ('Salsa de tomate'), ('Masa para lasaña');
