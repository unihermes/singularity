# TODO

1. Finish verifying the Ollama sidebar engine: exercise coding tools and interactive HTML mockups with a suitable local model, and verify screenshot feedback end to end with sufficient context. Codex fallback model metadata omitted shell tools; the local adapter now supplies explicit metadata. Verify command execution and images after setting the Ollama service context to 32768 (it was 4096, then 16384).

   Initial discovery: `python3 tools/ollama-status.py` reports installed model capabilities and GPU memory used by currently loaded models. A nonzero `size_vram` indicates GPU offload; an unloaded model cannot establish acceleration. Vision capability is only a prerequisite for screenshot feedback, which still needs an end-to-end test.
