# DEPLOYMENT

## Goal

Deploy Novel Writer as a hosted web app so it can be opened from any browser while keeping local-first editing on each device.

Recommended host:

- Vercel

## What Stays The Same

- editing remains local-first in the browser
- each device keeps its own IndexedDB cache
- Supabase remains the auth and sync backend
- typing does not wait on the network

## One-Time Setup

Before deploying, make sure you already have:

- a Supabase project
- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`
- the remote tables and RLS policies from `supabase/schema.sql`

## Vercel Deploy

### 1. Push the project to GitHub

Novel Writer should live in a GitHub repository so Vercel can build and deploy it automatically.

### 2. Create a Vercel project

In Vercel:

1. Click `Add New...`
2. Choose `Project`
3. Import the GitHub repository

### 3. Add environment variables

In the Vercel project settings, add:

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`

Use the same values currently stored in your local `.env`.

### 4. Deploy

Vercel should detect this as a Vite app automatically.

Expected build command:

```bash
npm run build
```

Expected output directory:

```text
dist
```

### 5. Verify browser routing

This repo includes `vercel.json` with a rewrite to `index.html`, so direct links like these should work:

- `/projects`
- `/projects/:projectId`
- `/projects/:projectId/scenes/:sceneId`

## Supabase Settings For Hosted Use

After Vercel gives you a production URL:

1. Open Supabase
2. Go to Authentication settings
3. Add the deployed site URL to the allowed site/redirect settings

Recommended additions:

- your main Vercel app URL
- your custom domain later, if you add one

Password reset emails should then return users to:

- `/login` on the deployed site

## Daily Use After Deployment

Once deployed, using Novel Writer should be simple:

1. open the app URL
2. sign in
3. write

No local dev server is required for normal use.

## Safety Notes

- the hosted app still depends on local browser storage for fast local-first editing
- Supabase remains the shared sync layer across devices
- exports are still the best extra safety net

Recommended ongoing safety habits:

- keep Supabase sync enabled
- periodically export Safety ZIP backups
- optionally save exports to iCloud Drive
