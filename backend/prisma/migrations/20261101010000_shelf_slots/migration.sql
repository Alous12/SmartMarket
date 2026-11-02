-- Espacios de estantería de cada sucursal (uno por caja del modelo 3D).
-- product_id indica qué producto lo ocupa; NULL significa espacio libre.
CREATE TABLE `shelf_slots` (
    `slot_id` INTEGER NOT NULL AUTO_INCREMENT,
    `branch_id` INTEGER NOT NULL,
    `code` VARCHAR(100) NOT NULL,
    `section_id` INTEGER NOT NULL,
    `shelf` VARCHAR(100) NULL,
    `coordinate_x` DECIMAL(10, 3) NOT NULL,
    `coordinate_y` DECIMAL(10, 3) NOT NULL,
    `coordinate_z` DECIMAL(10, 3) NOT NULL,
    `product_id` INTEGER NULL,

    UNIQUE INDEX `uq_shelf_slots_code`(`branch_id`, `code`),
    UNIQUE INDEX `uq_shelf_slots_product`(`branch_id`, `product_id`),
    INDEX `idx_shelf_slots_section`(`section_id`),
    INDEX `idx_shelf_slots_product`(`product_id`),
    PRIMARY KEY (`slot_id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `shelf_slots` ADD CONSTRAINT `fk_shelf_slots_branch` FOREIGN KEY (`branch_id`) REFERENCES `branches`(`branch_id`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `shelf_slots` ADD CONSTRAINT `fk_shelf_slots_section` FOREIGN KEY (`section_id`) REFERENCES `sections`(`section_id`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `shelf_slots` ADD CONSTRAINT `fk_shelf_slots_product` FOREIGN KEY (`product_id`) REFERENCES `products`(`product_id`) ON DELETE SET NULL ON UPDATE CASCADE;
