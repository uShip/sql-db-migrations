import os
import sys
import pyodbc
import glob
from datetime import datetime, date

# from db_conn import connect_db, DestroyDBConnections

# Get the current date
current_date = date.today()


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


def find_sql_files(start_path):
    """Recursively find all .sql files in the given directory."""
    return glob.glob(start_path + "/**/*.sql", recursive=True)


def log_message(message, *args):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"{timestamp} - {message}")


def execute_sql_script(file_path, cursor, conn):
    # Read the SQL file
    try:
        with open(file_path, "r") as file:
            sql_script = file.read()

        # Check the file path and execute the corresponding SQL command
        if "create_table" in file_path:
            print("Starting Create Table")
            cursor.execute(sql_script)
            conn.commit()
            print(f"Output of {file_path}:\n")
        elif "insert_data" in file_path:
            print("Starting INSERT DATA FUNCTION")
            # cursor.execute(sql_script)
            # conn.commit()
            print(f"Data inserted from {file_path}")
        elif "stored_procedures" in file_path:
            print("Starting Stored Procedure file")
            cursor.execute(sql_script)
            conn.commit()
            print(f"Stored procedure executed from {file_path}")
    except pyodbc.Error as e:
        # Log SQL error
        log_message(f"SQL Error occurred: {e}")
        # Continue with the next file instead of stopping the script
    except Exception as e:
        # Log other types of errors
        log_message(f"Error occurred: {e}")
        # Continue with the next file


def main(db_server, db_name, username, password, sql_files):
    try:
        # Create connection string
        conn, crs = connect_db(db_server, db_name, username, password)
        # Get list of .sql files in specified directory, sorted alphabetically

        # base_folder_path = 'sql/Pricing'

        # for root, dirs, files in os.walk(base_folder_path):
        #     for file in files:
        #         if file.endswith('.sql'):
        #             file_path = os.path.join(root, file)
        #             print(f'{file_path} : {date.fromtimestamp(os.path.getmtime(file_path))}')
        #             # Get the modification time of the file
        #             file_modified_date = date.fromtimestamp(os.path.getmtime(file_path))
        #             # Check if the file was modified or created today
        #             if file_modified_date == current_date:
        #                 execute_sql_script(file_path, crs, conn)

        for sql_file in sql_files:
            if sql_file.endswith(".sql"):
                print(f"starting {sql_file}")
                execute_sql_script(sql_file, crs, conn)

        # Close the cursor and connection
        crs.close()
        conn.close()
    except Exception as e:
        print(f"Error occurred: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    # parser = argparse.ArgumentParser(description="Database Migration Script")
    # parser.add_argument('--db_server', default='localhost', help='Database server address (default: localhost)')
    # parser.add_argument('--db_name', required=True, help='Database name')
    # parser.add_argument('--username', required=True, help='Database username')
    # parser.add_argument('--password', required=True, help='Database password')
    # parser.add_argument('--repo_path', default='.', help='Path to the repository containing SQL files (default: current directory)')

    # args = parser.parse_args()
    db_server = os.getenv("DB_SERVER")
    db_name = os.getenv("DB_NAME")
    username = os.getenv("USERNAME")
    password = os.getenv("PASSWORD")
    repo_path = os.getenv("REPO_PATH", ".")
    # sql_files = sys.argv[1:]

    # Parse the list of SQL files passed as a space-separated string
    sql_files_str = os.getenv("SQL_FILES", "")
    sql_files = sql_files_str.split() if sql_files_str else []

    main(db_server, db_name, username, password, sql_files)

    # main(db_server, db_name, username, password, repo_path)
