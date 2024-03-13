import io
import random
import gzip
import json
import numpy as np
from typing import Any, List, Tuple
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.neighbors import NearestNeighbors

class ChatHistoryManager:
    def __init__(self, context_limit: int, max_message_length: int):
        self.context_limit = context_limit
        self.max_message_length = max_message_length
        self.chat_history = []

    def estimate_token_count(self, messages: List[Any]) -> int:
        """Estimate the total number of tokens in the list of messages."""
        return sum(len(message["content"].split()) for message in messages)

    def extract_features(self, message: Any) -> np.ndarray:
        """Extract features from the message content."""
        return TfidfVectorizer().fit_transform([message["content"]])[0]

    def insert_message(self, user: str, message: Any) -> None:
        """Insert a new message into the chat history."""
        if self.estimate_token_count(self.chat_history) + self.extract_features(message).size > self.context_limit:
            self.trim_oldest_messages(self.extract_features(message).size)
        self.chat_history.append({"user": user, "content": message["content"]})

    def trim_oldest_messages(self, token_estimate: int) -> None:
        """Trim the oldest entries in the chat history to fit within the context limit."""
        while self.estimate_token_count(self.chat_history[:-token_estimate]) + token_estimate > self.context_limit:
            self.chat_history.pop(0)

    def get_relevant_messages(self, new_message: Any) -> List[Any]:
        """Return a list of relevant messages from the chat history based on the new message content."""
        new_message_features = self.extract_features(new_message)
        relevant_messages = []
        for message in self.chat_history:
            message_features = self.extract_features(message)
            if np.inner(new_message_features, message_features) > 0.5:  # Cosine similarity threshold
                relevant_messages.append(message)
        return relevant_messages

# Example usage:
chat_history_manager = ChatHistoryManager(context_limit=100, max_message_length=250)

# Simulate user input
def simulate_user_input(user: str) -> Tuple[str, Any]:
    # Randomly generate a message content
    message_content = " ".join(random.choices(["Hello, how are you?", "I'm doing well, thank you.", "What's new with you?"], k=random.randint(1, 3)))
    # Generate a random message length
    message_length = random.randint(50, 250)
    # Simulate a message with random user input and length
    return user, {"content": message_content, "length": message_length}

# Simulate a chat conversation
for _ in range(100):
    user, message = simulate_user_input("User")
    chat_history_manager.insert_message("User", message)
    new_message_content = " ".join(random.choices(["I just read an interesting article on renewable energy.", "Tell me more about your work at SolidRusT Networks.", "I heard you're working on a new chatbot project."], k=random.randint(1, 3)))
    chat_history_manager.insert_message("Veronica", {"content": new_message_content, "length": random.randint(50, 250)})
