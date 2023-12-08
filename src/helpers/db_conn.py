import os
import sys
import pyodbc
import coloredlogs
from datetime import datetime
import logging
from sqlalchemy.engine import URL
from sqlalchemy import create_engine, event

logger = logging.getLogger(__name__)
coloredlogs.install(level="DEBUG", logger=logger, isatty=True)


def log_message(message, *args):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"{timestamp} - {message}")


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

    logger.info("Establishing mssql database connection")
    CONNECTION_STRING: str = "DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={server};DATABASE={database};UID={username};PWD={password};Encrypt=no"
    connection_str = CONNECTION_STRING.format(
        server=host_server, database=dbName, username=userName, password=userPassword
    )

    logger.info("Trying to connect to Database")
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


def connect_db_sqlalchemy(
    host_server, dbName, userName, userPassword
) -> pyodbc.Connection:
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

    logger.info("Establishing mssql database connection")
    CONNECTION_STRING: str = "DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={server};DATABASE={database};UID={username};PWD={password};Encrypt=no;Trusted_Connection=yes"
    connection_str = CONNECTION_STRING.format(server=host_server, database=dbName, username=userName, password=userPassword)

    logger.info("Trying to connect to Database")
    try:
        connection_url = URL.create(
            "mssql+pyodbc",
            query={
                "odbc_connect": connection_str,
                # "trusted_connection": "yes",  # Add trusted_connection here
            },
        )
        engine = create_engine(connection_url)
        logger.info("Connected to Database")
        return engine
    except (pyodbc.Error, pyodbc.OperationalError) as e:
        logger.info("Failed to connect to the Database: {}".format(e))
        raise Exception("Database connection timed out or failed") from e
