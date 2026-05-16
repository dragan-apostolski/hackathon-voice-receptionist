#!/usr/bin/env bash
# Run this after every codeplain re-render from the project root:
#   bash scripts/post-render-patch.sh
set -e

DIST="$(cd "$(dirname "$0")/.." && pwd)/dist"

echo "==> Post-render patch: $DIST"

# ── 1. src/lib/utils.ts (required by every shadcn/ui component) ──────────────
UTILS="$DIST/src/lib/utils.ts"
if [ ! -f "$UTILS" ] || ! grep -q "twMerge" "$UTILS"; then
  echo "  [patch] writing src/lib/utils.ts"
  mkdir -p "$(dirname "$UTILS")"
  cat > "$UTILS" <<'EOF'
import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
EOF
fi

# ── 2. package.json fixes ─────────────────────────────────────────────────────
PKG="$DIST/package.json"

# 2a. dev script: prisma migrate deploy → prisma db push
if grep -q "prisma migrate deploy" "$PKG"; then
  echo "  [patch] fixing dev script (prisma migrate deploy → prisma db push)"
  sed -i '' 's/prisma migrate deploy/prisma db push/g' "$PKG"
fi

# 2b. missing runtime deps: clsx, tailwind-merge, tailwindcss-animate
node -e "
const fs = require('fs');
const pkgPath = '$PKG';
const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
const required = { 'clsx': '^2.1.1', 'tailwind-merge': '^3.6.0', 'tailwindcss-animate': '^1.0.7' };
let changed = false;
for (const [name, version] of Object.entries(required)) {
  if (!pkg.dependencies[name]) {
    console.log('  [patch] adding missing dep: ' + name);
    pkg.dependencies[name] = version;
    changed = true;
  }
}
if (changed) fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + '\n');
"

# ── 3. Ensure StaffTask model exists in prisma/schema.prisma ─────────────────
SCHEMA="$DIST/prisma/schema.prisma"
if ! grep -q "model StaffTask" "$SCHEMA" 2>/dev/null; then
  echo "  [patch] adding missing StaffTask model to prisma/schema.prisma"
  cat >> "$SCHEMA" <<'EOF'

model StaffTask {
  id           String    @id @default(cuid())
  callId       String
  call         Call      @relation(fields: [callId], references: [id])
  patientPhone String
  patientName  String    @default("")
  description  String
  topic        String    @default("")
  type         String
  priority     String    @default("normal")
  status       String    @default("open")
  createdAt    DateTime  @default(now())
  resolvedAt   DateTime?
}
EOF
  # Also add tasks relation to Call model
  sed -i '' 's/isDemo         Boolean      @default(false)\n}/isDemo         Boolean      @default(false)\n  tasks          StaffTask[]\n}/' "$SCHEMA" 2>/dev/null || true
fi

# ── 4. Ensure /api/tasks route exists ────────────────────────────────────────
TASKS_ROUTE="$DIST/src/app/api/tasks/route.ts"
if [ ! -f "$TASKS_ROUTE" ]; then
  echo "  [patch] creating missing /api/tasks route"
  mkdir -p "$(dirname "$TASKS_ROUTE")"
  cat > "$TASKS_ROUTE" <<'EOF'
import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { getTasks, createTask } from "@/repositories/task-repository";
import { prisma } from "@/lib/prisma";

const createSchema = z.object({
  callId: z.string().min(1),
  description: z.string().min(1),
  type: z.enum(["callback", "action"]),
  priority: z.enum(["normal", "high"]).optional(),
  patientName: z.string().optional(),
  topic: z.string().optional(),
});

export async function GET(req: NextRequest) {
  const status = (req.nextUrl.searchParams.get("status") ?? "open") as "open" | "done" | "all";
  if (!["open", "done", "all"].includes(status)) {
    return NextResponse.json({ error: "invalid status" }, { status: 400 });
  }
  const tasks = await getTasks(status);
  return NextResponse.json(tasks);
}

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => null);
  const parsed = createSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.issues[0].message }, { status: 400 });
  }
  const call = await prisma.call.findUnique({ where: { id: parsed.data.callId } });
  if (!call) return NextResponse.json({ error: "call not found" }, { status: 404 });
  const task = await createTask({ ...parsed.data, patientPhone: call.patientPhone });
  return NextResponse.json(task, { status: 201 });
}
EOF
  mkdir -p "$(dirname "$TASKS_ROUTE")/[id]"
  cat > "$DIST/src/app/api/tasks/[id]/route.ts" <<'EOF'
import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { getTaskById, updateTaskStatus } from "@/repositories/task-repository";

const updateSchema = z.object({ status: z.enum(["open", "done"]) });

export async function PUT(req: NextRequest, { params }: { params: { id: string } }) {
  const body = await req.json().catch(() => null);
  const parsed = updateSchema.safeParse(body);
  if (!parsed.success) return NextResponse.json({ error: parsed.error.issues[0].message }, { status: 400 });
  const existing = await getTaskById(params.id);
  if (!existing) return NextResponse.json({ error: "not found" }, { status: 404 });
  const task = await updateTaskStatus(params.id, parsed.data.status);
  return NextResponse.json(task);
}
EOF
fi

# ── 5. Ensure task-repository.ts exists ──────────────────────────────────────
TASK_REPO="$DIST/src/repositories/task-repository.ts"
if [ ! -f "$TASK_REPO" ]; then
  echo "  [patch] creating missing task-repository.ts"
  cat > "$TASK_REPO" <<'EOF'
import { prisma } from "@/lib/prisma";

export async function getTasks(status: "open" | "done" | "all" = "open") {
  const where = status === "all" ? {} : { status };
  return prisma.staffTask.findMany({ where, orderBy: [{ priority: "desc" }, { createdAt: "desc" }] });
}

export async function createTask(data: {
  callId: string; description: string; type: string; priority?: string;
  patientName?: string; topic?: string; patientPhone: string;
}) {
  return prisma.staffTask.create({
    data: { callId: data.callId, patientPhone: data.patientPhone, patientName: data.patientName ?? "",
      description: data.description, topic: data.topic ?? "", type: data.type,
      priority: data.priority ?? "normal", status: "open" },
  });
}

export async function updateTaskStatus(id: string, status: string) {
  return prisma.staffTask.update({
    where: { id }, data: { status, resolvedAt: status === "done" ? new Date() : null },
  });
}

export async function getTaskById(id: string) {
  return prisma.staffTask.findUnique({ where: { id } });
}
EOF
fi

# ── 7. npm install + prisma db push ─────────────────────────────────────────
echo "  [patch] running npm install in dist/"
(cd "$DIST" && npm install --legacy-peer-deps --silent)
echo "  [patch] running prisma db push"
(cd "$DIST" && npx prisma db push --skip-generate 2>&1 | tail -3)

echo "==> Patch complete. Run: cd dist && npm run dev"
