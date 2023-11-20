import os
import sys
import pyodbc

def connect_db(host_server, dbName, userName, userPassword) -> pyodbc.Connection:
    """
    Connect to database

    Parameters:
        host_server (str) = the host server name or IP address.
        dbName (str) = the database name.
        userName (str) = the username of login .
        userPassword (str) = the user password for login.

    Returns:
        conn, crs = the key-value pair of the database conncection.
    """

    log_message("Establishing mssql database connection")
    CONNECTION_STRING: str = "DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={server};DATABASE={database};UID={username};PWD={password};Encrypt=no"
    connection_str = CONNECTION_STRING.format(
        server=host_server, database=dbName, username=userName, password=userPassword
    )

    log_message("Trying to connect to Database")
    try:
        conn = pyodbc.connect(connection_str, timeout=90)
        crs = conn.cursor()
        log_message("Connected to Database")
        return conn, crs
    except (pyodbc.Error, pyodbc.OperationalError) as e:
        log_message("Failed to connect to the Database: {}".format(e))
        raise Exception("Database connection timed out or failed") from e

def DestroyDBConnections(conn, crs):
    if "Connection" in str(type(conn)) and "Cursor" in str(type(crs)):
        crs.close()
        conn.close()
        log_message("Closing the connection.")
