# Admin UI Reference

The admin surface should look like a polished healthcare operations dashboard, not a browser-default document.

## Visual Direction

- Use a calm white and slate base with teal or blue accents.
- Use shadcn/ui-style components: top navigation, cards, tables, badges, alerts, dialogs, buttons, inputs, selects, textareas, and skeleton loading states.
- Use a global stylesheet imported from `src/app/layout.tsx`; Tailwind utility classes must render in the browser.
- Keep page content in a centered container with a maximum width around 1120-1200px.
- Use 8px border radius for cards, buttons, inputs, badges, and panels.
- Use subtle borders and shadows, not heavy outlines or browser-default controls.
- Use readable system sans-serif typography. Do not rely on browser default serif fonts.

## Dashboard Layout

- Top navigation is a horizontal app bar with clear spacing between links and an active state.
- The dashboard header has the title on the left and the primary "Seed demo data" action on the right.
- Practice setup is a card with three rows. Each row has a label on the left and a colored status badge on the right.
- Summary metrics are four equal cards in a responsive grid. Each card has a small uppercase label and a large numeric value.
- Quick links are styled as secondary buttons in a wrapped row.
- Error states use alert components. Empty states use muted text inside the relevant card or table area.

## Admin Lists And Forms

- Tables use shadcn-style table structure with a header row, consistent cell padding, row hover states, and empty-state rows.
- Inline edit and delete confirmations should remain visually contained in the row they affect.
- Forms use labelled controls, compact helper/error text, and primary/secondary button styling.
- Demo badges are small rounded badges placed beside the entity name or in a dedicated table column.

## Accessibility

- Interactive controls have visible focus states.
- Status badges are readable without relying only on color.
- Buttons and links have clear labels and adequate touch targets.
