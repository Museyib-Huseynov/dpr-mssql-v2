CREATE DATABASE dpr;  
GO  

USE dpr; 
GO 

CREATE TABLE ogpd (  
  id INT PRIMARY KEY IDENTITY(1,1),  
  name NVARCHAR(255) NOT NULL,  
  CONSTRAINT UQ_ogpd UNIQUE (name)  
);  
GO

CREATE TABLE fields (  
  id INT PRIMARY KEY IDENTITY(1,1),  
  name NVARCHAR(255) NOT NULL,  
  ogpd_id INT NOT NULL,
  CONSTRAINT FK_f_ogpdId FOREIGN KEY (ogpd_id) REFERENCES dbo.ogpd(id),
  CONSTRAINT UQ_field UNIQUE (name, ogpd_id)
);  
GO

CREATE INDEX IDX_f_ogpdId ON dbo.fields(ogpd_id);
GO

CREATE TABLE platforms (
	id INT PRIMARY KEY IDENTITY(1,1),  
  name INT NOT NULL,  
  field_id INT NOT NULL,
	CONSTRAINT FK_p_fieldId FOREIGN KEY (field_id) REFERENCES dbo.fields(id),
	CONSTRAINT UQ_platform UNIQUE (name, field_id)
);
GO

CREATE INDEX IDX_p_fieldId ON dbo.platforms(field_id);
GO

CREATE TABLE wells (
	id INT PRIMARY KEY IDENTITY(1,1),  
	name NVARCHAR(255) NOT NULL,  
	platform_id INT NOT NULL,
	CONSTRAINT FK_w_platformId FOREIGN KEY (platform_id) REFERENCES dbo.platforms(id),
	CONSTRAINT UQ_well UNIQUE (name, platform_id)
);
GO

CREATE INDEX IDX_w_platformId ON dbo.wells(platform_id);
GO

CREATE TABLE horizons (
	id INT PRIMARY KEY IDENTITY(1,1),  
	name NVARCHAR(255) NOT NULL,  
	CONSTRAINT UQ_horizon UNIQUE (name)
);
GO

CREATE TABLE well_stock_categories (
  id INT PRIMARY KEY IDENTITY(1,1),  
	name NVARCHAR(255) NOT NULL,  
  CONSTRAINT UQ_wellStockCategory UNIQUE (name)
);
GO

CREATE TABLE well_stock_sub_categories (
  id INT PRIMARY KEY IDENTITY(1,1),  
	name NVARCHAR(255) NOT NULL,  
  CONSTRAINT UQ_wellStockSubCategory UNIQUE (name)
);
GO

CREATE TABLE production_well_stock_sub_categories (
	id INT PRIMARY KEY IDENTITY(1,1),  
	name NVARCHAR(255) NOT NULL,  
	CONSTRAINT UQ_productionWellStockSubCategory UNIQUE (name)
);
GO

CREATE TABLE production_methods (
	id INT PRIMARY KEY IDENTITY(1,1),  
	name NVARCHAR(255) NOT NULL,  
	CONSTRAINT UQ_productionMethod UNIQUE (name)
);
GO

CREATE TABLE production_skins (
	id INT PRIMARY KEY IDENTITY(1,1),  
	name NVARCHAR(255) NOT NULL,  
	CONSTRAINT UQ_productionSkin UNIQUE (name)
);
GO

CREATE TABLE production_sub_skins (
	id INT PRIMARY KEY IDENTITY(1,1),  
	name NVARCHAR(255) NOT NULL,  
	production_skin_id INT NOT NULL,
	CONSTRAINT FK_pss_productionSkinId FOREIGN KEY (production_skin_id) REFERENCES dbo.production_skins(id),
	CONSTRAINT UQ_productionSubSkin UNIQUE (name, production_skin_id)
);
GO

CREATE INDEX IDX_pss_productionSkinId ON dbo.production_sub_skins(production_skin_id);
GO

CREATE TABLE production_sub_skins_activities (
	id INT PRIMARY KEY IDENTITY(1,1),  
	name NVARCHAR(255) NOT NULL,  
	production_sub_skin_id INT NOT NULL,
	CONSTRAINT FK_pssa_productionSubSkinId FOREIGN KEY (production_sub_skin_id) REFERENCES dbo.production_sub_skins(id),
	CONSTRAINT UQ_productionSubSkinsActivity UNIQUE (name, production_sub_skin_id)
);
GO

CREATE INDEX IDX_pssa_productionSubSkinId ON dbo.production_sub_skins_activities(production_sub_skin_id);
GO

CREATE TABLE report_dates (
	id INT PRIMARY KEY IDENTITY(1,1),  
	report_date DATE NOT NULL,  
	CONSTRAINT UQ_reportDate UNIQUE (report_date)
);
GO

