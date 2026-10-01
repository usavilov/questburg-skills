# Questburg skills

A skill that connects your AI agent to your family in [Questburg](https://questburg.com):
what the kids have today, approving what they checked off, adding quests.

Скилл, который подключает вашего ИИ-агента к семье в [Questburg](https://questburg.com/ru):
что сегодня у детей, зачёт отмеченного, новые задания.

## Install

```bash
npx -y skills add usavilov/questburg-skills
```

Works with agents that can run shell commands (Claude Code, Cursor, OpenClaw and
the like). The skill needs only `bash` and `curl`.

## Key

1. In the app: **Family → Agents and API → Create key**. The key is shown once.
2. Save it where the skill looks for it:

```bash
mkdir -p ~/.config/questburg && printf '%s' 'qb_PASTE_HERE' > ~/.config/questburg/key && chmod 600 ~/.config/questburg/key
```

3. Ask the agent: “What do the kids have today in Questburg?”

A key acts as the grown-up who created it. It can read and change quests and
check-offs; it cannot reach passwords, login codes, invites or delete anything.
Revoke it in the same place in the app.

## Without the skill

The API is plain HTTPS + JSON — see [questburg.com/en/developers](https://questburg.com/en/developers).

```bash
curl -s -H "Authorization: Bearer $QUESTBURG_API_KEY" https://questburg.com/api/v1/me
```

## License

MIT
