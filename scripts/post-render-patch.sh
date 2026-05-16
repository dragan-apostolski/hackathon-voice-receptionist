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

# ── 2. src/components/ui/select.tsx (must be full Radix shadcn/ui, not native) ─
SELECT="$DIST/src/components/ui/select.tsx"
if [ ! -f "$SELECT" ] || ! grep -q "radix-ui/react-select" "$SELECT"; then
  echo "  [patch] rewriting select.tsx as full shadcn/ui Radix Select"
  mkdir -p "$(dirname "$SELECT")"
  cat > "$SELECT" <<'EOF'
"use client";
import * as React from "react";
import * as SelectPrimitive from "@radix-ui/react-select";
import { Check, ChevronDown, ChevronUp } from "lucide-react";
import { cn } from "@/lib/utils";
const Select = SelectPrimitive.Root;
const SelectGroup = SelectPrimitive.Group;
const SelectValue = SelectPrimitive.Value;
const SelectTrigger = React.forwardRef<React.ElementRef<typeof SelectPrimitive.Trigger>, React.ComponentPropsWithoutRef<typeof SelectPrimitive.Trigger>>(
  ({ className, children, ...props }, ref) => (
    <SelectPrimitive.Trigger ref={ref} className={cn("flex h-10 w-full items-center justify-between rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50 [&>span]:line-clamp-1", className)} {...props}>
      {children}<SelectPrimitive.Icon asChild><ChevronDown className="h-4 w-4 opacity-50" /></SelectPrimitive.Icon>
    </SelectPrimitive.Trigger>
  )
);
SelectTrigger.displayName = SelectPrimitive.Trigger.displayName;
const SelectScrollUpButton = React.forwardRef<React.ElementRef<typeof SelectPrimitive.ScrollUpButton>, React.ComponentPropsWithoutRef<typeof SelectPrimitive.ScrollUpButton>>(
  ({ className, ...props }, ref) => <SelectPrimitive.ScrollUpButton ref={ref} className={cn("flex cursor-default items-center justify-center py-1", className)} {...props}><ChevronUp className="h-4 w-4" /></SelectPrimitive.ScrollUpButton>
);
SelectScrollUpButton.displayName = SelectPrimitive.ScrollUpButton.displayName;
const SelectScrollDownButton = React.forwardRef<React.ElementRef<typeof SelectPrimitive.ScrollDownButton>, React.ComponentPropsWithoutRef<typeof SelectPrimitive.ScrollDownButton>>(
  ({ className, ...props }, ref) => <SelectPrimitive.ScrollDownButton ref={ref} className={cn("flex cursor-default items-center justify-center py-1", className)} {...props}><ChevronDown className="h-4 w-4" /></SelectPrimitive.ScrollDownButton>
);
SelectScrollDownButton.displayName = SelectPrimitive.ScrollDownButton.displayName;
const SelectContent = React.forwardRef<React.ElementRef<typeof SelectPrimitive.Content>, React.ComponentPropsWithoutRef<typeof SelectPrimitive.Content>>(
  ({ className, children, position = "popper", ...props }, ref) => (
    <SelectPrimitive.Portal>
      <SelectPrimitive.Content ref={ref} className={cn("relative z-50 max-h-96 min-w-[8rem] overflow-hidden rounded-md border bg-popover text-popover-foreground shadow-md data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95", position === "popper" && "data-[side=bottom]:translate-y-1", className)} position={position} {...props}>
        <SelectScrollUpButton />
        <SelectPrimitive.Viewport className={cn("p-1", position === "popper" && "h-[var(--radix-select-trigger-height)] w-full min-w-[var(--radix-select-trigger-width)]")}>{children}</SelectPrimitive.Viewport>
        <SelectScrollDownButton />
      </SelectPrimitive.Content>
    </SelectPrimitive.Portal>
  )
);
SelectContent.displayName = SelectPrimitive.Content.displayName;
const SelectLabel = React.forwardRef<React.ElementRef<typeof SelectPrimitive.Label>, React.ComponentPropsWithoutRef<typeof SelectPrimitive.Label>>(
  ({ className, ...props }, ref) => <SelectPrimitive.Label ref={ref} className={cn("py-1.5 pl-8 pr-2 text-sm font-semibold", className)} {...props} />
);
SelectLabel.displayName = SelectPrimitive.Label.displayName;
const SelectItem = React.forwardRef<React.ElementRef<typeof SelectPrimitive.Item>, React.ComponentPropsWithoutRef<typeof SelectPrimitive.Item>>(
  ({ className, children, ...props }, ref) => (
    <SelectPrimitive.Item ref={ref} className={cn("relative flex w-full cursor-default select-none items-center rounded-sm py-1.5 pl-8 pr-2 text-sm outline-none focus:bg-accent focus:text-accent-foreground data-[disabled]:pointer-events-none data-[disabled]:opacity-50", className)} {...props}>
      <span className="absolute left-2 flex h-3.5 w-3.5 items-center justify-center"><SelectPrimitive.ItemIndicator><Check className="h-4 w-4" /></SelectPrimitive.ItemIndicator></span>
      <SelectPrimitive.ItemText>{children}</SelectPrimitive.ItemText>
    </SelectPrimitive.Item>
  )
);
SelectItem.displayName = SelectPrimitive.Item.displayName;
const SelectSeparator = React.forwardRef<React.ElementRef<typeof SelectPrimitive.Separator>, React.ComponentPropsWithoutRef<typeof SelectPrimitive.Separator>>(
  ({ className, ...props }, ref) => <SelectPrimitive.Separator ref={ref} className={cn("-mx-1 my-1 h-px bg-muted", className)} {...props} />
);
SelectSeparator.displayName = SelectPrimitive.Separator.displayName;
export { Select, SelectGroup, SelectValue, SelectTrigger, SelectContent, SelectLabel, SelectItem, SelectSeparator, SelectScrollUpButton, SelectScrollDownButton };
EOF
fi

# ── 3. package.json fixes ─────────────────────────────────────────────────────
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
const required = { 'clsx': '^2.1.1', 'tailwind-merge': '^3.6.0', 'tailwindcss-animate': '^1.0.7', '@radix-ui/react-select': '^2.1.1' };
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