CREATE TABLE well_stock (
	id INT PRIMARY KEY IDENTITY(1,1),  
	well_id INT NOT NULL,
	report_date_id INT NOT NULL,
	well_stock_category_id INT,
	well_stock_sub_category_id INT,
	production_well_stock_sub_category_id INT,
	production_method_id INT,
	created_at DATE DEFAULT GETDATE(),
	CONSTRAINT FK_ws_wellId FOREIGN KEY (well_id) REFERENCES dbo.wells(id),
	CONSTRAINT FK_ws_reportDateId FOREIGN KEY (report_date_id) REFERENCES dbo.report_dates(id),
	CONSTRAINT FK_ws_wellStockCategoryId FOREIGN KEY (well_stock_category_id) REFERENCES dbo.well_stock_categories(id),
	CONSTRAINT FK_ws_wellStockSubCategoryId FOREIGN KEY (well_stock_sub_category_id) REFERENCES dbo.well_stock_sub_categories(id),
	CONSTRAINT FK_ws_productionWellStockSubCategoryId FOREIGN KEY (production_well_stock_sub_category_id) REFERENCES dbo.production_well_stock_sub_categories(id),
	CONSTRAINT FK_ws_productionMethodId FOREIGN KEY (production_method_id) REFERENCES dbo.production_methods(id),
	CONSTRAINT UQ_wellStock UNIQUE (well_id, report_date_id)
);
GO

CREATE INDEX IDX_ws_wellId ON dbo.well_stock(well_id);
GO

CREATE INDEX IDX_ws_reportDateId ON dbo.well_stock(report_date_id);
GO

CREATE INDEX IDX_ws_wellStockCategoryId ON dbo.well_stock(well_stock_category_id);
GO

CREATE INDEX IDX_ws_wellStockSubCategoryId ON dbo.well_stock(well_stock_sub_category_id);
GO

CREATE INDEX IDX_ws_productionWellStockSubCategoryId ON dbo.well_stock(production_well_stock_sub_category_id);
GO

CREATE INDEX IDX_ws_productionMethodId ON dbo.well_stock(production_method_id);
GO

CREATE TABLE completions (
  id INT PRIMARY KEY IDENTITY(1,1),
  well_id INT NOT NULL,
  report_date_id INT NOT NULL,
  horizon_id INT,
  casing NVARCHAR(255),
  completion_interval NVARCHAR(255),
  tubing1_depth NVARCHAR(255),
  tubing1_length NVARCHAR(255),
  tubing2_depth NVARCHAR(255),
  tubing2_length NVARCHAR(255),
  tubing3_depth NVARCHAR(255),
  tubing3_length NVARCHAR(255),
  packer_depth NVARCHAR(255),
  created_at DATE DEFAULT GETDATE(),
  CONSTRAINT FK_c_wellId FOREIGN KEY (well_id) REFERENCES dbo.wells(id),
  CONSTRAINT FK_c_reportDateId FOREIGN KEY (report_date_id) REFERENCES dbo.report_dates(id),
  CONSTRAINT FK_c_horizonId FOREIGN KEY (horizon_id) REFERENCES dbo.horizons(id),
  CONSTRAINT UQ_completion UNIQUE (well_id, report_date_id)
);
GO

CREATE INDEX IDX_c_wellId ON dbo.completions(well_id);
GO

CREATE INDEX IDX_c_reportDateId ON dbo.completions(report_date_id);
GO

CREATE INDEX IDX_c_horizonId ON dbo.completions(horizon_id);
GO

CREATE TABLE well_tests (
  id INT PRIMARY KEY IDENTITY(1,1),
  well_id INT NOT NULL,
  report_date_id INT NOT NULL,
  well_test_date DATE NOT NULL,
  choke NVARCHAR(255),
  pqa NVARCHAR(255),
  phf NVARCHAR(255),
  pba NVARCHAR(255),
  p6x9 NVARCHAR(255),
  p9x13 NVARCHAR(255),
  p13x20 NVARCHAR(255),
  liquid_ton FLOAT,
  total_gas FLOAT,
  gaslift_gas FLOAT,
  reported_water_cut FLOAT,
  water_cut FLOAT,
  mechanical_impurities FLOAT,
  oil_density FLOAT,
  created_at DATE DEFAULT GETDATE(),
  CONSTRAINT FK_wt_wellId FOREIGN KEY (well_id) REFERENCES dbo.wells(id),
  CONSTRAINT FK_wt_reportDateId FOREIGN KEY (report_date_id) REFERENCES dbo.report_dates(id),
  CONSTRAINT UQ_wellTest UNIQUE (well_id, well_test_date)
);
GO

CREATE INDEX IDX_wt_wellId ON dbo.well_tests(well_id);
GO

CREATE INDEX IDX_wt_reportDateId ON dbo.well_tests(report_date_id);
GO

