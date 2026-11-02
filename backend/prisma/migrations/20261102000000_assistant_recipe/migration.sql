-- Resultado del análisis de la IA (HU-14, HU-15): receta identificada y mensaje
-- para el usuario. REJECTED marca las peticiones que no corresponden a una receta.
ALTER TABLE `assistant_requests`
    ADD COLUMN `recipe_name` VARCHAR(150) NULL AFTER `status`,
    ADD COLUMN `response_message` VARCHAR(500) NULL AFTER `recipe_name`,
    MODIFY `status` ENUM('RECEIVED', 'PROCESSING', 'COMPLETED', 'REJECTED', 'FAILED') NOT NULL DEFAULT 'RECEIVED';
