import logging
import os
import smtplib
from email.message import EmailMessage

from google.cloud import secretmanager

PROJECT_ID = os.environ.get("GCP_PROJECT_ID", "my-project-77-511616")
SECRET_NAME = os.environ.get("GMAIL_SECRET_NAME", "gmail-app-password")
SENDER = os.environ["GMAIL_SENDER"]
RECIPIENT = os.environ["GMAIL_RECIPIENT"]


def _secret():
    client = secretmanager.SecretManagerServiceClient()
    name = f"projects/{PROJECT_ID}/secrets/{SECRET_NAME}/versions/latest"
    return client.access_secret_version(request={"name": name}).payload.data.decode().strip()


def send_email(subject: str, body: str) -> None:
    password = _secret()
    message = EmailMessage()
    message["Subject"] = subject
    message["From"] = SENDER
    message["To"] = RECIPIENT
    message.set_content(body)
    with smtplib.SMTP("smtp.gmail.com", 587, timeout=30) as smtp:
        smtp.ehlo()
        smtp.starttls()
        smtp.ehlo()
        smtp.login(SENDER, password)
        smtp.send_message(message)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    send_email("AtmosData email module test", "Email module connectivity test.")
