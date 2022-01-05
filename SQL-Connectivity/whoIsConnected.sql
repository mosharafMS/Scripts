SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure [dbo].[whoIsConnected]
AS
Select c.session_id,c.connect_time,c.net_transport,c.protocol_type,c.encrypt_option,auth_scheme,
c.client_net_address,s.program_name,s.login_name,t.text
from sys.dm_exec_connections c join sys.dm_exec_sessions s 
on c.session_id=s.session_id
CROSS APPLY sys.dm_exec_sql_text(c.most_recent_sql_handle) t
where s.is_user_process=1
GO
