CREATE TRIGGER after_laboratory_results_insert
ON laboratory_results
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE wt
    SET water_cut = i.water_cut, 
        mechanical_impurities = i.mechanical_impurities
    FROM well_tests wt
    INNER JOIN inserted i ON wt.well_id = i.well_id
    OUTER APPLY (
        SELECT MIN(lr2.last_lab_date) AS next_lab_date 
        FROM laboratory_results lr2 
        WHERE lr2.last_lab_date > i.last_lab_date 
        AND lr2.well_id = i.well_id
    ) AS next_lab
    WHERE wt.well_test_date >= i.last_lab_date
    AND (
        NOT EXISTS (
            SELECT 1 FROM laboratory_results lr1 
            WHERE lr1.last_lab_date > i.last_lab_date AND lr1.well_id = i.well_id
        )
        OR wt.well_test_date < next_lab.next_lab_date
    );

    UPDATE dwp
    SET oil_loss_ton = CASE 
        WHEN dwp.water_cut = 100 OR (i.water_cut = 0 AND dwp.oil_density = 0) THEN 0
        ELSE (dwp.oil_loss_ton * (dwp.oil_density * (1 - dwp.water_cut / 100) + dwp.water_cut / 100) / (1 - dwp.water_cut / 100)) 
             * (1 - i.water_cut / 100) / (dwp.oil_density * (1 - i.water_cut / 100) + i.water_cut / 100) 
    END,
        water_cut = i.water_cut,
        mechanical_impurities = i.mechanical_impurities
    FROM daily_well_parameters dwp
    INNER JOIN inserted i ON dwp.well_id = i.well_id
    OUTER APPLY (
        SELECT MIN(lr2.last_lab_date) AS next_lab_date 
        FROM laboratory_results lr2 
        WHERE lr2.last_lab_date > i.last_lab_date 
        AND lr2.well_id = i.well_id
    ) AS next_lab
    WHERE (
        SELECT rd.report_date 
        FROM report_dates rd 
        WHERE rd.id = dwp.report_date_id
    ) >= i.last_lab_date
    AND (
        NOT EXISTS (
            SELECT 1 FROM laboratory_results lr1 
            WHERE lr1.last_lab_date > i.last_lab_date AND lr1.well_id = i.well_id
        )
        OR (SELECT rd.report_date FROM report_dates rd WHERE rd.id = dwp.report_date_id) < next_lab.next_lab_date
    );
END;
GO

CREATE TRIGGER after_laboratory_results_delete
ON laboratory_results
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TempLabResults TABLE (
        well_id INT,
        water_cut FLOAT,
        mechanical_impurities FLOAT
    );

    INSERT INTO @TempLabResults (well_id, water_cut, mechanical_impurities)
    SELECT d.well_id, 
           ISNULL(lr.water_cut, 0) AS water_cut, 
           ISNULL(lr.mechanical_impurities, 0) AS mechanical_impurities
    FROM deleted d
    OUTER APPLY (
        SELECT TOP 1 lr.water_cut, lr.mechanical_impurities
        FROM laboratory_results lr
        WHERE lr.well_id = d.well_id AND lr.last_lab_date < d.last_lab_date
        ORDER BY lr.last_lab_date DESC
    ) lr;

    UPDATE wt
    SET 
        wt.water_cut = twi.water_cut, 
        wt.mechanical_impurities = twi.mechanical_impurities
    FROM well_tests wt
    INNER JOIN deleted d ON wt.well_id = d.well_id
    INNER JOIN @TempLabResults twi ON twi.well_id = d.well_id
    WHERE wt.well_test_date >= d.last_lab_date
    AND (
        NOT EXISTS (
            SELECT 1 FROM laboratory_results lr1 WHERE lr1.last_lab_date > d.last_lab_date AND lr1.well_id = d.well_id
        )
        OR wt.well_test_date < (
            SELECT MIN(lr2.last_lab_date) 
            FROM laboratory_results lr2 
            WHERE lr2.last_lab_date > d.last_lab_date 
            AND lr2.well_id = d.well_id
        )
    );

    UPDATE dwp
    SET 
        dwp.oil_loss_ton = CASE 
            WHEN dwp.water_cut = 100 OR (d.water_cut = 0 AND dwp.oil_density = 0) THEN 0
            ELSE (dwp.oil_loss_ton * (dwp.oil_density * (1 - dwp.water_cut / 100) + dwp.water_cut / 100) / (1 - dwp.water_cut / 100)) * (1 - d.water_cut / 100) / (dwp.oil_density * (1 - d.water_cut / 100) + d.water_cut / 100) 
        END,
        dwp.water_cut = twi.water_cut,
        dwp.mechanical_impurities = twi.mechanical_impurities
    FROM daily_well_parameters dwp
    INNER JOIN deleted d ON dwp.well_id = d.well_id
    INNER JOIN @TempLabResults twi ON twi.well_id = d.well_id
    WHERE (
        SELECT rd.report_date 
        FROM report_dates rd 
        WHERE rd.id = dwp.report_date_id
    ) >= d.last_lab_date
    AND (
        NOT EXISTS (
            SELECT 1 FROM laboratory_results lr1 WHERE lr1.last_lab_date > d.last_lab_date AND lr1.well_id = d.well_id
        )
        OR (SELECT rd.report_date FROM report_dates rd WHERE rd.id = dwp.report_date_id) < (
            SELECT MIN(lr2.last_lab_date) 
            FROM laboratory_results lr2 
            WHERE lr2.last_lab_date > d.last_lab_date 
            AND lr2.well_id = d.well_id
        )
    );
END;
GO
