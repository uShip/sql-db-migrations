import os

# Assuming your files are in the root directory of your repo
repo_path = os.getcwd()

for root, dirs, files in os.walk(repo_path):
    for file in files:
        print(os.path.join(root, file))
