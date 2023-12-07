import os
import sys
import pandas as pd
from datetime import datetime
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError
import logging
import coloredlogs

# Adding custom module paths
sys.path.append("src/helpers")

# Importing custom modules
from db_conn import connect_db_sqlalchemy
from snowflake_conn import snowflake_connection_sqlalchemy

# Configuring logging
logger = logging.getLogger(__name__)
coloredlogs.install(level="DEBUG", logger=logger, isatty=True)

# Configuration Management
config = {
    "db_server": os.getenv("DB_SERVER"),
    "db_name": os.getenv("DB_NAME"),
    "username": os.getenv("USERNAME"),
    "password": os.getenv("PASSWORD"),
    "snowflake": {
        "username": os.getenv("snowflake_username"),
        "keypass": os.getenv("snowflake_keypassword"),
        "password": os.getenv("snowflake_password"),
        "account": os.getenv("snowflake_accountname"),
        "warehouse": os.getenv("snowflake_warehouse"),
        "database": os.getenv("snowflake_database"),
        "role": os.getenv("snowflake_role"),
    },
}


# Define utility functions
def insert_data_into_mssql(engine, table_name, data):
    """
    Inserts data into a Microsoft SQL Server table using SQLAlchemy engine.

    Args:
        engine (sqlalchemy.engine.Engine): SQLAlchemy engine object.
        table_name (str): Name of the target SQL Server table.
        data (DataFrame): Pandas DataFrame containing data to be inserted.
    """
    data.to_sql(table_name, schema="dbo", con=engine, if_exists="append", index=False)


def fetch_data_from_snowflake(conn, query):
    """
    Fetches data from Snowflake.

    Args:
        conn (sqlalchemy.engine.Engine): Connection object for Snowflake.
        query (str): SQL query to be executed.

    Returns:
        DataFrame: Pandas DataFrame containing the fetched data.
    """
    return pd.read_sql(query, conn)


def truncate_table(engine, table_name):
    """
    Truncates a table in SQL Server.

    Args:
        engine (sqlalchemy.engine.Engine): SQLAlchemy engine object.
        table_name (str): Name of the table to truncate.
    """
    with engine.connect() as conn:
        conn.execution_options(autocommit=True).execute(
            text(f"TRUNCATE TABLE [Pricing].[dbo].[{table_name}]")
        )


def main():
    try:
        # Establishing connections
        logger.info("Connecting to Snowflake with sqlalchemy...")
        conn_snowflake = snowflake_connection_sqlalchemy(
            **config["snowflake"]
        ).connect()
        logger.info("Connected to Snowflake")

        logger.info("Connecting to SQL Server with sqlalchemy...")
        sig_engine = connect_db_sqlalchemy(
            config["db_server"],
            config["db_name"],
            config["username"],
            config["password"],
        )
        logger.info("Connected to SQL Server")

        # Business logic here...
        # ...

    except SQLAlchemyError as e:
        logger.error(f"Database error occurred: {e}")
    except Exception as e:
        logger.error(f"An unexpected error occurred: {e}")
    finally:
        # Clean up and close connections
        logger.info("Closing database connections...")
        if conn_snowflake:
            conn_snowflake.close()
        if sig_engine:
            sig_engine.dispose()


if __name__ == "__main__":
    main()
