import coloredlogs
from datetime import datetime
import logging

from snowflake.sqlalchemy import URL
from sqlalchemy import create_engine

from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.asymmetric import dsa
from cryptography.hazmat.primitives import serialization
from snowflake.connector.pandas_tools import write_pandas
from snowflake.connector import connect

logger = logging.getLogger(__name__)
coloredlogs.install(level="DEBUG", logger=logger, isatty=True)

def snowflake_connection(
    snowflake_username,
    snowflake_keypass,
    snowflake_password,
    snowflake_account,
    snowflake_warehouse,
    snowflake_database,
    snowflake_role
):
    """
    Establishes a connection to Snowflake and returns the connection object.

    Args:
        username (str): Snowflake username.
        keypass (str): Snowflake key password.
        password (str): Snowflake password.
        account (str): Snowflake account name.
        warehouse (str): Snowflake warehouse name.
        database (str): Snowflake database name.
        role (str): Snowflake role name.

    Returns:
        snowflake.connector.connection: Snowflake connection object.
    """
    logger.debug("Getting the credentials...")

    pem_data = snowflake_keypass
    p_key = serialization.load_pem_private_key(
        pem_data.encode(),
        password=snowflake_password.encode(),
        backend=default_backend(),
    )
    pkb = p_key.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )

    try:
        conn = connect(
            user=snowflake_username,
            private_key=pkb,
            account=snowflake_account,
            role=snowflake_role,
            warehouse=snowflake_warehouse,
            database=snowflake_database,
        )
        return conn
    except Exception as e:
        logger.error(f"Failed to write to Snowflake: {e}")
        raise


def snowflake_connection_sqlalchemy(
    snowflake_username,
    snowflake_keypass,
    snowflake_password,
    snowflake_account,
):
    """
    Establishes a connection to Snowflake and returns the connection object.

    Args:
        username (str): Snowflake username.
        keypass (str): Snowflake key password.
        password (str): Snowflake password.
        account (str): Snowflake account name.
        warehouse (str): Snowflake warehouse name.
        database (str): Snowflake database name.
        role (str): Snowflake role name.

    Returns:
        snowflake.connector.connection: Snowflake connection object.
    """
    logger.debug("Getting the credentials for snowflake connection with sqlalchemy...")

    from snowflake.sqlalchemy import URL
    from sqlalchemy import create_engine

    from cryptography.hazmat.backends import default_backend
    from cryptography.hazmat.primitives.asymmetric import rsa
    from cryptography.hazmat.primitives.asymmetric import dsa
    from cryptography.hazmat.primitives import serialization


    pem_data = snowflake_keypass
    p_key = serialization.load_pem_private_key(
        pem_data.encode(),
        password=snowflake_password.encode(),
        backend=default_backend(),
    )
    pkb = p_key.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )

    try:
        engine = create_engine(URL(
                    account=snowflake_account,
                    user=snowflake_username,
                    ),
                    connect_args={
                        'private_key': pkb,
                        },
                )
        return engine
    except Exception as e:
        logger.error(f"Failed to write to Snowflake: {e}")
        raise
