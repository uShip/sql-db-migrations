import os
import sys
import pyodbc
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization
import coloredlogs
from datetime import datetime
import logging
from snowflake.connector.pandas_tools import write_pandas
from snowflake.connector import connect
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

    log_message("Establishing mssql database connection")
    CONNECTION_STRING: str = "DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={server};DATABASE={database};UID={username};PWD={password};Encrypt=no"
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


def connect_db_sqlaclchemy(
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

    log_message("Establishing mssql database connection")
    CONNECTION_STRING: str = "DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={server};DATABASE={database};UID={username};PWD={password};Encrypt=no"
    connection_str = CONNECTION_STRING.format(
        server=host_server, database=dbName, username=userName, password=userPassword
    )

    log_message("Trying to connect to Database")
    try:
        connection_url = URL.create(
            "mssql+pyodbc", query={"odbc_connect": connection_str}
        )
        engine = create_engine(connection_url)
        log_message("Connected to Database")
        return engine
    except (pyodbc.Error, pyodbc.OperationalError) as e:
        log_message("Failed to connect to the Database: {}".format(e))
        raise Exception("Database connection timed out or failed") from e


def snowflake_connection(
    snowflake_username,
    snowflake_keypass,
    snowflake_password,
    snowflake_account,
    snowflake_warehouse,
    snowflake_database,
    snowflake_role,
    conn_engine,
):
    """
    Establishes a connection to Snowflake and returns the connection object.

    Args:
        username (str): Snowflake username.
        keypass (str): Snowflake key password.
        password (str): Snowflake password.
        account (str): Snowflake account name.
        warehouse (str): Snowflake warehouse name.
        database (str): Snowflake database name.
        role (str): Snowflake role name.

    Returns:
        snowflake.connector.connection: Snowflake connection object.
    """
    logger.debug("Getting the credentials...")

    pem_data = snowflake_keypass
    p_key = serialization.load_pem_private_key(
        pem_data.encode(),
        password=snowflake_password.encode(),
        backend=default_backend(),
    )
    pkb = p_key.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )

    try:
        if conn_engine == "snowflake":
            conn = connect(
                user=snowflake_username,
                private_key=pkb,
                account=snowflake_account,
                role=snowflake_role,
                warehouse=snowflake_warehouse,
                database=snowflake_database,
            )
        elif conn_engine == "sqlacl":
            conn = create_engine(URL(
                    account = snowflake_account,
                    user = snowflake_username,
                    ),
                    connect_args={
                        "private_key": pkb,
                    },
                )
        else:
            raise Exception("Mention a valid connection engine")
        return conn
    except Exception as e:
        logger.error(f"Failed to write to Snowflake: {e}")
        raise
