FROM node:18-alpine

WORKDIR /app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy application code
COPY . .

# Expose the API port
EXPOSE 8080

# Define default environment variables
ENV PORT=8080
ENV HTTPS_PORT=443
ENV VLLM_PORT=8000
ENV VLLM_HOST=localhost
ENV MODEL_ID=""
ENV USE_HTTPS="false"

# Run the application
CMD ["node", "server.js"]
