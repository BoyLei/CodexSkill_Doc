$env:ARK_API_KEY = "ark-da2ec9a3-81bf-4e08-b68e-106c58f64e63-a3911"

Invoke-RestMethod `
  -Uri "https://ark.cn-beijing.volces.com/api/v3/chat/completions" `
  -Method Post `
  -Headers @{
  "Authorization" = "Bearer $env:ARK_API_KEY"
  "Content-Type"  = "application/json"
} `
  -Body '{
    "model": "deepseek-v4-flash-260425",
    "messages": [
      { "role": "user", "content": "只回复 ok" }
    ],
    "max_tokens": 10
  }'