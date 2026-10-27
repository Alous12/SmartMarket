-- AlterTable: sucursal seleccionada por el usuario al enviar la petición
ALTER TABLE `assistant_requests` ADD COLUMN `branch_id` INTEGER NULL AFTER `user_id`;
CREATE INDEX `idx_assistant_requests_branch` ON `assistant_requests`(`branch_id`);

-- CreateTable
CREATE TABLE `shopping_lists` (
    `list_id` INTEGER NOT NULL AUTO_INCREMENT,
    `user_id` INTEGER NOT NULL,
    `branch_id` INTEGER NOT NULL,
    `request_id` INTEGER NULL,
    `source` ENUM('MANUAL', 'RECIPE', 'AI') NOT NULL,
    `status` ENUM('ACTIVE', 'COMPLETED', 'CANCELLED') NOT NULL DEFAULT 'ACTIVE',
    `created_at` TIMESTAMP(0) NOT NULL DEFAULT CURRENT_TIMESTAMP(0),
    `updated_at` TIMESTAMP(0) NOT NULL DEFAULT CURRENT_TIMESTAMP(0),

    UNIQUE INDEX `uq_shopping_lists_request`(`request_id`),
    INDEX `idx_shopping_lists_user`(`user_id`),
    INDEX `idx_shopping_lists_branch`(`branch_id`),
    PRIMARY KEY (`list_id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `shopping_list_items` (
    `item_id` INTEGER NOT NULL AUTO_INCREMENT,
    `list_id` INTEGER NOT NULL,
    `ingredient_id` INTEGER NULL,
    `raw_name` VARCHAR(150) NOT NULL,
    `normalized_name` VARCHAR(150) NOT NULL,
    `quantity` DECIMAL(10, 3) NULL,
    `unit` VARCHAR(50) NULL,
    `created_at` TIMESTAMP(0) NOT NULL DEFAULT CURRENT_TIMESTAMP(0),

    INDEX `idx_shopping_list_items_list`(`list_id`),
    INDEX `idx_shopping_list_items_ingredient`(`ingredient_id`),
    PRIMARY KEY (`item_id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `assistant_requests` ADD CONSTRAINT `fk_assistant_requests_branch` FOREIGN KEY (`branch_id`) REFERENCES `branches`(`branch_id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `shopping_lists` ADD CONSTRAINT `fk_shopping_lists_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`user_id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `shopping_lists` ADD CONSTRAINT `fk_shopping_lists_branch` FOREIGN KEY (`branch_id`) REFERENCES `branches`(`branch_id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `shopping_lists` ADD CONSTRAINT `fk_shopping_lists_request` FOREIGN KEY (`request_id`) REFERENCES `assistant_requests`(`request_id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `shopping_list_items` ADD CONSTRAINT `fk_shopping_list_items_list` FOREIGN KEY (`list_id`) REFERENCES `shopping_lists`(`list_id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `shopping_list_items` ADD CONSTRAINT `fk_shopping_list_items_ingredient` FOREIGN KEY (`ingredient_id`) REFERENCES `ingredients`(`ingredient_id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- Restricciones CHECK que Prisma no puede modelar en schema.prisma
ALTER TABLE `shopping_list_items` ADD CONSTRAINT `chk_shopping_list_items_quantity` CHECK ((`quantity` IS NULL) OR (`quantity` > 0));
