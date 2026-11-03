# TODO

1. Add a local model engine to the AI sidebar using Ollama, with model selection, chat and coding-agent support, conversation history, and interactive HTML mockups. Verify GPU acceleration and image input for screenshot feedback.

   Initial discovery: `python3 tools/ollama-status.py` reports installed model capabilities and GPU memory used by currently loaded models. A nonzero `size_vram` indicates GPU offload; an unloaded model cannot establish acceleration. Vision capability is only a prerequisite for screenshot feedback, which still needs an end-to-end test.
