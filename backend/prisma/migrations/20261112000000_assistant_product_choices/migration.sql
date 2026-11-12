CREATE TABLE `assistant_product_choices` (
    `item_id` INTEGER NOT NULL,
    `branch_id` INTEGER NOT NULL,
    `product_id` INTEGER NOT NULL,
    `selected_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`item_id`, `branch_id`),
    INDEX `idx_assistant_choice_product` (`product_id`),
    INDEX `idx_assistant_choice_branch` (`branch_id`),
    CONSTRAINT `fk_assistant_choice_item` FOREIGN KEY (`item_id`) REFERENCES `shopping_list_items` (`item_id`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_assistant_choice_branch` FOREIGN KEY (`branch_id`) REFERENCES `branches` (`branch_id`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_assistant_choice_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`product_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `assistant_choice_events` (
    `event_id` INTEGER NOT NULL AUTO_INCREMENT,
    `user_id` INTEGER NOT NULL,
    `item_id` INTEGER NULL,
    `branch_id` INTEGER NOT NULL,
    `product_id` INTEGER NOT NULL,
    `ingredient_id` INTEGER NOT NULL,
    `price` DECIMAL(10, 2) NOT NULL,
    `chose_cheapest` BOOLEAN NULL,
    `candidates_at_selection` JSON NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`event_id`),
    INDEX `idx_assistant_event_user` (`user_id`),
    INDEX `idx_assistant_event_item` (`item_id`),
    INDEX `idx_assistant_event_product` (`product_id`),
    INDEX `idx_assistant_event_ingredient` (`ingredient_id`),
    INDEX `idx_assistant_event_branch` (`branch_id`),
    CONSTRAINT `fk_assistant_event_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_assistant_event_item` FOREIGN KEY (`item_id`) REFERENCES `shopping_list_items` (`item_id`) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT `fk_assistant_event_branch` FOREIGN KEY (`branch_id`) REFERENCES `branches` (`branch_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_assistant_event_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`product_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_assistant_event_ingredient` FOREIGN KEY (`ingredient_id`) REFERENCES `ingredients` (`ingredient_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
