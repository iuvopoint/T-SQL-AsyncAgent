# T-SQL-AsyncAgent

## What is T-SQL-AsyncAgent?

_T-SQL-AsyncAgent_ is a lightweight utility to call SQL Server stored procedures in an asynchronous manner. It is written in T-SQL only, which makes it easy to install and use (no additional programming language, runtime, machines etc.).


## Usage

To call a procedure asynchronously, use procedure `[AsyncAgent].[StartProc]`. To wait for it to finish, call `[AsyncAgent].[AwaitProc]`:

```tsql
EXECUTE PROCEDURE [AsyncAgent].[StartProc]
     @SchemaName = N'dbo'
    ,@ProcName = N'MyProc'
;

-- Do some other stuff in the meanwhile.

EXECUTE PROCEDURE [AsyncAgent].[AwaitProc]
     @SchemaName = N'dbo'
    ,@ProcName = N'MyProc'
;

-- Asynchronous proc call finished.
```

---

Additionally, you may group multiple asynchronous stored procedure calls to an _AsyncGroup_, which you then can wait for using `[AsyncAgent].[AwaitGroup]`:

```tsql
EXECUTE PROCEDURE [AsyncAgent].[StartProc]
     @SchemaName = N'dbo'
    ,@ProcName = N'MyProc1'
    ,@AsyncGroup = N'MyGroup'
;

EXECUTE PROCEDURE [AsyncAgent].[StartProc]
     @SchemaName = N'dbo'
    ,@ProcName = N'MyProc2'
    ,@AsyncGroup = N'MyGroup'
;

-- Do some other stuff in the meanwhile.

EXECUTE PROCEDURE [AsyncAgent].[AwaitGroup]
     @AsyncGroup = N'MyGroup'
    ,@DelaySec = 5 -- Ask every @DelaySec seconds for group finished executing
;

-- Asynchronous proc call finished.
```

---

T-SQL-AsyncAgent is compatible with cross-database stored procedure calls:

```tsql
USE [MyDB1];
GO

EXECUTE PROCEDURE [AsyncAgent].[StartProc]
     @SchemaName = N'dbo'
    ,@ProcName = N'MyProc'
    ,@DatabaseName = N'MyDB2'
;

-- Do some other stuff on [MyDB1] in the meanwhile.

EXECUTE PROCEDURE [AsyncAgent].[AwaitProc]
     @SchemaName = N'dbo'
    ,@ProcName = N'MyProc'
    ,@DatabaseName = N'MyDB2'
;

-- Asynchronous cross-database proc call finished.
```


## Prerequisites

Tested for SQL Server 2019. Should work with SQL Server 2016 and newer, perhaps even some older versions.

As _T-SQL-AsyncAgent_ makes (obviously) use of the [SQL Server Agent][Agent], the service must be running. Callers should have sysadmin privileges. If it can be guaranteed that a stored procedure is called using _T-SQL-AsyncAgent_ by a single user only, [SQLAgentUserRole](https://docs.microsoft.com/en-us/sql/ssms/agent/sql-server-agent-fixed-database-roles?view=sql-server-ver15#sqlagentuserrole-permissions) may be sufficient.


## Installation

Currently it's required to deploy _T-SQL-AsyncAgent_ using Visual Studio:

- Install [Visual Studio 2019](https://visualstudio.microsoft.com/vs/) (check [pricing/license terms](https://visualstudio.microsoft.com/vs/pricing/) first)
- In Visual Studio 2019 Installer, make sure _SQL Server Data Tools_ are installed
- Clone _T-SQL-AsyncAgent_ repository
- Open solution and deploy SSDT project _Async_ to target database

If Visual Studio 2019 pricing/licensing terms are a blocking point, you may use [Visual Studio 2017 SSDT](https://docs.microsoft.com/en-us/sql/ssdt/download-sql-server-data-tools-ssdt?view=sql-server-ver15#ssdt-for-vs-2017-standalone-installer) which is completely free of charge. But you will have to adjust project database references to `[msdb]` and `[master]` as there are different file paths for each Visual Studio version.

In future, an installation script may be added to ease this process.


## Limitations

As a heir to [SQL Server Agent][Agent], functionality of _T-SQL-AsyncAgent_ is closely tied to that.

Here's a list that holds some bullet points regarding _T-SQL-AsyncAgent_ limitations:

- For a stored procedure call, a job is used that is based on database, schema and procedure name. A job has to be finished before it can run again. As a result, the same procedure can be run only once at the same time, not multiple times in parallel.
- Currently there is no way to pass values to stored procedure parameters. If parameters are required, you will have to work around e.g. using tables to store parameters which then are looked up by the asynchronously called stored procedure.
- If output parameters are required, again you will have to work around e.g. using tables to store results.
- Cross-server stored procedure calls are not supported.
- For each distinct stored procedure that has ever been called, a job is created. Therefore, the [SQL Server Agent][Agent] GUI will be bloated if used extensively. Hopefully, we can come up with a solution for this issue in near future.

Of course, there may be other limitations that haven't been discovered yet.


## Contribution

Yet there is neither a code of conduct nor a feature roadmap etc. Nevertheless, if you have some questions or suggestions feel free to contact us :)


## License

Copyright © 2021 [iuvopoint Business Intelligence](https://www.iuvopoint.de/).

Licensed under the MIT License (MIT). See LICENSE for details.

[Agent]: https://docs.microsoft.com/en-us/sql/ssms/agent/sql-server-agent?view=sql-server-ver15
