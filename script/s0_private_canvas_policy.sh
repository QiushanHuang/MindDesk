#!/usr/bin/env bash

# S0 private-Canvas release policy. This file is sourced by both the verifier
# and its adversarial self-test; keep rules explicit and fail closed.
readonly S0_POLICY_SCHEMA="1"
readonly S0_PACKAGE_MANIFEST_SHA256="37e150edd51f92738da9aaed9c7b3bb37cb28f7950c28d641c60f637c415db75"
readonly S0_RESOURCE_ACCESSOR_NORMALIZED_SHA256S="a158e2ca54b4baec93604f4983209dbc0123079c855e92dc28e7fe43821e01f1 2b6a13c13ca020403f5f3e5c0a6b004a07785063bdef23e2439348f739b5e7fc"

readonly -a S0_PRODUCTION_ROOTS=(
  "Sources/MindDesk"
  "Sources/MindDeskCore"
)

readonly -a S0_ALLOWED_IMPORTS=(
  "AppKit"
  "Combine"
  "CoreGraphics"
  "CryptoKit"
  "Darwin"
  "Foundation"
  "MindDeskCore"
  "OSLog"
  "Quartz"
  "QuartzCore"
  "SwiftData"
  "SwiftUI"
  "UniformTypeIdentifiers"
)

readonly -a S0_DELETED_APP_BASENAMES=(
  "CanvasCodexAgentSidebar"
  "CanvasCodexSessionController"
  "CanvasCodexTerminalView"
  "CodexTerminalService"
  "ProposalReviewSheet"
)

readonly -a S0_DENIED_SOURCE_TOKENS=(
  "import SwiftTerm"
  "openpty("
  ".startProcess("
  "CanvasRightRailPanel.codexAgent"
  "MindDeskInterchangePackage(manifest:"
  "AppPreferenceKeys.agentReviewCustomPromptGuidance"
  "AppPreferenceKeys.canvasCodexPromptTemplateLibrary"
  "AppPreferenceKeys.canvasCodexPromptTemplateGroup"
  "AppPreferenceKeys.canvasCodexPromptTemplateOption"
  "Review Agent Proposal"
  "Export Agent Review Package"
  "minddesk-open-codex"
  "minddesk-open-codex-with-prompt"
  "Start Shell"
  "+ Prompt Run"
)

readonly -a S0_DENIED_SYMBOL_STEMS=(
  "CanvasCodexAgentSidebar"
  "CanvasCodexSessionController"
  "CanvasCodexTerminalView"
  "CodexTerminalService"
  "ProposalReviewSheet"
  "CanvasCodexPrompt"
  "MindDeskAgentHandoffPrompt"
  "MindDeskAgentReviewCustomGuidancePresentation"
  "MindDeskAgentReviewPackageReadiness"
  "MindDeskAgentWorkflowSearch"
  "MindDeskProposalCopyPathPlanner"
  "MindDeskProposalEnvelopeExtractor"
  "MindDeskProposalEnvelopeTemplate"
  "MindDeskProposalReviewGate"
  "MindDeskProposalSourcePackageRawValidation"
)

readonly -a S0_DENIED_ARTIFACT_STRINGS=(
  "Review Agent Proposal"
  "Export Agent Review Package"
  "minddesk-open-codex"
  "minddesk-open-codex-with-prompt"
  "Start Shell"
  "+ Prompt Run"
)

readonly -a S0_ZERO_RUNTIME_SOURCE_PATTERNS=(
  '(^|[^A-Za-z0-9_])Process[[:space:]]*\('
  '(^|[^A-Za-z0-9_])NSTask([^A-Za-z0-9_]|$)'
  '(^|[^A-Za-z0-9_])posix_spawn[a-z_]*[[:space:]]*\('
  '(^|[^A-Za-z0-9_])(fork|vfork|popen|openpty|dlopen|dlsym|socket)[[:space:]]*\('
  '(^|[^A-Za-z0-9_])exec[a-z_]*[[:space:]]*\('
  '(^|[^A-Za-z0-9_])URLSession([^A-Za-z0-9_]|$)'
  '(^|[^A-Za-z0-9_])CommandLine[.](arguments|argc)'
)

