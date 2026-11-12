ALTER TABLE shopping_list_items ADD COLUMN excluded BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE assistant_requests ADD COLUMN recommendations_ready BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE user_preferences MODIFY ingredient_id INTEGER NULL,
    ADD COLUMN intent VARCHAR(191) NULL,
    ADD UNIQUE KEY uq_user_preference_intent (user_id, intent);
CREATE TABLE assistant_recommendations (
    item_id INTEGER NOT NULL,
    branch_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    PRIMARY KEY (item_id, branch_id),
    CONSTRAINT fk_recommendation_item FOREIGN KEY (item_id) REFERENCES shopping_list_items(item_id) ON DELETE CASCADE,
    CONSTRAINT fk_recommendation_branch FOREIGN KEY (branch_id) REFERENCES branches(branch_id) ON DELETE CASCADE,
    CONSTRAINT fk_recommendation_product FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
