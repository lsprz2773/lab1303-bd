-- Implementacion 1
CREATE OR REPLACE FUNCTION fn_horas_trabajadas(
    IN p_empleado_id INT,
    IN p_mes INT,
    IN p_anio NUMERIC
) RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE 
    total_horas NUMERIC;
BEGIN
    SELECT 
    COALESCE(
        SUM(EXTRACT(EPOCH FROM (salida -  entrada)) / 3600)
    , 0) AS total_horas
    INTO total_horas
    FROM registros_asistencia
    WHERE empleado_id = p_empleado_id
    AND EXTRACT(MONTH FROM fecha) = p_mes
    AND EXTRACT(YEAR FROM fecha) = p_anio
    AND entrada IS NOT NULL
    AND salida IS NOT NULL;

    RETURN ROUND(total_horas, 2);
END;
$$;

-- QUERY DE USO
-- SELECT fn_horas_trabajadas(15, 3, 2026); 




-- Implementacion 2
CREATE OR REPLACE FUNCTION fn_validar_entrada() RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS(
        SELECT 1 FROM registros_asistencia WHERE empleado_id = NEW.empleado_id
        AND fecha = NEW.fecha
        AND entrada IS NOT NULL
        AND salida IS NUll
    ) THEN
        RAISE EXCEPTION 'El empleado %, debe registrar primero su salida', NEW.empleado_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_validar_entrada
BEFORE INSERT
ON registros_asistencia
FOR EACH ROW
EXECUTE FUNCTION fn_validar_entrada();

-- QUERY DE USO (usarla dos veces para ver el log de la BD)
-- INSERT INTO registros_asistencia (empleado_id, fecha, entrada)
-- VALUES (1, CURRENT_DATE, NOW());




-- Implementacion 3
CREATE OR REPLACE PROCEDURE sp_cerrar_dia(
    OUT p_cerrados INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    rec RECORD;
BEGIN
    p_cerrados := 0;

    FOR rec IN
        SELECT ra.id, ra.fecha, e.nombre AS nombre_empleado
        FROM registros_asistencia ra 
        JOIN empleados e ON e.id = ra.empleado_id
        WHERE ra.fecha = CURRENT_DATE - 1
        AND ra.entrada IS NOT NULL
        AND ra.salida IS NULL
    LOOP
        UPDATE registros_asistencia
        SET salida = rec.fecha::TIMESTAMP +  TIME '18:00:00'
        WHERE id = rec.id;

        RAISE NOTICE 'Cerrado automaticamente registro de empleado %, en la fecha %', rec.nombre_empleado, rec.fecha;
        p_cerrados := p_cerrados + 1;
        COMMIT;
    END LOOP;
END;
$$;

-- DO $$
-- DECLARE
--     total INT;
-- BEGIN
--     CALL sp_cerrar_dia(total);        -- total recibe el valor del OUT
--     RAISE NOTICE 'Cerrados: %', total; -- imprime el resultado
-- END;
-- $$;



-- Implementacion 4
CREATE OR REPLACE VIEW v_ranking_asistencia AS

WITH horas_por_dia AS (
    SELECT
        ra.empleado_id,
        ra.fecha,
        EXTRACT(EPOCH FROM (ra.salida - ra.entrada)) / 3600 AS horas
    FROM registros_asistencia ra
    WHERE ra.entrada IS NOT NULL
      AND ra.salida  IS NOT NULL
),

promedio_por_empleado AS (
    SELECT
        empleado_id,
        AVG(horas) AS promedio_horas_dia
    FROM horas_por_dia
    GROUP BY empleado_id
)

SELECT
    d.nombre AS departamento,
    COUNT(e.id) AS cantidad_empleados,
    ROUND(AVG(ppe.promedio_horas_dia)::NUMERIC, 2) AS promedio_horas_diarias
FROM departamentos d
JOIN empleados e ON e.departamento_id = d.id
JOIN promedio_por_empleado ppe ON ppe.empleado_id = e.id
GROUP BY d.nombre
ORDER BY promedio_horas_diarias DESC;

-- QUERY DE USO
-- SELECT * FROM v_ranking_asistencia;