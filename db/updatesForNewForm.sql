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
    responsible_person NVARCHAR(255),
    phone_number NVARCHAR(255);
GO
--

--
CREATE TABLE daily_general_comments (
  id INT PRIMARY KEY IDENTITY(1,1),
  report_date_id INT NOT NULL,
  field_id INT NOT NULL,
  platform NVARCHAR(255) NOT NULL,  
  general_comments NVARCHAR(MAX),
  created_at DATE DEFAULT GETDATE(),
  CONSTRAINT FK_dgc_reportDateId FOREIGN KEY (report_date_id) REFERENCES dbo.report_dates(id),
  CONSTRAINT FK_dgc_fieldId FOREIGN KEY (field_id) REFERENCES dbo.fields(id),
  CONSTRAINT UQ_dailyGeneralComments UNIQUE (field_id, platform, report_date_id)
);
GO
--

--
DROP TABLE daily_operatives;
GO

CREATE TABLE daily_operatives (
  id INT PRIMARY KEY IDENTITY(1,1),
  ogpd_id INT NOT NULL,  
  report_date_id INT NOT NULL,
  produced_oil FLOAT,
  produced_condensate FLOAT,
  produced_gas FLOAT,
  produced_water FLOAT,
  injected_water FLOAT, 
  created_at DATE DEFAULT GETDATE(),
  CONSTRAINT FK_do_ogpdId FOREIGN KEY (ogpd_id) REFERENCES dbo.ogpd(id),
  CONSTRAINT FK_do_reportDateId FOREIGN KEY (report_date_id) REFERENCES dbo.report_dates(id),
  CONSTRAINT UQ_dailyOperatives UNIQUE (ogpd_id, report_date_id)
);
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
      WHEN f.name <> 'Günəşli' THEN wt.oil_ton
      WHEN h.oil_density = 0 AND lr.water_cut = 0 THEN 0
      ELSE ROUND(wt.liquid_ton * h.oil_density * (1 - (lr.water_cut / 100)) / (h.oil_density * (1 - (lr.water_cut / 100)) + (lr.water_cut / 100)), 0)
  END AS oil_ton,
  CASE 
      WHEN f.name <> 'Günəşli' THEN wt.oil_ton * (24 - dwp.well_uptime_hours) / 24
      WHEN h.oil_density = 0 AND lr.water_cut = 0 THEN 0
      ELSE ROUND((wt.liquid_ton * h.oil_density * (1 - (lr.water_cut / 100)) / (h.oil_density * (1 - (lr.water_cut / 100)) + (lr.water_cut / 100))) * (24 - dwp.well_uptime_hours) / 24, 0)
  END AS oil_loss_ton,
  CASE
      WHEN f.name <> 'Günəşli' THEN wt.water_ton
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
GO
--

--
UPDATE fields
set name = N'Günəşli'
where id=1;

INSERT INTO ogpd (name) 
VALUES 
  (N'Neft Daşları');
GO
--

--
INSERT INTO fields (name, ogpd_id)
VALUES 
  (N'Neft Daşları', 2),
  (N'Palçıq Pilpiləsi', 2);
GO
--

--

