--
ALTER TABLE horizons   
DROP CONSTRAINT UQ_horizon;
GO

ALTER TABLE horizons
ADD field_id INT NOT NULL DEFAULT 1,
    oil_density FLOAT;
GO

ALTER TABLE horizons
ADD CONSTRAINT FK_h_fieldId FOREIGN KEY (field_id) REFERENCES dbo.fields(id),
    CONSTRAINT UQ_horizon UNIQUE (name, field_id);
GO
--

--
ALTER TABLE platforms
DROP CONSTRAINT UQ_platform;
GO

ALTER TABLE platforms
ALTER COLUMN name NVARCHAR(255) NOT NULL;
GO

ALTER TABLE platforms
ADD square NVARCHAR(255);
GO

ALTER TABLE platforms
ADD CONSTRAINT UQ_platform UNIQUE (name, square, field_id);
GO
--

--
ALTER TABLE well_stock NOCHECK CONSTRAINT ALL;
GO

DELETE FROM production_well_stock_sub_categories;
GO

DBCC CHECKIDENT ('production_well_stock_sub_categories', RESEED, 0);
GO

INSERT INTO production_well_stock_sub_categories (name)
VALUES 
  (N'Fəaliyyətdə'),
  (N'Fəaliyyətsiz'),
  (N'Qazmadan mənimsədə');
GO

UPDATE well_stock
SET production_well_stock_sub_category_id = 1
WHERE production_well_stock_sub_category_id IN (1, 2);

UPDATE well_stock
SET production_well_stock_sub_category_id = 2
WHERE production_well_stock_sub_category_id = 3;

UPDATE well_stock
SET production_well_stock_sub_category_id = 3
WHERE production_well_stock_sub_category_id = 4;
GO

ALTER TABLE well_stock WITH CHECK CHECK CONSTRAINT ALL;
GO
--

--
ALTER TABLE well_tests
DROP COLUMN 
  choke, 
  pqa, 
  phf, 
  pba, 
  p6x9, 
  p9x13, 
  p13x20, 
  total_gas,
  gaslift_gas,
  reported_water_cut,
  water_cut,
  mechanical_impurities,
  oil_density;
GO

ALTER TABLE well_tests
ADD oil_ton FLOAT,
    water_ton FLOAT;
GO
--

--
CREATE TABLE gas_well_tests (
  id INT PRIMARY KEY IDENTITY(1,1),
  well_id INT NOT NULL,
  report_date_id INT NOT NULL,
  well_test_date DATE NOT NULL,
  total_gas FLOAT,
  gaslift_gas FLOAT,
  created_at DATE DEFAULT GETDATE(),
  CONSTRAINT FK_gwt_wellId FOREIGN KEY (well_id) REFERENCES dbo.wells(id),
  CONSTRAINT FK_gwt_reportDateId FOREIGN KEY (report_date_id) REFERENCES dbo.report_dates(id),
  CONSTRAINT UQ_gasWellTest UNIQUE (well_id, well_test_date)
);
GO

CREATE INDEX IDX_gwt_wellId ON dbo.gas_well_tests(well_id);
GO

CREATE INDEX IDX_gwt_reportDateId ON dbo.gas_well_tests(report_date_id);
GO
--

--
ALTER TABLE daily_well_parameters
DROP COLUMN 
  liquid_ton,
  total_gas,
  reported_water_cut,
  water_cut,
  mechanical_impurities,
  oil_density,
  oil_loss_ton;
GO

ALTER TABLE daily_well_parameters
ADD gaslift_system_pressure NVARCHAR(255),
    pump_depth FLOAT,
    pump_frequency FLOAT,
    pump_hydrostatic_pressure FLOAT,
    esp_pump_size FLOAT,
    esp_pump_stages FLOAT,
    esp_pump_rate FLOAT,
    esp_pump_head FLOAT,
    esp_downhole_gas_separator BIT,
    srp_pumpjack_type NVARCHAR(255),
    srp_pump_plunger_diameter FLOAT,
    srp_plunger_stroke_length FLOAT,
    srp_balancer_oscillation_frequency FLOAT,
    srp_pump_rate_coefficient FLOAT,
    srp_max_motor_speed FLOAT,
    srp_shaft_diameter FLOAT,
    pcp_pump_rate FLOAT,
    pcp_rpm FLOAT,
    pcp_screw_diameter FLOAT,
    static_fluid_level FLOAT,
    dynamic_fluid_level FLOAT,
    general_comments NVARCHAR(MAX),
    responsible_person NVARCHAR(255),
    phone_number NVARCHAR(255);
