# AI Stack

This is a simple stack that stands up a full-featured AI stack that can be run on a local machine using Docker.  It's tuned specifically
for Intel ARC devices using IPEX.  That being said, each of the technologies involved in the stack can be relatively easily re-tuned
for Cuda (nVidia) or ROCM (AMD).

## Models

Ollama models can be found at [https://ollama.com/library](https://ollama.com/library) and Stable Diffusion models for SD.Next can be found at [https://huggingface.co/models](https://huggingface.co/models).

>NOTE:  Commercial and closed-source models [Gemini, ChatGPT, Claude, etc] cannot be run locally.  You may find those models in the Ollama library however they will not be run locally.  For those models you will be proxied through the Ollama cloud to run the requests directly against the models.  These cloud models are heavily limited and sometimes required a paid account.


| Name                      | Purpose                                                                         |
| ------------------------- | ------------------------------------------------------------------------------- |
| `codegemma:2b`            | Standard, fast-response, code completion.                                       |
| `gemma3:4b`               | Gemini-equivalent for general conversation, image generation and web searching. |
| `qwen2.5-coder`           | Code conversation and complex code completion.                                  |
| `DreamShaperXL_Lightning` | Stable diffusion image generation.                                              |

## Environment Variables

Each of the following environment variables can be overridden to control the exact function of the stack.

| Variable                              | Default                                                                                                            |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `STACK_DNS_IPV4_1`                    | `9.9.9.11`                                                                                                         |
| `STACK_DNS_IPV4_2`                    | `149.112.112.11`                                                                                                   |
| `STACK_DNS_IPV6_1`                    | `2620:fe::11`                                                                                                      |
| `STACK_DNS_IPV6_2`                    | `2620:fe::fe:11`                                                                                                   |
| `STACK_IMAGE_STARTUP_TIMEOUT`         | `10m`                                                                                                              |
| `STACK_KEY`                           | `ai`                                                                                                               |
| `STACK_DOMAIN`                        | `${STACK_KEY}.local`                                                                                               |
| `STACK_NAME`                          | `${STACK_KEY}-stack`                                                                                               |
| `STACK_PORTAINER_USERNAME`            | `admin` *static*                                                                                                   |
| `STACK_PORTAINER_PASSWORD`            | `ChangeMe123!!!$`                                                                                                  |
| `STACK_RESTART_POLICY`                | `unless-stopped`                                                                                                   |
| `STACK_SUBNET_IPV4`                   | `172.16.13`                                                                                                        |
| `STACK_SUBNET_IPV6`                   | `fdd0:172:16:13`                                                                                                   |
| `STACK_TIMEZONE`                      | `America/New_York`                                                                                                 |
| `STACK_OLLAMA_DEFAULT_MODEL`          | `gemma3:4b`                                                                                                        |
| `STACK_OLLAMA_MODEL_LIST`             | `gemma3:4b,qwen2.5-coder:7b,codegemma:2b`                                                                          |
| `STACK_SDNEXT_MODEL_LIST`             | `https://huggingface.co/Lykon/dreamshaper-xl-lightning/resolve/main/DreamShaperXL_Lightning-SFW.safetensors`       |
| `STACK_SDNEXT_MODEL_PATH`             | `/mnt/models/Stable-diffusion`                                                                                     |
| `STACK_FRONTEND_WEBUI_ADMIN_EMAIL`    | `admin@${STACK_DOMAIN}`                                                                                            |
| `STACK_FRONTEND_WEBUI_ADMIN_PASSWORD` | `$(openssl rand -base64 32 \| tr -d '\n' \| tr -d '\r' \| tr -d ' ' \| tr -d '=')`                                 |
| `STACK_FRONTEND_WEBUI_ADMIN_NAME`     | `System Administrator`                                                                                             |
| `STACK_FRONTEND_WEBUI_SECRET_KEY`     | `$(openssl rand -base64 64 \| tr -d '\n' \| tr -d '\r' \| tr -d ' ' \| tr -d '=')`                                 |

## Access

The stack will automatically provision two web consoles.  One is Portainer which is a web-based management platform for Docker.
The other is OpenWebUI which is where most of the interaction with the LLMs will occur.

> NOTE: SD.Next also comes with a Web UI however it has not been exposed as it's not directly used.

### Portainer

#### Hosts

| Host                      | Hostname                                            | Port                   | URL                                   |
| ------------------------- | --------------------------------------------------- | ---------------------- | ------------------------------------- |
| `${STACK_SUBNET_IPV4}.2`  | `${STACK_NAME}-management-portainer.${STACK_DOMAIN} | `9000/tcp`, `9443/tcp` | `http://${STACK_SUBNET_IPV4}.2:9000/` |
| `${STACK_SUBNET_IPV6}::2` | `${STACK_NAME}-management-portainer.${STACK_DOMAIN} | `9000/tcp`, `9443/tcp` | `http://${STACK_SUBNET_IPV6}.2:9000/` |

#### Credentials

Credentials can be changed in the environment file, however the previous `management-portainer-data` volume must be completely purged before recreating the `management-portainer` service.

| Username | Password                      |
| -------- | ----------------------------- |
| `admin`  | `${STACK_PORTAINER_PASSWORD}` |

### OpenWebUI

#### Hosts

| Host                      | Hostname                                            | Port       | URL                                   |
| ------------------------- | --------------------------------------------------- | ---------- | ------------------------------------- |
| `${STACK_SUBNET_IPV4}.4`  | `${STACK_NAME}-management-portainer.${STACK_DOMAIN} | `8080/tcp` | `http://${STACK_SUBNET_IPV4}.4:9000/` |
| `${STACK_SUBNET_IPV6}::4` | `${STACK_NAME}-management-portainer.${STACK_DOMAIN} | `8080/tcp` | `http://${STACK_SUBNET_IPV6}.4:9000/` |

#### Credentials

Credentials can be changed in the environment file and are immediately available upon recreation of the `ai-frontend` service.

| Username | Password                      |
| -------- | ----------------------------- |
| `admin`  | `${STACK_PORTAINER_PASSWORD}` |

## Stack Execution

### Creation

The commands below will stand the entire stack [or specific services] up in one command.

```pwsh

## All services.
.\Invoke-StackComposer.ps1 -Pull -Up

## Specific services.
.\Invoke-StackComposer.ps1 -Pull -Up -Only @('management-portainer')
```

### Teardown

The commands below will tear the entire stack [or specific services] down in one command.  This action is destructive and if the volumes are not persisted then all data will be purged.

```pwsh

## All services.
.\Invoke-Stack -Down -Prune

## Specific services.
.\Invoke-StackComposer.ps1 -Down -Prune -Only @('management-portainer')
```

### Recreation

The commands below will tear the entire stack [or specific services] down then stand it back up in one command.

```pwsh

## All services.
.\Invoke-Stack -Pull -Recreate

## Specific services.
.\Invoke-StackComposer.ps1 -Pull -Recreate -Only @('management-portainer')
```

## Further Reading

[Ollama](https://github.com/ollama/ollama) - Frontend to `llama.cpp`.  Used to download and interact with LLMs.

[SD.Next](https://github.com/vladmandic/sdnext/wiki/Docker) - Stable Diffusion image and video generation.

[OpenWebUI](https://github.com/open-webui/open-webui) - Clean and modern web interface to bring everything together.

[SearXNG](https://github.com/searxng/searxng) - Internet meta search engine to allow the LLMs to perform web searches.

[Portainer](https://github.com/portainer/portainer) `community-edition` - Clean and modern web interface for managing Docker infrastructure.

[Docker Desktop](https://www.docker.com/products/docker-desktop/) - Orchestration software [desktop edition] used to run all of this.

[PowerShell Universal](https://github.com/PowerShell/PowerShell/releases) - Used to control the stack.  Containerized version used to download LLMs.