INSERT INTO platforms (name, square, field_id)
VALUES 
  ('1', '642', 2),
  ('1', '810', 2),
  ('1', '2164', 2),
  ('1', '1936', 2),
  ('1', '2150', 2),
  ('1', '2387', 2),
  ('1', '2346', 2),
  ('1', '2415', 2),
  ('1', '2346a', 2),
  ('2', '61', 2),
  ('2', '331', 2),
  ('2', '418a', 2),
  ('2', '617', 2),
  ('2', '1645', 2),
  ('2', '1646', 2),
  ('2', 'M-1', 2),
  ('2', '201', 2),
  ('2', '1716', 2),
  ('2', '1923', 2),
  ('2', '259', 2),
  ('2', '348', 2),
  ('2', '1517', 2),
  ('2', '1501', 2),
  ('2', '1926', 2),
  ('2', NULL, 2),
  ('3', '1304', 3),
  ('3', '1005a', 3),
  ('3', '1295', 3),
  ('3', '1296', 3),
  ('3', '1284', 3),
  ('3', '1043', 3),
  ('3', '1063', 3),
  ('3', '1100', 3),
  ('3', '1077', 3),
  ('3', '1201', 3),
  ('3', '1145', 3),
  ('3', '1146', 3),
  ('3', '1183', 3),
  ('3', '1157', 3),
  ('4', '99', 2),
  ('4', '1541a', 2),
  ('4', '1637', 2),
  ('4', '1637a', 2),
  ('4', '1770', 2),
  ('4', '2182', 2),
  ('4', '2214', 2),
  ('4', '1620', 2),
  ('4', '2192', 2),
  ('4', '2223', 2),
  ('4', '2521', 2),
  ('5', '419a', 2),
  ('5', '594', 2),
  ('5', '1778', 2),
  ('5', '1799', 2),
  ('5', '1773', 2),
  ('5', '1779', 2),
  ('5', '741a', 2),
  ('5', '602a', 2),
  ('5', '620a', 2),
  ('5', '683', 2),
  ('5', '516a', 2),
  ('5', '1954a', 2),
  ('5', '1955', 2),
  ('5', '1956', 2),
  ('1887', '1887', 2),
  ('2585', '2585', 2);
GO
--

