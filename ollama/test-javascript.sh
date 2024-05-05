#!/bin/bash

# Load nvm and use latest Node.js
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
nvm install node
nvm use node

# Check if OpenAI npm package is installed, install if not
if ! npm list -g | grep -q openai; then
  npm install -g openai
fi

# Run the Node.js script using CommonJS syntax
node - <<EOF
const OpenAI = require('openai');

const openai = new OpenAI({
  baseURL: 'http://hades:8081/v1',
  apiKey: 'ollama',
});

async function getResponse() {
  const completion = await openai.chat.completions.create({
    model: 'llama3',
    messages: [
        { role: 'system', content: 'You are a helpful AI assistant who answers mundane questions from humans.' },
        { role: 'user', content: 'Why is the sky blue?' }
    ],
  });
  console.log(completion.choices[0].message.content);
}

getResponse();
EOF
