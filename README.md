# hackathon-voice-receptionist

A hackathon project for a voice receptionist.

## Running the rendered web app

The rendered Next.js app lives in `dist/`. Run all commands from that directory.

### First time setup

```bash
cd dist
npm install
cp .env.example .env.local
# Edit .env.local — fill in DATABASE_URL, LIVEKIT_URL, LIVEKIT_API_KEY,
# LIVEKIT_API_SECRET, and PRACTICE_TIMEZONE
```

### Start the dev server

```bash
cd dist
npm run dev
```

This single command starts Postgres via Docker Compose, runs any pending Prisma migrations, and launches Next.js on **http://localhost:3000**.

- Admin UI: http://localhost:3000/admin
- Call simulator: http://localhost:3000/simulator

### Re-rendering after spec changes

```bash
# From the project root (not dist/)
CODEPLAIN_API_KEY=<your-key> codeplain web.plain --force-render --headless
```

After a re-render, re-run `npm install` in `dist/` if `package.json` changed.

### Stop Postgres

```bash
cd dist
npm run db:down
```
