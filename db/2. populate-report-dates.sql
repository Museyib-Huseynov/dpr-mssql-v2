DECLARE @start_date DATE = '2024-01-01';
DECLARE @end_date DATE = '2030-01-01';

WHILE @start_date <= @end_date
BEGIN
    INSERT INTO report_dates (report_date) VALUES (@start_date);
    SET @start_date = DATEADD(DAY, 1, @start_date);
END