GO
--

--
DROP TRIGGER IF EXISTS after_laboratory_results_insert;

DROP TRIGGER IF EXISTS after_laboratory_results_delete;
--

--
DROP VIEW IF EXISTS complete_table;
GO

CREATE VIEW complete_table AS

SELECT 
  rd.report_date AS report_date,
  f.name AS field,
  COALESCE(p.name, '') +' / ' + COALESCE(p.square, '') AS "platform / square",
  w.name AS well,
  wsc.name AS well_stock_category,
  pwssc.name AS production_well_stock_sub_category,
  pm.name AS production_method,
  h.name AS horizon,
  dwp.flowmeter AS flowmeter,
  dwp.well_uptime_hours AS well_uptime_hours,
  ROUND(wt.liquid_ton, 0) AS liquid_ton,
  ROUND(lr.water_cut, 1) AS water_cut,
  CASE
      WHEN f.name <> 'SWG' THEN wt.oil_ton
      WHEN h.oil_density = 0 AND lr.water_cut = 0 THEN 0
      ELSE ROUND(wt.liquid_ton * h.oil_density * (1 - (lr.water_cut / 100)) / (h.oil_density * (1 - (lr.water_cut / 100)) + (lr.water_cut / 100)), 0)
  END AS oil_ton,
  CASE 
      WHEN f.name <> 'SWG' THEN wt.oil_ton * (24 - dwp.well_uptime_hours) / 24
      WHEN h.oil_density = 0 AND lr.water_cut = 0 THEN 0
      ELSE ROUND((wt.liquid_ton * h.oil_density * (1 - (lr.water_cut / 100)) / (h.oil_density * (1 - (lr.water_cut / 100)) + (lr.water_cut / 100))) * (24 - dwp.well_uptime_hours) / 24, 0)
  END AS oil_loss_ton,
  CASE
      WHEN f.name <> 'SWG' THEN wt.water_ton
      WHEN h.oil_density = 0 AND lr.water_cut = 0 THEN 0
      ELSE ROUND(wt.liquid_ton * (lr.water_cut / 100) / (h.oil_density * (1 - (lr.water_cut / 100)) + (lr.water_cut / 100)), 0)
  END AS water_ton,
  ROUND(gwt.total_gas, 0) AS total_gas,
  ROUND(gwt.gaslift_gas, 0) AS gaslift_gas,
  ROUND((gwt.total_gas - gwt.gaslift_gas) * dwp.well_uptime_hours / 24, 0) AS produced_gas,
  ROUND(lr.mechanical_impurities, 1) AS mechanical_impurities,
  dwp.pqa AS Pqa,
  dwp.phf AS Phf,
  dwp.pba AS Pba,
  dwp.p6x9 AS P6x9,
  dwp.p9x13 AS P9x13,
  dwp.p13x20 AS P13x20,
  dwp.choke AS choke,
  dwp.gaslift_gas AS gaslift_gas_daily,
  dwp.gaslift_system_pressure AS gaslift_system_pressure,
  dwp.pump_depth AS pump_depth,
  dwp.pump_frequency AS pump_frequency,
  dwp.pump_hydrostatic_pressure AS pump_hydrostatic_pressure,
  dwp.esp_pump_size AS esp_pump_size,
  dwp.esp_pump_stages AS esp_pump_stages,
  dwp.esp_pump_rate AS esp_pump_rate,
  dwp.esp_pump_head AS esp_pump_head,
  dwp.esp_downhole_gas_separator AS esp_downhole_gas_separator,
  dwp.srp_pumpjack_type AS srp_pumpjack_type,
  dwp.srp_pump_plunger_diameter AS srp_pump_plunger_diameter,
  dwp.srp_plunger_stroke_length AS srp_plunger_stroke_length,
  dwp.srp_balancer_oscillation_frequency AS srp_balancer_oscillation_frequency,
  dwp.srp_pump_rate_coefficient AS srp_pump_rate_coefficient,
  dwp.srp_max_motor_speed AS srp_max_motor_speed,
  dwp.srp_shaft_diameter AS srp_shaft_diameter,
  dwp.pcp_pump_rate AS pcp_pump_rate,
  dwp.pcp_rpm AS pcp_rpm,
  dwp.pcp_screw_diameter AS pcp_screw_diameter,
  dwp.static_fluid_level AS static_fluid_level,
  dwp.dynamic_fluid_level AS dynamic_fluid_level,
  wdr.downtime_category AS donwtime_category,
  pssa.name AS production_skin,
  wdr.comments AS comments
