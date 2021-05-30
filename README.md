# T-SQL-AsyncAgent

---


## What is T-SQL-AsyncAgent?

---

T-SQL-AsyncAgent is a lightweight utility to call SQL Server stored procedures in an asynchronous manner. It is written in T-SQL only, which makes it easy to install and use (no additional programming language, runtime, machines etc.).


## Usage

---

To call a procedure asynchronously, use procedure `[AsyncAgent].[StartProc]`. To wait for it to finish, call `[AsyncAgent].[AwaitProc]`:

```sql
EXEC PROC [AsyncAgent].[StartProc]
     @SchemaName = N'dbo'
    ,@ProcName = N'MyProc'
;

-- Do some other stuff in the meanwhile.

EXEC PROC [AsyncAgent].[AwaitProc]
     @SchemaName = N'dbo'
    ,@ProcName = N'MyProc'
;

-- Asynchronous proc call finished.
```


Additionally, you may group multiple asynchronous stored procedure calls to an _AsyncGroup_, which you then can wait for using `[AsyncAgent].[AwaitGroup]`:

```sql
EXEC PROC [AsyncAgent].[StartProc]
     @SchemaName = N'dbo'
    ,@ProcName = N'MyProc1'
    ,@AsyncGroup = N'MyGroup'
;

EXEC PROC [AsyncAgent].[StartProc]
     @SchemaName = N'dbo'
    ,@ProcName = N'MyProc2'
    ,@AsyncGroup = N'MyGroup'
;

-- Do some other stuff in the meanwhile.

EXEC PROC [AsyncAgent].[AwaitGroup]
     @AsyncGroup = N'MyGroup'
    ,@DelaySec = 5 -- Ask every @DelaySec seconds if group finished executing
;

-- Asynchronous proc call finished.
```


T-SQL-AsyncAgent is compatible with cross-database stored procedure calls:

```sql
USE [MyDB1];
GO

EXEC PROC [AsyncAgent].[StartProc]
     @SchemaName = N'dbo'
    ,@ProcName = N'MyProc'
    ,@DatabaseName = N'MyDB2'
;

-- Do some other stuff on [MyDB1] in the meanwhile.

EXEC PROC [AsyncAgent].[AwaitProc]
     @SchemaName = N'dbo'
    ,@ProcName = N'MyProc'
    ,@DatabaseName = N'MyDB2'
;

-- Asynchronous cross-database proc call finished.
```


## Prerequisites

---

Tested for SQL Server 2019. Should work with SQL Server 2016 and newer, perhaps even some older versions.

As T-SQL-AsyncAgent makes (obviously) use of the SQL Server Agent, the service must be running. Callers should have sysadmin privileges. If it can be guaranteed that a stored procedure is called using T-SQL-AsyncAgent by a single user only, "SQLAgentUserRole" may be sufficient.


## Installation

---

Currently it's required to deploy T-SQL-AsyncAgent using Visual Studio:

- Install [Visual Studio 2019](https://visualstudio.microsoft.com/vs/) (check [pricing/license terms](https://visualstudio.microsoft.com/vs/pricing/) first)
- In Visual Studio 2019 Installer, make sure _SQL Server Data Tools_ are installed
- Check out T-SQL-AsyncAgent repository
- Open solution and deploy Project _Async_ to target database

If Visual Studio 2019 pricing/licensing terms are a blocking point, you may use [Visual Studio 2017 SSDT](https://docs.microsoft.com/en-us/sql/ssdt/download-sql-server-data-tools-ssdt?view=sql-server-ver15#ssdt-for-vs-2017-standalone-installer) which is completely free of charge. But you will have to adjust database references to `[msdb]` and `[master]` as there are different file paths for each Visual Studio version.

In future, an installation script may be added to ease this process.


## Contribution

---

Yet there is neither a code of conduct nor a feature roadmap etc. Nevertheless, if you have some questions or suggestions feel free to contact us :)


## License

---

Copyright © 2021 [iuvopoint Business Intelligence](https://www.iuvopoint.de/).

Licensed under the MIT License (MIT). See LICENSE for details.
