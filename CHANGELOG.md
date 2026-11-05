# Changelog

All notable changes to NotDefteri will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Image cropping: dragging an image edge crops that side (left edge crops the left, top edge crops the top); dragging back restores the cropped part. Corners still resize proportionally. The crop is saved in Markdown as `{WxH kirp=x,y,w,h}` and shown on macOS, Linux and in HTML export.
- macOS window placement: double-click the title bar to fill the screen and again to restore the previous size and position; drag a window to a screen edge or corner to snap it to a half or quarter.
- Home page: live clock under the date, larger and clearer page cards, centered "Home" title in the sidebar and animated card layout when the window is resized.
- macOS: Notion-style block moving. Each paragraph is a block; code blocks, callouts and tables stay whole, and list items move with their sub-items. ⌘⇧↑/↓ moves the blocks of the cursor or selection one block up/down; when the pointer is over a paragraph, the ⋮⋮ handle on the left can be dragged to drop the block anywhere (clicking it selects the block). A move is undone in one step and numbered lists are renumbered.
- macOS: centering also works in callout, list and quote lines (`> [!💡 mavi] <center>…</center>`); a code block is centered as a whole and `{center}` is written on its opening fence (the language tag is kept). Right-clicking selected text shows "Center" and "Align Left" with icons; right-click inside a callout keeps the selection.
- macOS: ⌘O (Format > Center) centers the selected lines like Word and pressing it again aligns them left. The line is saved as `<center>…</center>` (Obsidian and GitHub center it too) and is centered in HTML export. Code, callout, list and table lines are not centered.
- macOS: `/red` opens a red and `/info` a green callout (applied on space, like `/uyari`).
- macOS: theme selection directly under View in the note, home page and sidebar context menus.
- Table insertion with `/table` and `/tablo`, with cell editing that keeps the source Markdown layout.
- Terminal theme, one-time migration of the saved theme choice and theme refresh on macOS and Linux.
- General syntax highlighting for code blocks without or with an unknown language tag.
- macOS code blocks: auto-closing `(`, `[`, `{`, `"`, `'`; keyword + Tab inserts language-specific try/catch, if, for, while, switch, function and class snippets.
- CodeQL code scanning for Swift and GitHub Actions, a security policy (`SECURITY.md`), a code of conduct, `CODEOWNERS` and `.editorconfig`.

### Changed

- Home page: recently opened page cards are smaller and at most 6 are shown; on wide windows more columns appear instead of larger cards.
- macOS image resize handles are easier to grab: clear corner and edge handles, direction cursors on every macOS version, and a wider grab area than the visible handle.
- macOS editor gives more room to text: the widest line grew from 760 to 960 pt, the side margin dropped from 48 to 40 pt, the text's top/bottom inset from 12 to 4 pt, the page options area from 36 to 28 pt and the footer bar from 26 to 22 pt (`kEnGenisMetin`, `kEditorYanPayi`, `kEditorDikeyBoslugu`, `kAltBilgiYuksekligi`).
- macOS: the space below colored callouts and code blocks is now 2 pt; there is no extra top space when a blank line or another box is above, and a single blank line between two boxes is 6 pt high.
- macOS: the space below code blocks and callouts was halved; the following text sits closer to the box.
- Callouts are typed like code blocks: Enter on a blank line stays in the box, Ctrl+Enter leaves it (moving to the blank line below if there is one); Backspace on an empty first line does not break the box.
- macOS interface matches the intro: page links show with a 📄 emoji, blue and underlined without brackets (`[[ ]]` appears while the cursor is in the link), completed tasks get a green tick, images are rounded cards with a shadow, the sidebar has a "Pages" title and pages with sub-pages get a folder icon.
- macOS sidebar: triple-clicking a page opens it alone in a separate window; double-clicking renames it. This window is the same editor as the main one (typing, formatting, tables, images, undo, page options, autosave). When the same page is open in two windows and one saves, the other reloads from disk and saves do not overwrite each other; a page moved in the main window is tracked, and a deleted page is not recreated.
- Inserting a callout or code block adds a blank line below it; callout colors and borders are darker.
- Numbered lists right-align their numbers; numbers 10 and above do not shift the text.
- The "Full width" page option was removed (the `genislik: tam` line in older pages is kept and has no effect). The "•••" page options area is only as wide as its button.
- The Cream theme was removed; a saved Cream choice falls back to Sepia. Theme backgrounds were darkened by the same amount to be easier on the eyes; on paper themes the title bar and sidebar were darkened further to stand apart from the editor, and secondary text was darkened to keep contrast.
- CI, issue and pull request templates are in English.

