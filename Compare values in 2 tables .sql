
-- PARAMETERS - update manualy

DECLARE
	@BaseDB				AS NVARCHAR(MAX),
	@BaseTable			AS NVARCHAR(MAX),
	
	@CompareDB			AS NVARCHAR(MAX),
	@CompareTable		AS NVARCHAR(MAX),

	@KeyColumns			AS NVARCHAR(MAX),
	@IgnoredColumns		AS NVARCHAR(MAX),
	@WhereConditions	AS NVARCHAR(MAX)

SET @BaseDB = N'db_Test'
SET @BaseTable = N'Import'
	
SET @CompareDB = N'db_Dev'
SET @CompareTable = N'Import'

SET @KeyColumns =N'''PK_Import'', ''Cust_Id'''--, ''SourceRows'',''zuPSPName'''
SET @IgnoredColumns =N'''PK_Import'''										-- Examples: (N'''ID'',''PK_Import''')
SET @WhereConditions = N'[importDate] = ''2024-03-15'' and [Cust_Id] = 1'	-- Examples: (NULL -> no conditions,	N'[COI] = ''Sum''',		N'[Service name] like ''%service%''')


print '@KeyColumns:'+char(10)+char(9)+@KeyColumns
print '@IgnoredColumns:'+char(10)+char(9)+@IgnoredColumns
print '@WhereConditions:'+char(10)+char(9)+@WhereConditions

-- PARAMETERS
DROP TABLE IF EXISTS #Param
CREATE TABLE #Param (KeyColumns nvarchar(255), IgnoredColumns nvarchar(255), WhereConditions nvarchar(255))
INSERT INTO #Param (KeyColumns, IgnoredColumns, WhereConditions) VALUES (@KeyColumns, @IgnoredColumns, @WhereConditions)
SELECT WhereConditions FROM #Param 


-- CALCULATION - don't touch below !!!

DECLARE 
	@Query				AS NVARCHAR(MAX),
	@ParamsDefinition	AS NVARCHAR(MAX),
	@Result				AS NVARCHAR(MAX),

	@BaseTableFull		AS NVARCHAR(MAX),
	@BaseSysColumns		AS SYSNAME,
	@BaseSysTypes		AS SYSNAME,

	@CompareTableFull	AS NVARCHAR(MAX),
	@CompareSysColumns	AS SYSNAME,
	@CompareSysTypes	AS SYSNAME

SELECT
	@BaseTableFull = '[' + @BaseDB + '].[dbo].[' + @BaseTable + ']',
	@BaseSysColumns = '[' + @BaseDB + '].[sys].[columns]',
	@BaseSysTypes = '[' + @BaseDB + '].[sys].[types]',
	
	@CompareTableFull = '[' + @CompareDB + '].[dbo].[' + @CompareTable +']',
	@CompareSysColumns = '[' + @CompareDB + '].[sys].[columns]',
	@CompareSysTypes = '[' + @CompareDB + '].[sys].[types]'
	
	print '@BaseTableFull:'+char(10)+char(9)+@BaseTableFull
	print '@BaseSysColumns:'+char(10)+char(9)+@BaseSysColumns
	print '@BaseSysTypes:'+char(10)+char(9)+@BaseSysTypes
	print '@CompareTableFull:'+char(10)+char(9)+@CompareTableFull
	print '@CompareSysColumns:'+char(10)+char(9)+@CompareSysColumns
	print '@CompareSysTypes:'+char(10)+char(9)+@CompareSysTypes


-- BASE TABLE DETAILS
print ''
print '---------------------------------- BASE TABLE DETAILS'

