import os
import pyodbc
import glob
from datetime import datetime

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
        # crs = conn.cursor()
        log_message("Connected to Database")
        return conn
    except (pyodbc.Error, pyodbc.OperationalError) as e:
        log_message("Failed to connect to the Database: %s", e)
        raise Exception("Database connection timed out or failed") from e

def DestroyDBConnections(conn, crs):
    if "Connection" in str(type(conn)) and "Cursor" in str(type(crs)):
        crs.close()
        conn.close()
        logger.info("Closing the connection.")

def find_sql_files(start_path):
    """Recursively find all .sql files in the given directory."""
    return glob.glob(start_path + '/**/*.sql', recursive=True)

def log_message(message):
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    print(f"{timestamp} - {message}")

def main(db_server, db_name, username, password, repo_path):
    # Create connection string
    # conn_str = f'DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={db_server};DATABASE={db_name};UID={username};PWD={password}'
    conn = connect_db(db_server, db_name, username, password)
    # Get list of .sql files in specified directory, sorted alphabetically
    sql_files = sorted(find_sql_files(repo_path))
    sql_script = "SELECT * FROM dbo.calendar"

    try:
        with conn:
            # with open(sql_file, 'r') as file:
                # sql_script = file.read()
            with conn.cursor() as cursor:
                cursor.execute(sql_script)
                conn.commit()
        # Log on success
        log_message("Success")
    except Exception as e:
        # Log other types of errors
        log_message(f"Error occurred: {e}")

    for sql_file in sql_files:

        # Log before executing
        log_message(f"Executing {sql_file}")

        try:
            # with pyodbc.connect(conn_str) as conn:
            #     with open(sql_file, 'r') as file:
            #         sql_script = file.read()
            #         with conn.cursor() as cursor:
            #             cursor.execute(sql_script)
            #             conn.commit()

            # Log on success
            log_message("Success")

        # except pyodbc.Error as e:
        #     # Log SQL error
        #     log_message(f"SQL Error occurred: {e}")
        #     # Continue with the next file instead of stopping the script
        except Exception as e:
            # Log other types of errors
            log_message(f"Error occurred: {e}")
            # Continue with the next file

if __name__ == "__main__":
    # parser = argparse.ArgumentParser(description="Database Migration Script")
    # parser.add_argument('--db_server', default='localhost', help='Database server address (default: localhost)')
    # parser.add_argument('--db_name', required=True, help='Database name')
    # parser.add_argument('--username', required=True, help='Database username')
    # parser.add_argument('--password', required=True, help='Database password')
    # parser.add_argument('--repo_path', default='.', help='Path to the repository containing SQL files (default: current directory)')

    # args = parser.parse_args()
    db_server = os.getenv('DB_SERVER')
    db_name = os.getenv('DB_NAME')
    username = os.getenv('USERNAME')
    password = os.getenv('PASSWORD')
    repo_path = os.getenv('REPO_PATH', '.')

    main(db_server, db_name, username, password, repo_path)
