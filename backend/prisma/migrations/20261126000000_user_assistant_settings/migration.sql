-- Interruptores de Perfil: "Priorizar lo más barato" y "Recordar mis marcas".
-- Una fila por usuario; sin fila, el asistente usa los valores por defecto.
CREATE TABLE `user_assistant_settings` (
    `user_id` INTEGER NOT NULL,
    `prioritize_cheapest` BOOLEAN NOT NULL DEFAULT false,
    `remember_brands` BOOLEAN NOT NULL DEFAULT true,
    `created_at` TIMESTAMP(0) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP(0) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`user_id`),
    CONSTRAINT `fk_user_assistant_settings_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
