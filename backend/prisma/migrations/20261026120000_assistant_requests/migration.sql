-- CreateTable
CREATE TABLE `assistant_requests` (
    `request_id` INTEGER NOT NULL AUTO_INCREMENT,
    `user_id` INTEGER NOT NULL,
    `prompt` TEXT NOT NULL,
    `status` ENUM('RECEIVED', 'PROCESSING', 'COMPLETED', 'FAILED') NOT NULL DEFAULT 'RECEIVED',
    `created_at` TIMESTAMP(0) NOT NULL DEFAULT CURRENT_TIMESTAMP(0),
    `updated_at` TIMESTAMP(0) NOT NULL DEFAULT CURRENT_TIMESTAMP(0),

    INDEX `idx_assistant_requests_user`(`user_id`),
    PRIMARY KEY (`request_id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `assistant_requests` ADD CONSTRAINT `fk_assistant_requests_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`user_id`) ON DELETE CASCADE ON UPDATE CASCADE;
