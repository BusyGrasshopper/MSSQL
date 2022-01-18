/*
Created By LazyDaddy.

MSSQL DB 객체에서 text 검색

USE [DataBase]
*/
DECLARE @sWords			NVARCHAR(300), -- 검색어. 구분자(|) 로 최대 3 개의 text 입력 가능
				@skipWords	NVARCHAR(300); -- 제외text. 구분자(|) 로 최대 3 개의 text 입력 가능

SET @sWords = 'sText1|sText2';
SET @skipWords = 'sSkipText1|sSkipText2';



BEGIN
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	SET NOCOUNT ON;
	
	DECLARE @sql						NVARCHAR(MAX)
				, @join						NVARCHAR(MAX)
				, @where					NVARCHAR(MAX)
				, @orderBy				NVARCHAR(40)
				, @paramDef				NVARCHAR(1000)
				, @dbName					NVARCHAR(128);
	
	DECLARE @sWord1			NVARCHAR(100)
				, @sWord2			NVARCHAR(100)
				, @sWord3			NVARCHAR(100)
				, @skipWord1			NVARCHAR(100) = ''
				, @skipWord2			NVARCHAR(100) = ''
				, @skipWord3			NVARCHAR(100) = ''
				, @buff				VARCHAR(8000)
				, @token			VARCHAR(10)
				, @cnt				INT
				, @pos				INT
				, @rec				VARCHAR(300);
	
	DECLARE @tokenTable		TABLE (
			Seq			INT IDENTITY
		, Code		VARCHAR(300)
	)
	
	SET @buff = @sWords;
	SET @token = '|';
	
	SET @cnt = 0

	WHILE @cnt < 3000
	BEGIN
		SET @pos = CHARINDEX(@token, @buff, 0)

		IF @pos <= 0 AND @buff = ''
			BREAK

		IF @pos > 0
		BEGIN
			SET @rec = LEFT(@buff, @pos - 1)
			SET @buff = RIGHT(@buff, LEN(@buff) - @pos)
		END
		ELSE
		BEGIN
			SET @rec = @buff
			SET @buff = ''
		END

		INSERT INTO @tokenTable
		VALUES (@rec)

		SET @cnt = @cnt + 1

	END
	
	SELECT	@sWord1 = ISNULL(MIN(CASE	WHEN gtt.seq = 1 THEN gtt.code END), '')
				, @sWord2 = ISNULL(MIN(CASE	WHEN gtt.seq = 2 THEN gtt.code END), '')
				, @sWord3 = ISNULL(MIN(CASE	WHEN gtt.seq = 3 THEN gtt.code END), '')
	FROM @tokenTable gtt;
	
	
	DECLARE @tokenTable2		TABLE (
			Seq			INT IDENTITY
		, Code		VARCHAR(300)
	)
	
	SET @buff = @skipWords;
	SET @token = '|';
	
	SET @cnt = 0

	WHILE @cnt < 3000
	BEGIN
		SET @pos = CHARINDEX(@token, @buff, 0)

		IF @pos <= 0 AND @buff = ''
			BREAK

		IF @pos > 0
		BEGIN
			SET @rec = LEFT(@buff, @pos - 1)
			SET @buff = RIGHT(@buff, LEN(@buff) - @pos)
		END
		ELSE
		BEGIN
			SET @rec = @buff
			SET @buff = ''
		END

		INSERT INTO @tokenTable2
		VALUES (@rec)

		SET @cnt = @cnt + 1

	END
	
	SELECT	@skipWord1 = ISNULL(MIN(CASE	WHEN gtt.seq = 1 THEN gtt.code END), '')
				, @skipWord2 = ISNULL(MIN(CASE	WHEN gtt.seq = 2 THEN gtt.code END), '')
				, @skipWord3 = ISNULL(MIN(CASE	WHEN gtt.seq = 3 THEN gtt.code END), '')
	FROM @tokenTable2 gtt;
	
	SELECT	'sWords' vType, @sWord1 word1, @sWord2 word2, @sWord3 word3
	UNION ALL
	SELECT	'skipWords' vType, @skipWord1 word1, @skipWord2 word2, @skipWord3 word3;

	SET @dbName = DB_NAME();
	
	SET @paramDef = N'@sWord1					NVARCHAR(100)
      , @sWord2					NVARCHAR(100)
      , @sWord3					NVARCHAR(100)
      , @skipWord1					NVARCHAR(100)
      , @skipWord2					NVARCHAR(100)
      , @skipWord3					NVARCHAR(100)';
	
	-- Query to handle error
	-- 검색
	SET @join = N'
FROM (
		SELECT	s.[name] AS SchemaName, o.[name], o.[object_id], o.[type], o.create_date
					, o.modify_date,
					REPLACE(
					REPLACE(
					REPLACE(
					REPLACE(OBJECT_DEFINITION(o.[object_id]), ''기본 제외 문구 입력'', '''')
					, @skipWord1, '''')
					, @skipWord2, '''')
					, @skipWord3, '''')
					AS CONTENT
		FROM ' + @dbName + N'.sys.objects o
			INNER JOIN ' + @dbName + N'.sys.schemas s
				ON s.[schema_id] = o.[schema_id]
		WHERE o.[type] IN (''V'',''TR'',''TF'',''IF'',''FN'',''P'',''U'')
		) t1';
	
	SET @where = N'
WHERE t1.[content] NOT LIKE ''%기존 제외 문구 입력2%''
AND t1.[name] NOT LIKE ''%_Dev'' -- 개발용 객체 제외
AND t1.[name] NOT LIKE ''%_tunning'' -- 개발용 객체 제외
AND t1.[content] LIKE ''%'' + @sWord1 + ''%''
AND (@sWord2 = '''' OR (@sWord2 > '''' AND t1.[content] LIKE ''%'' + @sWord2 + ''%''))
AND (@sWord3 = '''' OR (@sWord3 > '''' AND t1.[content] LIKE ''%'' + @sWord3 + ''%''))';
	
	SET @orderBy = N'
ORDER BY	t1.[name] ASC;';
	
	SET @sql = N'
SELECT	TOP 500	t1.SchemaName, t1.[name], t1.[object_id], t1.[type], t1.create_date
		, t1.modify_date
		, datalength(t1.[content])
		, ''sp_helptext '''''' + t1.SchemaName + ''.'' + t1.[name] + '''''''' AS helptext'
				+ @join + @where + @orderBy;



	PRINT N'DECLARE ' + @paramDef;

	PRINT N'SET @sWord1 = ''' + @sWord1 + N'''
SET @sWord2 = ''' + @sWord2 + N'''
SET @sWord3 = ''' + @sWord3 + N'''
SET @skipWord1 = ''' + @skipWord1 + N'''
SET @skipWord2 = ''' + @skipWord2 + N'''
SET @skipWord3 = ''' + @skipWord3 + N'''';

	PRINT @sql;

	EXEC sp_executesql	@sql, @paramDef
										, @sWord1 = @sWord1
										, @sWord2 = @sWord2
										, @sWord3 = @sWord3
										, @skipWord1 = @skipWord1
										, @skipWord2 = @skipWord2
										, @skipWord3 = @skipWord3;
END
