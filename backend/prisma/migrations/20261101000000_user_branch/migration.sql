-- Cada admin administra una sola sucursal; los usuarios normales no tienen.
ALTER TABLE `users` ADD COLUMN `branch_id` INTEGER NULL;
CREATE INDEX `idx_users_branch` ON `users`(`branch_id`);

-- AddForeignKey
ALTER TABLE `users` ADD CONSTRAINT `fk_users_branch` FOREIGN KEY (`branch_id`) REFERENCES `branches`(`branch_id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- Los admins existentes quedan a cargo de la sucursal más grande.
UPDATE `users`
SET `branch_id` = (SELECT `branch_id` FROM `branches` WHERE `name` = 'SmartMarket Piloto' LIMIT 1)
WHERE `role` = 'admin' AND `branch_id` IS NULL;
