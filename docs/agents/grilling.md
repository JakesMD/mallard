# Grilling sessions

Grilling sessions (`/grilling`, `/grill-me`, `/grill-with-docs`) must ask every question through the `AskUserQuestion` tool (popups), never as plain text in chat. This overrides any skill text that says to ask in prose. Put each round's questions in `AskUserQuestion` calls (max 4 per call), recommended option first, labelled "(Recommended)".