DECLARE @BaseTableColumns	AS NVARCHAR(MAX)
	SET @Query = 
		N'SELECT @valOUT =('+char(10)+char(9)+ 
			N'SELECT '+char(10)+char(9)+char(9)+ 
				N' CASE'+char(10)+char(9)+char(9)+char(9)+ 
					N' WHEN UTyps.Name IN (''decimal'', ''float'', ''money'') THEN'+char(10)+char(9)+char(9)+char(9)+char(9)+ 
						N''',ISNULL(CAST(FORMAT('' + quotename(Cols.name) + '',''''0.######'''') AS VARCHAR(MAX)),''''<null>'''') AS '' + quotename(Cols.name)'+char(10)+char(9)+char(9)+char(9)+ 
					N' ELSE'+char(10)+char(9)+char(9)+char(9)+char(9)+
						N''',ISNULL(CAST('' + quotename(Cols.name) + '' AS VARCHAR(MAX)),''''<null>'''') AS '' + quotename(Cols.name)'+char(10)+char(9)+char(9)+ 
				N' END'+char(10)+char(9)+ 
			N'FROM ' + @BaseSysColumns + ' as Cols ' +char(10)+char(9)+ 
			N'JOIN ' + @BaseSysTypes + ' as UTyps ' +char(10)+char(9)+char(9)+ 
				N'ON Cols.user_type_id = UTyps.user_type_id '+char(10)+char(9)+ 
			N'WHERE Cols.object_id = object_id(''' + @BaseTableFull +''') ' +char(10)+char(9)+ 
			N'FOR XML PATH(''''), TYPE '+char(10)
		+N').value(''.'', ''NVARCHAR(MAX)'') '
	SET @ParamsDefinition = N'@valOUT NVARCHAR(MAX) OUTPUT'
	EXEC sp_executesql @Query, @ParamsDefinition, @valOUT = @Result OUTPUT
SET @BaseTableColumns = STUFF(@Result, 1, 1, '')
--print '@BaseTableColumns @Query:'+char(10)+char(9)+ @Query
print '@BaseTableColumns:'+char(10)+char(9)+ @BaseTableColumns

DECLARE @BaseColsUnpivot	AS NVARCHAR(MAX)
	SET @Query = 
		N'SELECT @valOUT = (SELECT '','' + quotename(Cols.[name])' 
		+ N' FROM ' + @BaseSysColumns + ' as Cols' 
		+ N' WHERE Cols.[object_id] = object_id(''' + @BaseTableFull +''')' 
			+ N' AND Cols.[name] NOT IN (' + @IgnoredColumns +')' --+ @KeyColumns +','
		+ N' ORDER BY Cols.[column_id] ASC'
		+ N' FOR XML PATH(''''), TYPE).value(''.'', ''NVARCHAR(MAX)'')'
	SET @ParamsDefinition = N'@valOUT NVARCHAR(MAX) OUTPUT'
	EXEC sp_executesql @Query, @ParamsDefinition, @valOUT = @Result OUTPUT
SET @BaseColsUnpivot = STUFF(@Result, 1, 1, '')
print '@BaseColsUnpivot @Query:'+char(10)+char(9)+ @Query
print '@BaseColsUnpivot:'+char(10)+char(9)+ @BaseColsUnpivot


-- COMPARE TABLE DETAILS
print ''
print '---------------------------------- COMPARE TABLE DETAILS'

DECLARE @CompareTableColumns	AS NVARCHAR(MAX)
	SET @Query = 
		N'SELECT @valOUT =('+char(10)+char(9)+ 
			N'SELECT '+char(10)+char(9)+char(9)+ 
				N' CASE'+char(10)+char(9)+char(9)+char(9)+ 
					N' WHEN UTyps.Name IN (''decimal'', ''float'', ''money'') THEN'+char(10)+char(9)+char(9)+char(9)+char(9)+ 
						N''',ISNULL(CAST(FORMAT('' + quotename(Cols.name) + '',''''0.######'''') AS VARCHAR(MAX)),''''<null>'''') AS '' + quotename(Cols.name)'+char(10)+char(9)+char(9)+char(9)+ 
					N' ELSE'+char(10)+char(9)+char(9)+char(9)+char(9)+
						N''',ISNULL(CAST('' + quotename(Cols.name) + '' AS VARCHAR(MAX)),''''<null>'''') AS '' + quotename(Cols.name)'+char(10)+char(9)+char(9)+ 
				N' END'+char(10)+char(9)+ 
			N'FROM ' + @CompareSysColumns + ' as Cols ' +char(10)+char(9)+ 
			N'JOIN ' + @CompareSysTypes + ' as UTyps ' +char(10)+char(9)+char(9)+ 
				N'ON Cols.user_type_id = UTyps.user_type_id '+char(10)+char(9)+ 
			N'WHERE Cols.object_id = object_id(''' + @CompareTableFull +''') ' +char(10)+char(9)+ 
			N'FOR XML PATH(''''), TYPE '+char(10)
		+N').value(''.'', ''NVARCHAR(MAX)'') '
	SET @ParamsDefinition = N'@valOUT NVARCHAR(MAX) OUTPUT'
	EXEC sp_executesql @Query, @ParamsDefinition, @valOUT = @Result OUTPUT
SET @CompareTableColumns = STUFF(@Result, 1, 1, '')
--print '@CompareTableColumns @Query:'+char(10)+char(9)+ @Query
print '@CompareTableColumns:'+char(10)+char(9)+ @CompareTableColumns

DECLARE @CompareColsUnpivot	AS NVARCHAR(MAX)
	SET @Query = 
		N'SELECT @valOUT = (SELECT '','' + quotename(Cols.[name])' 
		+ N' FROM ' + @CompareSysColumns + ' as Cols' 
		+ N' WHERE Cols.[object_id] = object_id(''' + @CompareTableFull +''')' 
			+ N' AND Cols.[name] NOT IN (' + @IgnoredColumns +')' --+ @KeyColumns +','
		+ N' ORDER BY Cols.[column_id] ASC'
		+ N' FOR XML PATH(''''), TYPE).value(''.'', ''NVARCHAR(MAX)'')'
	SET @ParamsDefinition = N'@valOUT NVARCHAR(MAX) OUTPUT'
	EXEC sp_executesql @Query, @ParamsDefinition, @valOUT = @Result OUTPUT
SET @CompareColsUnpivot = STUFF(@Result, 1, 1, '')
print '@CompareColsUnpivot @Query:'+char(10)+char(9)+ @Query
print '@CompareColsUnpivot:'+char(10)+char(9)+ @CompareColsUnpivot


-- COMMON KEY
print ''
print '---------------------------------- COMMON KEY'

DECLARE @RowKey			AS NVARCHAR(MAX)
	SET @Query = 
		N'SELECT @valOUT =('+char(10)+char(9)+ 
			N'SELECT '+char(10)+char(9)+char(9)+ 
				N' CASE'+char(10)+char(9)+char(9)+char(9)+ 
					N' WHEN UTyps.Name IN (''decimal'', ''float'', ''money'') THEN'+char(10)+char(9)+char(9)+char(9)+char(9)+ 
						N'''+''''-''''+ISNULL(CAST(FORMAT('' + quotename(Cols.name) + '',''''0.######''''),''''<null>'''') AS VARCHAR(MAX))'''+char(10)+char(9)+char(9)+char(9)+ 
					N' ELSE'+char(10)+char(9)+char(9)+char(9)+char(9)+
						N'''+''''-''''+ISNULL(CAST('' + quotename(Cols.name) + '' AS VARCHAR(MAX)),''''<null>'''')'''+char(10)+char(9)+char(9)+ 
				N' END'+char(10)+char(9)+ 
			N'FROM ' + @CompareSysColumns + ' as Cols ' +char(10)+char(9)+ 
			N'JOIN ' + @CompareSysTypes + ' as UTyps ' +char(10)+char(9)+char(9)+ 
				N'ON Cols.user_type_id = UTyps.user_type_id ' +char(10)+char(9)+ 
			N'WHERE Cols.object_id = object_id(''' + @CompareTableFull +''') ' +char(10)+char(9)+char(9)+
				N'AND Cols.[name] IN (' + @KeyColumns +') ' +char(10)+char(9)+ 
			N'ORDER BY Cols.[column_id] ASC '+char(10)+char(9)+
			N'FOR XML PATH(''''), TYPE '+char(10)
		+N').value(''.'', ''NVARCHAR(MAX)'') '
	SET @ParamsDefinition = N'@valOUT NVARCHAR(MAX) OUTPUT'
	EXEC sp_executesql @Query, @ParamsDefinition, @valOUT = @Result OUTPUT
SET @RowKey = STUFF(@Result, 1, 5, '')
print '@RowKey @Query:'+char(10)+char(9)+ @Query
print '@RowKey:'+char(10)+char(9)+ @RowKey

-- CREATE TEMP TABLES
print ''
print '---------------------------------- CREATE TEMP TABLES'

DECLARE @CountOfColumns AS NVARCHAR(10)

DECLARE @BaseDataQuery AS NVARCHAR(MAX)	
	SET @BaseDataQuery = 
		N'SELECT [RowKey], [Column], [Value] '
		+ N'FROM ( '
			+ N'SELECT (' + @RowKey + ') as [RowKey], ' + @BaseTableColumns + ' '
			+ N'FROM ' + @BaseTableFull + ' '
		+ IIF(@WhereConditions IS NOT NULL, N'WHERE ' + @WhereConditions, N'')
		+ N') as cp '
		+ N'UNPIVOT '
		+ N'([Value] FOR [Column] IN (' + @BaseColsUnpivot + ')) as up'
	print '@BaseDataQuery:' +char(10)+char(9)+ @BaseDataQuery

DROP TABLE IF EXISTS #BASE
CREATE TABLE #BASE ([RowKey] NVARCHAR(MAX), [Column] NVARCHAR(MAX), [Value] NVARCHAR(MAX))
INSERT INTO #BASE EXEC(@BaseDataQuery)
	-- partiali results: 3 values for each column
	SET @CountOfColumns =  STR((LEN(@BaseColsUnpivot)-LEN(REPLACE(@BaseColsUnpivot, ',', '')) + 1)*3)
	print '@CountOfColumns:'+char(10)+char(9)+ @CountOfColumns
	SET @Query =  N'SELECT TOP ' + @CountOfColumns +' * FROM #BASE'
	PRINT @query --// TODEL
	--EXEC sp_executesql @Query
--SELECT '#BASE' AS QueryName, * FROM #BASE

DECLARE @CompareDataQuery AS NVARCHAR(MAX)
	SET @CompareDataQuery = 
		N'SELECT [RowKey], [Column], [Value] '
		+ N'FROM ( '
			+ N'SELECT (' + @RowKey + ') as [RowKey], ' + @CompareTableColumns + ' '
			+ N'FROM ' + @CompareTableFull + ' '
		+ IIF(@WhereConditions IS NOT NULL, N'WHERE ' + @WhereConditions, N'')
		+ N') as cp '
		+ N' UNPIVOT'
		+ N' ([Value] FOR [Column] IN (' + @CompareColsUnpivot + ')) as up'
	print '@CompareDataQuery:' +char(10)+char(9)+ @CompareDataQuery

DROP TABLE IF EXISTS #COMPARE
CREATE TABLE #COMPARE ([RowKey] NVARCHAR(MAX), [Column] NVARCHAR(MAX), [Value] NVARCHAR(MAX))
INSERT INTO #COMPARE EXEC(@CompareDataQuery)
	-- partiali results: 3 values for each column
	SET @CountOfColumns =  STR((LEN(@CompareColsUnpivot)-LEN(REPLACE(@CompareColsUnpivot, ',', '')) + 1)*3)
	print '@CountOfColumns:'+char(10)+char(9)+ @CountOfColumns
	SET @Query =  N'SELECT TOP ' + @CountOfColumns +' * FROM #COMPARE'
	--EXEC sp_executesql @Query
--SELECT '#COMPARE' AS QueryName, * FROM #COMPARE

-- COMPARISION
print ''
print '---------------------------------- COMPARISION'

DROP TABLE IF EXISTS #COMPARISION1
SELECT 
	(SELECT WhereConditions FROM #Param) as [Filter],
	CASE WHEN b.[RowKey] IS NOT NULL THEN b.[RowKey] ELSE c.[RowKey] END AS [RowKey],
	CASE WHEN b.[RowKey] IS NOT NULL THEN b.[Column] ELSE c.[Column] END AS [Column],
	CASE WHEN b.[RowKey] IS NOT NULL THEN ISNULL(b.[Value],'<null>') ELSE '<key no exists>' END AS [TEST_MsAccess],
	CASE WHEN c.[RowKey] IS NOT NULL THEN ISNULL(c.[Value],'<null>') ELSE '<key no exists>' END AS [DEV_WebApp],
	CASE WHEN
		CASE WHEN b.[RowKey] IS NOT NULL THEN ISNULL(b.[Value],'<null>') ELSE '<key no exists>' END 
		=
		CASE WHEN c.[RowKey] IS NOT NULL THEN ISNULL(c.[Value],'<null>') ELSE '<key no exists>' END
	THEN 'OK' ELSE 'NOT OK' END AS [TEST] ,
	CASE WHEN b.[RowKey] IS NULL OR c.[RowKey] IS NULL THEN 0 ELSE 1 END AS [BOTH_KEYS]

INTO #COMPARISION1 
FROM 
	#BASE as b
FULL JOIN 
	#COMPARE as c
		ON b.[RowKey]=c.[RowKey] and b.[Column]=c.[Column]
GO

DROP TABLE IF EXISTS #COMPARISION
SELECT *, ROUND(ISNULL(ABS(TRY_CAST (TEST_MsAccess as float) - TRY_CAST (DEV_WebApp as float)),-1),12) AS DIFF
INTO #COMPARISION 
FROM #COMPARISION1
GO

SELECT TOP 2000 *
FROM #COMPARISION 
WHERE 1 =1
	and [TEST] = 'NOT OK'
	and [BOTH_KEYS] = 1
	--and [DIFF] > 0.0001
	--and [RowKey] in (' Report-137', ' Report-200')
	--and [RowKey] not like ('Project Charging%')
	--and [RowKey] = 16667079
	--and [Column] in ('Detail6')
	and [Column] not in ('IsCalculated') 
	--and [DEV_WebApp] not like 'deferred%'
ORDER BY
	[RowKey] Asc, [Column]