--
INSERT INTO wells (name, platform_id)
VALUES
  ('794',15),
  ('795',15),
  ('819',15),
  ('966',16),
  ('977',16),
  ('1738',17),
  ('1939',18),
  ('1943',18),
  ('2149',19),
  ('2150',19),
  ('2151',19),
  ('2152',19),
  ('2153',19),
  ('2156',19),
  ('2157',19),
  ('2158',19),
  ('2159',19),
  ('2160',19),
  ('2161',19),
  ('2162',19),
  ('2165',17),
  ('2166',17),
  ('2167',17),
  ('2169',17),
  ('2180',17),
  ('2209',17),
  ('2210',17),
  ('2213',17),
  ('2293',17),
  ('2339',20),
  ('2346',21),
  ('2347',21),
  ('2349',21),
  ('2350',21),
  ('2352',21),
  ('2354',21),
  ('2358',20),
  ('2360',21),
  ('2361',20),
  ('2364',19),
  ('2366',19),
  ('2376',20),
  ('2383',20),
  ('2385',20),
  ('2386',20),
  ('2414',20),
  ('2415',22),
  ('2416',17),
  ('2417',21),
  ('2418',21),
  ('2419',21),
  ('2420',22),
  ('2421',22),
  ('2422',22),
  ('2423',22),
  ('2425',17),
  ('2426',22),
  ('2427',17),
  ('2428',22),
  ('2429',22),
  ('2430',22),
  ('2432',22),
  ('2442',22),
  ('2444',22),
  ('2498',20),
  ('2499',20),
  ('2503',20),
  ('2559',20),
  ('2560',20),
  ('2565',21),
  ('2566',21),
  ('2567',21),
  ('2568',21),
  ('2569',21),
  ('2570',23),
  ('2571',23),
  ('2572',23),
  ('2573',21),
  ('2574',23),
  ('2575',23),
  ('2576',23),
  ('2577',23),
  ('2578',23),
  ('61',24),
  ('1747',25),
  ('1907',25),
  ('1920',25),
  ('1929',25),
  ('1948',25),
  ('1980',25),
  ('1985',25),
  ('2048',25),
  ('2073',25),
  ('2079',25),
  ('2473',25),
  ('2474',25),
  ('2475',25),
  ('2476',25),
  ('2492',25),
  ('2493',25),
  ('2506',25),
  ('2507',25),
  ('2508',25),
  ('2609',26),
  ('2610',26),
  ('testA',26),
  ('2611',26),
  ('2612',26),
  ('2613',26),
  ('testB',26),
  ('2614',26),
  ('2615',26),
  ('2616',26),
  ('2617',26),
  ('2618',26),
  ('2631',26),
  ('2632',26),
  ('2633',26),
  ('2634',26),
  ('1845',27),
  ('2013',27),
  ('2014',27),
  ('2015',27),
  ('2020',27),
  ('2040',27),
  ('2041',27),
  ('2042',27),
  ('2043',27),
  ('1645',28),
  ('1783',28),
  ('1869',28),
  ('1952',28),
  ('2035',28),
  ('2037',28),
  ('2038',28),
  ('2088',29),
  ('M-1',30),
  ('1870',30),
  ('1732',30),
  ('1713',31),
  ('1669',31),
  ('1668',31),
  ('2063',31),
  ('1712',32),
  ('1716',32),
  ('1718',32),
  ('1784',32),
  ('1856',33),
  ('1923',33),
  ('1924',33),
  ('1998',33),
  ('2067',34),
  ('2068',34),
  ('2069',34),
  ('2076',34),
  ('2144',34),
  ('347',35),
  ('348',35),
  ('1725',35),
  ('1884',35),
  ('1922',35),
  ('1925',35),
  ('1997',35),
  ('2000',35),
  ('115',24),
  ('2057',30),
  ('2058',30),
  ('1921',35),
  ('1555',36),
  ('1769',36),
  ('1706',37),
  ('1563',36),
  ('1724',36),
  ('2001',38),
  ('2021',38),
  ('2022',38),
  ('469',39),
  ('2023',38),
  ('2027',38),
  ('1302',40),
  ('1303',40),
  ('1305',40),
  ('1321',40),
  ('1171',41),
  ('1172',41),
  ('1300',41),
  ('1301',41),
  ('1308',42),
  ('1310',42),
  ('1311',42),
  ('1309',43),
  ('1316',43),
  ('1255',44),
  ('1256',44),
  ('1258',44),
  ('1284',44),
  ('1285',44),
  ('1322',44),
  ('1355',44),
  ('1267',44),
  ('1323',44),
  ('1044',45),
  ('1045',45),
  ('1049',45),
  ('1074',45),
  ('1075',45),
  ('1113',46),
  ('1129',46),
  ('1130',46),
  ('1133',46),
  ('1134',46),
  ('1208',46),
  ('1209',46),
  ('1210',46),
  ('1100',47),
  ('1123',47),
  ('1147',47),
  ('1148',47),
  ('1149',47),
  ('1150',47),
  ('1161',47),
  ('1215',47),
  ('1216',47),
  ('1223',47),
  ('1294',47),
  ('1214',47),
  ('1195',47),
  ('1073',48),
  ('1137',48),
  ('1140',48),
  ('1141',48),
  ('1143',48),
  ('1151',48),
  ('1174',48),
  ('1176',48),
  ('1199',48),
  ('1217',48),
  ('1218',48),
  ('1239',48),
  ('1185',49),
  ('1244',49),
  ('1254',49),
  ('1265',49),
  ('1277',49),
  ('1276',49),
  ('1236',49),
  ('1145',50),
  ('1156',50),
  ('1158',50),
  ('1159',50),
  ('1175',50),
  ('1177',50),
  ('1184',50),
  ('1186',50),
  ('1187',50),
  ('1196',50),
  ('1205',50),
  ('1206',50),
  ('1234',50),
  ('1251',50),
  ('1282',50),
  ('1153',50),
  ('1280',51),
  ('1281',51),
  ('1324',51),
  ('1325',51),
  ('1326',51),
  ('1327',51),
  ('1328',51),
  ('1329',51),
  ('1330',51),
  ('1331',51),
  ('1335',51),
  ('1333',51),
  ('1334',51),
  ('1332',51),
  ('1178',52),
  ('1179',52),
  ('1183',52),
  ('1249',52),
  ('1261',52),
  ('1269',52),
  ('1270',52),
  ('1273',52),
  ('1336',53),
  ('1338',53),
  ('1339',53),
  ('1340',53),
  ('1341',53),
  ('1345',53),
  ('1346',53),
  ('1347',53),
  ('1349',53),
  ('1344',53),
  ('99',54),
  ('113',54),
  ('312',54),
  ('1677',54),
  ('1675',54),
  ('147',54),
  ('2635',55),
  ('2636',55),
  ('2638',55),
  ('2639',55),
  ('2637',55),
  ('2640',55),
  ('2641',55),
  ('2642',55),
  ('2657',55),
  ('2658',55),
  ('2659',55),
  ('2660',55),
  ('2661',55),
  ('2662',55),
  ('2469',55),
  ('2470',55),
  ('2471',55),
  ('2472',55),
  ('1931',56),
  ('1932',56),
  ('2619',57),
  ('2620',57),
  ('2643',57),
  ('2644',57),
  ('2645',57),
  ('2646',57),
  ('2647',57),
  ('2648',57),
  ('2649',57),
  ('2650',57),
  ('2651',57),
  ('2652',57),
  ('2653',57),
  ('2654',57),
  ('2655',57),
  ('2656',57),
  ('1852',58),
  ('1858',58),
  ('1861',58),
  ('2024',58),
  ('2182',59),
  ('2183',59),
  ('2184',59),
  ('2099',59),
  ('2188',59),
  ('2185',59),
  ('2186',59),
  ('2187',59),
  ('2296',59),
  ('2306',59),
  ('2387',59),
  ('2214',60),
  ('2215',60),
  ('2216',60),
  ('2218',60),
  ('2305',60),
  ('2222',60),
  ('1620',61),
  ('1625',61),
  ('1650',61),
  ('1659',61),
  ('1673',61),
  ('1798',61),
  ('1860',61),
  ('2192',62),
  ('2198',62),
  ('2390',62),
  ('2193',62),
  ('2194',62),
  ('2195',62),
  ('2197',62),
  ('2199',62),
  ('2202',62),
  ('2392',62),
  ('2200',63),
  ('2191',63),
  ('2223',63),
  ('2224',63),
  ('2225',63),
  ('2227',63),
  ('2239',64),
  ('2256',64),
  ('2521',64),
  ('2522',64),
  ('2523',64),
  ('2524',64),
  ('2525',64),
  ('2526',64),
  ('2527',64),
  ('2528',64),
  ('2529',64),
  ('2530',64),
  ('2532',64),
  ('2533',64),
  ('2534',64),
  ('1788',65),
  ('1801',65),
  ('2034',65),
  ('2045',65),
  ('1787',65),
  ('519',66),
  ('520',66),
  ('595',66),
  ('656',66),
  ('1778',67),
  ('1972',67),
  ('1875',68),
  ('1976',68),
  ('1973',68),
  ('1773',69),
  ('1967',69),
  ('1969',69),
  ('1978',69),
  ('2134',70),
  ('2135',70),
  ('2136',70),
  ('2137',70),
  ('2138',70),
  ('2139',70),
  ('2142',70),
  ('2143',70),
  ('2145',70),
  ('2147',70),
  ('2483',70),
  ('2484',70),
  ('2485',70),
  ('2486',70),
  ('2487',70),
  ('2488',70),
  ('2301',71),
  ('2317',71),
  ('2318',71),
  ('2319',71),
  ('2320',71),
  ('2321',71),
  ('2333',71),
  ('2335',71),
  ('2396',71),
  ('2302',71),
  ('2397',71),
  ('2316',71),
  ('2451',72),
  ('2452',72),
  ('2605',72),
  ('2606',72),
  ('2607',72),
  ('2608',72),
  ('2663',72),
  ('2664',72),
  ('2665',72),
  ('2666',72),
  ('2667',72),
  ('2668',72),
  ('2669',72),
  ('2670',72),
  ('2671',72),
  ('2672',72),
  ('2673',72),
  ('2674',72),
  ('2675',72),
  ('2676',72),
  ('2561',73),
  ('2562',73),
  ('2563',73),
  ('2564',73),
  ('2621',73),
  ('2622',73),
  ('2623',73),
  ('2624',73),
  ('2625',73),
  ('2626',73),
  ('2627',73),
  ('2628',73),
  ('2629',73),
  ('2630',73),
  ('636',74),
  ('842',74),
  ('1700',74),
  ('1701',74),
  ('1782',74),
  ('1991',74),
  ('683',74),
  ('1736',75),
  ('1827',75),
  ('2080',75),
  ('2244',75),
  ('2248',75),
  ('2273',75),
  ('1752',75),
  ('2078',75),
  ('1863',75),
  ('2494',76),
  ('2495',76),
  ('2496',76),
  ('2497',76),
  ('2681',76),
  ('2682',76),
  ('2683',76),
  ('2684',76),
  ('2685',76),
  ('2686',76),
  ('2687',76),
  ('2688',76),
  ('2689',76),
  ('2690',76),
  ('1749',77),
  ('1877',77),
  ('1965',77),
  ('2004',77),
  ('1961',77),
  ('1962',77),
  ('1874',78),
  ('1963',78),
  ('1964',78),
  ('2031',78),
  ('2032',78),
  ('2033',78),
  ('1617',79),
  ('1795',79),
  ('1813a',79),
  ('1846',79),
  ('1865',79),
  ('1878',79),
  ('1887',79),
  ('1888a',79),
  ('1898a',79),
  ('1908a',79),
  ('2118',79),
  ('2119b',79),
  ('2122a',79),
  ('2124',79),
  ('2181',79),
  ('2206',79),
  ('2211',79),
  ('2226a',79),
  ('2271',79),
  ('2279',79),
  ('2280a',79),
  ('2282',79),
  ('2283',79),
  ('2284',79),
  ('2285',79),
  ('2286',79),
  ('2287',79),
  ('2288',79),
  ('2290',79),
  ('2291',79),
  ('2292',79),
  ('2294',79),
  ('2295',79),
  ('2297',79),
  ('2677',79),
  ('2678',79),
  ('2679',79),
  ('2680',79),
  ('2579',80),
  ('2580',80),
  ('2581a',80),
  ('2582',80),
  ('2583',80),
  ('2584a',80),
  ('2585',80),
  ('2586a',80),
  ('2587',80),
  ('2588a',80),
  ('2589',80),
  ('2590',80),
  ('2591',80),
  ('2592',80),
  ('2593',80),
  ('2594',80),
  ('2595',80),
  ('2596',80),
  ('2597',80),
  ('2598',80),
  ('2599',80),
  ('2600',80),
  ('2601',80),
  ('2602',80),
  ('2603a',80),
  ('2604',80);
