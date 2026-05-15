#!/bin/bash
# 修复 xcodegen 生成的 .xcodeproj 的几个问题：
#   1. "." 文件夹引用被加入 Copy Bundle Resources（与二进制同名冲突）
#   2. "." 出现在 Models 组的 children 中（warning 提示）
#   3. kokoro_models folder ref 重复出现在 root group 和 KokoroModels group
# 每次运行 xcodegen generate 后执行一次
# Usage: ./fix_xcodeproj.sh

set -euo pipefail
cd "$(dirname "$0")"

PBXPROJ="LexiGo.xcodeproj/project.pbxproj"
if [ ! -f "$PBXPROJ" ]; then
    echo "❌ $PBXPROJ not found. Run xcodegen generate first."
    exit 1
fi

python3 << 'PYEOF'
import re

with open('LexiGo.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

changes = 0

# 1. Remove ". in Resources" build file entry
new_content = re.sub(
    r'\t+[A-F0-9]{24} /\* \. in Resources \*/ = \{isa = PBXBuildFile; fileRef = [A-F0-9]{24} /\* \. \*/; \};',
    '',
    content
)
if new_content != content:
    changes += 1
    content = new_content

# 2. Remove ". in Resources" from resource build phase
new_content = re.sub(
    r'\t+[A-F0-9]{24} /\* \. in Resources \*/,',
    '',
    content
)
if new_content != content:
    changes += 1
    content = new_content

# 3. Remove "." from ALL group children lists (remove the entire line containing ", . */,")
new_content = re.sub(
    r'\t+[A-F0-9]{24} /\* \. \*/,',
    '',
    content
)
if new_content != content:
    changes += 1
    content = new_content

# 4. Remove the "." PBXFileReference itself
new_content = re.sub(
    r'\t+[A-F0-9]{24} /\* \. \*/ = \{isa = PBXFileReference; lastKnownFileType = folder; name = \.; path = \.; sourceTree = SOURCE_ROOT; \};',
    '',
    content
)
if new_content != content:
    changes += 1
    content = new_content

# 5. Remove kokoro_models file ref from root group (duplicate — already in KokoroModels group)
lines = content.splitlines(True)
new_lines = []
in_root_group = False
for line in lines:
    if 'A6B16276FB1A453CB88E1118 = {' in line:
        in_root_group = True
    if in_root_group and '/* kokoro_models */' in line:
        in_root_group = False
        continue  # skip this line
    if in_root_group and line.strip() == ');':
        in_root_group = False
    new_lines.append(line)
new_content = ''.join(new_lines)
if new_content != content:
    changes += 1
    content = new_content

with open('LexiGo.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print(f'✅ Fixed {changes} issue(s) in xcodeproj')
PYEOF

echo "Done."
