SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [AmyTest] (@ID varchar(10))
AS

SELECT [Description] from dbo.AmyTest where ID = @ID
