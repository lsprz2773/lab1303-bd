-- Implementacion 1
CREATE OR REPLACE FUNCTION fn_horas_trabajadas(
    IN p_empleado_id INT,
    IN p_mes INT,
    IN p_anio NUMERIC -- Parametros indicados en mi actividad
) RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE 
    total_horas NUMERIC; -- Variable que almacenara el total de horas del empleado indicado
BEGIN
    SELECT 
    COALESCE(
        SUM(EXTRACT(EPOCH FROM (salida -  entrada)) / 3600)
    , 0) AS total_horas -- Coalesce para evitar datos NUll, Salida menos entrada da un intervalo,EXTRACT + EPOCH convierte ese intervalo en segundos
    -- para luego obtener las horas totales al dividir entre 3600
    INTO total_horas -- Guarda las horas totales en la variable
    FROM registros_asistencia
    WHERE empleado_id = p_empleado_id
    AND EXTRACT(MONTH FROM fecha) = p_mes -- Extract + Month obtiene el mes de la fecha establecida
    AND EXTRACT(YEAR FROM fecha) = p_anio -- Extract + Year obtiene solo el año de la fecha establecida
    AND entrada IS NOT NULL -- Que tenga entrada registrada
    AND salida IS NOT NULL; -- Que tenga salida registrada

    RETURN ROUND(total_horas, 2); -- Redondea con dos decimales y retorna el total de horas
END;
$$;
-- QUERY DE USO
-- SELECT fn_horas_trabajadas(15, 3, 2026); 






-- Implementacion 2
CREATE OR REPLACE FUNCTION fn_validar_entrada() RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS( -- Condicional que verifica que tenga entrada pero no salida
        SELECT 1 FROM registros_asistencia WHERE empleado_id = NEW.empleado_id -- Filtra que haya registros en la tabla con el nuevo registro
        AND fecha = NEW.fecha -- Filtra la fecha guardada con la del nuevo registro
        AND entrada IS NOT NULL -- Filtra que el registro tenga entrada y no sea nulo
        AND salida IS NUll -- Filtra que el registro no tenga salida
    ) THEN
        RAISE EXCEPTION 'El empleado %, debe registrar primero su salida', NEW.empleado_id; -- Si se cumple la condicional da el log de aviso
    END IF;

    RETURN NEW; -- Si no ocurren problemas con la condicional, permite crear el nuevo registro
END;
$$;

CREATE OR REPLACE TRIGGER trg_validar_entrada
BEFORE INSERT -- Antes de crear un registro
ON registros_asistencia -- En la tabla indicada
FOR EACH ROW -- Por cada fila
EXECUTE FUNCTION fn_validar_entrada(); -- Ejecuta la funcion
-- QUERY DE USO (usarla dos veces para ver el log de la BD)
-- INSERT INTO registros_asistencia (empleado_id, fecha, entrada)
-- VALUES (1, CURRENT_DATE, NOW());






-- Implementacion 3
CREATE OR REPLACE PROCEDURE sp_cerrar_dia(
    OUT p_cerrados INT -- Dato a retornar
)
LANGUAGE plpgsql
AS $$
DECLARE
    rec RECORD; -- Variable que guardara cada registro
BEGIN
    p_cerrados := 0; -- Se inicializa contador

    FOR rec IN -- En cada registro
        SELECT ra.id, ra.fecha, e.nombre AS nombre_empleado -- Se seleccionan los campos
        FROM registros_asistencia ra -- De la siguiente tabla
        JOIN empleados e ON e.id = ra.empleado_id -- Une tablas
        WHERE ra.fecha = CURRENT_DATE - 1 -- Hace el primer filtrado donde sea el dia anterior al actual (por eso se resta uno al dia actual)
        AND ra.entrada IS NOT NULL -- Donde tenga registro de entrada
        AND ra.salida IS NULL -- Y donde no tenga registro de salida
    LOOP -- Itera cada fila
        UPDATE registros_asistencia -- En la tabla de registros_asistencia
        SET salida = rec.fecha::TIMESTAMP +  TIME '18:00:00' -- Asigna la salida a las 18:00 del mismo dia del registro
        WHERE id = rec.id;

        RAISE NOTICE 'Cerrado automaticamente registro de empleado %, en la fecha %', rec.nombre_empleado, rec.fecha; -- Muestra el log con el empleado y la fecha cambiada
        p_cerrados := p_cerrados + 1; -- Aumenta el contador por cada empleado que no haya marcado su salida
        COMMIT; -- Guarda cada cambio
    END LOOP;
END;
$$;
-- QUERY DE USO: 
-- DO $$
-- DECLARE
--     total INT;
-- BEGIN
--     CALL sp_cerrar_dia(total);
--     RAISE NOTICE 'Cerrados: %', total;
-- END;
-- $$;



-- Implementacion 4
CREATE OR REPLACE VIEW v_ranking_asistencia AS

WITH horas_por_dia AS ( -- Primer CTE: calcula las horas trabajadas por empleado por dia
    SELECT
        ra.empleado_id,
        ra.fecha,
        EXTRACT(EPOCH FROM (ra.salida - ra.entrada)) / 3600 AS horas -- Salida menos entrada da un intervalo, EXTRACT + EPOCH convierte ese intervalo en segundos
        -- para luego obtener las horas del dia al dividir entre 3600
    FROM registros_asistencia ra
    WHERE ra.entrada IS NOT NULL -- Que tenga entrada registrada
      AND ra.salida  IS NOT NULL -- Que tenga salida registrada
),

promedio_por_empleado AS ( -- Segundo CTE: calcula el promedio de horas diarias por empleado
    SELECT
        empleado_id, --
        AVG(horas) AS promedio_horas_dia
    FROM horas_por_dia -- Toma los datos del primer CTE
    GROUP BY empleado_id -- Agrupa para obtener un promedio por empleado
)

SELECT
    d.nombre AS departamento,
    COUNT(e.id) AS cantidad_empleados, -- Cuenta cuantos empleados tiene el departamento
    ROUND(AVG(ppe.promedio_horas_dia)::NUMERIC, 2) AS promedio_horas_diarias -- Promedio de horas del departamento, redondeado a dos decimales
FROM departamentos d
JOIN empleados e ON e.departamento_id = d.id -- Une departamentos con sus empleados
JOIN promedio_por_empleado ppe ON ppe.empleado_id = e.id -- Une empleados con su promedio calculado en el CTE
GROUP BY d.nombre -- Agrupa por departamento para obtener una fila por cada uno
ORDER BY promedio_horas_diarias DESC; -- Ordena de mayor a menor promedio
-- QUERY DE USO
-- SELECT * FROM v_ranking_asistencia;