GO
--

--
DELETE FROM horizons
WHERE id in (1, 4, 5, 6, 14, 15, 16, 17, 20, 21, 23, 24, 25, 26, 27, 28, 29, 32);
GO

UPDATE horizons
SET oil_density = 0.754
WHERE name = 'Sabunçu_III' AND field_id = 1
GO

UPDATE horizons
SET oil_density = 0.755
WHERE name = 'Sabunçu_IV' AND field_id = 1
GO

UPDATE horizons
SET oil_density = 0.753
WHERE name = 'BLD_V' AND field_id = 1
GO

UPDATE horizons
SET oil_density = 0.733
WHERE name = 'BLD_VI' AND field_id = 1
GO

UPDATE horizons
SET oil_density = 0.76
WHERE name = 'BLD_VII' AND field_id = 1
GO

UPDATE horizons
SET oil_density = 0.9
WHERE name = 'BLD_VIII' AND field_id = 1
GO

UPDATE horizons
SET oil_density = 0.873
WHERE name = 'BLD_IX' AND field_id = 1
GO

UPDATE horizons
SET oil_density = 0.861
WHERE name = 'BLD_X' AND field_id = 1
GO

UPDATE horizons
SET oil_density = 0.867
WHERE name = 'BLD_X+BLD_IX' AND field_id = 1
GO

