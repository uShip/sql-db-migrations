import os
import sys
from dotenv import load_dotenv
os.environ["SQLALCHEMY_WARN_20"] = "1"
import pandas as pd
from datetime import datetime
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError
import logging
import coloredlogs
import json

sys.path.append("src/helpers")
from db_conn import connect_db_sqlalchemy
from snowflake_conn import snowflake_connection_sqlalchemy

# from src.helpers.db_conn import connect_db, DestroyDBConnections, snowflake_connection
logger = logging.getLogger(__name__)
coloredlogs.install(level="DEBUG", logger=logger, isatty=True)

sig_config_str = os.getenv('SIG_CONFIG')
sig_config = json.loads(sig_config_str)

# Configuration Management
config = {
    "sig_config": json.loads(os.getenv("sig_config")),
    "snowflake": {
        "snowflake_username": os.getenv("snowflake_username"),
        "snowflake_keypass": os.getenv("snowflake_keypassword"),
        "snowflake_password": os.getenv("snowflake_password"),
        "snowflake_account": os.getenv("snowflake_accountname"),
        "snowflake_warehouse": os.getenv("snowflake_warehouse"),
        "snowflake_database": os.getenv("snowflake_database"),
        "snowflake_role": os.getenv("snowflake_role"),
    },
}

print(config)
def connection_string(host_server, dbName, userName, userPassword):
    # Construct the connection string using string formatting
    modified_connection_string = f"Driver={{ODBC Driver 18 for SQL Server}};Server={host_server};Database={dbName};Uid={userName};Pwd={userPassword};TrustServerCertificate=yes"

    # Set the modified connection string in the environment
    os.environ['CONNECTION_STRING'] = modified_connection_string

    # Optionally, print the connection string (for debugging purposes, remove in production)
    print(os.environ['CONNECTION_STRING'])


def build_snowflake_query(table):
    if "fuelprices" in table.lower():
        return f"SELECT \
                    DATE as date, \
                    MAX(CASE WHEN TYPE = 'Total Gasoline' THEN PPG ELSE NULL END) AS gas, \
                    MAX(CASE WHEN TYPE = 'No 2 Diesel' THEN PPG ELSE NULL END) AS diesel \
                FROM {table} \
                WHERE DATE > DATEADD(DAY, -7, GETDATE()) \
                GROUP BY DATE;"
    else:
        return f"SELECT * FROM {table}"

# Data Insertion Function
def insert_data_into_mssql(conn, table_name, data):
    data.to_sql(table_name, schema="dbo", con=conn, if_exists="append", index=False)

def process_table_data(sf_connection, table, mapping, environments, connections, env):
    query = build_snowflake_query(table)
    df = pd.read_sql(query, sf_connection)
    print("Length of dataframe: ", len(df))
    logger.info(f"Data retrieved from {table}, processing...")

    mssql_table_name = mapping[table]
    for env in environments:
        logger.info('Processing data for environment: %s', env)
        if "ushipcommerce_partners" in mssql_table_name:
            with connections[f'sig_engine_{env}'].connect() as conn:
                result = conn.execute(text("SELECT 1"))
                logger.info("Connection test successful: %s", result.fetchone())
                try:
                    # Execute the statement
                    trun_result = conn.execution_options(autocommit=True).execute(
                        text(f"TRUNCATE TABLE [Pricing].[dbo].[{mssql_table_name}]")
                    )
                    logger.info("Execution successful: %s", trun_result)
                except SQLAlchemyError as e:
                    logger.info(f"An error occurred: {e}")
        insert_data_into_mssql(connections[f'sig_engine_{env}'], mssql_table_name, df)
    logger.info(f"Data inserted into {mssql_table_name} in all environments.")

def close_connections(connections):
    for conn in connections.values():
        if conn:
            conn.dispose()
    logger.info("All SQL Server connections closed.")

def main():
    # Get the current date
    current_date = datetime.now()

    table_mapping = {
        "DATAMART.SRA.FUELPRICES": "fuelprices",
        "DATAMART.SRA.USHIPCOMMERCE_PARTNERS": "ushipcommerce_partners",
    }

    # Check if today is Wednesday (Wednesday corresponds to 2 in the weekday() function, where Monday is 0 and Sunday is 6)
    snowflake_tables = ["DATAMART.SRA.USHIPCOMMERCE_PARTNERS"]
    if current_date.weekday() == 2:
        logger.info("Today is Wednesday! Time for FuelPrices")
        snowflake_tables.append("DATAMART.SRA.FUELPRICES")

    try:
        # Establishing connections
        logger.info("Connecting to Snowflake with sqlalchemy...")
        conn_snowflake = snowflake_connection_sqlalchemy(**config["snowflake"])
        with conn_snowflake.connect() as sf_sqlal_connection:
            logger.info("Connected to Snowflake")
            environments = ['dev', 'qa', 'sand', 'prod']
            connections = {}

            for env in environments:
                try:
                    connections[f'sig_engine_{env}'] = connect_db_sqlalchemy(**config["sig_config"][env])
                    logger.info(f"Connected to SQL Server for environment: {env}")
                except Exception as e:
                    logger.error(f"Failed to connect to SQL Server for environment {env}: {e}")
                    continue

            for table in snowflake_tables:
                process_table_data(conn_snowflake, table, table_mapping, environments, connections, env)

    except SQLAlchemyError as e:
        logger.error(f"Database error occurred: {e}")
        raise
    except Exception as e:
        logger.error(f"An unexpected error occurred: {e}")
        raise
    finally:
        close_connections(connections)


if __name__ == "__main__":
    main()