CREATE TABLE daily_well_parameters (
  id INT PRIMARY KEY IDENTITY(1,1),
  well_id INT NOT NULL,
  report_date_id INT NOT NULL,
  flowmeter INT,
  well_uptime_hours FLOAT,
  choke NVARCHAR(255),
  pqa NVARCHAR(255),
  phf NVARCHAR(255),
  pba NVARCHAR(255),
  p6x9 NVARCHAR(255),
  p9x13 NVARCHAR(255),
  p13x20 NVARCHAR(255),
  liquid_ton FLOAT,
  total_gas FLOAT,
  gaslift_gas FLOAT,
  reported_water_cut FLOAT,
  water_cut FLOAT,
  mechanical_impurities FLOAT,
  oil_density FLOAT,
  oil_loss_ton FLOAT,
  created_at DATE DEFAULT GETDATE(),
  CONSTRAINT FK_dwp_wellId FOREIGN KEY (well_id) REFERENCES dbo.wells(id),
  CONSTRAINT FK_dwp_reportDateId FOREIGN KEY (report_date_id) REFERENCES dbo.report_dates(id),
  CONSTRAINT UQ_dailyWellParameter UNIQUE (well_id, report_date_id)
);
GO

CREATE INDEX IDX_dwp_wellId ON dbo.daily_well_parameters(well_id);
GO

CREATE INDEX IDX_dwp_reportDateId ON dbo.daily_well_parameters(report_date_id);
GO

CREATE TABLE laboratory_results (
  id INT PRIMARY KEY IDENTITY(1,1),
  well_id INT NOT NULL,
  report_date_id INT NOT NULL,
  last_lab_date DATE,
  water_cut FLOAT,
  mechanical_impurities FLOAT,
  created_at DATE DEFAULT GETDATE(),
  CONSTRAINT FK_lr_wellId FOREIGN KEY (well_id) REFERENCES dbo.wells(id),
  CONSTRAINT FK_lr_reportDateId FOREIGN KEY (report_date_id) REFERENCES dbo.report_dates(id),
  CONSTRAINT UQ_laboratoryResult UNIQUE (well_id, last_lab_date)
);
GO

CREATE INDEX IDX_lr_wellId ON dbo.laboratory_results(well_id);
GO

CREATE INDEX IDX_lr_report_date_id ON dbo.laboratory_results(report_date_id);
GO

CREATE TABLE well_downtime_reasons (
  id INT PRIMARY KEY IDENTITY(1,1),
  well_id INT NOT NULL,
  report_date_id INT NOT NULL,
  downtime_category NVARCHAR(255),
  production_sub_skins_activity_id INT,
  comments NVARCHAR(MAX),
  created_at DATE DEFAULT GETDATE(),
  CONSTRAINT FK_wdr_wellId FOREIGN KEY (well_id) REFERENCES dbo.wells(id),
  CONSTRAINT FK_wdr_reportDateId FOREIGN KEY (report_date_id) REFERENCES dbo.report_dates(id),
  CONSTRAINT FK_wdr_productionSubSkinsActivityId FOREIGN KEY (production_sub_skins_activity_id) REFERENCES dbo.production_sub_skins_activities(id),
  CONSTRAINT UQ_wellDowntimeReason UNIQUE (well_id, report_date_id)
);
GO

CREATE INDEX IDX_wdr_wellId ON dbo.well_downtime_reasons(well_id);
GO

CREATE INDEX IDX_wdr_reportDateId ON dbo.well_downtime_reasons(report_date_id);
GO

CREATE INDEX IDX_wdr_productionSubSkinsActivityId ON dbo.well_downtime_reasons(production_sub_skins_activity_id);
GO

CREATE TABLE flowmeters (
  id INT PRIMARY KEY IDENTITY(1,1),
  platform_id INT NOT NULL,
  report_date_id INT NOT NULL,
  reading1 INT,
  reading2 INT,
  reading3 INT,
  reading4 INT,
  calibration_date DATE,
  created_at DATE DEFAULT GETDATE(),
  CONSTRAINT FK_f_platformId FOREIGN KEY (platform_id) REFERENCES dbo.platforms(id),
  CONSTRAINT FK_f_reportDateId FOREIGN KEY (report_date_id) REFERENCES dbo.report_dates(id),
  CONSTRAINT UQ_flowmeter UNIQUE (platform_id, report_date_id)
);
GO

CREATE INDEX IDX_f_platformId ON dbo.flowmeters(platform_id);
GO

CREATE INDEX IDX_f_reportDateId ON dbo.flowmeters(report_date_id);
GO

CREATE TABLE daily_operatives (
  id INT PRIMARY KEY IDENTITY(1,1),
  field_id INT NOT NULL,
  report_date_id INT NOT NULL,
  oil_ton FLOAT,
  water_ton FLOAT,
  created_at DATE DEFAULT GETDATE(),
  CONSTRAINT FK_do_fieldId FOREIGN KEY (field_id) REFERENCES fields(id),
  CONSTRAINT FK_do_reportDateId FOREIGN KEY (report_date_id) REFERENCES report_dates(id),
  CONSTRAINT UQ_dailyOperative UNIQUE (field_id, report_date_id)
);
GO

CREATE INDEX IDX_do_fieldId ON dbo.daily_operatives(field_id);
GO

CREATE INDEX IDX_do_reportDateId ON dbo.daily_operatives(report_date_id);
GO