# sql_files = sorted(find_sql_files(repo_path))
    sql_files = sorted(find_sql_files('sql/Pricing/test'))

    for sql_file in sql_files:

        # Log before executing
        log_message(f"Executing {sql_file}")

        try:
            with open(sql_file, 'r') as file:
                sql_script = file.read()
            crs.execute(sql_script)
            conn.commit()
            # result = crs.fetchall()
            print(f"Output of {sql_file}:\n")
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

    try:

        # with open(sql_file, 'r') as file:
            # sql_script = file.read()
        sql_script = "SELECT * FROM dbo.omsa_surcharge"
        crs.execute(sql_script)
        # conn.commit()
        # Fetch all rows from the query
        rows = crs.fetchall()

        # Print the rows
        for row in rows:
            print(row)
        # Log on success
        log_message("Success")
    except Exception as e:
        # Log other types of errors
        log_message(f"Error occurred: {e}")
