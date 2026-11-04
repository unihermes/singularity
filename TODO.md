# TODO

1. Finish verifying the Ollama sidebar engine: exercise coding tools and interactive HTML mockups with a suitable local model, and verify screenshot feedback end to end with sufficient context. The installed qwen3.5:4b hallucinated a tool name in an agent test, and image requests exceeded the server’s 4096-token context.

   Initial discovery: `python3 tools/ollama-status.py` reports installed model capabilities and GPU memory used by currently loaded models. A nonzero `size_vram` indicates GPU offload; an unloaded model cannot establish acceleration. Vision capability is only a prerequisite for screenshot feedback, which still needs an end-to-end test.
