# Token Analysis Example

## Command

```text
python .\scripts\analyze_codex_tokens.py --thread-id 019f2335-83d5-70a0-9f6c-1ca52518f60b --task-dir .\docs\refactor\example-unity-network --output .\tmp\codex-token-report-example.json --top-turns 5 --verbose
```

## Why This Thread Should Be Reset

The report produced these thread-level signals:

- `start_new_thread`
- `truncate_terminal_output`
- `stop_after_heavy_turn`

Those signals are justified by the observed metrics:

- `total_tokens`: `2545723`
- `max_turn_total_tokens`: `222196`
- `avg_cached_input_ratio`: `0.6525`
- `max_cached_input_ratio`: `0.9958`
- `long_context_turn_count`: `16`
- `terminal_tool_output_chars`: `676979`
- `terminal_tool_output_ratio`: `0.8442`

## Protocol Read

Because the example task directory has all 8 protocol artifacts and non-zero claim references, the report shows:

- no `claim_reference_gaps`
- no missing artifact warnings
- a clear recommendation to reset the thread because the token pattern itself is unhealthy

This is the intended behavior:

- protocol files keep architecture decisions durable
- token analysis still tells you when the current thread is too expensive to continue