UPDATE horizons
SET oil_density = 0.855
WHERE name = 'FLD' AND field_id = 1
GO

UPDATE horizons
SET oil_density = 0.858
WHERE name = 'FLD+BLD_X' AND field_id = 1
GO

UPDATE horizons
SET oil_density = 0.851
WHERE name = 'QÜQ' AND field_id = 1
GO

UPDATE horizons
SET oil_density = 0.881
WHERE name = 'BLD_X+BLD_VIII' AND field_id = 1
GO

UPDATE horizons
SET oil_density = 0.872
WHERE name = 'QA+QÜQ' AND field_id = 1
GO

INSERT INTO horizons (name, field_id, oil_density)
VALUES
  (N'BLD_VIII+BLD_VII', 1, 0.873),
  (N'BLD_VII', 2, 0.86),
  (N'BLD_VIIa', 2, 0.86),
  (N'BLD_VIII', 2, 0.86),
  (N'QÜQ', 2, 0.86),
  (N'BLD_X', 2, 0.86),
  (N'FLD', 2, 0.86),
  (N'QÜG', 2, 0.86),
  (N'BLD_IX', 2, 0.86),
  (N'QaLD-1', 2, 0.86),
  (N'QA-2ü', 2, 0.86),
  (N'QD-2', 2, 0.86),
  (N'QaLD-3', 2, 0.86),
  (N'QA-1', 2, 0.86),
  (N'QalD-2', 2, 0.86),
  (N'QA-2y', 2, 0.86),
  (N'FLD+X', 2, 0.86),
  (N'BLD_VI+BLD_V', 2, 0.86),
  (N'BLD_V', 2, 0.86),
  (N'BLD_VI', 2, 0.86),
  (N'QD-1', 2, 0.86),
  (N'QA-2a', 2, 0.86),
  (N'QA-1y', 2, 0.86),
  (N'QA-2a/2y', 2, 0.86),
  (N'QA-1y/QD-2', 2, 0.86),
  (N'QA-1/1y', 2, 0.86),
  (N'QA-1a', 2, 0.86),
  (N'QA-2a,QA-1', 2, 0.86),
  (N'QD-1+2', 2, 0.86),
  (N'QD2+1', 2, 0.86),
  (N'BLD_VII+BLD_VI', 2, 0.86),
  (N'QA-3', 2, 0.86),
  (N'BLD_VIIa+BLD_VII', 2, 0.86),
  (N'BLD_IV', 2, 0.86),
  (N'QaLD-3', 3, 0.86),
  (N'QaLD-1', 3, 0.86),
  (N'QA-2', 3, 0.86),
  (N'QaLD-2', 3, 0.86),
  (N'QaLD-4', 3, 0.86),
  (N'QÜQ', 3, 0.86),
  (N'QD-5', 3, 0.86),
  (N'FLD', 3, 0.86),
  (N'QÜG', 3, 0.86),
  (N'QD-3', 3, 0.86),
  (N'QD-4', 3, 0.86),
  (N'QA-1', 3, 0.86),
  (N'QA-3', 3, 0.86);
