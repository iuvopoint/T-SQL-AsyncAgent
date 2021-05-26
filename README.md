# T-SQL-AsyncAgent

---

## What is T-SQL-AsyncAgent?

---

T-SQL-AsyncAgent is a lightweight utility to call T-SQL stored procedures in an asynchronous manner. It is written in T-SQL only which makes it easy to install and use (no additional programming language, runtime etc.).


## How to use it?

---

To call a procedure asynchronously, use procedure `[Agent].[StartProc]`. To wait for it to finish, call `[Agent].[AwaitProc]`:

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


Additionally, you may group multiple asynchronous stored procedure calls to an _AsyncGroup_, which you then can wait for using `[Async].[AwaitGroup]`:

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


T-SQL-AsyncAgent can be used cross-database:

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
