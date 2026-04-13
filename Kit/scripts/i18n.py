import os
import sys
import json
import urllib.request
import subprocess

try:
    import langcodes
except Exception:
    langcodes = None


def dictionary(lines):
    parsed_lines = {}
    for i, line in enumerate(lines):
        if line.startswith("//") or len(line) == 0 or line == "\n":
            continue
        line = line.replace("\n", "")
        pair = line.split(" = ")
        parsed_lines[i] = {
            "key": pair[0].replace('"', ""),
            "value": pair[1].replace('"', "").replace(';', "")
        }
    return parsed_lines


class i18n:
    path = os.getcwd() + "/Stats/Supporting Files/"

    def __init__(self):
        if "Kit/scripts" in os.getcwd():
            self.path = os.getcwd() + "/../../Stats/Supporting Files/"
        self.languages = list(filter(lambda x: x.endswith(".lproj"), os.listdir(self.path)))

    def en_file(self):
        with open(f"{self.path}/en.lproj/Localizable.strings", "r") as f:
            en_file = f.readlines()
        if en_file is None:
            sys.exit("English language not found.")
        return en_file

    def check(self):
        en_file = self.en_file()
        en_dict = dictionary(en_file)

        for lang in self.languages:
            with open(f"{self.path}/{lang}/Localizable.strings", "r") as f:
                file = f.readlines()
            name = lang.replace(".lproj", "")
            lang_dict = dictionary(file)

            for v in en_dict:
                en_key = en_dict[v].get("key")
                if v not in lang_dict:
                    sys.exit(f"missing key `{en_key}` in `{name}` on line `{v}`")
                lang_key = lang_dict[v].get("key")
                if lang_key != en_key:
                    sys.exit(f"missing or wrong key `{lang_key}` in `{name}` on line `{v}`, must be `{en_key}`")

        print(f"All fine, found {len(en_file)} lines in {len(self.languages)} languages.")

    def fix(self):
        en_file = self.en_file()
        en_dict = dictionary(en_file)

        for v in en_dict:
            en_key = en_dict[v].get("key")
            en_value = en_dict[v].get("value")

            for lang in self.languages:
                lang_path = f"{self.path}/{lang}/Localizable.strings"
                with open(lang_path, "r") as f:
                    file = f.readlines()
                lang_dict = dictionary(file)

                if v not in lang_dict or en_key != lang_dict[v].get("key"):
                    file.insert(v, f"\"{en_key}\" = \"{en_value}\";\n")
                    with open(lang_path, "w") as f:
                        f.write("".join(file))

        self.check()

    def _normalize_lang_code(self, code):
        code = (code or "").strip()
        if code.endswith(".lproj"):
            code = code[:-6]
        return code.replace("-", "_")

    def _extract_translation(self, raw, fallback):
        raw = (raw or "").strip()
        if not raw:
            return fallback

        def _clean(s):
            return (s or "").strip().strip("*").strip('"').strip("'").strip()

        def _from_dict(obj):
            if not isinstance(obj, dict):
                return None

            role = (obj.get("role") or "").strip().lower()
            obj_type = (obj.get("type") or "").strip().lower()

            text = obj.get("text")
            if isinstance(text, str) and text.strip():
                if role in ("assistant", "translation") or obj_type == "translation":
                    return _clean(text)

            content = obj.get("content")
            if isinstance(content, list):
                for item in content:
                    if not isinstance(item, dict):
                        continue
                    item_role = (item.get("role") or role).strip().lower()
                    item_type = (item.get("type") or "").strip().lower()
                    t = item.get("text")
                    if isinstance(t, str) and t.strip():
                        if item_role in ("assistant", "translation") or item_type in ("translation", "text"):
                            return _clean(t)
            return None

        try:
            parsed = json.loads(raw)
            if isinstance(parsed, dict):
                hit = _from_dict(parsed)
                if hit:
                    return hit
            elif isinstance(parsed, list):
                for item in parsed:
                    hit = _from_dict(item)
                    if hit:
                        return hit
        except json.JSONDecodeError:
            pass

        if "\n" not in raw and len(raw) <= 200:
            candidate = _clean(raw)
            if candidate and not candidate.startswith("{") and not candidate.startswith("["):
                return candidate

        for line in raw.splitlines():
            line = _clean(line)
            if line and not line.startswith("{") and not line.startswith("["):
                return line

        return fallback

    def _lang_name_from_code(self, code):
        c = self._normalize_lang_code(code).replace("_", "-").strip()
        if not c:
            return "Unknown"

        if langcodes:
            try:
                name = langcodes.get(c).display_name("en")
                if name:
                    return name
            except Exception:
                pass

        return c

    def _script_hint(self, lang_code):
        lang = self._normalize_lang_code(lang_code).lower()
        hints = {
            "el": "Greek script only (Α-Ω, α-ω) except numbers/punctuation/brand names.",
            "ru": "Cyrillic script only except numbers/punctuation/brand names.",
            "uk": "Cyrillic script only except numbers/punctuation/brand names.",
            "bg": "Cyrillic script only except numbers/punctuation/brand names.",
            "ja": "Japanese writing system (Hiragana/Katakana/Kanji), no romaji unless required.",
            "zh_cn": "Simplified Chinese characters.",
            "zh_hans": "Simplified Chinese characters.",
            "zh_tw": "Traditional Chinese characters.",
            "zh_hant": "Traditional Chinese characters.",
            "ko": "Korean Hangul preferred.",
            "et": "Use Estonian only. Do not use Russian.",
        }
        return hints.get(lang, "")

    def _ollama_translate(self, text, target_lang, model="translategemma:4b", retries=2):
        url = "http://ai:11434/api/generate"
        tgt = self._normalize_lang_code(target_lang)
        lang = self._lang_name_from_code(tgt)
        script_hint = self._script_hint(tgt)

        prompt = (
            f"You are a professional English (en) to {lang} ({tgt}) translator. Your goal is to accurately convey the meaning and nuances of the original English text while adhering to {lang} grammar, vocabulary, and cultural sensitivities. Produce only the {lang} translation, without any additional explanations or commentary. Output only the final translated text. Do not add explanations, notes, JSON, markdown, or quotes. Preserve placeholders/tokens exactly \\(e\\.g\\. `%@`, `%d`, `{0}`, `MB/s`\\). Preserve punctuation, casing intent, and technical abbreviations. {script_hint} Please translate the following English text into {lang}:\\n\\n"
            f"{text}"
        )
        
        payload = {
            "model": model,
            "prompt": prompt,
            "stream": False,
        }

        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST"
        )

        with urllib.request.urlopen(req, timeout=240) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            raw = data.get("response", "").strip()

        return self._extract_translation(raw, fallback=text)

    def _line_authors(self, file_path):
        cmd = ["git", "blame", "--line-porcelain", file_path]
        out = subprocess.check_output(cmd, text=True, cwd=os.getcwd(), stderr=subprocess.DEVNULL)
        authors = []
        for line in out.splitlines():
            if line.startswith("author "):
                authors.append(line[len("author "):].strip())
        return authors

    def _file_author(self, authors):
        if not authors:
            return ""
        counts = {}
        for a in authors:
            if a:
                counts[a] = counts.get(a, 0) + 1
        if not counts:
            return ""
        return max(counts, key=counts.get)


    def _strings_escape(self, value):
        s = "" if value is None else str(value)
        s = s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
        return s

    def translate(self, model="translategemma:4b", accept=False):
        en_lines = self.en_file()
        en_dict = dictionary(en_lines)
        omit_keys = ["Swap"]
        ai_tag = f"// {model}"

        target_languages = [
            l for l in self.languages
            if not self._normalize_lang_code(l).lower().startswith("en")
#            if self._normalize_lang_code(l).lower() in ("sk")
        ]
        total_langs = len(target_languages)

        for lang_idx, lang in enumerate(target_languages, start=1):
            lang_code = lang.replace(".lproj", "")
            lang_name = self._lang_name_from_code(lang_code)
            lang_path = f"{self.path}/{lang}/Localizable.strings"

            with open(lang_path, "r") as f:
                old_lines = f.readlines()

            new_lines = old_lines[:]
            lang_dict = dictionary(old_lines)
            changed = False

            try:
                authors = self._line_authors(lang_path)
            except Exception:
                authors = [""] * len(old_lines)
            file_author = self._file_author(authors)

            candidates = []
            for i, en_item in en_dict.items():
                en_key = en_item.get("key")
                en_value = en_item.get("value")

                translate_item = lang_dict.get(i)
                translate_key = translate_item.get("key") if translate_item else None
                translate_value = translate_item.get("value") if translate_item else None

                if translate_item is None or translate_key != en_key:
                    line = f"\"{en_key}\" = \"{en_value}\";\n"
                    if i < len(new_lines):
                        new_lines.insert(i, line)
                    else:
                        new_lines.append(line)
                    if i <= len(authors):
                        authors.insert(i, file_author)
                    changed = True
                    translate_value = en_value

                if translate_key != en_key:
                    continue
                if en_key in omit_keys:
                    continue
                if i < len(authors) and file_author and authors[i] != file_author:
                    continue

                if translate_value is None or translate_value == en_value:
                    candidates.append((i, en_key, en_value))

            print("Candidates for translation in {} ({}): {}".format(lang_name, lang_code, len(candidates)))

            for idx, (i, en_key, en_value) in enumerate(candidates, start=1):
                translated = self._ollama_translate(en_value, lang_code, model=model)
                safe_translated = self._strings_escape(translated)
                print(f"[{lang_name} {lang_idx}/{total_langs}] {idx}/{len(candidates)} {en_key} -> {safe_translated}")

                translated_line = f"\"{en_key}\" = \"{safe_translated}\";\n"
                update_line = f"\"{en_key}\" = \"{safe_translated}\"; {ai_tag}\n"
                if i < len(new_lines):
                    if new_lines[i] != translated_line:
                        new_lines[i] = update_line
                        changed = True
                else:
                    new_lines.append(update_line)
                    changed = True

            if not changed:
                print(f"No changes for {lang_code} ({lang_code}).")
                continue

            if accept:
                with open(lang_path, "w") as f:
                    f.write("".join(new_lines))
                print(f"Saved: {lang_path}")
            else:
                answer = input(f"Save changes to {lang_path}? [Y/n]: ").strip().lower()
                if answer in ("", "y", "yes"):
                    with open(lang_path, "w") as f:
                        f.write("".join(new_lines))
                    print(f"Saved: {lang_path}")
                else:
                    print(f"Skipped: {lang_path}")

        print("Translation completed.")


if __name__ == "__main__":
    i18n = i18n()
    args = sys.argv[1:]
    accept = "--accept" in args
    args = [a for a in args if a != "--accept"]

    if len(sys.argv) >= 2 and sys.argv[1] == "fix":
        print("running fix command...")
        i18n.fix()
    elif len(sys.argv) >= 2 and sys.argv[1] == "translate":
        print("running translate command...")
        i18n.translate(accept=accept)
    else:
        print("running check command...")
        i18n.check()

    print("done")