GO
--

--
DROP PROCEDURE DeleteTodayEntries;
GO
DROP PROCEDURE DeleteAllEntries;
GO
DROP PROCEDURE DeleteEntries;
GO

CREATE PROCEDURE DeleteTodayEntries
AS
BEGIN
    DELETE FROM flowmeters WHERE CAST(created_at AS DATE) = CAST(GETDATE() AS DATE);
    DELETE FROM well_stock WHERE CAST(created_at AS DATE) = CAST(GETDATE() AS DATE);
    DELETE FROM completions WHERE CAST(created_at AS DATE) = CAST(GETDATE() AS DATE);
    DELETE FROM well_downtime_reasons WHERE CAST(created_at AS DATE) = CAST(GETDATE() AS DATE);
    DELETE FROM daily_well_parameters WHERE CAST(created_at AS DATE) = CAST(GETDATE() AS DATE);
    DELETE FROM well_tests WHERE CAST(created_at AS DATE) = CAST(GETDATE() AS DATE);
    DELETE FROM gas_well_tests WHERE CAST(created_at AS DATE) = CAST(GETDATE() AS DATE);
    DELETE FROM laboratory_results WHERE CAST(created_at AS DATE) = CAST(GETDATE() AS DATE);
    DELETE FROM daily_general_comments WHERE CAST(created_at AS DATE) = CAST(GETDATE() AS DATE);
