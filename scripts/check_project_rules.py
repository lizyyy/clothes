#!/usr/bin/env python3
# 文件input：git 暂存区变更、源码文本内容、项目质量阈值配置
# 文件output：规范检查结果、错误列表、pre-commit 阻断退出码
# 文件pos：仓库级质量门禁脚本层
# 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
import re
import subprocess
import sys
from pathlib import Path

MAX_FILE_LINES = 800
MAX_FUNC_LINES = 30
MAX_NESTING = 3
MAX_BRANCHES = 3

SOURCE_EXTS = {".go", ".swift", ".sh", ".py"}
ANALYZE_FUNC_EXTS = {".go", ".swift"}

HEADER_RULES = [
    "文件input：",
    "文件output：",
    "文件pos：",
    "一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。",
]

EXCLUDE_PATTERNS = [
    "/.git/",
    "go-service/builds/",
    "Clothes/Assets.xcassets/",
    "Clothes/Models/",
    "Clothes.xcodeproj/",
]

CONTROL_KEYWORD_RE = re.compile(r"\\b(if|for|while|switch|guard)\\b")
BRANCH_RE = re.compile(r"\\bif\\b|\\bfor\\b|\\bwhile\\b|\\bswitch\\b|\\bguard\\b")
GO_FUNC_RE = re.compile(r"^\\s*func\\b")
SWIFT_FUNC_RE = re.compile(
    r"^\\s*(?:@[\\w().]+\\s*)*(?:(?:public|private|internal|fileprivate|open|static|class|final|override|mutating|nonmutating|convenience|required|actor|lazy|indirect|prefix|postfix|infix|async|throws|rethrows)\\s+)*func\\b"
)


def run_git(args, check=True):
    proc = subprocess.run(["git", *args], capture_output=True, text=True)
    if check and proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or f"git {' '.join(args)} failed")
    return proc


def get_repo_root() -> Path:
    return Path(run_git(["rev-parse", "--show-toplevel"]).stdout.strip())


def is_excluded(path_text: str) -> bool:
    norm = path_text.replace("\\", "/")
    for pattern in EXCLUDE_PATTERNS:
        if pattern in norm or norm.startswith(pattern):
            return True
    return False


def get_staged_files():
    out = run_git(["diff", "--cached", "--name-only", "--diff-filter=ACMR"]).stdout
    return [line.strip() for line in out.splitlines() if line.strip()]


def get_staged_changed_lines(path_text: str):
    diff = run_git(["diff", "--cached", "-U0", "--", path_text]).stdout
    touched = set()
    for line in diff.splitlines():
        if not line.startswith("@@"):
            continue
        match = re.search(r"\\+(\\d+)(?:,(\\d+))?", line)
        if not match:
            continue
        start = int(match.group(1))
        count = int(match.group(2) or "1")
        if count <= 0:
            continue
        for n in range(start, start + count):
            touched.add(n)
    return touched


def get_head_content(path_text: str):
    proc = run_git(["show", f"HEAD:{path_text}"], check=False)
    if proc.returncode != 0:
        return None
    return proc.stdout


def strip_inline_comment(line: str, ext: str) -> str:
    if ext in {".go", ".swift"}:
        return line.split("//", 1)[0]
    if ext == ".sh":
        if line.startswith("#!"):
            return line
        return line.split("#", 1)[0]
    return line


def extract_func_name(signature: str, ext: str, start_line: int) -> str:
    if ext == ".go":
        m = re.search(r"func\\s+(?:\\([^)]*\\)\\s*)?([A-Za-z_][A-Za-z0-9_]*)\\s*\\(", signature)
        if m:
            return m.group(1)
    if ext == ".swift":
        m = re.search(r"func\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*\\(", signature)
        if m:
            return m.group(1)
    return f"func@L{start_line}"


