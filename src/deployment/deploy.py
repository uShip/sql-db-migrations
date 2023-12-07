import os
import sys
import pyodbc
import glob
from datetime import datetime
import logging
import coloredlogs

sys.path.append("src/helpers")
from db_conn import (
    connect_db,
    DestroyDBConnections,
    log_message,
)

# Setting up logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)
coloredlogs.install(level="DEBUG", logger=logger, isatty=True)


def log_execution_status(file_path, status):
    """
    Logs the execution status of a SQL script to a file.

    Parameters:
        file_path (str): The path of the SQL file.
        status (str): The execution status ('Success' or 'Error').
    """
    with open("src/deployment/execution_log.txt", "a") as log_file:
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        logger.info(f"{timestamp} - {file_path} - {status}")
        log_file.write(f"{timestamp} - {file_path} - {status}\n")


def find_sql_files(start_path):
    """Recursively find all .sql files in the given directory."""
    return glob.glob(start_path + "/**/*.sql", recursive=True)


def execute_sql_script(file_path, cursor, conn):
    # Read the SQL file
    try:
        with open(file_path, "r") as file:
            sql_script = file.read()

        # Check the file path and execute the corresponding SQL command
        if "create_table" in file_path:
            logging.info("Starting Create Table")
            cursor.execute(sql_script)
            conn.commit()
            # logging.info(f"Output of {file_path}:\n")
        elif "insert_data" in file_path:
            logging.info("Skipping Insert Folder Scripts")

        elif "stored_procedures" in file_path:
            logging.info("Starting Stored Procedure file")
            cursor.execute(sql_script)
            conn.commit()

        logging.info(f"Executed script from {file_path}")
        log_execution_status(file_path, "Success")

        return True  # Indicates successful execution
    except pyodbc.Error as e:
        # Log SQL error
        # Continue with the next file instead of stopping the script
        logging.error(f"SQL Error occurred in {file_path}: {e}")
        log_execution_status(file_path, "Error")
        # log_message(f"SQL Error occurred: {e}")


def main(db_server, db_name, username, password, sql_files):
    error_count = 0

    try:
        # Create connection string
        conn, crs = connect_db(db_server, db_name, username, password)
        # Get list of .sql files in specified directory, sorted alphabetically
        for sql_file in sql_files:
            logging.info(f"Starting execution of {sql_file}")
            if sql_file.endswith(".sql"):
                success = execute_sql_script(sql_file, crs, conn)
                if not success:
                    error_count += 1

        if error_count > 0:
            logging.error("One or more SQL scripts failed to execute.")
            # raise Exception("Multiple SQL script execution errors occurred.")
        else:
            logging.info("All SQL scripts executed successfully.")

        # Close the cursor and connection
        crs.close()
        conn.close()
    except Exception as e:
        print(f"Error occurred: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    # args = parser.parse_args()
    db_server = os.getenv("DB_SERVER")
    db_name = os.getenv("DB_NAME")
    username = os.getenv("USERNAME")
    password = os.getenv("PASSWORD")
    repo_path = os.getenv("REPO_PATH", ".")

    # Parse the list of SQL files passed as a space-separated string
    sql_files_str = os.getenv("SQL_FILES", "")
    sql_files = sql_files_str.split() if sql_files_str else []

    main(db_server, db_name, username, password, sql_files)
