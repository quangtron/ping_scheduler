# Product Requirements Document
## Claude Pro Ping Scheduler
**Version 3.0 | February 2026**

---

## 1. Executive Summary

A minimal background script that automatically sends a ping to Claude Pro at
scheduled times. The sole purpose is to open a session at the right time so
the user's 5-hour usage window aligns with their intended work hours.

No dashboard. No notifications. No database. Just a ping.

---

## 2. Problem Statement

Claude Pro resets usage on a rolling 5-hour window. The user wants to control
exactly when that window starts so it aligns with their work schedule.

Without this tool, the user must manually open Claude and send a message at the
right time. Missing the window start means the 5-hour clock runs during hours
the user is not working -- wasting paid quota.

**This tool solves it with one job: send a ping to Claude Pro at a scheduled time.**

---

## 3. How It Works

```
User sets a schedule:
  - Ping at 08:00 every weekday
  - Ping at 19:00 every day

         |
         v

At the scheduled time, the script sends:

  POST /v1/messages
  {
    "model": "claude-sonnet-4-6",
    "max_tokens": 10,
    "messages": [{ "role": "user", "content": "hi" }]
  }

         |
         v

Session is open. User's 5-hour window has started.
```

---

## 4. Functional Requirements

- Send a ping to the Anthropic API at each configured schedule time
- Support multiple schedules (e.g. 08:00 and 19:00 daily)
- Support day-of-week filtering (e.g. weekdays only)
- Timezone configurable (default: system timezone)
- Retry once if the ping fails, then silently move on
- Write a one-line log entry per ping to a local log file (time + success/fail)

---

## 5. Out of Scope

- Notifications or alerts of any kind
- Dashboard or UI
- Reset window tracking
- Response handling or storing Claude's reply
- Multi-user or cloud deployment

---

## 6. Recommended Technology Stack

| Component    | Choice                   | Reason                                    |
|--------------|--------------------------|-------------------------------------------|
| Language     | Elixir                   | Functional, reliable, good for background jobs |
| Scheduler    | GitHub Actions           | Free, reliable cron scheduling           |
| Anthropic    | Req (HTTP client)        | Pure Elixir, no external deps            |
| Config       | config.yaml (YAML)       | Human-readable, easy to edit             |
| Logging      | Append to ping.log file | No DB needed, plain text                 |
| Secrets      | GitHub Secrets           | Secure API key storage                   |

---

## 7. Project Structure

```
claude-ping-scheduler/
├── .github/
│   └── workflows/
│       └── ping.yml      # GitHub Actions workflow
├── lib/
│   └── ping_scheduler/
│       ├── application.ex
│       ├── pinger.ex      # Send ping to Anthropic API
│       └── config.ex      # Load config.yaml
├── config/
│   └── config.yaml        # User schedule + API key
├── ping.log               # Auto-generated log file
├── mix.exs
└── README.md
```

---

## 8. Flow Diagram: Elixir + GitHub Actions

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           GITHUB REPOSITORY                                  │
│                                                                              │
│  ┌─────────────────┐         ┌─────────────────────────────────────────┐    │
│  │  GitHub Actions │         │              Elixir Code                │    │
│  │   Scheduler     │         │                                         │    │
│  │                 │         │  ┌───────────────────────────────────┐  │    │
│  │  cron: "0 8 * *" │────────▶│  │ lib/ping_scheduler/pinger.ex      │  │    │
│  │  cron: "0 19 *" │         │  │                                   │  │    │
│  │                 │  trigger │  │  1. Load config (config.yaml)     │  │    │
│  └─────────────────┘         │  │  2. Build HTTP request            │  │    │
│        │                     │  │  3. POST /v1/messages             │  │    │
│        │                     │  │     - model: claude-sonnet-4-6    │  │    │
│        │                     │  │     - max_tokens: 10              │  │    │
│        │                     │  │     - messages: [{content: "hi"}] │  │    │
│        │                     │  │  4. Handle response (success/fail) │  │    │
│        │                     │  │  5. Write log to ping.log          │  │    │
│        │                     │  └───────────────────────────────────┘  │    │
│        │                     │                    │                       │    │
│        │                     │                    ▼                       │    │
│        │                     │  ┌───────────────────────────────────┐  │    │
│        │                     │  │ lib/ping_scheduler/config.ex       │  │    │
│        │                     │  │                                   │  │    │
│        │                     │  │  - Read config.yaml               │  │    │
│        │                     │  │  - Get API key from ENV           │  │    │
│        │                     │  │  - Load schedules                 │  │    │
│        │                     │  └───────────────────────────────────┘  │    │
│        │                     └─────────────────────────────────────────┘    │
│        │                                                                   │
│        │                           ┌──────────────────────┐                   │
│        └──────────────────────────▶│    GitHub Actions    │                   │
│                                    │       Logs           │                   │
│                                    │                      │                   │
│                                    │  - Job started       │                   │
│                                    │  - SUCCESS/FAILED    │                   │
│                                    │  - Duration           │                   │
│                                    └──────────────────────┘                   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐     │
│  │                        SECRETS (GitHub)                            │     │
│  │                                                                       │     │
│  │   ANTHROPIC_API_KEY: "sk-ant-..."                                    │     │
│  │                                                                       │     │
│  └─────────────────────────────────────────────────────────────────────┘     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                          EXTERNAL SERVICES                                  │
│                                                                              │
│  ┌─────────────────┐                                                      │
│  │  Anthropic API  │                                                      │
│  │                 │  ◀── POST /v1/messages                               │
│  │  - claude-sonnet-4-6                                                    │
│  │  - Response     │  ──▶ 200 OK                                          │
│  └─────────────────┘                                                      │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Flow Steps:

1. **GitHub Actions** triggers workflow at scheduled times (cron: `0 8 * * 1-5`, `0 19 * * *`)
2. **Workflow** reads `ANTHROPIC_API_KEY` from GitHub Secrets
3. **Elixir code** (`mix run -e PingScheduler.run`) is executed
4. **Pinger module** builds HTTP request with:
   - API key from environment
   - Model: `claude-sonnet-4-6`
   - Max tokens: 10
   - Message: `hi`
5. **Req** sends POST to `https://api.anthropic.com/v1/messages`
6. **Response** handled (success/fail)
7. **Log** written to `ping.log` with timestamp, status, duration
8. **GitHub Actions** logs show job status

---

## 9. Example config.yaml

```yaml
api_key: "sk-ant-..."
timezone: "Asia/Ho_Chi_Minh"

schedules:
  - name: "Morning"
    cron: "0 8 * * 1-5"      # 08:00 weekdays
  - name: "Evening"
    cron: "0 19 * * *"       # 19:00 every day

ping:
  model: "claude-sonnet-4-6"
  max_tokens: 10
  prompt: "hi"
```

---

## 10. Example ping.log

```
2026-02-26 08:00:01 | Morning  | SUCCESS | 312ms
2026-02-26 19:00:01 | Evening  | SUCCESS | 287ms
2026-02-27 08:00:02 | Morning  | FAILED  | retried -> SUCCESS | 601ms
```

---

## 11. Milestones

| Phase | Timeline | Deliverables                                    |
|-------|----------|-------------------------------------------------|
| MVP   | Week 1   | config.yaml loader, CRON ping, log file output  |
| v1.0  | Week 2   | Encrypted API key, retry logic, README          |

---

*End of Document | Version 3.0*
