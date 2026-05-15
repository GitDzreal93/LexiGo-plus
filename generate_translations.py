#!/usr/bin/env python3
"""
为 words.json 的 2850 个英文单词生成中/日/韩翻译。
逐词翻译，每秒 1 个，结果实时保存到 translations.json。
中断后重跑会自动从断点继续。
"""

import json
import os
import time

from deep_translator import GoogleTranslator

WORDS_PATH = "LexiGo/Resources/words.json"
OUT_PATH = "LexiGo/Resources/translations.json"

# 每个词翻译后的间隔（秒）
INTERVAL = 1.0
# 失败重试等待（秒）
RETRY_WAIT = 5
# 最大重试次数
MAX_RETRIES = 5

LANGUAGES = [
    ("zh", "zh-CN"),
    ("ja", "ja"),
    ("ko", "ko"),
]


def main():
    # 1. 读取词表
    with open(WORDS_PATH) as f:
        words = json.load(f)

    # 2. 加载已有翻译（断点续跑）
    if os.path.exists(OUT_PATH):
        with open(OUT_PATH) as f:
            all_translations = json.load(f)
    else:
        all_translations = {}

    total = len(words)
    done_before = len(all_translations)
    pending = [w for w in words if w["word"] not in all_translations]
    print(f"📝 总计 {total} 词，已完成 {done_before}，待翻译 {len(pending)}")

    if not pending:
        print("🎉 全部翻译完成！")
        return

    # 3. 逐词翻译
    done_count = done_before
    for lang_code, google_code in LANGUAGES:
        translator = GoogleTranslator(source="en", target=google_code)
        print(f"\n🌐 开始翻译 → {lang_code} ({google_code})")
        lang_pending = [w for w in pending if w["word"] not in all_translations
                        or lang_code not in all_translations[w["word"]]]
        print(f"   本语言待翻译: {len(lang_pending)} 词")

        for idx, w in enumerate(lang_pending):
            wid = w["word"]

            if wid not in all_translations:
                all_translations[wid] = {}

            # 已有该语言翻译则跳过
            if lang_code in all_translations[wid] and all_translations[wid][lang_code]:
                continue

            # 翻译（带重试）
            translated = None
            for attempt in range(1, MAX_RETRIES + 1):
                try:
                    translated = translator.translate(wid)
                    if translated:
                        break
                except Exception as e:
                    print(f"  ⚠️ [{wid}] 第 {attempt} 次失败: {e}")
                    if attempt < MAX_RETRIES:
                        time.sleep(RETRY_WAIT)

            if translated:
                all_translations[wid][lang_code] = translated
            else:
                all_translations[wid][lang_code] = ""
                print(f"  ❌ [{wid}] 翻译失败，留空")

            # 每翻译 1 词就保存
            with open(OUT_PATH, "w") as f:
                json.dump(all_translations, f, ensure_ascii=False, indent=2)

            done_count = len(all_translations)
            progress = f"[{idx+1}/{len(lang_pending)}]"
            print(f"  {progress} {wid} → {translated or ''}")

            time.sleep(INTERVAL)

        print(f"  ✅ {lang_code} 完成")

    total_done = len(all_translations)
    print(f"\n🎉 完成！共翻译 {total_done}/{total} 词")
    print(f"   输出: {OUT_PATH}")


if __name__ == "__main__":
    main()