def parse_functions(lines, ext):
    funcs = []
    total = len(lines)
    i = 0

    while i < total:
        line = lines[i]
        if ext == ".go":
            is_decl = bool(GO_FUNC_RE.match(line))
        else:
            is_decl = bool(SWIFT_FUNC_RE.match(line))

        if not is_decl:
            i += 1
            continue

        decl_start = i
        j = i
        brace_line = None
        brace_idx = None
        while j < total and j - i <= 15:
            candidate = strip_inline_comment(lines[j], ext)
            idx = candidate.find("{")
            if idx != -1:
                brace_line = j
                brace_idx = idx
                break
            if candidate.strip().endswith(";"):
                break
            j += 1

        if brace_line is None:
            i += 1
            continue

        depth = 0
        end_line = None
        for k in range(brace_line, total):
            segment = strip_inline_comment(lines[k], ext)
            start_idx = brace_idx if k == brace_line else 0
            for ch in segment[start_idx:]:
                if ch == "{":
                    depth += 1
                elif ch == "}":
                    depth -= 1
                    if depth == 0:
                        end_line = k
                        break
            if end_line is not None:
                break

        if end_line is None:
            i += 1
            continue

        signature = " ".join(lines[decl_start : brace_line + 1])
        name = extract_func_name(signature, ext, decl_start + 1)
        start = decl_start + 1
        end = end_line + 1
        func_lines = end - start + 1

        branch_count = 0
        for raw in lines[decl_start : end_line + 1]:
            content = strip_inline_comment(raw, ext)
            branch_count += len(BRANCH_RE.findall(content))

        pending_controls = 0
        control_depth = 0
        max_control_depth = 0
        stack = []

        for idx_line in range(brace_line, end_line + 1):
            content = strip_inline_comment(lines[idx_line], ext)
            pending_controls += len(CONTROL_KEYWORD_RE.findall(content))
            start_at = brace_idx if idx_line == brace_line else 0
            for ch in content[start_at:]:
                if ch == "{":
                    if pending_controls > 0:
                        stack.append("control")
                        pending_controls -= 1
                        control_depth += 1
                        max_control_depth = max(max_control_depth, control_depth)
                    else:
                        stack.append("other")
                elif ch == "}":
                    if not stack:
                        continue
                    popped = stack.pop()
                    if popped == "control" and control_depth > 0:
                        control_depth -= 1

        funcs.append(
            {
                "name": name,
                "start": start,
                "end": end,
                "lines": func_lines,
                "branches": branch_count,
                "nesting": max_control_depth,
            }
        )

        i = end_line + 1

    return funcs


def function_touched(func_item, touched_lines):
    if not touched_lines:
        return False
    for n in touched_lines:
        if func_item["start"] <= n <= func_item["end"]:
            return True
    return False


def check_header(path_text: str, content: str, errors):
    top = "\n".join(content.splitlines()[:12])
    missing = [rule for rule in HEADER_RULES if rule not in top]
    if missing:
        errors.append(f"{path_text}: 缺少文件头注释字段 -> {', '.join(missing)}")


def check_file_lines(path_text: str, content: str, head_content: str, errors):
    current_lines = len(content.splitlines())
    if current_lines <= MAX_FILE_LINES:
        return

    if head_content is None:
        errors.append(f"{path_text}: 文件行数 {current_lines} 超过 {MAX_FILE_LINES}")
        return

    baseline = len(head_content.splitlines())
    if baseline <= MAX_FILE_LINES:
        errors.append(f"{path_text}: 文件行数 {current_lines} 超过 {MAX_FILE_LINES}")
        return

    if current_lines > baseline:
        errors.append(
            f"{path_text}: 历史文件已超限({baseline})且本次继续膨胀到 {current_lines}，请拆分文件"
        )


def check_functions(path_text: str, ext: str, content: str, touched_lines, errors):
    lines = content.splitlines()
    for func_item in parse_functions(lines, ext):
        if not function_touched(func_item, touched_lines):
            continue

        if func_item["lines"] > MAX_FUNC_LINES:
            errors.append(
                f"{path_text}:{func_item['start']}: 函数 {func_item['name']} 行数 {func_item['lines']} 超过 {MAX_FUNC_LINES}"
            )
        if func_item["nesting"] > MAX_NESTING:
            errors.append(
                f"{path_text}:{func_item['start']}: 函数 {func_item['name']} 嵌套深度 {func_item['nesting']} 超过 {MAX_NESTING}"
            )
        if func_item["branches"] > MAX_BRANCHES:
            errors.append(
                f"{path_text}:{func_item['start']}: 函数 {func_item['name']} 分支数量 {func_item['branches']} 超过 {MAX_BRANCHES}"
            )


def check_arch_sync(path_text: str, staged_set, errors):
    parent = Path(path_text).parent
    arch_file = (parent / "ARCH.md").as_posix()
    if arch_file not in staged_set:
        errors.append(f"{path_text}: 目录文档未同步，请同时提交 {arch_file}")


def main():
    repo_root = get_repo_root()
    staged_files = get_staged_files()
    if not staged_files:
        print("[rules] 未检测到暂存改动，跳过检查")
        return 0

    staged_set = set(staged_files)
    errors = []

    for path_text in staged_files:
        ext = Path(path_text).suffix
        if ext not in SOURCE_EXTS:
            continue
        if is_excluded(path_text):
            continue

        abs_path = repo_root / path_text
        if not abs_path.exists() or not abs_path.is_file():
            continue

        try:
            content = abs_path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            errors.append(f"{path_text}: 不是 UTF-8 文本文件，无法执行规范检查")
            continue

        check_header(path_text, content, errors)
        check_arch_sync(path_text, staged_set, errors)

        head_content = get_head_content(path_text)
        check_file_lines(path_text, content, head_content, errors)

        if ext in ANALYZE_FUNC_EXTS:
            touched_lines = get_staged_changed_lines(path_text)
            check_functions(path_text, ext, content, touched_lines, errors)

    if errors:
        print("[rules] 规范检查失败：")
        for msg in errors:
            print(f"- {msg}")
        print("\n请修复后重新提交。")
        return 1

    print("[rules] 规范检查通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
