#!/usr/bin/env node
'use strict';
/* Committed empty so the tool runs from a checkout unchanged: with no embedded
 * text, `swr init` reads skills/smart-web-read/SKILL.md from the tree as usual.
 * tools/build.sh overwrites this file (in a temp copy of the tree) with the real
 * body, which is what makes a compiled binary work with no skill file beside it. */
const EMBEDDED_SKILL_MD = null;

module.exports = { EMBEDDED_SKILL_MD };
