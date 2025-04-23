import mssql from 'mssql';

let pool;
try {
  pool = await mssql.connect(
    'Server=localhost,1433;Database=dpr;User Id=museyib;Password=3231292;Encrypt=false'
  );
  await pool.request().execute('DeleteAllEntries');
  console.log('DELETED!');
} catch (error) {
  console.log('Database error:', error);
} finally {
  if (pool) {
    await pool.close();
  }
}
