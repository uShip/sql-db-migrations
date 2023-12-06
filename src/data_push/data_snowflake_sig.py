from datetime import datetime
import os
import sys
import pandas as pd
from sqlalchemy import create_engine
import coloredlogs
import logging

sys.path.append("src/helpers")
from db_conn import (
    connect_db,
    DestroyDBConnections,
    connect_db_sqlaclchemy,
    log_message,
)

from snowflake_conn import (
    snowflake_connection,
    snowflake_connection_sqlalchemy
)

# from src.helpers.db_conn import connect_db, DestroyDBConnections, snowflake_connection
logger = logging.getLogger(__name__)
coloredlogs.install(level="DEBUG", logger=logger, isatty=True)

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
    # SQL connection parameters
    db_server = os.getenv("DB_SERVER")
    db_name = os.getenv("DB_NAME")
    username = os.getenv("USERNAME")
    password = os.getenv("PASSWORD")

    # Snowflake connection parameters
    snowflake_username = os.environ["snowflake_username"]
    snowflake_keypass = os.environ["snowflake_keypassword"]
    snowflake_password = os.environ["snowflake_password"]
    snowflake_account = os.environ["snowflake_accountname"]
    snowflake_warehouse = os.environ["snowflake_warehouse"]
    snowflake_database = os.environ["snowflake_database"]
    snowflake_role = os.environ["snowflake_role"]

    # Get the current date
    current_date = datetime.now()

    # Check if today is Wednesday (Wednesday corresponds to 2 in the weekday() function, where Monday is 0 and Sunday is 6)
    if current_date.weekday() == 2:
        print("Today is Wednesday!")
        snowflake_tables = [
            "DATAMART.SRA.FUELPRICES",
            "DATAMART.SRA.USHIPCOMMERCE_PARTNERS",
        ]
    else:
        snowflake_tables = ["DATAMART.SRA.USHIPCOMMERCE_PARTNERS"]

    try:
        table_mapping = {
            "DATAMART.SRA.FUELPRICES": "dbo.fuelprices",
            "DATAMART.SRA.USHIPCOMMERCE_PARTNERS": "dbo.ushipcommerce_partners",
        }

        # Establish connection to Snowflake and SQL Server
        print("Connecting to Snowflake with sqlalchemy...")
        conn_snowflake = snowflake_connection_sqlalchemy(
            snowflake_username, snowflake_keypass, snowflake_password, snowflake_account
        )
        # print("Connecting to Snowflake...")
        # conn_snowflake = snowflake_connection(
        #     snowflake_username,
        #     snowflake_keypass,
        #     snowflake_password,
        #     snowflake_account,
        #     snowflake_warehouse,
        #     snowflake_database,
        #     snowflake_role,
        # )
        # cursor_snowflake = conn_snowflake.cursor()
        sf_sqlal_connection = conn_snowflake.connect()
        log_message("Connected to Snowflake")

        # Create a connection to MSSQL using SQLAlchemy engine
        # connection_str = f'mssql+pyodbc://{username}:{password}@{db_server}/{db_name}?driver=ODBC+Driver+18+for+SQL+Server&Encrypt=no'
        log_message("trying SQL engine connection with import sqlserver statement")
        sig_engine = connect_db_sqlaclchemy(db_server, db_name, username, password)
        log_message("succesful connection established to SQL server")
        # engine = create_engine(connection_str, echo=True, connect_args={'timeout': 90})

        for i in range(0, len(snowflake_tables)):
            # Snowflake query
            if "fuelprices" in snowflake_tables[i]:
                snowflake_query = f"SELECT \
                                        DATE, \
                                        MAX(CASE WHEN TYPE = 'Total Gasoline' THEN PPG ELSE NULL END) AS gas, \
                                        MAX(CASE WHEN TYPE = 'No 2 Diesel' THEN PPG ELSE NULL END) AS diesel \
                                    FROM {snowflake_tables[i]} \
                                    WHERE DATE > DATEADD(DAY, -7, GETDATE()) \
                                    GROUP BY DATE;"
            else:
                snowflake_query = f"SELECT * FROM {snowflake_tables[i]}"

            # Query to read data from Snowflake
            log_message("Getting Data from Snowflake")
            # conn_snowflake.execute(snowflake_query)
            # df = cursor_snowflake.fetch_pandas_all()
            df = pd.read_sql(snowflake_query, conn_snowflake)
            print('Length of dataframe: ', len(df))

            # Define target MSSQL table name
            mssql_table_name = table_mapping[snowflake_tables[i]]
            print("Table Name:", mssql_table_name)

            if "ushipcommerce_partners" in mssql_table_name:
                print("The substring 'partners' is found in the table name.")
                print('Calling sig engine connection')
                # Truncate the table in MSSQL
                with sig_engine.connect() as conn:
                    result = conn.execute("SELECT 1")
                    print("Connection test successful:", result.fetchone())
                    conn.execute(f"TRUNCATE TABLE {mssql_table_name}")

            # Write data to MSSQL
            log_message("Writing Data to SQL Server")
            df.to_sql(mssql_table_name, con=sig_engine, if_exists="append", index=False)

            # Close the MSSQL connection
            log_message("Reading, Writing done. Closing all connections")
            sig_engine.dispose()
            sf_sqlal_connection.close()
            conn_snowflake.dispose()

    except Exception as e:
        # Log other types of errors
        log_message(f"Error occurred: {e}")
        raise Exception("A new error occurred") from e


if __name__ == "__main__":
    main()
