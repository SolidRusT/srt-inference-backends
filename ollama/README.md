# Using ollama inference

## Linux Servers

`curl -fsSL https://ollama.com/install.sh | sh`

then: `systemctl edit ollama.service` and add between the comments:

```plaintext
[Service]
Environment="OLLAMA_HOST=0.0.0.0:8081"
```

Then run: `systemctl daemon-reload && systemctl restart ollama`

## Modelfiles

create a `Modelfile` with the contets referring to your model.
For example:

```Dockerfile
FROM ./vicuna-33b.Q4_0.gguf
```

Create the ollama bindings.

```bash
ollama create Vicuna33 -f Modelfile
```

Launch the CLI

```bash
ollama run Vicuna33
```

## Advanced Modelfile

Control the parameters and system prompt.

```Dockerfile
FROM llama2

# set the temperature to 1 [higher is more creative, lower is more coherent]
PARAMETER temperature 1

# set the system message
SYSTEM """
You are Mario from Super Mario Bros. Answer as Mario, the assistant, only.
"""
```

## References

- [ollama](https://github.com/ollama/ollama)
