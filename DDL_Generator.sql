USE [AdventureWorks2012]
GO
-- [dbo].[SP_DDL_Generator] Person

IF EXISTS(SELECT * FROM sys.procedures WHERE Name like 'SP_DDL_Generator')
	DROP PROCEDURE [dbo].[SP_DDL_Generator]
GO
CREATE PROCEDURE [dbo].[SP_DDL_Generator]
(
	--If no object name is provided, the SPROC returns DDL for all tables / view in the database
	@ObjectName SYSNAME = NULL
)
AS

SET NOCOUNT ON

BEGIN TRY
	--This is the string containing the DDL info the we will print to the console
	DECLARE @DDL_String NVARCHAR(MAX) = ''

	SET @DDL_String = 
		'    USE ' + CONVERT(NVARCHAR, DB_NAME()) + ' 
	GO
	'

	SELECT 
		@DDL_String = @DDL_String + 
		CASE 
			WHEN AO.Type = 'V'
			THEN 'CREATE VIEW '
			WHEN AO.Type = 'U'
			THEN 'CREATE TABLE '
		END

		+ '[' + S.Name + '].[' + AO.Name + ']
		('
	+
		STUFF(Columns.Name, LEN(Columns.Name), 1, '')
	+
	'
		)' + CHAR(10) + CHAR(9) 
	FROM
		sys.all_objects AS AO
		INNER JOIN
			sys.schemas AS S
				ON S.Schema_ID = AO.Schema_ID
		CROSS APPLY
			(

				SELECT
					(
						SELECT	
							CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + 
							'[' + AC.Name + '] ' +	--Column Name
							 CASE 
								WHEN AC.is_identity = 1
								THEN 'IDENTITY(' + 
									  CONVERT(NVARCHAR, IC.seed_value) + ',' + 
									  CONVERT(NVARCHAR, IC.increment_value) + ') '
								ELSE ''
							END + 
							'[' + T.Name +
							CASE
								WHEN T.Name like '%varchar%' 
								THEN  '(' + CONVERT(NVARCHAR, T.Max_Length) + ')'
								ELSE ''
							END + ']' +
							',' 
						FROM
							sys.all_columns AS AC
							LEFT JOIN
								sys.types AS T
									ON T.user_type_id = AC.user_type_id
							LEFT JOIN
								sys.identity_columns AS IC
									ON IC.Object_ID = AC.Object_ID
						WHERE
							AC.object_ID = AO.Object_ID
						FOR XML PATH('')
					) AS Name
			) AS Columns
	WHERE
		AO.Name = ISNULL(@ObjectName, AO.Name)
	AND AO.type IN ('U', 'V')
	AND SCHEMA_NAME(AO.schema_id) NOT IN('sys', 'INFORMATION_SCHEMA')		--We don't want to return sys objects
	ORDER BY
		AO.name ASC

	PRINT @DDL_String 
END TRY

BEGIN CATCH
	DECLARE @ErrorMsg NVARCHAR(2048) = ERROR_MESSAGE()
	RAISERROR(@ErrorMsg, 16, 1)
END CATCH

SET NOCOUNT OFF