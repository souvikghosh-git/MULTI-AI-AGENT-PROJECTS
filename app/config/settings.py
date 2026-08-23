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
    # Try the specific secret name first, then with environment suffixes
    candidates = [
        secret_name,
        f"{secret_name}-prod",
        f"{secret_name}-dev",
        f"{secret_name}-staging"
    ]
    last_error = None
    for name in candidates:
        try:
            response = client.get_secret_value(SecretId=name)
            value = response.get("SecretString", "")
            try:
                parsed = json.loads(value)
                return parsed if isinstance(parsed, str) else value
            except (json.JSONDecodeError, TypeError):
                return value
        except ClientError as e:
            last_error = e
            continue
    print(f"Warning: Could not fetch secret '{secret_name}' from Secrets Manager: {last_error}")
    return ""


def _resolve_key(env_var: str, secret_name: str) -> str:
    """
    Resolve an API key:
    - If already present in environment (e.g. .env or ECS task def injection), use it.
    - Otherwise fetch from AWS Secrets Manager.
    - Export to os.environ so all libraries (LangChain/Tavily) find it.
    """
    val = os.getenv(env_var)
    if val and val.strip():
        return val.strip()
    
    try:
        secret_val = _get_secret(secret_name)
        if secret_val:
            os.environ[env_var] = secret_val
            return secret_val
    except Exception as e:
        print(f"Warning: Error resolving key {env_var}: {e}")
    
    return ""


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
        "openai/gpt-oss-20b",
        "openai/gpt-oss-120b",
        "qwen/qwen3.6-27b",
        "groq/compound",
        "groq/compound-mini",
        "allam-2-7b",
    ]


settings = Settings()
if settings.GROQ_API_KEY:
    os.environ["GROQ_API_KEY"] = settings.GROQ_API_KEY
if settings.TAVILY_API_KEY:
    os.environ["TAVILY_API_KEY"] = settings.TAVILY_API_KEY

