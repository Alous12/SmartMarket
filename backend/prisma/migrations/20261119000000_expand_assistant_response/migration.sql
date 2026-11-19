-- Las respuestas del asistente administrativo pueden superar los mensajes
-- breves usados originalmente para rechazos y errores.
ALTER TABLE `assistant_requests`
    MODIFY COLUMN `response_message` TEXT NULL;