END;
GO

CREATE PROCEDURE DeleteAllEntries
AS
BEGIN
    TRUNCATE TABLE flowmeters;
    TRUNCATE TABLE well_stock;
    TRUNCATE TABLE completions;
    TRUNCATE TABLE well_downtime_reasons;
    TRUNCATE TABLE daily_well_parameters;
    TRUNCATE TABLE well_tests;
    TRUNCATE TABLE gas_well_tests;
    TRUNCATE TABLE laboratory_results;
    TRUNCATE TABLE daily_general_comments;
END;
GO

CREATE PROCEDURE DeleteEntries
    @reportDate DATE,
    @platform INT
AS
BEGIN
    DECLARE @reportDateId INT;

    SELECT @reportDateId = rd.id
    FROM report_dates AS rd
    WHERE rd.report_date = @reportDate;

    DELETE flowmeters
    FROM flowmeters
    INNER JOIN platforms ON flowmeters.platform_id = platforms.id
    WHERE report_date_id = @reportDateId AND (platforms.name = @platform OR @platform IS NULL);

    DELETE well_stock
    FROM well_stock
    INNER JOIN wells ON well_stock.well_id = wells.id
    INNER JOIN platforms ON wells.platform_id = platforms.id
    WHERE report_date_id = @reportDateId AND (platforms.name = @platform OR @platform IS NULL);

    DELETE completions
    FROM completions
    INNER JOIN wells ON completions.well_id = wells.id
    INNER JOIN platforms ON wells.platform_id = platforms.id
    WHERE report_date_id = @reportDateId AND (platforms.name = @platform OR @platform IS NULL);

    DELETE well_downtime_reasons
    FROM well_downtime_reasons
    INNER JOIN wells ON well_downtime_reasons.well_id = wells.id
    INNER JOIN platforms ON wells.platform_id = platforms.id
    WHERE report_date_id = @reportDateId AND (platforms.name = @platform OR @platform IS NULL);

    DELETE daily_well_parameters
    FROM daily_well_parameters
    INNER JOIN wells ON daily_well_parameters.well_id = wells.id
    INNER JOIN platforms ON wells.platform_id = platforms.id
    WHERE report_date_id = @reportDateId AND (platforms.name = @platform OR @platform IS NULL);

    DELETE well_tests
    FROM well_tests
    INNER JOIN wells ON well_tests.well_id = wells.id
    INNER JOIN platforms ON wells.platform_id = platforms.id
    WHERE report_date_id = @reportDateId AND (platforms.name = @platform OR @platform IS NULL);

    DELETE gas_well_tests
    FROM gas_well_tests
    INNER JOIN wells ON gas_well_tests.well_id = wells.id
    INNER JOIN platforms ON wells.platform_id = platforms.id
    WHERE report_date_id = @reportDateId AND (platforms.name = @platform OR @platform IS NULL);

    DELETE laboratory_results
    FROM laboratory_results
    INNER JOIN wells ON laboratory_results.well_id = wells.id
    INNER JOIN platforms ON wells.platform_id = platforms.id
    WHERE report_date_id = @reportDateId AND (platforms.name = @platform OR @platform IS NULL);

    DELETE daily_general_comments
    FROM daily_general_comments
    INNER JOIN platforms ON daily_general_comments.platform = platforms.name
    WHERE report_date_id = @reportDateId AND (platforms.name = @platform OR @platform IS NULL);
END;
GO
--