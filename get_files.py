import os
import glob

# Assuming your files are in the root directory of your repo
repo_path = os.getcwd()

# for root, dirs, files in os.walk(repo_path):
#     for file in files:
#         print(os.path.join(root, file))

def find_sql_files(start_path):
    """Recursively find all .sql files in the given directory."""
    return glob.glob(start_path + '/**/*.sql', recursive=True)

print(sorted(find_sql_files(repo_path)))
