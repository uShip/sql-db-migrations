import os
import sys

os.environ["SQLALCHEMY_WARN_20"] = "1"
import pandas as pd
from datetime import datetime
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError
import logging
import coloredlogs


sys.path.append("src/helpers")
from db_conn import connect_db_sqlalchemy

from snowflake_conn import snowflake_connection_sqlalchemy

# from src.helpers.db_conn import connect_db, DestroyDBConnections, snowflake_connection
logger = logging.getLogger(__name__)
coloredlogs.install(level="DEBUG", logger=logger, isatty=True)

# Configuration Management
config = {
    "db_server": os.getenv("DB_SERVER"),
    "db_name": os.getenv("DB_NAME"),
    "username": os.getenv("USERNAME"),
    "password": os.getenv("PASSWORD"),
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


def insert_data_into_mssql(connection, cursor, table_name, columns, data):
    """
    Inserts data into a Microsoft SQL Server table.

    Args:
        connection (pyodbc.Connection): SQL Server connection object.
        cursor (pyodbc.Cursor): SQL Server cursor object.
        table_name (str): Name of the target SQL Server table.
        columns (list): List of column names in the target table.
        data (list): List of data rows to be inserted.
    """
    # MSSQL insert query template
    mssql_insert_query = "INSERT INTO {} ({}) VALUES ({})"

    # Insert data into MSSQL
    for row in data:
        values = ",".join(["?"] * len(row))
        insert_query = mssql_insert_query.format(table_name, ",".join(columns), values)
        cursor.execute(insert_query, row)
        connection.commit()


def main():
    # Get the current date
    current_date = datetime.now()

    table_mapping = {
        "DATAMART.SRA.FUELPRICES": "fuelprices",
        "DATAMART.SRA.USHIPCOMMERCE_PARTNERS": "ushipcommerce_partners",
    }

    # Check if today is Wednesday (Wednesday corresponds to 2 in the weekday() function, where Monday is 0 and Sunday is 6)
    if current_date.weekday() == 2:
        logger.info("Today is Wednesday! Time for FuelPrices")
        snowflake_tables = [
            "DATAMART.SRA.FUELPRICES",
            "DATAMART.SRA.USHIPCOMMERCE_PARTNERS",
        ]
    else:
        snowflake_tables = ["DATAMART.SRA.USHIPCOMMERCE_PARTNERS"]

    try:
        # Establishing connections
        logger.info("Connecting to Snowflake with sqlalchemy...")
        conn_snowflake = snowflake_connection_sqlalchemy(**config["snowflake"])
        sf_sqlal_connection = conn_snowflake.connect()
        logger.info("Connected to Snowflake")

        logger.info("Connecting to SQL Server with sqlalchemy...")
        sig_engine = connect_db_sqlalchemy(
            config["db_server"],
            config["db_name"],
            config["username"],
            config["password"],
        )
        logger.info("Connected to SQL Server")

        for i in range(0, len(snowflake_tables)):
            # Snowflake query
            if "fuelprices" in snowflake_tables[i].lower():
                logger.info(
                    "Getting data from the snowflake table: %s", snowflake_tables[i]
                )
                snowflake_query = f"SELECT \
                                        DATE as date, \
                                        MAX(CASE WHEN TYPE = 'Total Gasoline' THEN PPG ELSE NULL END) AS gas, \
                                        MAX(CASE WHEN TYPE = 'No 2 Diesel' THEN PPG ELSE NULL END) AS diesel \
                                    FROM {snowflake_tables[i]} \
                                    WHERE DATE > DATEADD(DAY, -7, GETDATE()) \
                                    GROUP BY DATE;"
            else:
                logger.info(
                    "Getting data from the snowflake table (not fuelprices): %s",
                    snowflake_tables[i],
                )
                snowflake_query = f"SELECT * FROM {snowflake_tables[i]}"

            # Query to read data from Snowflake
            logger.info("Getting Data from Snowflake")
            df = pd.read_sql(snowflake_query, conn_snowflake)
            print("Length of dataframe: ", len(df))

            # Define target MSSQL table name
            mssql_table_name = table_mapping[snowflake_tables[i]]
            print("Table Name:", mssql_table_name)

            if "ushipcommerce_partners" in mssql_table_name:
                # print("The substring 'partners' is found in the table name.")
                # Truncate the table in MSSQL
                with sig_engine.connect() as conn:
                    result = conn.execute(text("SELECT 1"))
                    logger.info("Connection test successful: %s", result.fetchone())
                    sql_statement = text(
                        f"TRUNCATE TABLE [Pricing].[dbo].[{mssql_table_name}]"
                    )
                    logger.info("sql_statement: %s", sql_statement)
                    # Execute the statement
                    try:
                        # Execute the statement
                        trun_result = conn.execution_options(autocommit=True).execute(
                            text(f"TRUNCATE TABLE [Pricing].[dbo].[{mssql_table_name}]")
                        )
                        logger.info("Execution successful: %s", trun_result)
                    except SQLAlchemyError as e:
                        logger.info(f"An error occurred: {e}")

            # Write data to MSSQL
            logger.info("Writing Data to SQL Server")
            df.to_sql(
                mssql_table_name,
                schema="dbo",
                con=sig_engine,
                if_exists="append",
                index=False,
            )

        # Close the MSSQL connection
        logger.info("Reading, Writing done. Closing all connections")

    except SQLAlchemyError as e:
        logger.error(f"Database error occurred: {e}")
        raise Exception("A new error occurred") from e
    except Exception as e:
        logger.error(f"An unexpected error occurred: {e}")
        raise Exception("A new error occurred") from e
    finally:
        # Clean up and close connections
        logger.info("Closing database connections...")
        if sf_sqlal_connection:
            sf_sqlal_connection.close()
            conn_snowflake.dispose()
        if sig_engine:
            sig_engine.dispose()


if __name__ == "__main__":
    main()