### Removed

- Leftover Claudesidian template files that were not part of the app: `install.sh`, `package.json` and its npm tooling, `.scripts/`, `CLAUDE-BOOTSTRAP.md`, vault-only agent skills and hooks, and sample notes and templates.
- "Pending to-dos" section on the home page.

### Fixed

- Code blocks: pressing Enter three times on the last line no longer jumps out of the block to the content below; Enter always stays in the code, and **Ctrl+Enter** leaves it (macOS and Linux).
- macOS: the block handle (⋮⋮) fell inside code blocks and callouts; it now sits left of the frame, aligned with the first line. While dragging, the moved block is outlined in blue, a translucent copy follows the pointer, and the drop position is shown as a thick line with a ring at its start, midway between the visible edges of two blocks (with a background-colored halo so it does not blend into box borders).
- macOS: the space around boxes updates immediately when a neighboring line changes; the spacing seen while editing does not change after reopening the app. A blank line saved between an adjacent quote and callout is drawn at almost zero height on open (it used to appear as a full line first).
- macOS: a single-line fragment copied from a code block, callout, quote, list item, heading or table cell no longer splits the target line into a new block; it is pasted inline (a fragment from code becomes inline code, inline formatting is kept). Multi-line selections still move blocks. No blank line is left below a code block pasted at the end of a line.
- macOS: the box-drawn table was removed; tables appear as a native `NSTextTable` grid. In the box table, selected or pasted content could not be deleted and editing outside cells was blocked; now cells are selected, deleted, copied and edited like other text, the table fits the window width and header and alternate rows are shaded. Web tables and tab-separated plain text paste as tables. Tables are saved as Markdown tables.
- macOS: callouts broke on copy and paste: the title of a box pasted mid-line mixed into the text, lines taken from the middle of a box turned into plain quotes, pasting into a box created a ghost box with an empty title, and cutting a whole box left an empty box behind.
- macOS: cells of tables copied from web pages or documents turned into stacked lines instead of side-by-side cells; the table now pastes and saves as a Markdown table (with a blank line before and after; `|` in cells is escaped).
- macOS sidebar: renaming on double-click was delayed by the double-click interval; text typed meanwhile went to the editor, and a tree refresh in between erased the typed name. Editing now opens immediately, and a third click in the name field cancels editing and opens the content window.
- macOS: the row and column fields of the `/table` dialog could not be typed into.
- macOS: table row backgrounds and the selection highlight overflowed the table frame.
- macOS: selecting and deleting text in a callout or code box also deleted the box; a held Backspace stops at the emptied box.
- macOS: the checkbox of an empty task opened with Enter overlapped the line above.
- macOS: to-do boxes (☐/☑) were drawn at different sizes and lines with empty boxes were taller.
- Nested lists indented with a tab (Obsidian) or three spaces showed as raw text.
- macOS: the page name/path in the title bar was not centered in the window.
- macOS: the table of contents closed on focus loss and while taking a screenshot.
- Code blocks keep blank lines entered with Enter, and Ctrl+Enter leaves them explicitly.
- Headless Linux tests share the GTK initialization result to avoid creating a wrong window.
- Text and code colors update when the theme changes; cache test expectations follow Turkish search normalization.

### Security

- Dependabot alerts resolved; the npm toolchain that caused them was removed.