FROM daily_well_parameters AS dwp

LEFT JOIN well_stock AS ws
  ON dwp.well_id = ws.well_id
  AND ws.report_date_id = (
    SELECT MAX(ws_sub.report_date_id)
    FROM well_stock AS ws_sub
    WHERE ws_sub.well_id = dwp.well_id
    AND ws_sub.report_date_id <= dwp.report_date_id
  )

LEFT JOIN completions AS c
  ON dwp.well_id = c.well_id
  AND c.report_date_id = (
    SELECT MAX(c_sub.report_date_id)
    FROM completions AS c_sub
    WHERE c_sub.well_id = dwp.well_id
    AND c_sub.report_date_id <= dwp.report_date_id
  )

LEFT JOIN well_downtime_reasons AS wdr
    ON dwp.well_id = wdr.well_id
    AND wdr.report_date_id = (
        SELECT MAX(wdr_sub.report_date_id)
        FROM well_downtime_reasons AS wdr_sub
        WHERE wdr_sub.well_id = dwp.well_id
        AND wdr_sub.report_date_id <= dwp.report_date_id
    )

LEFT JOIN well_tests AS wt
    ON dwp.well_id = wt.well_id
    AND wt.report_date_id = (
        SELECT MAX(wt_sub.report_date_id)
        FROM well_tests AS wt_sub
        WHERE wt_sub.well_id = dwp.well_id
        AND wt_sub.report_date_id <= dwp.report_date_id
    )

LEFT JOIN laboratory_results as lr
    ON dwp.well_id = lr.well_id
    AND lr.report_date_id = (
      SELECT MAX(lr_sub.report_date_id)
      FROM laboratory_results AS lr_sub
      WHERE lr_sub.well_id = dwp.well_id
      AND lr_sub.report_date_id <= dwp.report_date_id
    )

LEFT JOIN gas_well_tests as gwt
    ON dwp.well_id = gwt.well_id
    AND gwt.report_date_id = (
      SELECT MAX(gwt_sub.report_date_id)
      FROM gas_well_tests AS gwt_sub
      WHERE gwt_sub.well_id = dwp.well_id
      AND gwt_sub.well_id <= dwp.report_date_id
    )

LEFT JOIN report_dates AS rd
    ON dwp.report_date_id = rd.id

LEFT JOIN wells AS w
    ON dwp.well_id = w.id

LEFT JOIN platforms AS p
    ON w.platform_id = p.id

LEFT JOIN fields AS f
    ON p.field_id = f.id

LEFT JOIN well_stock_categories AS wsc
    ON ws.well_stock_category_id = wsc.id

LEFT JOIN production_well_stock_sub_categories AS pwssc
    ON ws.production_well_stock_sub_category_id = pwssc.id

LEFT JOIN production_methods AS pm
    ON ws.production_method_id = pm.id

LEFT JOIN horizons AS h
    ON c.horizon_id = h.id

LEFT JOIN production_sub_skins_activities AS pssa
    ON wdr.production_sub_skins_activity_id = pssa.id;
--