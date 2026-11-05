-- HU-21: última disponibilidad registrada de cada elemento de la lista, para
-- poder informar al usuario qué le falta. NULL significa que aún no se consultó.
ALTER TABLE `shopping_list_items`
    ADD COLUMN `availability` ENUM('AVAILABLE', 'UNAVAILABLE', 'NOT_IN_CATALOG') NULL;

-- Ingredientes que pueden reemplazar a otro cuando no hay stock. priority ordena
-- las alternativas: se sugiere la primera que tenga producto en la sucursal.
CREATE TABLE `ingredient_substitutes` (
    `ingredient_id` INTEGER NOT NULL,
    `substitute_ingredient_id` INTEGER NOT NULL,
    `priority` INTEGER NOT NULL DEFAULT 1,

    INDEX `idx_ingredient_substitutes_substitute`(`substitute_ingredient_id`),
    PRIMARY KEY (`ingredient_id`, `substitute_ingredient_id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `ingredient_substitutes` ADD CONSTRAINT `fk_ingredient_substitutes_ingredient` FOREIGN KEY (`ingredient_id`) REFERENCES `ingredients`(`ingredient_id`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE `ingredient_substitutes` ADD CONSTRAINT `fk_ingredient_substitutes_substitute` FOREIGN KEY (`substitute_ingredient_id`) REFERENCES `ingredients`(`ingredient_id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- Ingredientes que ya tienen producto en las sucursales: sin ellos la lista los
-- marcaría como fuera de catálogo aunque estén en el estante.
INSERT IGNORE INTO `ingredients` (`name`) VALUES
    ('Agua'), ('Aceituna'), ('Ají amarillo'), ('Atún'), ('Avena'),
    ('Canela'), ('Cerdo'), ('Chocolate'), ('Durazno'), ('Esencia de vainilla'),
    ('Galleta'), ('Gelatina'), ('Ketchup'), ('Maní'), ('Mayonesa'),
    ('Mermelada'), ('Mostaza'), ('Palmito'), ('Pasta de tomate'), ('Polvo de hornear'),
    ('Salsa de soya'), ('Sardina'), ('Uva'), ('Verduras mixtas');

INSERT IGNORE INTO `ingredient_substitutes`
    (`ingredient_id`, `substitute_ingredient_id`, `priority`)
SELECT base.`ingredient_id`, alt.`ingredient_id`, pairs.priority
FROM (
    SELECT 'Crema de leche' AS base_name, 'Leche' AS alt_name, 1 AS priority
    UNION ALL SELECT 'Crema de leche', 'Mantequilla', 2
    UNION ALL SELECT 'Mantequilla', 'Aceite', 1
    UNION ALL SELECT 'Aceite', 'Mantequilla', 1
    UNION ALL SELECT 'Carne de res', 'Carne molida', 1
    UNION ALL SELECT 'Carne de res', 'Cerdo', 2
    UNION ALL SELECT 'Carne molida', 'Carne de res', 1
    UNION ALL SELECT 'Carne molida', 'Cerdo', 2
    UNION ALL SELECT 'Salsa de tomate', 'Pasta de tomate', 1
    UNION ALL SELECT 'Salsa de tomate', 'Tomate', 2
    UNION ALL SELECT 'Pasta de tomate', 'Salsa de tomate', 1
    UNION ALL SELECT 'Masa para lasaña', 'Fideo', 1
    UNION ALL SELECT 'Brócoli', 'Verduras mixtas', 1
    UNION ALL SELECT 'Zanahoria', 'Verduras mixtas', 1
    UNION ALL SELECT 'Pimentón', 'Ají amarillo', 1
    UNION ALL SELECT 'Orégano', 'Albahaca', 1
    UNION ALL SELECT 'Albahaca', 'Orégano', 1
    UNION ALL SELECT 'Perejil', 'Cilantro', 1
    UNION ALL SELECT 'Cilantro', 'Perejil', 1
    UNION ALL SELECT 'Limón', 'Naranja', 1
    UNION ALL SELECT 'Maicena', 'Harina', 1
    UNION ALL SELECT 'Harina', 'Maicena', 1
    UNION ALL SELECT 'Arroz', 'Quinua', 1
    UNION ALL SELECT 'Quinua', 'Arroz', 1
    UNION ALL SELECT 'Lenteja', 'Frejol', 1
    UNION ALL SELECT 'Frejol', 'Lenteja', 1
    UNION ALL SELECT 'Garbanzo', 'Frejol', 1
    UNION ALL SELECT 'Pescado', 'Atún', 1
    UNION ALL SELECT 'Atún', 'Sardina', 1
) pairs
JOIN `ingredients` base ON base.`name` = pairs.base_name
JOIN `ingredients` alt ON alt.`name` = pairs.alt_name;
