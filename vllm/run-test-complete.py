import yaml
import os
import logging
import time
from openai import OpenAI
import gradio as gr

# Load configuration
with open("config.yaml", "r") as stream:
    config = yaml.safe_load(stream)

# Environment variables
llm_model = "cognitivecomputations/dolphin-2.6-mistral-7b-dpo-laser"
llm_url = os.environ.get("LLM_URL", "http://Hades:8000")
llm_context = 4096
openai_api_key = "YOUR_API_KEY"
openai_api_base = llm_url + "/v1"
persona_name = os.environ.get("PERSONA", "Default")
server_port = int(os.environ.get("PORT", 8650))
server_name = os.environ.get("SERVER_NAME", "0.0.0.0")
ui_theme = config["personas"][persona_name]["theme"]
persona_full_name = config["personas"][persona_name]["name"]
app_title = config["personas"][persona_name]["title"]
persona_avatar_image = f"images/{config['personas'][persona_name]['avatar']}"
description = config["personas"][persona_name]["description"]
system_message = config["personas"][persona_name]["system_message"]
persona = config["personas"][persona_name]["persona"]
chat_examples = config["personas"][persona_name]["topic_examples"]
temperature = config["personas"][persona_name]["temperature"]
preferences = config["personas"][persona_name]["preferences"]

# Define Logging setup
debug = False
log_level = logging.DEBUG if debug else logging.INFO
logs_path = config["logs_path"]
if not os.path.exists(logs_path):
    os.makedirs(logs_path)
logging.basicConfig(
    filename=logs_path + "/client-chat-" + persona_full_name + ".log",
    level=log_level,
    format="%(asctime)s:%(levelname)s:%(message)s",
)

# Initialize LLM client
client = OpenAI(
    api_key=openai_api_key,
    base_url=openai_api_base,
)

# Configure tools and external data
def current_timestamp():
    return time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(time.time()))

# Cache for model parameters to avoid repeated fetches
model_parameters_cache = {}

# Chat history list
chat_history = []

def estimate_token_count(messages):
    """Estimate the total number of tokens in the list of messages."""
    return sum(len(message["content"].split()) for message in messages)  # Simple word count as a proxy for token count

def trim_history_to_fit(context_limit, new_entry_token_estimate):
    """Trim the oldest entries in the chat history to fit within the context limit."""
    global chat_history
    current_token_count = estimate_token_count(chat_history)
    while current_token_count + new_entry_token_estimate > context_limit and chat_history:
        removed_message = chat_history.pop(0)  # Remove the oldest message
        current_token_count -= estimate_token_count([removed_message])  # Update the token count


# Execute inference
def inference(message, history):
    global chat_history  # Use the global chat history
    try:
        timestamp = current_timestamp()
        
        # Construct the full message with system information
        system_message_full = system_message + persona + "The current time is " + timestamp
        
        # Estimate token count for the new entries (user message and system message)
        new_entry_token_estimate = estimate_token_count([{"content": message}, {"content": system_message_full}])
        
        # Ensure the chat history fits within the model's context limit before adding new messages
        trim_history_to_fit(llm_context, new_entry_token_estimate)
        
        # Now, it's safe to add the user message and system message to the history
        chat_history += [
            {"role": "system", "content": system_message_full},
            {"role": "user", "content": message}
        ]
        
        chat_response = client.chat.completions.create(
            model=llm_model,
            messages=chat_history,
            temperature=temperature,
        )
        
        # Extract response and update chat history with model's response
        response_text = chat_response.choices[0].message.content
        chat_history.append({"role": "system", "content": response_text})
        
        return response_text
    except Exception as e:
        logging.error(f"Error during inference: {str(e)}")
        logging.error("Partial response object may not be available due to the error")
        return f"An error occurred: {str(e)}"


# Launch UI
chat_interface = gr.ChatInterface(
    inference,
    title=app_title,
    description=description,
    chatbot=gr.Chatbot(
        height=500,
        avatar_images=[None, persona_avatar_image],
        likeable=True,
        show_copy_button=True,
    ),
    textbox=gr.Textbox(
        placeholder="Hello! What would you like to talk about?",
        container=False,
        scale=7,
    ),
    retry_btn="Rephrase",
    undo_btn="Undo",
    clear_btn="Clear",
    examples=chat_examples,
    theme=ui_theme,
    analytics_enabled=False,
)

# Run program
if __name__ == "__main__":
    chat_interface.queue().launch(server_name=server_name, server_port=server_port)
