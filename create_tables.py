import os
# import pyodbc
import sys
import glob
import argparse
from datetime import datetime

def find_sql_files(start_path):
    """Recursively find all .sql files in the given directory."""
    return glob.glob(start_path + '/**/*.sql', recursive=True)

def log_message(message):
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    print(f"{timestamp} - {message}")

def main(db_server, db_name, username, password, repo_path):
    # Create connection string
    conn_str = f'DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={db_server};DATABASE={db_name};UID={username};PWD={password}'

    # Get list of .sql files in specified directory, sorted alphabetically
    sql_files = sorted(find_sql_files(repo_path))

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

        except pyodbc.Error as e:
            # Log SQL error
            log_message(f"SQL Error occurred: {e}")
            # Continue with the next file instead of stopping the script
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
    db_server = os.getenv('DB_SERVER', 'localhost')
    db_name = os.getenv('DB_NAME', 'test')
    username = os.getenv('USERNAME')
    password = os.getenv('PASSWORD')
    repo_path = os.getenv('REPO_PATH', '.')

    main(db_server, db_name, username, password, repo_path)
