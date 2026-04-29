@AGENTS.md

<!--
This file contains Claude-specific overlay for this repository.
Cross-agent shared content is in AGENTS.md, included above via the
@AGENTS.md directive. Claude-specific content below is wrapped in
CLAUDE-ONLY markers to make drift detection mechanical.
-->

<!-- CLAUDE-ONLY -->
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when
working with code in this repository.

The "Hook bypass exceptions" section in AGENTS.md documents the one
permitted use of `git commit --no-verify` (in `bash/update-repo-tags`
during a CI release). All other uses of `--no-verify` are prohibited.

<!-- /CLAUDE-ONLY -->
