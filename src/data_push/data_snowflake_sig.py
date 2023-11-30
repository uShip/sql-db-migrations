from datetime import datetime
import os
import sys
sys.path.append("src/helpers")
from db_conn import connect_db, DestroyDBConnections, snowflake_connection, log_message
# from src.helpers.db_conn import connect_db, DestroyDBConnections, snowflake_connection


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
        print('Connecting to Snowflake')
        conn_snowflake = snowflake_connection(
            snowflake_username,
            snowflake_keypass,
            snowflake_password,
            snowflake_account,
            snowflake_warehouse,
            snowflake_database,
            snowflake_role,
        )
        cursor_snowflake = conn_snowflake.cursor()
        print('Connected to Snowflake')

        print('Connecting to Snowflake')
        conn_mssql, cursor_mssql = connect_db(db_server, db_name, username, password)

        for i in range(0, len(snowflake_tables)):
            # Snowflake query
            if snowflake_tables[i].contains("fuelprices"):
                snowflake_query = f"SELECT \
                                        DATE, \
                                        MAX(CASE WHEN TYPE = 'Total Gasoline' THEN PPG ELSE NULL END) AS gas, \
                                        MAX(CASE WHEN TYPE = 'No 2 Diesel' THEN PPG ELSE NULL END) AS diesel \
                                    FROM {snowflake_tables[i]} \
                                    WHERE DATE > DATEADD(DAY, -7, GETDATE()) \
                                    GROUP BY DATE;"
            else:
                snowflake_query = f"SELECT * FROM {snowflake_tables[i]}"
            # Fetch data from Snowflake
            cursor_snowflake.execute(snowflake_query)
            data = cursor_snowflake.fetchall()
            print(data)

            # Get column names from Snowflake result
            columns = [desc[0] for desc in cursor_snowflake.description]

            # Define target MSSQL table name
            mssql_table_name = table_mapping[snowflake_tables[i]]

            # Insert data into MSSQL
            insert_data_into_mssql(
                conn_mssql, cursor_mssql, mssql_table_name, columns, data
            )

    except Exception as e:
        # Log other types of errors
        log_message(f"Error occurred: {e}")
        # Continue with the next file
    # finally:
    #     DestroyDBConnections(conn_mssql, cursor_mssql)


if __name__ == "__main__":
    main()
