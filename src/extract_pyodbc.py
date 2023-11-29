from os import getenv
from requests import get

remove_exits = getenv("REMOVE_EXITS", "True")
docs_url = getenv("DOCS_URL")
distro = getenv("DISTRO", "Ubuntu")
ODBC_version = getenv("ODBC_VERSION", "18")

response = get(docs_url, timeout=10).text
split_content = response.split(f"Microsoft ODBC {ODBC_version}")

if len(split_content) < 2:
    print("Error: Expected content not found in the documentation.")
    exit()

ODBC_section = split_content[1].split("---")[0]
platforms = ODBC_section.split("### [")[1:]
per_platform_instructions = {}

for platform in platforms:
    name, code = platform.split("]")[0], platform.split("```bash")[1].split("```")[0]
    per_platform_instructions[name] = (
        code.replace("exit\n", "") if remove_exits else code
    )

if distro in per_platform_instructions:
    print(per_platform_instructions[distro])
else:
    print(f"No instructions found for {distro}.")