s0_policy_check_source_tree() {
  local repo_root="$1"
  command -v python3 >/dev/null 2>&1 || {
    printf 'required tool is unavailable: python3\n' >&2
    return 1
  }

  python3 - "$repo_root" \
    "${S0_ALLOWED_IMPORTS[*]}" \
    "${S0_DELETED_APP_BASENAMES[*]}" <<'PY'
import os
import re
import stat
import sys

root = os.path.realpath(sys.argv[1])
allowed_imports = set(sys.argv[2].split())
deleted_basenames = set(sys.argv[3].split())
denied_tokens = [
    "import SwiftTerm",
    "openpty(",
    ".startProcess(",
    "CanvasRightRailPanel.codexAgent",
    "MindDeskInterchangePackage(manifest:",
    "AppPreferenceKeys.agentReviewCustomPromptGuidance",
    "AppPreferenceKeys.canvasCodexPromptTemplateLibrary",
    "AppPreferenceKeys.canvasCodexPromptTemplateGroup",
    "AppPreferenceKeys.canvasCodexPromptTemplateOption",
    "Review Agent Proposal",
    "Export Agent Review Package",
    "minddesk-open-codex",
    "minddesk-open-codex-with-prompt",
    "Start Shell",
    "+ Prompt Run",
]
zero_runtime_patterns = [
    re.compile(r"(^|[^A-Za-z0-9_])Process\s*\("),
    re.compile(r"(^|[^A-Za-z0-9_])NSTask([^A-Za-z0-9_]|$)"),
    re.compile(r"(^|[^A-Za-z0-9_])posix_spawn[a-z_]*\s*\("),
    re.compile(r"(^|[^A-Za-z0-9_])(fork|vfork|popen|openpty|dlopen|dlsym|socket)\s*\("),
    re.compile(r"(^|[^A-Za-z0-9_])exec[a-z_]*\s*\("),
    re.compile(r"(^|[^A-Za-z0-9_])URLSession([^A-Za-z0-9_]|$)"),
    re.compile(r"(^|[^A-Za-z0-9_])CommandLine[.](arguments|argc)"),
]
production_roots = ["Sources/MindDesk", "Sources/MindDeskCore"]
import_pattern = re.compile(r"^\s*import(?:\s+(?:class|enum|func|protocol|struct|typealias|var|let))?\s+([A-Za-z_][A-Za-z0-9_]*)", re.MULTILINE)
app_legacy_pattern = re.compile(r"\b(?:MindDeskInterchange[A-Za-z0-9_]*|MindDeskProposal[A-Za-z0-9_]*|MindDeskValidationReport[A-Za-z0-9_]*|MindDeskAgent[A-Za-z0-9_]*|MindDeskExtensionCapability[A-Za-z0-9_]*)\b")

for relative_root in production_roots:
    scan_root = os.path.join(root, relative_root)
    if not os.path.isdir(scan_root) or os.path.islink(scan_root):
        raise SystemExit(f"missing or unsafe production root: {relative_root}")
    for directory, dirnames, filenames in os.walk(scan_root, topdown=True, followlinks=False):
        for name in sorted(dirnames):
            path = os.path.join(directory, name)
            if os.path.islink(path):
                raise SystemExit(f"symlink in production root: {os.path.relpath(path, root)}")
        for name in sorted(filenames):
            path = os.path.join(directory, name)
            relative = os.path.relpath(path, root)
            mode = os.lstat(path).st_mode
            if not stat.S_ISREG(mode):
                raise SystemExit(f"non-regular production input: {relative}")
            stem = os.path.splitext(name)[0]
            if stem in deleted_basenames:
                raise SystemExit(f"deleted app path is present: {relative}")
            data = open(path, "rb").read()
            for token in denied_tokens:
                if token.encode("utf-8") in data:
                    raise SystemExit(f"forbidden production token {token!r} in {relative}")
            if not name.endswith(".swift"):
                continue
            try:
                text = data.decode("utf-8")
            except UnicodeDecodeError:
                raise SystemExit(f"Swift source is not UTF-8: {relative}")
            for module in import_pattern.findall(text):
                if module not in allowed_imports:
                    raise SystemExit(f"unapproved production import {module!r} in {relative}")
            for pattern in zero_runtime_patterns:
                if pattern.search(text):
                    raise SystemExit(f"zero-call runtime family is present in {relative}")
            if relative.startswith("Sources/MindDesk/"):
                match = app_legacy_pattern.search(text)
                if match:
                    raise SystemExit(f"historical DTO reference {match.group(0)!r} in app source {relative}")
PY
}
