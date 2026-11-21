from google.cloud.sql.connector import Connector, IPTypes
from google.cloud import secretmanager

PROJECT = "my-project-77-511616"
INSTANCE = "my-project-77-511616:asia-south1:atmosdata-mysql-dev"

password = secretmanager.SecretManagerServiceClient().access_secret_version(
    request={
        "name": f"projects/{PROJECT}/secrets/atmosdata-mysql-password/versions/latest"
    }
).payload.data.decode().strip()

connector = Connector(ip_type=IPTypes.PUBLIC)

try:
    conn = connector.connect(
        INSTANCE,
        "pymysql",
        user="atmosdata_app",
        password=password,
        db="atmosdata_ops"
    )

    cursor = conn.cursor()
    cursor.execute("""
        SELECT run_id, city_name, status, gcs_object
        FROM ingestion_audit
        ORDER BY audit_id DESC
        LIMIT 10
    """)

    for row in cursor.fetchall():
        print(row)

    print("MySQL 8.4 authentication compatibility test: PASSED")

    cursor.close()
    conn.close()

finally:
    connector.close()
