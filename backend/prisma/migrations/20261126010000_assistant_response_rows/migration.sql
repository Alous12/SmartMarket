-- Filas de inventario que acompañan la respuesta del asistente del admin
-- (producto, stock y estado), tomadas de la consulta real, nunca de la IA.
-- Es opcional: las peticiones de clientes y las anteriores quedan en NULL.
ALTER TABLE `assistant_requests`
    ADD COLUMN `response_rows` JSON NULL;
