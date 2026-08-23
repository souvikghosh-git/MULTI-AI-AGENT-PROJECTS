import streamlit as st
import requests

from app.config.settings import settings
from app.common.logger import get_logger
from app.common.custom_exception import CustomException

logger = get_logger(__name__)

st.set_page_config(page_title="Multi AI Agent", page_icon="🤖", layout="centered")
st.title("🤖 Multi AI Agent (Groq & Tavily)")

# Models that support tool calling (Tavily search)
TOOL_ENABLED_MODELS = [
    "openai/gpt-oss-120b",
    "openai/gpt-oss-20b",
    "qwen/qwen3.6-27b",
]

# Initialize persistent session state for chat history
if "chat_history" not in st.session_state:
    st.session_state.chat_history = []

with st.sidebar:
    st.header("⚙️ Configuration")
    system_prompt = st.text_area(
        "Define Agent Persona / System Prompt:",
        value="You are a helpful and knowledgeable AI assistant.",
        height=100
    )
    
    selected_model = st.selectbox(
        "Select AI Model:",
        settings.ALLOWED_MODEL_NAMES,
        index=1  # Default to openai/gpt-oss-20b (fast & supports tools)
    )
    
    allow_web_search = st.checkbox("🔍 Allow Web Search (Tavily)", value=False)
    
    if allow_web_search and selected_model not in TOOL_ENABLED_MODELS:
        st.warning(f"⚠️ Web search is best supported by: {', '.join(TOOL_ENABLED_MODELS)}")
    
    if st.button("🗑️ Clear History"):
        st.session_state.chat_history = []
        st.rerun()

user_query = st.text_area("💬 Enter your query:", height=100, placeholder="Ask anything...")

API_URL = "http://127.0.0.1:9999/chat"

if st.button("🚀 Ask Agent", type="primary") and user_query.strip():
    payload = {
        "model_name": selected_model,
        "system_prompt": system_prompt,
        "messages": [user_query.strip()],
        "allow_search": allow_web_search
    }

    with st.spinner("🤖 Agent is thinking and retrieving response..."):
        try:
            logger.info("Sending request to backend")
            response = requests.post(API_URL, json=payload, timeout=90)

            if response.status_code == 200:
                agent_response = response.json().get("response", "")
                logger.info("Successfully received response from backend")

                # Store query and response in session state so it never vanishes
                st.session_state.chat_history.append({
                    "query": user_query.strip(),
                    "response": agent_response,
                    "model": selected_model,
                    "search": allow_web_search
                })
            else:
                error_detail = response.json().get("detail", "Unknown backend error")
                logger.error(f"Backend error: {error_detail}")
                st.error(f"❌ Backend Error: {error_detail}")

        except requests.exceptions.Timeout:
            logger.error("Request to backend timed out")
            st.error("❌ Request timed out. Try a faster model like `openai/gpt-oss-20b`.")
        except Exception as e:
            logger.error("Error occurred while communicating with backend")
            st.error(f"❌ Communication Error: {str(e)}")

# Display persistent conversation history
if st.session_state.chat_history:
    st.divider()
    for idx, item in enumerate(reversed(st.session_state.chat_history)):
        with st.container():
            st.markdown(f"**👤 You:** {item['query']}")
            badge = "🔍 Web Search" if item.get("search") else "⚡ Direct LLM"
            st.caption(f"Model: `{item['model']}` | {badge}")
            st.markdown(item["response"])
            st.divider()


        

