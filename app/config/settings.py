from dotenv import load_dotenv
import os
import json
import boto3
from botocore.exceptions import ClientError

load_dotenv()


def _get_secret(secret_name: str) -> str:
    """Fetch a secret value from AWS Secrets Manager."""
    region = os.getenv("AWS_DEFAULT_REGION", "us-east-1")
    client = boto3.client("secretsmanager", region_name=region)
    try:
        response = client.get_secret_value(SecretId=secret_name)
        value = response.get("SecretString", "")
        # Handle JSON-encoded secrets
        try:
            return json.loads(value)
        except (json.JSONDecodeError, TypeError):
            return value
    except ClientError as e:
        raise RuntimeError(f"Failed to fetch secret '{secret_name}': {e}")


def _resolve_key(env_var: str, secret_name: str) -> str:
    """
    Resolve an API key:
    - In local dev: read from .env file via environment variable.
    - In production (ECS): fetch from AWS Secrets Manager.
    """
    # If the env var is already set (local dev / .env), use it directly
    value = os.getenv(env_var)
    if value:
        return value
    # Otherwise fetch from Secrets Manager (production path)
    return _get_secret(secret_name)


class Settings:
    GROQ_API_KEY: str = _resolve_key(
        "GROQ_API_KEY",
        "multi-ai-agent/groq-api-key"
    )
    TAVILY_API_KEY: str = _resolve_key(
        "TAVILY_API_KEY",
        "multi-ai-agent/tavily-api-key"
    )

    ALLOWED_MODEL_NAMES = [
        "openai/gpt-oss-120b",
        "openai/gpt-oss-20b",
        "groq/compound",
        "groq/compound-mini",
        "qwen/qwen3.6-27b",
        "allam-2-7b",
    ]


settings = Settings()

